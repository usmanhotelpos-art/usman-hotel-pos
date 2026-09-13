import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'bt_service.dart';
import 'session.dart';
import 'stock_printer_settings.dart';

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
  String _serverUrl = '';
  bool _savingServer = false;

  Map<String, dynamic> _settings = {};
  List<String> _messageTypes = [];
  final _msgTypeCtrl = TextEditingController();
  bool _savingMsgType = false;

  @override
  void initState() {
    super.initState();
    _serverUrl = ApiClient.host;
    _boot();
  }

  @override
  void dispose() {
    _msgTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadSettings();
    await _loadMessageTypes();
    await _checkBluetooth();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMessageTypes() async {
    try {
      final types = await ApiClient.getMessageTypes(token: Session.token);
      if (types.isNotEmpty) {
        if (mounted) setState(() => _messageTypes = types.cast<String>());
      }
    } catch (_) {}
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
    final ok = await BtService.connect(p.mac);
    if (ok) {
      await BtService.savePrinter(p);
      setState(() {
        _savedMac = p.mac;
        _savedName = p.name;
        _btConnected = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${p.name}'), backgroundColor: Colors.green),
        );
      }
    } else {
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
                const SizedBox(height: 12),
                // Open full printer settings
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StockPrinterSettings()),
                      );
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('PRINTER SETTINGS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8).withOpacity(0.15),
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
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
          // Message Types Section (manager)
          _section(
            title: 'Message Types',
            icon: Icons.label_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgTypeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Naya message type...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          prefixIcon: Icon(Icons.label, color: Colors.white.withOpacity(0.3), size: 20),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _savingMsgType ? null : () => _addMessageType(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35)),
                        ),
                        child: _savingMsgType
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                              )
                            : const Icon(Icons.add, size: 18, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _messageTypes.map((t) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () => _renameMessageType(t),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.edit, size: 13, color: Color(0xFF38BDF8)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteMessageType(t),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close, size: 13, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ye types admin message dropdown aur replies mein use hote hain.',
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.35)),
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

  Future<void> _addMessageType() async {
    final name = _msgTypeCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Type ka naam likho'), backgroundColor: Color(0xFFF59E0B)),
        );
      }
      return;
    }
    if (_messageTypes.contains(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ye type pehle se mojood hai'), backgroundColor: Color(0xFFF59E0B)),
        );
      }
      return;
    }
    setState(() => _savingMsgType = true);
    try {
      final types = await ApiClient.createMessageType(name, token: Session.token);
      if (mounted) {
        setState(() {
          _messageTypes = types.cast<String>();
          _msgTypeCtrl.clear();
          _savingMsgType = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
      setState(() => _savingMsgType = false);
    }
  }

  Future<void> _renameMessageType(String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Message Type',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Naya naam',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    try {
      final types = await ApiClient.updateMessageType(oldName, newName, token: Session.token);
      if (mounted) {
        setState(() => _messageTypes = types.cast<String>());
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteMessageType(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Delete "$name"?', style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text('Message type hata diya jayega.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final types = await ApiClient.deleteMessageType(name, token: Session.token);
      if (mounted) {
        setState(() => _messageTypes = types.cast<String>());
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
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