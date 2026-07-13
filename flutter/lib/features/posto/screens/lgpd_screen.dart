import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/lgpd_provider.dart';
import '../services/lgpd_service.dart';

final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _dataHoraFormatada(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return _dataHoraBr.format(d.toLocal());
}

// Fase FLT-2 — Privacidade (LGPD), porta de lgpd/page.tsx + actions.ts (só
// os 4 blocos "não-admin" — ver comentário completo em lgpd_provider.dart).
class LgpdScreen extends ConsumerStatefulWidget {
  const LgpdScreen({super.key});

  @override
  ConsumerState<LgpdScreen> createState() => _LgpdScreenState();
}

class _LgpdScreenState extends ConsumerState<LgpdScreen> {
  bool _revogando = false;
  String? _erroRevogacao;
  String? _sucessoRevogacao;

  String? _empresaSelecionada;
  bool _solicitandoExclusao = false;
  String? _erroExclusao;
  String? _sucessoExclusao;

  Future<void> _revogarConsentimento() async {
    setState(() {
      _revogando = true;
      _erroRevogacao = null;
      _sucessoRevogacao = null;
    });
    final erro = await LgpdService().registrarRevogacaoConsentimento();
    if (!mounted) return;
    setState(() {
      _revogando = false;
      if (erro != null) {
        _erroRevogacao = erro;
      } else {
        _sucessoRevogacao = 'Revogação de consentimento registrada com sucesso.';
      }
    });
    if (erro == null) ref.invalidate(lgpdProvider);
  }

  Future<void> _solicitarExclusao(String empresaId) async {
    setState(() {
      _solicitandoExclusao = true;
      _erroExclusao = null;
      _sucessoExclusao = null;
    });
    final erro = await LgpdService().solicitarExclusaoDados(empresaId: empresaId);
    if (!mounted) return;
    setState(() {
      _solicitandoExclusao = false;
      if (erro != null) {
        _erroExclusao = erro;
      } else {
        _sucessoExclusao = 'Solicitação de exclusão registrada. A equipe FNI vai analisar e retornar por e-mail.';
      }
    });
    if (erro == null) ref.invalidate(lgpdProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lgpdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade (LGPD)')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) => _buildConteudo(context, dados),
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, LgpdDetalhe dados) {
    _empresaSelecionada ??= dados.empresasVinculadas.isNotEmpty ? dados.empresasVinculadas.first.id : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Seus direitos como titular de dados, conforme a Lei Geral de Proteção de Dados (LGPD).',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _secao(
          titulo: 'Seus dados cadastrais',
          subtitulo: 'Direito de acesso (art. 18, I). Para correção de algum dado, abra um chamado em Gestão de Chamados.',
          child: dados.dados == null
              ? const Text('Não foi possível carregar seus dados cadastrais.', style: TextStyle(color: Colors.grey))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _linhaDado('Nome', dados.dados!.nome),
                    _linhaDado('E-mail', dados.dados!.email),
                    _linhaDado('CPF', dados.dados!.cpf),
                    _linhaDado('Telefone', dados.dados!.telefone),
                    _linhaDado('Cliente vinculado', dados.dados!.empresaNome),
                    _linhaDado('Cadastrado em', _dataHoraFormatada(dados.dados!.criadoEm)),
                    _linhaDado('MFA', dados.dados!.mfaHabilitado ? 'Ativada' : 'Não ativada'),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _secao(
          titulo: 'Revogar consentimento',
          subtitulo:
              'Registra sua revogação de consentimento com o tratamento de dados. Isso NÃO encerra sua conta nem apaga seus dados — pra isso, use "Solicitar exclusão" abaixo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erroRevogacao != null) ...[
                _bannerErro(_erroRevogacao!),
                const SizedBox(height: 10),
              ],
              if (_sucessoRevogacao != null) ...[
                _bannerSucesso(_sucessoRevogacao!),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: _revogando ? null : _revogarConsentimento,
                child: Text(_revogando ? 'Registrando...' : 'Revogar consentimento'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _secao(
          titulo: 'Solicitar exclusão dos meus dados',
          subtitulo:
              'Direito ao esquecimento (art. 18, VI). A equipe FNI vai analisar e retornar por e-mail — alguns dados podem ser retidos por obrigação legal (ex: notas fiscais).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dados.empresasVinculadas.isEmpty)
                const Text('Nenhum cliente vinculado.', style: TextStyle(color: Colors.grey))
              else ...[
                if (dados.empresasVinculadas.length > 1)
                  DropdownButtonFormField<String>(
                    value: _empresaSelecionada,
                    decoration: const InputDecoration(labelText: 'Cliente/empresa', border: OutlineInputBorder()),
                    items: dados.empresasVinculadas
                        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.nome)))
                        .toList(),
                    onChanged: (v) => setState(() => _empresaSelecionada = v),
                  ),
                const SizedBox(height: 10),
                if (_erroExclusao != null) ...[
                  _bannerErro(_erroExclusao!),
                  const SizedBox(height: 10),
                ],
                if (_sucessoExclusao != null) ...[
                  _bannerSucesso(_sucessoExclusao!),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: (_solicitandoExclusao || _empresaSelecionada == null)
                      ? null
                      : () => _solicitarExclusao(_empresaSelecionada!),
                  child: Text(_solicitandoExclusao ? 'Enviando...' : 'Solicitar exclusão dos meus dados'),
                ),
              ],
              if (dados.exclusoes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Minhas solicitações', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...dados.exclusoes.map((ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text('Solicitado em ${_dataHoraFormatada(ex.solicitadoEm)}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          _statusChip(ex.status),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _secao(
          titulo: 'Histórico de consentimento',
          subtitulo: null,
          child: dados.consentimentos.isEmpty
              ? const Text('Nenhum registro ainda.', style: TextStyle(color: Colors.grey))
              : Column(
                  children: dados.consentimentos
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(tipoConsentimentoLabel[c.tipo] ?? c.tipo,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                                Text(_dataHoraFormatada(c.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _secao({required String titulo, required String? subtitulo, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _linhaDado(String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text((valor == null || valor.isEmpty) ? '—' : valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final executado = status == 'executado';
    final cor = executado ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(statusExclusaoLabel[status] ?? status,
          style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _bannerErro(String texto) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
      );

  Widget _bannerSucesso(String texto) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
      );
}
