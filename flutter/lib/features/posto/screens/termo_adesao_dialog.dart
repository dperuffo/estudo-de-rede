import 'package:flutter/material.dart';
import '../../../core/constants/termo_adesao.dart';

// Fase FLT-2 — porta de ModalTermoAdesao.tsx. Mesmo texto canônico
// (termo_adesao.dart), mesma exigência de marcar "li e aceito" antes de
// habilitar o botão de confirmar. Retorna `true` (via Navigator.pop) só se
// o usuário confirmar.
Future<bool> mostrarModalTermoAdesao(
  BuildContext context, {
  required String planoLabel,
  required String precoLabel,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TermoAdesaoDialog(planoLabel: planoLabel, precoLabel: precoLabel),
  );
  return resultado ?? false;
}

class _TermoAdesaoDialog extends StatefulWidget {
  final String planoLabel;
  final String precoLabel;
  const _TermoAdesaoDialog({required this.planoLabel, required this.precoLabel});

  @override
  State<_TermoAdesaoDialog> createState() => _TermoAdesaoDialogState();
}

class _TermoAdesaoDialogState extends State<_TermoAdesaoDialog> {
  bool _aceitou = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Termo de Adesão e Contrato de Prestação de Serviços',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Plano selecionado: ${widget.planoLabel} — ${widget.precoLabel} · Versão $versaoTermoAdesao',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: termoAdesaoParagrafos.map((p) {
                  if (p.isEmpty) return const SizedBox(height: 8);
                  if (p.startsWith('PARTE')) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Text(p,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2D6B))),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(p, style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155))),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _aceitou,
                    onChanged: (v) => setState(() => _aceitou = v ?? false),
                    title: const Text(
                      'Li e aceito o Termo de Adesão e Contrato de Prestação de Serviços acima, o que '
                      'também indica minha concordância com os Termos de Uso da plataforma FNI Gestão de Frotas.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _aceitou ? () => Navigator.of(context).pop(true) : null,
                        child: const Text('Aceito os Termos de Adesão'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
