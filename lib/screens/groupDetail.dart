import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'package:flutter_application_5/utils.dart';
import 'taskDetail.dart';

const String _kInProgress = 'орындалуда';
const String _kDone = 'орындалды';
const String _kOverdue = 'өтіп кетті';
const String _kSubmitted = 'жіберілді';

const List<String> _kFrequencies = [
  'бір рет',
  'күн сайын',
  'апта сайын',
  'ай сайын',
];

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String inviteCode;
  final bool isAdmin;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.isAdmin,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final User? _user = SupabaseService.client.auth.currentUser;

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = []; 
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _showSnackBar(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _loadAll() async {
    try {
      final memberRows = await SupabaseService.client
          .from('group_members')
          .select('user_id, role')
          .eq('group_id', widget.groupId);

      final ids = memberRows.map((r) => r['user_id'].toString()).toList();

      final Map<String, Map<String, dynamic>> profiles = {};
      try {
        final users = await SupabaseService.client
            .from('users')
            .select('id, full_name, email')
            .inFilter('id', ids);
        for (final u in users) {
          profiles[u['id'].toString()] = Map<String, dynamic>.from(u);
        }
      } catch (_) {}

      final members = memberRows.map<Map<String, dynamic>>((r) {
        final uid = r['user_id'].toString();
        final p = profiles[uid];
        String name = (p?['full_name'] ?? '').toString().trim();
        if (name.isEmpty) name = (p?['email'] ?? '').toString();
        if (name.isEmpty) name = 'Қатысушы ${uid.substring(0, 4)}';
        return {'user_id': uid, 'role': r['role'], 'name': name};
      }).toList();

      final taskRows = await SupabaseService.client
          .from('tasks')
          .select()
          .eq('group_id', widget.groupId)
          .order('deadline', ascending: true);

      if (!mounted) return;
      setState(() {
        _members = members;
        _tasks = List<Map<String, dynamic>>.from(taskRows);
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Деректерді жүктеу мүмкін болмады';
      });
    }
  }

  String _nameOf(dynamic userId) {
    if (userId == null) return 'Тағайындалмаған';
    if (userId.toString() == _user?.id) return 'Мен';
    final m = _members.where((m) => m['user_id'] == userId.toString());
    return m.isEmpty ? 'Қатысушы' : m.first['name'].toString();
  }

  DateTime? _deadlineOf(Map<String, dynamic> t) =>
      DateTime.tryParse((t['deadline'] ?? '').toString())?.toLocal();

  String _statusOf(Map<String, dynamic> t) {
    final s = (t['status'] ?? _kInProgress).toString();
    if (s == _kDone || s == _kSubmitted) return s;
    final dl = _deadlineOf(t);
    if (dl != null && dl.isBefore(DateTime.now())) return _kOverdue;
    return s;
  }


  Future<void> _toggleDone(Map<String, dynamic> task) async {
    final old = task['status'];
    final next = old == _kDone ? _kInProgress : _kDone;
    final oldCompleted = task['completed_at'];
    final completedAt =
        next == _kDone ? DateTime.now().toUtc().toIso8601String() : null;
    setState(() {
      task['status'] = next;
      task['completed_at'] = completedAt;
    });
    try {
      await SupabaseService.client.from('tasks').update({
        'status': next,
        'completed_at': completedAt,
      }).eq('id', task['id']);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        task['status'] = old;
        task['completed_at'] = oldCompleted;
      });
      _showSnackBar('Статусты жаңарту мүмкін болмады');
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Міндетті өшіру'),
        content: Text('"${task['title']}" өшірілсін бе?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жоқ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client.from('tasks').delete().eq('id', task['id']);
      if (!mounted) return;
      setState(() => _tasks.removeWhere((t) => t['id'] == task['id']));
    } catch (_) {
      _showSnackBar('Өшіру мүмкін болмады');
    }
  }

  Future<void> _addDuty() async {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    DateTime? deadline;
    String frequency = _kFrequencies.first;
    String assignee = _members.isNotEmpty
        ? _members.first['user_id'].toString()
        : 'random';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Топқа жаңа міндет',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleC,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Міндет атауы',
                    prefixIcon: Icon(Icons.task_alt),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Сипаттамасы (міндетті емес)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: assignee,
                  decoration: const InputDecoration(
                    labelText: 'Кім орындайды',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in _members)
                      DropdownMenuItem(
                        value: m['user_id'].toString(),
                        child: Text(
                          m['user_id'] == _user?.id
                              ? '${m['name']} (мен)'
                              : m['name'].toString(),
                        ),
                      ),
                    const DropdownMenuItem(
                      value: 'random',
                      child: Text('🎲 Кездейсоқ таңдау'),
                    ),
                  ],
                  onChanged: (v) => setSheet(() => assignee = v ?? assignee),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Қаншалықты жиі',
                    prefixIcon: Icon(Icons.repeat),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in _kFrequencies)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: (v) => setSheet(() => frequency = v ?? frequency),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(
                    deadline == null
                        ? 'Дедлайнды таңдау'
                        : formatDeadline(deadline!),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 20, minute: 0),
                    );
                    if (time == null) return;
                    setSheet(() {
                      deadline = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (titleC.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Міндетті қосу'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    String? assignedTo = assignee;
    if (assignee == 'random') {
      if (_members.isEmpty) {
        assignedTo = null;
      } else {
        assignedTo =
            _members[Random().nextInt(_members.length)]['user_id'].toString();
      }
    }

    try {
      await SupabaseService.client.from('tasks').insert({
        'title': titleC.text.trim(),
        'description': descC.text.trim(),
        'group_id': widget.groupId,
        'created_by': _user!.id,
        'assigned_to': assignedTo,
        'deadline': deadline?.toUtc().toIso8601String(),
        'frequency': frequency,
        'status': _kInProgress,
      });
      await _loadAll();
      _showSnackBar('Міндет қосылды', color: Colors.green);
    } on PostgrestException catch (e) {
      _showSnackBar('Қате: ${e.message}');
    } catch (_) {
      _showSnackBar('Міндетті қосу мүмкін болмады');
    }
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task['id'])),
    );
    _loadAll();
  }

  int _pointsOf(String userId, {bool weekOnly = false}) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    int p = 0;
    for (final t in _tasks) {
      if (t['assigned_to']?.toString() != userId) continue;
      if (t['status'] != _kDone) continue;
      final done = DateTime.tryParse((t['completed_at'] ?? '').toString());
      if (weekOnly && (done == null || done.isBefore(weekAgo))) continue;
      p += 10;
      final dl = DateTime.tryParse((t['deadline'] ?? '').toString());
      if (dl != null && done != null && !done.isAfter(dl)) p += 5;
    }
    return p;
  }

  List<Map<String, dynamic>> _sortedMembers() {
    final list = [..._members];
    list.sort((a, b) => _pointsOf(b['user_id']).compareTo(_pointsOf(a['user_id'])));
    return list;
  }

  String? get _weeklyBest {
    String? best;
    int bestPoints = 0;
    for (final m in _members) {
      final p = _pointsOf(m['user_id'], weekOnly: true);
      if (p > bestPoints) {
        bestPoints = p;
        best = m['user_id'];
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
          appBar: AppBar(
          title: Text(widget.groupName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Міндеттер'),
              Tab(text: 'Мүшелер'),
            ],
          ),
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: _isLoading ? null : _addDuty,
                icon: const Icon(Icons.add_task),
                label: const Text('Міндет қосу'),
              )
            : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildTasksTab(),
                  _buildMembersTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildTasksTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (_error != null)
            _message(Icons.error_outline, _error!)
          else if (_tasks.isEmpty)
            _message(
              Icons.checklist,
              widget.isAdmin
                  ? 'Бұл топта міндет жоқ.\n"Міндет қосу" батырмасын басыңыз'
                  : 'Топ иесі әлі міндет қосқан жоқ',
            )
          else
            for (final t in _tasks) _buildTaskTile(t),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final status = _statusOf(task);
    final isDone = status == _kDone;
    final isOverdue = status == _kOverdue;
    final dl = _deadlineOf(task);
    final mine = task['assigned_to']?.toString() == _user?.id;
    final canToggle = mine || widget.isAdmin;
    final freq = (task['frequency'] ?? '').toString();

    Color statusColor = Colors.orange;
    if (isDone) statusColor = Colors.green;
    if (isOverdue) statusColor = Colors.red;
    if (status == _kSubmitted) statusColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: () => _openTask(task),
        leading: Checkbox(
          value: isDone,
          activeColor: Colors.green,
          onChanged: widget.isAdmin
              ? (_) => _toggleDone(task)
              : (canToggle ? (_) => _openTask(task) : null),
        ),
        title: Text(
          (task['title'] ?? '').toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _meta(Icons.person_outline, _nameOf(task['assigned_to'])),
              _meta(
                Icons.access_time,
                dl == null ? 'Дедлайнсыз' : formatDeadline(dl),
                color: isOverdue ? Colors.red : null,
              ),
              if (freq.isNotEmpty) _meta(Icons.repeat, freq),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.isAdmin)
              InkWell(
                onTap: () => _deleteTask(task),
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }

  Widget _buildMembersTab() {
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Шақыру коды',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.inviteCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Көшіру',
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.inviteCode));
                    _showSnackBar('Код көшірілді', color: Colors.green);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Мүшелер (${_members.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final m in _sortedMembers())
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.line),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withOpacity(0.12),
                  child: Text(
                    m['name'].toString().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  m['user_id'] == _user?.id
                      ? '${m['name']} (мен)'
                      : m['name'].toString(),
                ),
                subtitle: Text(
                  (m['role'] == 'admin' ? 'Топ иесі' : 'Қатысушы') +
                      (m['user_id'] == _weeklyBest ? '  🏆 Апта үздігі' : ''),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_pointsOf(m['user_id'])} ұпай',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    Text(
                      '${_tasks.where((t) => t['assigned_to']?.toString() == m['user_id']).length} міндет',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
