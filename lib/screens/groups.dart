import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'groupDetail.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final User? _user = SupabaseService.client.auth.currentUser;

  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncProfile();
    _loadGroups();
  }

  Future<void> _syncProfile() async {
    final user = _user;
    if (user == null) return;
    try {
      final meta = user.userMetadata;
      await SupabaseService.client.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': (meta?['display_name'] ?? '').toString(),
      });
    } catch (_) {
    }
  }

  void _showSnackBar(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _loadGroups() async {
    final user = _user;
    if (user == null) return;

    try {
      final rows = await SupabaseService.client
          .from('group_members')
          .select('role, groups(id, name, invite_code, created_by)')
          .eq('user_id', user.id);

      final list = <Map<String, dynamic>>[];
      for (final r in rows) {
        final g = r['groups'];
        if (g == null) continue;
        list.add({...Map<String, dynamic>.from(g), 'role': r['role']});
      }

      if (!mounted) return;
      setState(() {
        _groups = list;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Топтарды жүктеу мүмкін болмады.\nSupabase-те SQL орындалғанын тексеріңіз';
      });
    }
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Жаңа топ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Топ атауы (мысалы: #405 бөлме)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Бас тарту'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Құру'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      await SupabaseService.client
          .rpc('create_group', params: {'group_name': name});
      await _loadGroups();
      _showSnackBar('Топ құрылды', color: Colors.green);
    } on PostgrestException catch (e) {
      _showSnackBar('Қате: ${e.message}');
    } catch (_) {
      _showSnackBar('Топ құру мүмкін болмады');
    }
  }

  Future<void> _joinGroup() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Топқа қосылу'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Шақыру коды',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Бас тарту'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Қосылу'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      await SupabaseService.client.rpc('join_group', params: {'code': code});
      await _loadGroups();
      _showSnackBar('Топқа қосылдыңыз', color: Colors.green);
    } on PostgrestException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Топқа қосылу мүмкін болмады');
    }
  }

  Future<void> _openGroup(Map<String, dynamic> g) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          groupId: g['id'].toString(),
          groupName: (g['name'] ?? '').toString(),
          inviteCode: (g['invite_code'] ?? '').toString(),
          isAdmin: g['role'] == 'admin',
        ),
      ),
    );
    _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Топтар'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Код арқылы қосылу',
            icon: const Icon(Icons.login),
            onPressed: _joinGroup,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.group_add),
        label: const Text('Топ құру'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  if (_error != null)
                    _message(Icons.error_outline, _error!)
                  else if (_groups.isEmpty)
                    _message(
                      Icons.groups_outlined,
                      'Сіз әлі ешбір топта жоқсыз.\n"Топ құру" батырмасын басыңыз\nнемесе шақыру коды арқылы қосылыңыз',
                    )
                  else
                    for (final g in _groups)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.line),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: primary.withOpacity(0.12),
                            child: Icon(Icons.groups, color: primary),
                          ),
                          title: Text(
                            (g['name'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            g['role'] == 'admin'
                                ? 'Сіз — топ иесі (админ)'
                                : 'Қатысушы',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openGroup(g),
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(icon, size: 60, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
