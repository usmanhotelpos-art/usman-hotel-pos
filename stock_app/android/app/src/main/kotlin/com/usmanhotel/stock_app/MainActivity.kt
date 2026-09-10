package com.usmanhotel.stock_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.lang.reflect.Method
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val channelName = "usmanhotel/bt"
    private val permRequestCode = 7001

    private var socket: BluetoothSocket? = null
    private var out: OutputStream? = null
    private var pendingPermResult: MethodChannel.Result? = null

    private fun adapter(): BluetoothAdapter? {
        val manager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    }

    private fun connectPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= 31) {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectPermissionGranted" ->
                        result.success(connectPermissionGranted())

                    "requestPermissions" -> {
                        if (connectPermissionGranted()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        val perms = mutableListOf<String>()
                        if (Build.VERSION.SDK_INT >= 31) {
                            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
                            perms.add(Manifest.permission.BLUETOOTH_SCAN)
                        } else {
                            perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
                        }
                        pendingPermResult = result
                        ActivityCompat.requestPermissions(
                            this, perms.toTypedArray(), permRequestCode
                        )
                    }

                    "bluetoothEnabled" -> {
                        val a = adapter()
                        result.success(a != null && a.isEnabled)
                    }

                    "enableBluetooth" -> {
                        val a = adapter()
                        if (a != null && !a.isEnabled) {
                            a.enable()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }

                    "pairedDevices" -> {
                        if (!connectPermissionGranted()) {
                            result.error("PERMISSION", "Bluetooth permission missing", null)
                            return@setMethodCallHandler
                        }
                        val a = adapter() ?: run {
                            result.success(emptyList<String>())
                            return@setMethodCallHandler
                        }
                        try {
                            val list = a.bondedDevices
                                .filter { it.address.isNotBlank() }
                                .map { "${safeName(it)}#${it.address}" }
                            result.success(list)
                        } catch (e: SecurityException) {
                            result.error("PERMISSION", "Bluetooth permission missing", null)
                        }
                    }

                    "isConnected" -> {
                        val s = socket
                        result.success(out != null && s != null && s.isConnected)
                    }

                    "connect" -> {
                        if (!connectPermissionGranted()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val mac = (call.arguments as? String)?.trim()?.uppercase()
                            ?: run {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                        Thread {
                            val err = connectSpp(mac)
                            runOnUiThread { result.success(err == null) }
                            if (err != null) {
                                android.util.Log.e("StockBT", "connect($mac): $err")
                            }
                        }.start()
                    }

                    "lastError" -> result.success(lastError)

                    "disconnect" -> {
                        closeSocketQuietly()
                        result.success(true)
                    }

                    "writeBytes" -> {
                        val os = out
                        if (os == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val args = call.arguments
                        val bytes: ByteArray? = when (args) {
                            is ByteArray -> args
                            is IntArray -> ByteArray(args.size) { i -> args[i].toByte() }
                            is List<*> -> {
                                val arr = ByteArray(args.size)
                                args.forEachIndexed { idx, v ->
                                    arr[idx] = (v as? Number)?.toByte() ?: 0
                                }
                                arr
                            }
                            else -> null
                        }
                        if (bytes == null) {
                            lastError = "Invalid print data"
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (bytes.isEmpty()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val ok = try {
                                var offset = 0
                                while (offset < bytes.size) {
                                    val end = minOf(offset + 1024, bytes.size)
                                    os.write(bytes, offset, end - offset)
                                    os.flush()
                                    offset = end
                                }
                                true
                            } catch (e: Exception) {
                                android.util.Log.e("StockBT", "write failed: ${e.message}")
                                closeSocketQuietly()
                                false
                            }
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private var lastError: String = ""

    @SuppressLint("MissingPermission")
    private fun safeName(d: BluetoothDevice): String =
        try { d.name?.takeIf { it.isNotBlank() } ?: d.address } catch (_: Exception) { d.address }

    private fun closeSocketQuietly() {
        try { out?.flush() } catch (_: Exception) {}
        try { out?.close() } catch (_: Exception) {}
        try { socket?.close() } catch (_: Exception) {}
        out = null
        socket = null
    }

    @SuppressLint("MissingPermission")
    private fun connectSpp(mac: String): String? {
        lastError = ""
        try {
            val a = adapter() ?: run { lastError = "Bluetooth adapter not available"; return lastError }
            if (!a.isEnabled) { lastError = "Phone ka Bluetooth OFF hai"; return lastError }

            closeSocketQuietly()

            val device: BluetoothDevice = try {
                a.getRemoteDevice(mac)
            } catch (e: IllegalArgumentException) {
                lastError = "Printer MAC address invalid ($mac)"
                return lastError
            }

            try { a.cancelDiscovery() } catch (_: Exception) {}

            val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            var firstError: Exception? = null

            try {
                val s = device.createRfcommSocketToServiceRecord(uuid)
                s.connect()
                socket = s; out = s.outputStream
                return null
            } catch (e: Exception) {
                firstError = e
                try { socket?.close() } catch (_: Exception) {}
                socket = null
            }

            try {
                val s = device.createInsecureRfcommSocketToServiceRecord(uuid)
                s.connect()
                socket = s; out = s.outputStream
                return null
            } catch (e: Exception) {
                try { socket?.close() } catch (_: Exception) {}
                socket = null
            }

            try {
                val m: Method = device.javaClass.getMethod(
                    "createRfcommSocket", Int::class.javaPrimitiveType
                )
                val s = m.invoke(device, 1) as BluetoothSocket
                try { a.cancelDiscovery() } catch (_: Exception) {}
                s.connect()
                socket = s; out = s.outputStream
                return null
            } catch (e: Exception) {
                lastError = "Connect failed: ${firstError?.message ?: e.message}"
                return lastError
            }
        } catch (e: SecurityException) {
            lastError = "Bluetooth permission missing - dobara attach karein"
            return lastError
        } catch (e: Exception) {
            lastError = "Connect failed: ${e.message}"
            return lastError
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermResult?.success(granted)
            pendingPermResult = null
        }
    }

    override fun onDestroy() {
        closeSocketQuietly()
        super.onDestroy()
    }
}