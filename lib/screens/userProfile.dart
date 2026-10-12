import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/main_page.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? get _user => SupabaseService.client.auth.currentUser;

  bool _loadingStats = true;
  int _total = 0;
  int _done = 0;
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  String get _name {
    final meta = _user?.userMetadata;
    final n = (meta?['display_name'] ?? meta?['full_name'] ?? '').toString();
    return n.trim().isEmpty ? 'Қолданушы' : n.trim();
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  void _showSnackBar(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  Future<void> _loadStats() async {
    final user = _user;
    if (user == null) return;
    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select('status, deadline, completed_at')
          .eq('assigned_to', user.id);

      int done = 0;
      int points = 0;
      for (final r in rows) {
        if (r['status'] == 'орындалды') {
          done++;
          points += 10;
          final dl = DateTime.tryParse((r['deadline'] ?? '').toString());
          final doneAt = DateTime.tryParse((r['completed_at'] ?? '').toString());
          if (dl != null && doneAt != null && !doneAt.isAfter(dl)) points += 5;
        }
      }
      if (!mounted) return;
      setState(() {
        _total = rows.length;
        _done = done;
        _points = points;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name == 'Қолданушы' ? '' : _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Атыңызды өзгерту'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Атыңыз',
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
            child: const Text('Сақтау'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );
      if (mounted) setState(() {});
      _showSnackBar('Аты жаңартылды', color: Colors.green);
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Қате орын алды. Қайтадан байқап көріңіз.');
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Құпия сөзді өзгерту'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Жаңа құпия сөз',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Бас тарту'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сақтау'),
          ),
        ],
      ),
    );

    if (newPass == null) return;
    if (newPass.length < 6) {
      _showSnackBar('Құпия сөз кемінде 6 символдан тұруы керек');
      return;
    }

    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      _showSnackBar('Құпия сөз өзгертілді', color: Colors.green);
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Қате орын алды. Қайтадан байқап көріңіз.');
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Жүйеден шығу'),
        content: const Text('Аккаунттан шығғыңыз келе ме?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жоқ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Иә, шығу'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.characters.first.toUpperCase();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primaryDark,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user?.email ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _statCard('Міндеттер', _total, Icons.list_alt_rounded),
                    const SizedBox(width: 10),
                    _statCard('Орындалды', _done, Icons.check_circle_rounded),
                    const SizedBox(width: 10),
                    _statCard('Ұпай', _points, Icons.emoji_events_rounded),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Аккаунт'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _infoTile(Icons.email_outlined, 'Email',
                            _user?.email ?? '-'),
                        const Divider(height: 1, color: AppColors.line),
                        _infoTile(Icons.calendar_today_outlined,
                            'Тіркелген күні', _formatDate(_user?.createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Баптаулар'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _actionTile(Icons.edit_outlined, 'Атын өзгерту',
                            _editName),
                        const Divider(height: 1, color: AppColors.line),
                        _actionTile(Icons.lock_reset_outlined,
                            'Құпия сөзді өзгерту', _changePassword),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Жүйеден шығу'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(
                          color: AppColors.danger, width: 1.4),
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

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text)),
    );
  }

  Widget _actionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _statCard(String label, int value, IconData icon) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            _loadingStats
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
