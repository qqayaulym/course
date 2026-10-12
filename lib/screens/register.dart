import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_5/services/supabase_service.dart';
import 'package:flutter_application_5/theme.dart';
import 'logIn.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String text, {Color color = AppColors.danger}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'display_name': _nameController.text.trim()},
      );

      if (response.user != null) {
        _showSnackBar(
          'Тіркелу сәтті өтті, ${_nameController.text.trim()}!',
          color: AppColors.success,
        );
        _navigateToLogin();
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Қате орын алды. Қайтадан байқап көріңіз.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _eye(bool obscured, VoidCallback onTap) => IconButton(
        icon: Icon(
            obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Аккаунт ашу',
      subtitle: 'Жалғастыру үшін деректерді толтырыңыз',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: inputDeco('Атыңыз', Icons.person_outline),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Атыңызды енгізіңіз' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  inputDeco('Электрондық пошта (Email)', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email енгізіңіз';
                final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegExp.hasMatch(v.trim())) {
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
                suffix: _eye(_obscurePassword,
                    () => setState(() => _obscurePassword = !_obscurePassword)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Құпия сөзді енгізіңіз';
                if (v.length < 6) {
                  return 'Құпия сөз кемінде 6 символдан тұруы керек';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: inputDeco(
                'Құпия сөзді қайталаңыз',
                Icons.lock_reset_outlined,
                suffix: _eye(_obscureConfirm,
                    () => setState(() => _obscureConfirm = !_obscureConfirm)),
              ),
              validator: (v) => v != _passwordController.text
                  ? 'Құпия сөздер сәйкес келмейді'
                  : null,
            ),
            const SizedBox(height: 24),
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
                  : const Text('Тіркелу'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Аккаунтыңыз бар ма?',
                    style: TextStyle(color: AppColors.muted)),
                TextButton(
                  onPressed: _navigateToLogin,
                  child: const Text('Кіру'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
