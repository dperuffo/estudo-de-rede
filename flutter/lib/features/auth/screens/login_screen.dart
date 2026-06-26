import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null && mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E27), Color(0xFF0D1B4B), Color(0xFF0A2A6E)],
        ),
      ),
      child: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

          // Logo em container branco arredondado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
              ],
            ),
            child: Image.asset('assets/logo_fni.png', height: 120, fit: BoxFit.contain),
          ),

          const SizedBox(height: 40),
          const Text('Gestao de Frotas',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text('Plataforma de inteligencia de rede',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 64),

          // Botão login
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D2D6B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D2D6B)))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Image.asset('assets/logo_fni.png', height: 28),
                      const SizedBox(width: 12),
                      const Text('Continuar com Google',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),

          const SizedBox(height: 40),
          const Text('Fleet Network Intelligence',
              style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1)),
        ]),
      ))),
    ),
  );
}
