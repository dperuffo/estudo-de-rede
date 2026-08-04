import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agendamentos_patio_provider.dart';
import '../services/agendamentos_patio_service.dart';

final _service = AgendamentosPatioService();

const _corStatus = <String, Color>{
  'agendado': Color(0xFFFEF3C7),
  'confirmado': Color(0xFFDBEAFE),
  'em_andamento': Color(0xFFEDE9FE),
  'concluido': Color(0xFFDCFCE7),
  'cancelado': Color(0xFFF1F5F9),
};
const _corTextoStatus = <String, Color>{
  'agendado': Color(0xFF92400E),
  'confirmado': Color(0xFF1E40AF),
  'em_andamento': Color(0xFF5B21B6),
  'concluido': Color(0xFF166534),
  'cancelado': Color(0xFF475569),
};

// Fase agendamento-patio (04/08/2026) — porta de AgendamentoPatioCard.tsx
// (web). Vive dentro da tela de detalhe do frete, uma instância pra coleta
// e outra pra entrega. Sem agendamento: formulário compacto de criação.
// Com agendamento: badge de status + janela + doca + ações.
class AgendamentoPatioCard extends ConsumerStatefulWidget {
  final String freteId;
  final String empresaId;
  final String tipo; // 'coleta' | 'entrega'
  final String localLabelPadrao;
  final AgendamentoPatio? agendamento;

  const AgendamentoPatioCard({
    super.key,
    required this.freteId,
    required this.empresaId,
    required this.tipo,
    required this.localLabelPadrao,
    required this.agendamento,
  });

  @override
  ConsumerState<AgendamentoPatioCard> createState() => _AgendamentoPatioCardState();
}

class _AgendamentoPatioCardState extends ConsumerState<AgendamentoPatioCard> {
  bool _editando = false;
  bool _carregando = false;
  String? _erro;
  DateTime? _inicio;
  DateTime? _fim;
  final _docaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _preencher();
  }

  @override
  void didUpdateWidget(covariant AgendamentoPatioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agendamento?.id != widget.agendamento?.id) _preencher();
  }

  void _preencher() {
    final a = widget.agendamento;
    _inicio = a?.janelaInicio;
    _fim = a?.janelaFim;
    _docaCtrl.text = a?.doca ?? '';
    _obsCtrl.text = a?.observacoes ?? '';
  }

  Future<DateTime?> _escolherDataHora(DateTime? valorAtual) async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: valorAtual ?? agora,
      firstDate: DateTime(agora.year - 1),
      lastDate: DateTime(agora.year + 2),
    );
    if (data == null) return null;
    if (!mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: valorAtual != null ? TimeOfDay.fromDateTime(valorAtual) : TimeOfDay.now(),
    );
    if (hora == null) return null;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  String _formatarDataHora(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  String _formatarJanela(DateTime inicio, DateTime fim) {
    final dd = inicio.day.toString().padLeft(2, '0');
    final mm = inicio.month.toString().padLeft(2, '0');
    final hi = '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
    final hf = '${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}';
    return '$dd/$mm, $hi–$hf';
  }

  Future<void> _salvar() async {
    if (_inicio == null || _fim == null) {
      setState(() => _erro = 'Informe o início e o fim da janela.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final erro = widget.agendamento == null
        ? await _service.criar(
            freteId: widget.freteId,
            empresaId: widget.empresaId,
            tipo: widget.tipo,
            localLabel: widget.localLabelPadrao,
            doca: _docaCtrl.text.trim(),
            janelaInicio: _inicio!,
            janelaFim: _fim!,
            observacoes: _obsCtrl.text.trim(),
          )
        : await _service.reagendar(
            id: widget.agendamento!.id,
            empresaId: widget.empresaId,
            doca: _docaCtrl.text.trim(),
            janelaInicio: _inicio!,
            janelaFim: _fim!,
            observacoes: _obsCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() {
      _carregando = false;
      _erro = erro;
    });
    if (erro == null) {
      setState(() => _editando = false);
      ref.invalidate(agendamentosPatioFreteProvider(widget.freteId));
    }
  }

  Future<void> _confirmar() async {
    setState(() => _carregando = true);
    await _service.confirmar(widget.agendamento!.id);
    if (!mounted) return;
    setState(() => _carregando = false);
    ref.invalidate(agendamentosPatioFreteProvider(widget.freteId));
  }

  Future<void> _cancelar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancelar agendamento de ${labelTipoAgendamentoPatio[widget.tipo]?.toLowerCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar agendamento')),
        ],
      ),
    );
    if (confirmou != true) return;
    setState(() => _carregando = true);
    await _service.cancelar(widget.agendamento!.id);
    if (!mounted) return;
    setState(() => _carregando = false);
    ref.invalidate(agendamentosPatioFreteProvider(widget.freteId));
  }

  @override
  Widget build(BuildContext context) {
    final agendamento = widget.agendamento;
    final mostrarFormulario = agendamento == null || _editando;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelTipoAgendamentoPatio[widget.tipo]?.toUpperCase() ?? widget.tipo.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          if (mostrarFormulario) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final v = await _escolherDataHora(_inicio);
                      if (v != null) setState(() => _inicio = v);
                    },
                    child: Text(_inicio != null ? 'Início: ${_formatarDataHora(_inicio!)}' : 'Início da janela'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final v = await _escolherDataHora(_fim);
                      if (v != null) setState(() => _fim = v);
                    },
                    child: Text(_fim != null ? 'Fim: ${_formatarDataHora(_fim!)}' : 'Fim da janela'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _docaCtrl,
              decoration: const InputDecoration(labelText: 'Doca/vaga (opcional)', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obsCtrl,
              decoration: const InputDecoration(labelText: 'Observações (opcional)', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _carregando ? null : _salvar,
                  child: Text(_carregando ? '...' : (_editando ? 'Salvar' : 'Agendar')),
                ),
                if (_editando) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _carregando
                        ? null
                        : () => setState(() {
                              _editando = false;
                              _preencher();
                              _erro = null;
                            }),
                    child: const Text('Cancelar edição'),
                  ),
                ],
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 6),
              Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _corStatus[agendamento.status] ?? const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labelStatusAgendamentoPatio[agendamento.status] ?? agendamento.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _corTextoStatus[agendamento.status] ?? Colors.black54),
                  ),
                ),
                Text(_formatarJanela(agendamento.janelaInicio, agendamento.janelaFim), style: const TextStyle(fontSize: 13)),
                if (agendamento.doca != null) Text('· doca ${agendamento.doca}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
            if (agendamento.observacoes != null) ...[
              const SizedBox(height: 4),
              Text(agendamento.observacoes!, style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
            ],
            if (['agendado', 'confirmado'].contains(agendamento.status)) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  if (agendamento.status == 'agendado')
                    TextButton(onPressed: _carregando ? null : _confirmar, child: const Text('Confirmar')),
                  TextButton(onPressed: _carregando ? null : () => setState(() => _editando = true), child: const Text('Reagendar')),
                  TextButton(
                    onPressed: _carregando ? null : _cancelar,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
