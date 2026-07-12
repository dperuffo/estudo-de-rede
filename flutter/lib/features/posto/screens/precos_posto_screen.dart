import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/negociacoes_provider.dart' show produtosPosto;
import '../providers/precos_posto_provider.dart';

final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtDataHora(String iso) {
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Fase FLT-2 — "Meus Preços" da visão Posto: 1 campo de preço por
// combustível, visível aos clientes com quem o posto negocia. Porta (com
// escopo reduzido — ver README) de precos-postos/page.tsx +
// FormularioPrecosPosto.tsx da web.
class PrecosPostoScreen extends ConsumerStatefulWidget {
  const PrecosPostoScreen({super.key});

  @override
  ConsumerState<PrecosPostoScreen> createState() => _PrecosPostoScreenState();
}

class _PrecosPostoScreenState extends ConsumerState<PrecosPostoScreen> {
  final _service = PrecosPostoService();
  final Map<String, TextEditingController> _controllers = {
    for (final p in produtosPosto) p: TextEditingController(),
  };
  bool _preenchido = false;
  bool _salvando = false;
  String? _erro;
  bool _sucesso = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _preencher(List<PrecoPosto> precos) {
    if (_preenchido) return;
    for (final p in precos) {
      _controllers[p.combustivel]?.text = p.preco.toStringAsFixed(3);
    }
    _preenchido = true;
  }

  Future<void> _salvar() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Não foi possível identificar seu posto na sessão atual.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
      _sucesso = false;
    });
    final erro = await _service.salvar(
      empresaPostoId: empresaId,
      precos: {for (final e in _controllers.entries) e.key: e.value.text},
    );
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) {
        _erro = erro;
      } else {
        _sucesso = true;
        ref.invalidate(precosPostoProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(precosPostoProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
      data: (precos) {
        _preencher(precos);
        final auditoria = {for (final p in precos) p.combustivel: p};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Meus Preços', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Preço por combustível que você fornece — visível aos clientes com quem você negocia. '
              'Deixe em branco o combustível que você não vende.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_erro != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            if (_sucesso) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Text('Preços salvos.', style: TextStyle(color: Color(0xFF15803D), fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            for (final produto in produtosPosto) ...[
              TextField(
                controller: _controllers[produto],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '$produto (R\$/L)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (auditoria[produto] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'Atualizado em ${_fmtDataHora(auditoria[produto]!.atualizadoEm)}'
                    '${auditoria[produto]!.atualizadoPor != null ? ' por ${auditoria[produto]!.atualizadoPor}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar preços'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
