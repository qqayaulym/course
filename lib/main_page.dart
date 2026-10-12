import 'package:flutter/material.dart';
import 'package:flutter_application_5/screens/logIn.dart';
import 'package:flutter_application_5/screens/register.dart';
import 'package:flutter_application_5/theme.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _blob(240, AppColors.primary.withOpacity(0.10)),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _blob(160, AppColors.primary.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _blob(260, AppColors.primary.withOpacity(0.10)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 290,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      'duty turn',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Үй міндеттері — әділ бөлінеді',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Отбасыңызбен немесе жатақхана бөлмесімен бірге\nкезекті бақылаңыз, ұпай жинаңыз',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const Spacer(flex: 3),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Жүйеге кіру'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Тіркелу'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
