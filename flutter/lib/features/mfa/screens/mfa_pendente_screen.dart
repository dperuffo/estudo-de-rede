import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

// Fase FLT-1b — completa o gate de MFA. Antes esta tela só explicava a
// exigência e mandava configurar pela web, mas isso resolvia só metade do
// problema: uma conta pode já ter o fator TOTP verificado (cadastrado via
// web) e mesmo assim cair aqui, porque cada sessão/login novo precisa
// elevar o nível pra aal2 digitando o código de 6 dígitos atual do app
// autenticador — é o desafio normal de qualquer 2FA, distinto do cadastro.
// Agora a tela busca o status detalhado (statusMfa()) e mostra:
//   - "nunca cadastrou fator" → orienta a configurar pela web (como antes).
//   - "tem fator, falta subir o nível" → campo de código + botão Verificar.
// O cadastro do fator (QR code + confirmação) continua só na web por
// enquanto — é uma tela grande, fica pra uma fase própria.
class MfaPendenteScreen extends StatefulWidget {
  const MfaPendenteScreen({super.key});

  @override
  State<MfaPendenteScreen> createState() => _MfaPendenteScreenState();
}

class _MfaPendenteScreenState extends State<MfaPendenteScreen> {
  MfaStatus? _status;
  bool _carregando = true;
  bool _enviando = false;
  String? _erro;
  final _codigoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarStatus();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarStatus() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final status = await AuthService().statusMfa();
    if (!mounted) return;
    if (!status.bloqueado) {
      context.go('/');
      return;
    }
    setState(() {
      _status = status;
      _carregando = false;
    });
  }

  Future<void> _verificarCodigo() async {
    final status = _status;
    if (status?.factorId == null) return;
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length != 6) {
      setState(() => _erro = 'Digite os 6 dígitos do código.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await AuthService().verificarCodigoMfa(factorId: status!.factorId!, code: codigo);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() => _erro = 'Código inválido ou expirado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final precisaCadastrar = !(_status?.temFatorVerificado ?? false);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 56, color: Color(0xFF0D2D6B)),
                const SizedBox(height: 20),
                Text(
                  precisaCadastrar
                      ? 'Verificação em duas etapas necessária'
                      : 'Digite o código do seu app autenticador',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  precisaCadastrar
                      ? 'Por segurança, toda conta da plataforma precisa ter a verificação em duas '
                          'etapas (TOTP) ativa antes de acessar. Configure pela versão web em '
                          '"Configurar MFA" e depois volte aqui.'
                      : 'Sua conta já tem a verificação em duas etapas ativa. Abra o app '
                          'autenticador (Google Authenticator, Authy, etc.) e digite o código de '
                          '6 dígitos atual pra continuar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (!precisaCadastrar) ...[
                  TextField(
                    controller: _codigoCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                    onSubmitted: (_) => _verificarCodigo(),
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _verificarCodigo,
                      child: _enviando
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verificar'),
                    ),
                  ),
                ] else ...[
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregarStatus,
                      child: const Text('Já configurei — tentar novamente'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
