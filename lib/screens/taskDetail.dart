import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'package:flutter_application_5/utils.dart';

const String _kInProgress = 'орындалуда';
const String _kDone = 'орындалды';
const String _kOverdue = 'өтіп кетті';
const String _kSubmitted = 'жіберілді';

class TaskDetailScreen extends StatefulWidget {
  final Object taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final User? _user = SupabaseService.client.auth.currentUser;
  final _commentController = TextEditingController();

  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _comments = [];
  Map<String, String> _names = {};
  String? _photoUrl;
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showSnackBar(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _load() async {
    try {
      final client = SupabaseService.client;

      final task = await client
          .from('tasks')
          .select()
          .eq('id', widget.taskId)
          .single();

      bool isAdmin = task['created_by']?.toString() == _user?.id;
      final groupId = task['group_id'];
      if (groupId != null) {
        final m = await client
            .from('group_members')
            .select('role')
            .eq('group_id', groupId)
            .eq('user_id', _user!.id)
            .maybeSingle();
        isAdmin = m?['role'] == 'admin';
      }

      final comments = await client
          .from('task_comments')
          .select()
          .eq('task_id', widget.taskId)
          .order('created_at', ascending: true);

      final ids = <String>{
        if (task['assigned_to'] != null) task['assigned_to'].toString(),
        if (task['created_by'] != null) task['created_by'].toString(),
        for (final c in comments)
          if (c['user_id'] != null) c['user_id'].toString(),
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

      String? photoUrl;
      final path = task['photo_path'];
      if (path != null && path.toString().isNotEmpty) {
        try {
          photoUrl = await client.storage
              .from('task-photos')
              .createSignedUrl(path.toString(), 3600);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _task = Map<String, dynamic>.from(task);
        _comments = List<Map<String, dynamic>>.from(comments);
        _names = names;
        _photoUrl = photoUrl;
        _isAdmin = isAdmin;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Міндетті жүктеу мүмкін болмады';
      });
    }
  }

  String _nameOf(dynamic id) {
    if (id == null) return 'Тағайындалмаған';
    if (id.toString() == _user?.id) return 'Мен';
    return _names[id.toString()] ?? 'Қатысушы';
  }

  DateTime? _deadline() =>
      DateTime.tryParse((_task?['deadline'] ?? '').toString())?.toLocal();

  String _status() {
    final s = (_task?['status'] ?? _kInProgress).toString();
    if (s == _kDone || s == _kSubmitted) return s;
    final dl = _deadline();
    if (dl != null && dl.isBefore(DateTime.now())) return _kOverdue;
    return s;
  }

  Color _statusColor(String s) {
    switch (s) {
      case _kDone:
        return Colors.green;
      case _kOverdue:
        return Colors.red;
      case _kSubmitted:
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Future<void> _addEvent(String text) async {
    await SupabaseService.client.from('task_comments').insert({
      'task_id': widget.taskId,
      'user_id': _user!.id,
      'text': text,
      'kind': 'event',
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    try {
      await SupabaseService.client.from('task_comments').insert({
        'task_id': widget.taskId,
        'user_id': _user!.id,
        'text': text,
        'kind': 'comment',
      });
      _commentController.clear();
      FocusScope.of(context).unfocus();
      await _load();
    } catch (_) {
      _showSnackBar('Пікірді жіберу мүмкін болмады');
    }
  }

  Future<void> _submitReport() async {
    final groupId = _task?['group_id'];
    if (groupId == null) {
      _showSnackBar('Фото-есеп тек топ міндеттері үшін');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камерамен түсіру'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галереядан таңдау'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _busy = true);

      final bytes = await picked.readAsBytes();
      final path =
          '$groupId/${widget.taskId}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseService.client.storage.from('task-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      await SupabaseService.client.from('tasks').update({
        'photo_path': path,
        'status': _kSubmitted,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'review_comment': null,
      }).eq('id', widget.taskId);

      await _addEvent('Фото-есеп жіберілді');
      await _load();
      _showSnackBar('Есеп жіберілді, тексеруді күтіңіз', color: Colors.green);
    } on StorageException catch (e) {
      _showSnackBar('Сурет жүктелмеді: ${e.message}');
    } on PostgrestException catch (e) {
      _showSnackBar('Қате: ${e.message}');
    } catch (_) {
      _showSnackBar('Есепті жіберу мүмкін болмады');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await SupabaseService.client.from('tasks').update({
        'status': _kDone,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'review_comment': null,
      }).eq('id', widget.taskId);
      await _addEvent('Міндет қабылданды');
      await _load();
      _showSnackBar('Қабылданды', color: Colors.green);
    } catch (_) {
      _showSnackBar('Қабылдау мүмкін болмады');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnForRework() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Қайта өңдеуге қайтару'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Себебі',
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
            child: const Text('Қайтару'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.client.from('tasks').update({
        'status': _kInProgress,
        'completed_at': null,
        'review_comment': reason,
      }).eq('id', widget.taskId);
      await _addEvent('Қайта өңдеуге қайтарылды: $reason');
      await _load();
    } catch (_) {
      _showSnackBar('Қайтару мүмкін болмады');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Міндет'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _task == null
              ? Center(child: Text(_error ?? 'Табылмады'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final task = _task!;
    final status = _status();
    final color = _statusColor(status);
    final dl = _deadline();
    final desc = (task['description'] ?? '').toString().trim();
    final freq = (task['frequency'] ?? '').toString();
    final isMine = task['assigned_to']?.toString() == _user?.id;
    final hasGroup = task['group_id'] != null;
    final reviewComment = (task['review_comment'] ?? '').toString();

    final canSubmit = hasGroup &&
        (isMine || _isAdmin) &&
        (status == _kInProgress || status == _kOverdue);
    final canReview = _isAdmin && status == _kSubmitted;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (task['title'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _card(
            child: Column(
              children: [
                _infoRow(Icons.person_outline, 'Орындаушы',
                    _nameOf(task['assigned_to'])),
                _infoRow(Icons.edit_outlined, 'Құрған адам',
                    _nameOf(task['created_by'])),
                _infoRow(
                  Icons.access_time,
                  'Дедлайн',
                  dl == null ? 'Дедлайнсыз' : formatDeadline(dl),
                  valueColor: status == _kOverdue ? Colors.red : null,
                ),
                if (freq.isNotEmpty)
                  _infoRow(Icons.repeat, 'Жиілігі', freq),
              ],
            ),
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Сипаттамасы',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(desc),
                ],
              ),
            ),
          ],

          if (reviewComment.isNotEmpty && status != _kDone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.undo, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Қайтарылды: $reviewComment'),
                  ),
                ],
              ),
            ),
          ],

          if (_photoUrl != null) ...[
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Фото-есеп',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _photoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : const SizedBox(
                              height: 160,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 80,
                        child: Center(child: Text('Суретті көрсету мүмкін емес')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (canSubmit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submitReport,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera),
              label: const Text('Фото-есеп жіберу'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _returnForRework,
                    icon: const Icon(Icons.undo),
                    label: const Text('Қайтару'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    icon: const Icon(Icons.check),
                    label: const Text('Қабылдау'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Тарих және пікірлер',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Әзірге жазба жоқ',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            for (final c in _comments) _buildComment(c),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Пікір жазу...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendComment,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> c) {
    final isEvent = c['kind'] == 'event';
    final when = DateTime.tryParse((c['created_at'] ?? '').toString())?.toLocal();
    final who = _nameOf(c['user_id']);
    final text = (c['text'] ?? '').toString();

    if (isEvent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.history, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$who: $text${when != null ? ' · ${formatDeadline(when)}' : ''}',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(who,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (when != null)
                Text(formatDeadline(when),
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: AppColors.muted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
