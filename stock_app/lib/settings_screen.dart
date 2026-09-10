import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bt_service.dart';
import 'session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _btConnected = false;
  bool _btEnabled = false;
  String? _savedMac;
  String? _savedName;
  List<PrinterInfo> _pairedDevices = [];
  String _message = '';
  String _serverUrl = '';
  bool _savingServer = false;

  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _serverUrl = ApiClient.host;
    _boot();
  }

  Future<void> _boot() async {
    await _loadSettings();
    await _checkBluetooth();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiClient.getSettings(token: Session.token);
      if (mounted) setState(() => _settings = settings);
    } catch (_) {}
  }

  Future<void> _checkBluetooth() async {
    final saved = await BtService.savedPrinter();
    setState(() {
      _savedMac = saved?.mac;
      _savedName = saved?.name;
    });
    _btEnabled = await BtService.isBluetoothEnabled();
    _btConnected = await BtService.isConnected() && _savedMac != null;
    if (_btEnabled) {
      _pairedDevices = await BtService.getPairedDevices();
    }
  }

  Future<void> _enableBt() async {
    final ok = await BtService.enableBluetooth();
    if (ok) {
      await _checkBluetooth();
    }
  }

  Future<void> _connectPrinter(PrinterInfo p) async {
    setState(() => _message = 'Connecting to ${p.name}...');
    final ok = await BtService.connect(p.mac);
    if (ok) {
      await BtService.savePrinter(p);
      setState(() {
        _savedMac = p.mac;
        _savedName = p.name;
        _btConnected = true;
        _message = 'Connected to ${p.name}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${p.name}'), backgroundColor: Colors.green),
        );
      }
    } else {
      setState(() => _message = BtService.lastError);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${BtService.lastError}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await BtService.disconnect();
    await BtService.clearPrinter();
    setState(() {
      _savedMac = null;
      _savedName = null;
      _btConnected = false;
      _message = '';
    });
  }

  Future<void> _saveServer() async {
    setState(() => _savingServer = true);
    try {
      ApiClient.setHost(_serverUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stock_serverUrl', ApiClient.host);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server saved'), backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid server URL'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingServer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
    }

    return RefreshIndicator(
      onRefresh: _checkBluetooth,
      color: const Color(0xFF38BDF8),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bluetooth Printer Section
          _section(
            title: 'Bluetooth Printer',
            icon: Icons.print_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bluetooth status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _btEnabled ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        size: 22,
                        color: _btEnabled ? const Color(0xFF38BDF8) : Colors.white24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _btEnabled ? 'Bluetooth is ON' : 'Bluetooth is OFF',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _btEnabled ? Colors.white : Colors.white38,
                              ),
                            ),
                            Text(
                              _btConnected
                                  ? 'Printer: $_savedName ($_savedMac)'
                                  : _savedMac != null
                                      ? 'Saved: $_savedName'
                                      : 'No printer configured',
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45)),
                            ),
                          ],
                        ),
                      ),
                      if (!_btEnabled)
                        TextButton(
                          onPressed: _enableBt,
                          child: const Text('Enable',
                              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
                        )
                      else if (_btConnected)
                        TextButton(
                          onPressed: _disconnect,
                          child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                        )
                      else if (_savedMac != null)
                        TextButton(
                          onPressed: () => _connectPrinter(PrinterInfo(_savedName ?? 'Printer', _savedMac!)),
                          child: const Text('Connect',
                              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_message, style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
                const SizedBox(height: 12),
                const Text(
                  'PAIRED PRINTERS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                if (_pairedDevices.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _btEnabled ? 'No paired devices found. Pair from Android settings first.' : 'Enable Bluetooth to find printers.',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._pairedDevices.map((p) {
                    final selected = p.mac == _savedMac;
                    return GestureDetector(
                      onTap: () => _connectPrinter(p),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF38BDF8).withOpacity(0.1) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF38BDF8).withOpacity(0.3) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.print, size: 20, color: selected ? const Color(0xFF38BDF8) : Colors.white38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              p.mac,
                              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Server Settings Section
          _section(
            title: 'Server',
            icon: Icons.dns_outlined,
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => _serverUrl = v,
                  controller: TextEditingController(text: _serverUrl),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Server URL',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(Icons.dns, color: Colors.white.withOpacity(0.3), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingServer ? null : _saveServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _savingServer
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('SAVE SERVER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hotel Info
          _section(
            title: 'Hotel',
            icon: Icons.apartment_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF38BDF8).withOpacity(0.15),
                      child: const Icon(Icons.apartment, size: 20, color: Color(0xFF38BDF8)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Usman Hotel',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text(
                            'Karachi, Pakistan',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat('Hotel', _settings['hotelName'] ?? 'Usman Hotel'),
                    const SizedBox(width: 8),
                    _miniStat('Currency', _settings['currency'] ?? 'PKR'),
                    const SizedBox(width: 8),
                    _miniStat('Location', _settings['location'] ?? 'Karachi'),
                  ],
                ),
                if (_settings['stockOrderCounter'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniStat('Date', _settings['stockOrderCounter']['date'] ?? '-'),
                      const SizedBox(width: 8),
                      _miniStat('Orders', '${_settings['stockOrderCounter']['count'] ?? 0}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}