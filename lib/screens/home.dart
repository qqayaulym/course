import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'package:flutter_application_5/utils.dart';
import 'groups.dart';
import 'review.dart';
import 'taskDetail.dart';
import 'userProfile.dart';

const String kStatusInProgress = 'орындалуда';
const String kStatusDone = 'орындалды';
const String kStatusOverdue = 'өтіп кетті';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedNavIndex,
        children: const [
          _TasksTab(),
          ReviewScreen(),
          GroupsScreen(),
          UserProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Басты бет',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Бақылау',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Топ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  const _TasksTab();

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  final User? currentUser = SupabaseService.client.auth.currentUser;

  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;

  String? _filter;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String get _userName {
    final meta = currentUser?.userMetadata;
    final n = (meta?['display_name'] ?? '').toString().trim();
    return n.isEmpty ? 'Қолданушы' : n;
  }


  Future<void> _loadTasks() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select()
          .or('assigned_to.eq.${user.id},created_by.eq.${user.id}')
          .order('deadline', ascending: true);

      if (!mounted) return;
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Міндеттерді жүктеу мүмкін болмады';
      });
    }
  }

  void _showSnackBar(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  DateTime? _deadlineOf(Map<String, dynamic> t) =>
      DateTime.tryParse((t['deadline'] ?? '').toString())?.toLocal();

  String _effectiveStatus(Map<String, dynamic> t) {
    final status = (t['status'] ?? kStatusInProgress).toString();
    if (status == kStatusDone || status == 'жіберілді') return status;
    final dl = _deadlineOf(t);
    if (dl != null && dl.isBefore(DateTime.now())) return kStatusOverdue;
    return status;
  }

  int get _doneCount =>
      _tasks.where((t) => t['status'] == kStatusDone).length;

  int get _points {
    int p = 0;
    for (final t in _tasks) {
      if (t['assigned_to'] != currentUser?.id) continue;
      if (t['status'] != kStatusDone) continue;
      p += 10;
      final dl = _deadlineOf(t);
      final doneAt = DateTime.tryParse((t['completed_at'] ?? '').toString());
      if (dl != null && doneAt != null && !doneAt.isAfter(dl)) p += 5;
    }
    return p;
  }

  List<Map<String, dynamic>> get _visibleTasks {
    if (_filter == null) return _tasks;
    return _tasks.where((t) => _effectiveStatus(t) == _filter).toList();
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final wasDone = task['status'] == kStatusDone;
    final newStatus = wasDone ? kStatusInProgress : kStatusDone;
    final oldStatus = task['status'];

    final oldCompleted = task['completed_at'];
    final completedAt =
        newStatus == kStatusDone ? DateTime.now().toUtc().toIso8601String() : null;

    setState(() {
      task['status'] = newStatus;
      task['completed_at'] = completedAt;
    });

    try {
      await SupabaseService.client.from('tasks').update({
        'status': newStatus,
        'completed_at': completedAt,
      }).eq('id', task['id']);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        task['status'] = oldStatus;
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

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    DateTime? deadline;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Жаңа міндет',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Міндет атауы',
                  prefixIcon: Icon(Icons.task_alt),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  deadline == null
                      ? 'Дедлайнды таңдау'
                      : _formatDeadline(deadline!),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: const TimeOfDay(hour: 20, minute: 0),
                  );
                  if (time == null) return;
                  setSheetState(() {
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
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Қосу'),
              ),
            ],
          ),
        ),
      ),
    );

    if (created != true) return;

    try {
      await SupabaseService.client.from('tasks').insert({
        'title': titleController.text.trim(),
        'created_by': currentUser!.id,
        'assigned_to': currentUser!.id,
        'deadline': deadline?.toUtc().toIso8601String(),
        'frequency': 'бір рет',
        'status': kStatusInProgress,
      });
      await _loadTasks();
      _showSnackBar('Міндет қосылды', color: Colors.green);
    } on PostgrestException catch (e) {
      _showSnackBar('Қате: ${e.message}');
    } catch (_) {
      _showSnackBar('Міндетті қосу мүмкін болмады');
    }
  }

  String _formatDeadline(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final time = '${two(d.hour)}:${two(d.minute)}';
    if (diff == 0) return 'Бүгін, $time';
    if (diff == 1) return 'Ертең, $time';
    if (diff == -1) return 'Кеше, $time';
    return '${two(d.day)}.${two(d.month)}.${d.year}, $time';
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task['id'])),
    );
    _loadTasks();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Міндет'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        edgeOffset: 120,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : _doneCount / total;

    return GradientHeader(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LogoBadge(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сәлем, $_userName! 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kzDateLabel(DateTime.now()),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Жаңарту',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadTasks();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: AppColors.gold, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Сіздің баллыңыз',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '$_points ұпай',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_doneCount / $total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'орындалды',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final visible = _visibleTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(),
        const SizedBox(height: 16),
        if (_error != null)
          EmptyState(icon: Icons.cloud_off_rounded, text: _error!)
        else if (visible.isEmpty)
          EmptyState(
            icon: _tasks.isEmpty
                ? Icons.checklist_rounded
                : Icons.filter_alt_off_rounded,
            text: _tasks.isEmpty
                ? 'Әзірге міндет жоқ.\n"Міндет" батырмасын басып қосыңыз'
                : 'Бұл санатта міндет жоқ',
          )
        else
          for (final task in visible) _buildTaskTile(task),
      ],
    );
  }

  Widget _buildFilters() {
    final options = <String?, String>{
      null: 'Барлығы',
      kStatusInProgress: 'Орындалуда',
      kStatusDone: 'Орындалды',
      kStatusOverdue: 'Өтіп кетті',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: _filter == e.key,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _filter == e.key ? Colors.white : AppColors.text,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                onSelected: (_) => setState(() => _filter = e.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final status = _effectiveStatus(task);
    final isDone = status == kStatusDone;
    final isOverdue = status == kStatusOverdue;
    final dl = _deadlineOf(task);
    final mine = task['assigned_to'] == currentUser?.id;
    final inGroup = task['group_id'] != null;

    return Dismissible(
      key: ValueKey(task['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteTask(task);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
        onTap: inGroup ? () => _openTask(task) : null,
        child: Row(
          children: [
            Transform.scale(
              scale: 1.15,
              child: Checkbox(
                value: isDone,
                shape: const CircleBorder(),
                activeColor: AppColors.success,
                side: const BorderSide(color: AppColors.muted, width: 1.5),
                onChanged: (_) =>
                    inGroup ? _openTask(task) : _toggleTaskStatus(task),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (task['title'] ?? '').toString(),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? AppColors.muted : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _meta(
                        inGroup ? Icons.groups_rounded : Icons.person_outline,
                        mine ? 'Маған' : 'Басқаға',
                      ),
                      _meta(
                        Icons.schedule_rounded,
                        dl == null ? 'Дедлайнсыз' : _formatDeadline(dl),
                        color: isOverdue ? AppColors.danger : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status),
          ],
        ),
      ),
    );
  }
}
