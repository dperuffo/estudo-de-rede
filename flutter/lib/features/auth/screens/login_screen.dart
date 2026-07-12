import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';

// Fase FLT-1 — mesmas duas opções de entrada da web (src/app/login):
// e-mail/senha (entrarComSenha) e "Continuar com Google" (entrarComGoogle),
// agora via Supabase Auth em vez da API Python própria.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _loadingSenha = false;
  bool _loadingGoogle = false;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrarComSenha() async {
    final email = _emailCtrl.text.trim();
    final senha = _senhaCtrl.text;
    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Informe e-mail e senha.');
      return;
    }
    setState(() {
      _loadingSenha = true;
      _erro = null;
    });
    try {
      await AuthService().signInWithPassword(email: email, senha: senha);
      ref.invalidate(sessaoProvider);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _erro = 'E-mail ou senha incorretos.');
    } finally {
      if (mounted) setState(() => _loadingSenha = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _loadingGoogle = true;
      _erro = null;
    });
    try {
      await AuthService().signInWithGoogle();
      ref.invalidate(sessaoProvider);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _erro = 'Não foi possível entrar com Google: $e');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Color(0xFF0D1B4B), Color(0xFF0A2A6E)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Image.asset('assets/logo_fni.png', height: 100, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 32),
                    const Text('Gestao de Frotas',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    const Text('Plataforma de inteligencia de rede',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                    const SizedBox(height: 40),

                    // Fase FLT-1 — formulário de e-mail/senha (equivalente a
                    // entrarComSenha na web).
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('E-mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _senhaCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Senha'),
                      onSubmitted: (_) => _entrarComSenha(),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 12),
                      Text(_erro!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loadingSenha ? null : _entrarComSenha,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loadingSenha
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(children: const [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ]),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loadingGoogle ? null : _entrarComGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D2D6B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: _loadingGoogle
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D2D6B)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/logo_fni.png', height: 24),
                                  const SizedBox(width: 12),
                                  const Text('Continuar com Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    const Text('Fleet Network Intelligence',
                        style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0)),
        ),
      );
}
