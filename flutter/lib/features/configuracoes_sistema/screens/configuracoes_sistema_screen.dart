import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/configuracoes_sistema_provider.dart';
import '../services/configuracoes_sistema_service.dart';

// Fase FLT-4 — Configurações do Sistema (admin): tela exclusiva do time
// interno, porta de configuracoes/page.tsx. Ver escopo em
// configuracoes_sistema_provider.dart.
class ConfiguracoesSistemaScreen extends ConsumerStatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  ConsumerState<ConfiguracoesSistemaScreen> createState() => _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState extends ConsumerState<ConfiguracoesSistemaScreen> {
  final _ctrl = TextEditingController();
  bool _inicializado = false;
  bool _salvando = false;
  String? _erro;
  bool _ok = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _ok = false;
    });
    final minutos = int.tryParse(_ctrl.text.trim());
    if (minutos == null) {
      setState(() => _erro = 'Informe um número válido de minutos.');
      return;
    }
    final erroValidacao = validarLogoutInatividadeMinutos(minutos);
    if (erroValidacao != null) {
      setState(() => _erro = erroValidacao);
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    setState(() => _salvando = true);
    try {
      await ConfiguracoesSistemaService().atualizarLogoutInatividade(minutos: minutos, atualizadoPor: sessao.email);
      ref.invalidate(configuracoesSistemaProvider);
      if (mounted) setState(() => _ok = true);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações do Sistema')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acesso restrito', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'Esta tela é exclusiva do time interno (perfil administrador). Fale com um '
                'administrador se você precisa ajustar essas configurações.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final minutosAsync = ref.watch(configuracoesSistemaProvider);
    return minutosAsync.when(
      data: (minutos) {
        if (!_inicializado) {
          _ctrl.text = minutos.toString();
          _inicializado = true;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Parâmetros globais da plataforma — valem para todos os clientes, postos e usuários.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Logout automático por inatividade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text(
                      'Se um usuário ficar sem interagir com o sistema por esse tempo, ele é desconectado '
                      'automaticamente e precisa entrar de novo. Vale para todos os perfis (admin, gestor de '
                      'frota, analista e posto) em todos os clientes.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_erro != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                        child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minutos',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _salvando ? null : _salvar,
                          child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                        ),
                      ],
                    ),
                    if (_ok) ...[
                      const SizedBox(height: 8),
                      const Text('Salvo.', style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Entre $logoutInatividadeMinutosMin e $logoutInatividadeMinutosMax minutos.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }
}
