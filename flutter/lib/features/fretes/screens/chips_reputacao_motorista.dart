import 'package:flutter/material.dart';
import '../providers/fretes_provider.dart';

// Fase Fretes-Dados-Completos — pedido do Daniel: "cliente precisa de
// algumas garantias de que o motorista é idôneo". Consolida sinais que já
// existiam espalhados (avaliações, CNH+validade, telefone verificado, 2FA)
// num cartão só — usado tanto nas propostas do mercado aberto quanto na
// lista de parceiros (ver _reputacao_motorista() no banco). Widget público
// porque é compartilhado entre frete_detalhe_screen.dart e
// motoristas_parceiros_screen.dart.
class ChipsReputacaoMotorista extends StatelessWidget {
  final ReputacaoMotorista reputacao;
  const ChipsReputacaoMotorista({super.key, required this.reputacao});

  @override
  Widget build(BuildContext context) {
    Widget chip(String texto, {Color? cor}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: (cor ?? Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Text(texto, style: TextStyle(fontSize: 10.5, color: cor ?? Colors.black54)),
        );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (reputacao.seloVerificado) chip('✅ Motorista verificado', cor: Colors.green),
        chip(
          reputacao.mediaEstrelas != null
              ? '⭐ ${reputacao.mediaEstrelas!.toStringAsFixed(1)} (${reputacao.totalAvaliacoes})'
              : '⭐ Sem avaliações',
        ),
        chip(
          '📦 ${reputacao.fretesConcluidos} concluído${reputacao.fretesConcluidos == 1 ? '' : 's'}'
          '${reputacao.taxaConclusao != null ? ' · ${reputacao.taxaConclusao!.toStringAsFixed(0)}%' : ''}',
        ),
        chip(reputacao.cnhValida ? '🪪 CNH válida' : '🪪 CNH vencida/ausente', cor: reputacao.cnhValida ? null : Colors.orange),
        chip(reputacao.telefoneVerificado ? '📱 Telefone verificado' : '📱 Não verificado'),
        if (reputacao.seguranca2faAtivo) chip('🔒 2FA ativo'),
        chip(reputacao.tempoCadastroFormatado),
      ],
    );
  }
}
