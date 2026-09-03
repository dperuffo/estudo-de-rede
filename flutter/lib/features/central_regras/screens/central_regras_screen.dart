import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

// Fase FLT-Central-Regras (03/09/2026) — porta de central-regras/page.tsx:
// hub com cards linkando pra Ações Sugeridas, Antifraude, Central de
// Avisos, Insights de IA (já portados antes) e Configurações de Regras
// (novo nesta fase — os 13 limiares configuráveis).
class CentralRegrasScreen extends StatelessWidget {
  const CentralRegrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itens = <({IconData icone, String titulo, String descricao, String rota})>[
      (
        icone: Icons.auto_awesome,
        titulo: 'Ações Sugeridas',
        descricao:
            'Anomalias de abastecimento detectadas (hodômetro parado, volume acima do tanque, distância suspeita, preço fora da região).',
        rota: '/acoes-sugeridas',
      ),
      (
        icone: Icons.security,
        titulo: 'Antifraude',
        descricao: 'Regras e alertas de antifraude configurados pela empresa.',
        rota: '/antifraude',
      ),
      (
        icone: Icons.campaign_outlined,
        titulo: 'Central de Avisos',
        descricao: 'Avisos e comunicados ativos para a empresa.',
        rota: '/avisos',
      ),
      (
        icone: Icons.psychology_outlined,
        titulo: 'Insights de IA',
        descricao:
            'Sinais cruzados entre combustível, manutenção, pneus, sinistros, multas, aprovações, seguro e motoristas.',
        rota: '/insights-ia',
      ),
      (
        icone: Icons.tune,
        titulo: 'Configurar limites',
        descricao:
            'Ajustar os limiares numéricos usados pelas detecções de anomalias, ações sugeridas e aprovações.',
        rota: '/central-regras/configuracoes',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Central de Regras & Alertas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: itens
            .map((i) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(i.icone),
                    title: Text(i.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(i.descricao,
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(i.rota),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
