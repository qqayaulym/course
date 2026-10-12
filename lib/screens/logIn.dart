import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'register.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static final _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String text, {Color color = AppColors.danger}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  void _navigateToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_emailRegExp.hasMatch(email)) {
      _showSnackBar('Алдымен Email жолына поштаңызды енгізіңіз');
      return;
    }
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      _showSnackBar(
        'Қалпына келтіру сілтемесі $email поштасына жіберілді',
        color: AppColors.success,
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar('Қате орын алды. Қайтадан байқап көріңіз.');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (error) {
      if (error.message.contains('Email not confirmed')) {
        _showSnackBar('Электрондық поштаңыз расталмаған. Поштаңызды тексеріңіз.');
      } else if (error.message.contains('Invalid login credentials')) {
        _showSnackBar('Email немесе құпия сөз қате.');
      } else {
        _showSnackBar(error.message);
      }
    } catch (_) {
      _showSnackBar('Қате орын алды. Қайтадан байқап көріңіз.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Қош келдіңіз!',
      subtitle: 'Жүйеге кіру үшін деректерді енгізіңіз',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  inputDeco('Электрондық пошта (Email)', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email енгізіңіз';
                if (!_emailRegExp.hasMatch(v.trim())) {
                  return 'Дұрыс Email енгізіңіз';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: inputDeco(
                'Құпия сөз',
                Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Құпия сөзді енгізіңіз' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Құпия сөзді ұмыттыңыз ба?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Кіру'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Аккаунтыңыз жоқ па?',
                    style: TextStyle(color: AppColors.muted)),
                TextButton(
                  onPressed: _navigateToRegister,
                  child: const Text('Тіркелу'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}