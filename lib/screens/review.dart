import 'package:flutter/material.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'package:flutter_application_5/utils.dart';
import 'taskDetail.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final String? _uid = SupabaseService.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _toReview = [];
  List<Map<String, dynamic>> _mineSubmitted = [];
  List<Map<String, dynamic>> _mineReturned = [];
  Map<String, String> _names = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    final client = SupabaseService.client;

    try {
      final adminRows = await client
          .from('group_members')
          .select('group_id')
          .eq('user_id', uid)
          .eq('role', 'admin');
      final groupIds = adminRows.map((r) => r['group_id']).toList();

      final toReview = groupIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(await client
              .from('tasks')
              .select()
              .inFilter('group_id', groupIds)
              .eq('status', 'жіберілді')
              .order('submitted_at', ascending: true));

      final mineSubmitted = List<Map<String, dynamic>>.from(await client
          .from('tasks')
          .select()
          .eq('assigned_to', uid)
          .eq('status', 'жіберілді')
          .order('submitted_at', ascending: true));

      final mineReturned = List<Map<String, dynamic>>.from(await client
          .from('tasks')
          .select()
          .eq('assigned_to', uid)
          .eq('status', 'орындалуда')
          .not('review_comment', 'is', null));

      final ids = <String>{
        for (final t in toReview)
          if (t['assigned_to'] != null) t['assigned_to'].toString(),
      }.toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        try {
          final users = await client
              .from('users')
              .select('id, full_name, email')
              .inFilter('id', ids);
          for (final u in users) {
            String n = (u['full_name'] ?? '').toString().trim();
            if (n.isEmpty) n = (u['email'] ?? '').toString();
            if (n.isNotEmpty) names[u['id'].toString()] = n;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _toReview = toReview;
        _mineSubmitted = mineSubmitted;
        _mineReturned = mineReturned;
        _names = names;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Жүктеу мүмкін болмады.\nSQL (supabase_stage2.sql) орындалғанын тексеріңіз';
      });
    }
  }

  Future<void> _open(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: task['id']),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _toReview.isEmpty &&
        _mineSubmitted.isEmpty &&
        _mineReturned.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бақылау'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _message(Icons.error_outline, _error!)
                  else if (empty)
                    _message(
                      Icons.verified_outlined,
                      'Тексеретін немесе күтіп тұрған есеп жоқ',
                    )
                  else ...[
                    if (_toReview.isNotEmpty) ...[
                      _header('Тексеруді күтіп тұр (${_toReview.length})'),
                      for (final t in _toReview)
                        _tile(
                          t,
                          icon: Icons.fact_check_outlined,
                          color: Colors.blue,
                          subtitle:
                              'Орындаушы: ${_names[t['assigned_to']?.toString()] ?? (t['assigned_to'] == _uid ? 'Мен' : 'Қатысушы')}',
                        ),
                    ],
                    if (_mineReturned.isNotEmpty) ...[
                      _header('Қайта өңдеуге қайтарылған'),
                      for (final t in _mineReturned)
                        _tile(
                          t,
                          icon: Icons.undo,
                          color: Colors.red,
                          subtitle: 'Себебі: ${t['review_comment']}',
                        ),
                    ],
                    if (_mineSubmitted.isNotEmpty) ...[
                      _header('Мен жіберген, тексеруді күтуде'),
                      for (final t in _mineSubmitted)
                        _tile(
                          t,
                          icon: Icons.hourglass_top,
                          color: Colors.orange,
                          subtitle: 'Тексерілуде',
                        ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tile(
    Map<String, dynamic> t, {
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    final dl = DateTime.tryParse((t['deadline'] ?? '').toString())?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          (t['title'] ?? '').toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          dl == null ? subtitle : '$subtitle\nДедлайн: ${formatDeadline(dl)}',
        ),
        isThreeLine: dl != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(t),
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
