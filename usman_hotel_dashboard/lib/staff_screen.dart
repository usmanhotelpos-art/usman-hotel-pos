import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';

String sOf(dynamic v) => v == null ? '' : v.toString();
double numOf(dynamic v) {
  final d = double.tryParse(sOf(v).replaceAll(',', ''));
  return d ?? 0;
}

const Color _accent = Color(0xFF059669);

const List<String> _roles = [
  'Admin',
  'Admin Rider',
  'Manager',
  'Cashier',
  'Biker',
  'Waiter',
  'Helper',
  'Tandoor Staff',
  'Order Taker',
  'Admin Order Taker',
  'Takeaway Order Taker',
  'Table Order Taker',
];

Color _roleColor(String role) {
  switch (role) {
    case 'Admin':
      return const Color(0xFFDC2626);
    case 'Admin Rider':
      return const Color(0xFFEA580C);
    case 'Manager':
      return const Color(0xFF7C3AED);
    case 'Cashier':
      return const Color(0xFF0D9488);
    case 'Biker':
      return const Color(0xFF0EA5E9);
    case 'Waiter':
      return const Color(0xFFF59E0B);
    case 'Helper':
      return const Color(0xFF64748B);
    case 'Tandoor Staff':
      return const Color(0xFFF97316);
    case 'Order Taker':
      return const Color(0xFF4F46E5);
    case 'Admin Order Taker':
      return const Color(0xFF8B5CF6);
    case 'Takeaway Order Taker':
      return const Color(0xFFEC4899);
    case 'Table Order Taker':
      return const Color(0xFF06B6D4);
    default:
      return const Color(0xFF64748B);
  }
}

void _toast(BuildContext context, String msg, {Color? bg}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontSize: 12.5)),
    backgroundColor: bg ?? (Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E2A44)
        : const Color(0xFF111827)),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}

String _initials(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _faceUrl(String src) {
  final s = sOf(src).trim();
  if (s.isEmpty) return '';
  if (s.startsWith('http')) return s;
  final host = ApiClient.host.trim();
  if (host.isEmpty) return s;
  if (s.startsWith('http') == false && s.startsWith('/')) {
    return '$host$s';
  }
  return '$host/$s';
}

class StaffScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  const StaffScreen({super.key, required this.token, required this.user});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late String _token = widget.token;
  List<dynamic> _staff = [];
  bool _loading = true;
  bool _fetching = false;
  String _err = '';
  String _q = '';
  String _roleFilter = 'All';
  final Set<String> _revealed = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<dynamic>> _fetchStaff(String token) async {
    try {
      final data = await ApiClient.send('GET', '/staff', token: token);
      if (data is List) return data;
      return const [];
    } on ApiException catch (e) {
      if (!e.isAuthError) rethrow;
      final r = await ApiClient.login(dashEmail, dashPassword);
      final newTok = r['token'];
      if (newTok is! String) rethrow;
      await saveSession(newTok, r['user']);
      _token = newTok;
      return _fetchStaff(newTok);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _fetching) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _err = '';
        _fetching = true;
      });
    }
    try {
      final data = await _fetchStaff(_token);
      if (!mounted) return;
      setState(() {
        _staff = data;
        _fetching = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _fetching = false;
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    final out = _staff.where((m) {
      if (m is! Map) return false;
      if (_roleFilter != 'All' && sOf(m['role']) != _roleFilter) return false;
      final q = _q.trim().toLowerCase();
      if (q.isEmpty) return true;
      return sOf(m['name']).toLowerCase().contains(q) ||
          sOf(m['username']).toLowerCase().contains(q) ||
          sOf(m['phone']).toLowerCase().contains(q) ||
          sOf(m['role']).toLowerCase().contains(q);
    }).toList();
    return out;
  }

  int get _activeCount =>
      _staff.where((m) => m is Map && sOf(m['status']).toLowerCase() == 'active')
          .length;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 14,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt, size: 22, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff Management',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    Text('${_staff.length} members · $_activeCount active',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: dark
                                ? const Color(0xFF9FB0C9)
                                : const Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search name, username, phone, role...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _addButton(context),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _roleChip('All', _roleFilter),
              ..._roles.map((r) => _roleChip(r, _roleFilter)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _err.isNotEmpty
                  ? _errorView()
                  : RefreshIndicator(
                      color: _accent,
                      onRefresh: () => _load(),
                      child: _filtered.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.only(top: 140),
                                  child: Center(
                                    child: Text(
                                      'No staff found',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 26),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) =>
                                  _staffCard(context,
                                      Map<String, dynamic>.from(_filtered[i] as Map)),
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String selected) {
    final sel = role == selected;
    final c = role == 'All' ? _accent : _roleColor(role);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(role, style: const TextStyle(fontSize: 11)),
        selected: sel,
        onSelected: (_) => setState(() => _roleFilter = role),
        selectedColor: c,
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : const Color(0xFF475569)),
        side: BorderSide(color: sel ? c : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _busy ? null : () => _openForm(context, editing: null, duplicating: null),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.person_add, size: 16),
      label: const Text('Add Staff',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _staffCard(BuildContext context, Map<String, dynamic> m) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final id = sOf(m['id']);
    final name = sOf(m['name']);
    final role = sOf(m['role']);
    final status = sOf(m['status']).toLowerCase();
    final activeStatus = status == 'active';
    final rc = _roleColor(role.isEmpty ? 'Unknown' : role);
    final face = _faceUrl(sOf(m['facePhoto']));
    final isRider = role == 'Biker' || role == 'Admin Rider';
    final hasRider = sOf(m['riderId']).isNotEmpty;
    final pwd = sOf(m['password']);
    final reveal = _revealed.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (role == 'Biker')
                ? const Color(0xFF0EA5E9).withValues(alpha: .35)
                : (dark ? const Color(0xFF1E2A44) : const Color(0xFFE5EAF2))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // avatar
              ClipOval(
                child: face.isNotEmpty
                    ? Image.network(
                        face,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(name, rc),
                      )
                    : _avatarFallback(name, rc),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w900)),
                      ),
                      if (isRider) ...[
                        const SizedBox(width: 5),
                        const Text('🚴', style: TextStyle(fontSize: 12)),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      _badge(role.isEmpty ? '—' : role, rc,
                          light: role == 'Biker'),
                      _badge(
                        status.isEmpty ? 'inactive' : status,
                        activeStatus
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                        light: false,
                      ),
                      if (hasRider)
                        _badge('rider linked', const Color(0xFF0EA5E9),
                            light: false),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconColor: const Color(0xFF94A3B8),
                onSelected: (a) => _onAction(context, m, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('📋 Duplicate')),
                  if (hasRider)
                    const PopupMenuItem(
                        value: 'pw', child: Text('🔑 View Rider Password')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('🗑 Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _infoRow(context, Icons.alternate_email, 'Username', sOf(m['username'])),
          _infoRow(context, Icons.phone, 'Phone', sOf(m['phone'])),
          _pwdRow(context, m, pwd, reveal),
          if (sOf(m['idCardNumber']).isNotEmpty)
            _infoRow(context, Icons.credit_card, 'ID Card', sOf(m['idCardNumber'])),
          if (sOf(m['address']).isNotEmpty)
            _infoRow(context, Icons.location_on_outlined, 'Address',
                sOf(m['address'])),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name, Color c) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: .15),
        shape: BoxShape.circle,
      ),
      child: Text(_initials(name),
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: c)),
    );
  }

  Widget _badge(String text, Color c, {bool light = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: light ? .15 : .12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: .35)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5)),
          ),
        ],
      ),
    );
  }

  Widget _pwdRow(BuildContext context, Map m, String pwd, bool reveal) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mono = const Color(0xFF0EA5E9);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 13, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text('Password: ',
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              reveal ? (pwd.isEmpty ? '••••••' : pwd) : '••••••',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: reveal && pwd.isNotEmpty
                      ? mono
                      : (dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              if (reveal) {
                _revealed.remove(sOf(m['id']));
              } else {
                _revealed.add(sOf(m['id']));
              }
            }),
            child: Icon(
              reveal ? Icons.visibility_off : Icons.visibility,
              size: 16,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            Text(_err,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, Map m, String action) async {
    switch (action) {
      case 'edit':
        await _openForm(context, editing: m, duplicating: null);
        break;
      case 'duplicate':
        await _openForm(context, editing: null, duplicating: m);
        break;
      case 'pw':
        await _viewRiderPassword(context, m);
        break;
      case 'delete':
        await _confirmDelete(context, m);
        break;
    }
  }

  Future<void> _viewRiderPassword(BuildContext context, Map m) async {
    final riderId = sOf(m['riderId']);
    if (riderId.isEmpty) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await ApiClient.send('GET', '/riders/raw/$riderId',
          token: _token);
      final pwd = (data is Map)
          ? (sOf(data['password']).isNotEmpty
              ? sOf(data['password'])
              : sOf(data['rawPassword']))
          : '';
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Rider Password — ${sOf(m['name'])}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          content: Text(pwd.isEmpty ? '(no plain password stored)' : pwd,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0EA5E9))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      _toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map m) async {
    final id = sOf(m['id']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
            'Delete ${sOf(m['name'])} (${sOf(m['role'])})? This cannot be undone.',
            style: const TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      await ApiClient.send('DELETE', '/staff/$id', token: _token);
      if (!mounted) return;
      _toast(context, '${sOf(m['name'])} deleted 🗑');
      await _load(silent: true);
    } catch (e) {
      _toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm(BuildContext context,
      {Map? editing, Map? duplicating}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _StaffFormSheet(
        editing: editing,
        duplicating: duplicating,
      ),
    );
    if (result == null || !mounted) return;
    await _saveStaff(context, editing ?? duplicating, result);
  }

  Future<void> _saveStaff(
      BuildContext context, Map? existing, Map<String, dynamic> payload) async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = sOf(payload['name']).trim();
    final username = sOf(payload['username']).trim();
    final role = sOf(payload['role']);
    final password = sOf(payload['password']).trim();
    final phone = sOf(payload['phone']).trim();
    final loginEnabled = payload['loginEnabled'] == true;

    // Basic validation
    if (name.isEmpty || username.isEmpty || role.isEmpty) {
      _toast(context, 'Name, username aur role required hain');
      setState(() => _busy = false);
      return;
    }
    if (existing == null && password.isEmpty) {
      _toast(context, 'New staff ke liye password zaroori hai');
      setState(() => _busy = false);
      return;
    }
    if ((role == 'Biker' || role == 'Admin Rider') && phone.isEmpty) {
      _toast(context, 'Biker/Admin Rider ke liye phone required hai');
      setState(() => _busy = false);
      return;
    }

    try {
      Map<String, dynamic> record;
      if (existing != null) {
        final id = sOf(existing['id']);
        final body = Map<String, dynamic>.from(payload);
        if (password.isEmpty) body.remove('password');
        record = Map<String, dynamic>.from(
            await ApiClient.send('PUT', '/staff/$id', token: _token, body: body));
      } else {
        record = Map<String, dynamic>.from(await ApiClient.send(
            'POST', '/staff',
            token: _token, body: {...payload, 'status': 'active'}));
      }
      final recordId = sOf(record['id']);

      // Rider linking for Biker / Admin Rider roles
      bool isRiderRole = role == 'Biker' || role == 'Admin Rider';
      String riderId = sOf(record['riderId']);
      if (isRiderRole && loginEnabled) {
        if (riderId.isEmpty) {
          try {
            final rider = await ApiClient.send('POST', '/riders/create',
                token: _token,
                body: {
                  'name': name,
                  'phone': phone,
                  'email': username,
                  'username': username,
                  'password': password,
                  'role': role == 'Admin Rider' ? 'Admin Rider' : 'Rider',
                });
            if (rider is Map) {
              riderId = sOf(rider['id']);
            }
          } catch (_) {}
        } else if (password.isNotEmpty) {
          try {
            await ApiClient.send('POST', '/rider/set-password', token: _token,
                body: {'id': riderId, 'password': password});
          } catch (_) {}
        }
        if (riderId.isNotEmpty && sOf(record['riderId']) != riderId) {
          await ApiClient.send('PUT', '/staff/$recordId', token: _token,
              body: {'riderId': riderId});
        }
      }

      if (!mounted) return;
      _toast(context, existing != null
          ? '${sOf(payload['name'])} updated ✅'
          : '${sOf(payload['name'])} added ✅');
      await _load(silent: true);
    } catch (e) {
      if (mounted) _toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StaffFormSheet extends StatefulWidget {
  final Map? editing;
  final Map? duplicating;
  const _StaffFormSheet({this.editing, this.duplicating});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  late final bool isNew = widget.editing == null;
  late final TextEditingController _name =
      TextEditingController(text: sOf(_src['name']));
  late final TextEditingController _otherName =
      TextEditingController(text: sOf(_src['otherName']));
  late final TextEditingController _phone =
      TextEditingController(text: sOf(_src['phone']));
  late final TextEditingController _username =
      TextEditingController(text: sOf(_src['username']));
  late final TextEditingController _password = TextEditingController();
  late final TextEditingController _idCard =
      TextEditingController(text: sOf(_src['idCardNumber']));
  late final TextEditingController _description =
      TextEditingController(text: sOf(_src['description']));
  late final TextEditingController _address =
      TextEditingController(text: sOf(_src['address']));
  late String _role =
      (sOf(_src['role']).isNotEmpty ? sOf(_src['role']) : _roles.first);
  late bool _loginEnabled =
      widget.editing == null || widget.editing!['loginEnabled'] == true;
  bool _obscured = true;
  bool _saving = false;

  Map get _src {
    if (widget.editing != null) return widget.editing!;
    if (widget.duplicating != null) return widget.duplicating!;
    return const {};
  }

  bool get _isRiderRole => _role == 'Biker' || _role == 'Admin Rider';

  @override
  void dispose() {
    _name.dispose();
    _otherName.dispose();
    _phone.dispose();
    _username.dispose();
    _password.dispose();
    _idCard.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
        'name': _name.text.trim(),
        'otherName': _otherName.text.trim(),
        'phone': _phone.text.trim(),
        'username': _username.text.trim(),
        if (_password.text.trim().isNotEmpty)
          'password': _password.text.trim(),
        'role': _role,
        'idCardNumber': _idCard.text.trim(),
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'loginEnabled': _loginEnabled,
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(isNew ? '➕ Add Staff' : '✏️ Edit Staff',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18)),
            ]),
            const SizedBox(height: 8),
            _field('Name *', _name),
            _field('Other Name', _otherName),
            _field('Phone ${_isRiderRole ? '*' : ''}', _phone,
                hint: _isRiderRole ? 'Required for rider role' : null),
            _field('Username *', _username),
            _field(isNew ? 'Password *' : 'New Password (blank = keep)', _password,
                obscured: _obscured,
                suffix: IconButton(
                  icon: Icon(
                      _obscured ? Icons.visibility : Icons.visibility_off,
                      size: 17),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )),
            const SizedBox(height: 8),
            const Text('Role *',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _roles
                  .map((r) => ChoiceChip(
                        label: Text(r, style: const TextStyle(fontSize: 10.5)),
                        selected: _role == r,
                        onSelected: (_) => setState(() => _role = r),
                        selectedColor: _roleColor(r),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _role == r ? Colors.white : const Color(0xFF475569)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _field('ID Card Number', _idCard),
            _field('Description', _description),
            _field('Address', _address),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Login Enabled',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              subtitle: _isRiderRole
                  ? const Text('Biker/Admin Rider: rider account bhi bane ga',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))
                  : null,
              value: _loginEnabled,
              activeThumbColor: _accent,
              onChanged: (v) => setState(() => _loginEnabled = v),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (_name.text.trim().isEmpty ||
                            _username.text.trim().isEmpty ||
                            _role.isEmpty) {
                          _toast(context, 'Name, username aur role required');
                          return;
                        }
                        setState(() => _saving = true);
                        Navigator.pop(context, _payload());
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saving ? 'Saving...' : (isNew ? 'Add Staff' : 'Save Changes'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool obscured = false, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            obscureText: obscured,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              suffixIcon: suffix,
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ],
      ),
    );
  }
}