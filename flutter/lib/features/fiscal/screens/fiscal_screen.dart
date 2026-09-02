import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/fiscal_provider.dart';
import '../services/fiscal_service.dart';

// Fase FLT-Fiscal (02/09/2026) — porta de fiscal/page.tsx +
// FormularioFiscal.tsx. Envio de certificado A1 e teste de conexão ficam
// só na web (exigem o provedor fiscal, código server-side não alcançável
// por RPC) — aqui mostramos o status já salvo em modo leitura.
class FiscalScreen extends ConsumerStatefulWidget {
  const FiscalScreen({super.key});

  @override
  ConsumerState<FiscalScreen> createState() => _FiscalScreenState();
}

class _FiscalScreenState extends ConsumerState<FiscalScreen> {
  final _ieCtrl = TextEditingController();
  final _rntrcCtrl = TextEditingController();
  final _serieCteCtrl = TextEditingController(text: '1');
  final _serieMdfeCtrl = TextEditingController(text: '1');
  String _regime = 'simples';
  String _ambiente = 'homologacao';
  bool _preenchido = false;
  bool _salvando = false;
  String? _erro;
  String? _sucesso;

  @override
  void dispose() {
    _ieCtrl.dispose();
    _rntrcCtrl.dispose();
    _serieCteCtrl.dispose();
    _serieMdfeCtrl.dispose();
    super.dispose();
  }

  void _preencher(EmpresaFiscal? f) {
    if (f == null) return;
    _ieCtrl.text = f.inscricaoEstadual ?? '';
    _rntrcCtrl.text = f.rntrc ?? '';
    _serieCteCtrl.text = f.serieCte.toString();
    _serieMdfeCtrl.text = f.serieMdfe.toString();
    _regime = f.regimeTributario;
    _ambiente = f.ambiente;
  }

  Future<void> _salvar() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    setState(() {
      _salvando = true;
      _erro = null;
      _sucesso = null;
    });
    final erro = await FiscalService().salvar(
      empresaId: empresaId,
      inscricaoEstadual: _ieCtrl.text,
      rntrc: _rntrcCtrl.text,
      regimeTributario: _regime,
      serieCte: int.tryParse(_serieCteCtrl.text) ?? 1,
      serieMdfe: int.tryParse(_serieMdfeCtrl.text) ?? 1,
      ambiente: _ambiente,
    );
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) {
        _erro = erro;
      } else {
        _sucesso = 'Dados fiscais salvos.';
      }
    });
    if (erro == null) {
      ref.invalidate(fiscalDetalheProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fiscalDetalheProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Fiscal (CT-e/MDF-e)')),
      body: async.when(
        data: (r) {
          if (!_preenchido) {
            _preencher(r.fiscal);
            _preenchido = true;
          }
          if (r.empresa == null || r.empresa!.cnpj.trim().isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'Cadastre o CNPJ da empresa em Clientes antes de configurar os dados fiscais.',
                        style: TextStyle(color: Colors.orange.shade800)),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.empresa!.nome,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('CNPJ: ${r.empresa!.cnpj}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Dados fiscais',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_erro != null) ...[
                Text(_erro!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              if (_sucesso != null) ...[
                Text(_sucesso!,
                    style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _ieCtrl,
                decoration:
                    const InputDecoration(labelText: 'Inscrição Estadual'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rntrcCtrl,
                decoration: const InputDecoration(
                    labelText: 'RNTRC', hintText: 'Registro ANTT'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _regime,
                decoration:
                    const InputDecoration(labelText: 'Regime tributário'),
                items: const [
                  DropdownMenuItem(
                      value: 'simples',
                      child: Text('Simples Nacional')),
                  DropdownMenuItem(
                      value: 'presumido', child: Text('Lucro Presumido')),
                  DropdownMenuItem(value: 'real', child: Text('Lucro Real')),
                ],
                onChanged: (v) => setState(() => _regime = v ?? 'simples'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serieCteCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Série CT-e'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _serieMdfeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Série MDF-e'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _ambiente,
                decoration: const InputDecoration(labelText: 'Ambiente'),
                items: const [
                  DropdownMenuItem(
                      value: 'homologacao', child: Text('Homologação')),
                  DropdownMenuItem(
                      value: 'producao', child: Text('Produção')),
                ],
                onChanged: (v) =>
                    setState(() => _ambiente = v ?? 'homologacao'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar'),
              ),
              const SizedBox(height: 24),
              const Text('Certificado digital e conexão',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Envio do certificado A1 (.pfx/.p12) e teste de conexão com o provedor fiscal só estão disponíveis na versão web, por segurança (o certificado precisa ir direto ao provedor, sem passar por armazenamento no app).',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 10),
                      Text(
                          'Vencimento do certificado: ${r.fiscal?.certificadoVencimento ?? '—'}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                          'Status da última conexão: ${r.fiscal?.statusConexao ?? '—'}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator())),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Não deu pra carregar: $e', textAlign: TextAlign.center)
          ],
        ),
      ),
    );
  }
}
