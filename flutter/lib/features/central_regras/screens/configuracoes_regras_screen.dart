import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/configuracoes_regras_provider.dart';
import '../services/configuracoes_regras_service.dart';

// Fase FLT-Central-Regras (03/09/2026) — porta de
// central-regras/configuracoes/page.tsx + LinhaConfiguracaoRegra.tsx.
// Catálogo fechado (13 chaves definidas em código, não no banco);
// edição inline por linha, sem criar/excluir regra.
class ConfiguracoesRegrasScreen extends ConsumerWidget {
  const ConfiguracoesRegrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(configuracoesRegrasOverridesProvider);
    final grupos = <String>[];
    for (final d in catalogoRegrasConfiguraveis) {
      if (!grupos.contains(d.grupo)) grupos.add(d.grupo);
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Configurar limites')),
      body: overrides.when(
        data: (mapa) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(configuracoesRegrasOverridesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final grupo in grupos) ...[
                Text(grupo,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...catalogoRegrasConfiguraveis
                    .where((d) => d.grupo == grupo)
                    .map((d) => _LinhaRegra(definicao: d, valorAtual: mapa[d.chave])),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
      ),
    );
  }
}

class _LinhaRegra extends ConsumerStatefulWidget {
  final DefinicaoRegra definicao;
  final double? valorAtual;

  const _LinhaRegra({required this.definicao, required this.valorAtual});

  @override
  ConsumerState<_LinhaRegra> createState() => _LinhaRegraState();
}

class _LinhaRegraState extends ConsumerState<_LinhaRegra> {
  late final TextEditingController _ctrl;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: (widget.valorAtual ?? widget.definicao.padrao).toString());
  }

  @override
  void didUpdateWidget(covariant _LinhaRegra oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valorAtual != widget.valorAtual) {
      _ctrl.text = (widget.valorAtual ?? widget.definicao.padrao).toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final valor = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (valor == null || valor < widget.definicao.min) {
      setState(() =>
          _erro = 'Valor inválido (mínimo ${widget.definicao.min}).');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ConfiguracoesRegrasService().salvar(
        empresaId: empresaId, chave: widget.definicao.chave, valor: valor);
    if (!mounted) return;
    setState(() {
      _salvando = false;
      _erro = erro;
    });
    if (erro == null) {
      ref.invalidate(configuracoesRegrasOverridesProvider);
    }
  }

  Future<void> _restaurarPadrao() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ConfiguracoesRegrasService()
        .restaurarPadrao(empresaId: empresaId, chave: widget.definicao.chave);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro == null) {
      ref.invalidate(configuracoesRegrasOverridesProvider);
    } else {
      setState(() => _erro = erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalizado = widget.valorAtual != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.definicao.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (personalizado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('Personalizado',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8))),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.definicao.ajuda,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            if (_erro != null) ...[
              Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar'),
                ),
              ],
            ),
            if (personalizado) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _salvando ? null : _restaurarPadrao,
                child: Text('Padrão (${widget.definicao.padrao})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
