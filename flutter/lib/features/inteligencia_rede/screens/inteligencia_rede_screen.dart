import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inteligencia_rede_provider.dart';
import '../widgets/inteligencia_shared.dart';
import 'abas/aba_alertas.dart';
import 'abas/aba_cobertura_demanda.dart';
import 'abas/aba_comparativo.dart';
import 'abas/aba_cruzamentos.dart';
import 'abas/aba_evolucao_temporal.dart';
import 'abas/aba_macrorregiao_expansao.dart';
import 'abas/aba_mapa_municipios.dart';
import 'abas/aba_operacional.dart';
import 'abas/aba_precos_anp.dart';
import 'abas/aba_tendencia_sazonalidade.dart';

// Fase FLT-5 — pedido do Daniel: "verificar se é possível trazer todas as
// abas de inteligência de rede pro PWA nas visões do admin e cliente".
// Reescrita completa desta tela (a v1 da Fase FLT-3, com só 1 aba
// resumida, fica no histórico do git) — agora com as 10 abas completas de
// src/app/(dashboard)/inteligencia-rede/page.tsx, cada uma em seu próprio
// arquivo dentro de screens/abas/.
//
// Acesso: mesmo padrão de sempre — cliente e admin, nunca perfil "posto"
// (replicado do gate da web em page.tsx). Admin usa o seletor de empresa
// já existente (sessao.empresaId) em vez da visão "toda a plataforma" da
// web — decisão confirmada com o Daniel (ver comentário completo no
// provider). Todos os dados das 10 abas são carregados de uma vez só
// (inteligenciaRedeCompletaProvider) e ficam instantâneos ao trocar de
// aba — só a 1ª carga tem loading.
class InteligenciaRedeScreen extends ConsumerWidget {
  const InteligenciaRedeScreen({super.key});

  // Achado real (reportado pelo Daniel com print): emoji como texto de aba
  // (ex.: "🚦 Operacional") renderiza gigante e colorido em cima do fundo
  // azul da TabBar (fonte de emoji nativa do navegador, bem maior que o
  // texto ao lado) e quebra o alinhamento. Trocado por texto simples, sem
  // emoji — os emojis continuam nos títulos DENTRO de cada aba, onde
  // renderizam em linha com o texto normalmente.
  static const _abas = [
    'Preços vs ANP',
    'Alertas',
    'Macrorregião',
    'Mapa',
    'Comparativo',
    'Cobertura×Demanda',
    'Cruzamentos',
    'Operacional',
    'Evolução',
    'Sazonalidade',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inteligenciaRedeCompletaProvider);

    return DefaultTabController(
      length: _abas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inteligência de Rede'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _abas.map((a) => Tab(text: a)).toList(),
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erro ao carregar: $e', textAlign: TextAlign.center))),
          data: (dados) {
            if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
            return Column(
              children: [
                _cabecalhoKpis(dados),
                Expanded(
                  child: TabBarView(
                    children: [
                      AbaPrecosAnp(dados: dados),
                      AbaAlertas(dados: dados),
                      AbaMacrorregiaoExpansao(dados: dados),
                      AbaMapaMunicipios(dados: dados),
                      AbaComparativo(dados: dados),
                      AbaCoberturaDemanda(dados: dados),
                      AbaCruzamentos(dados: dados),
                      AbaOperacional(dados: dados),
                      AbaEvolucaoTemporal(dados: dados),
                      AbaTendenciaSazonalidade(dados: dados),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cabecalhoKpis(InteligenciaRedeCompleta d) {
    final k = d.kpis;
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: GridView.count(
        // Achado real: 4 colunas deixava cada cartão estreito demais pra
        // rótulos como "Diesel Médio GF" — trocado pra 2 colunas (mais
        // largura por cartão) com um aspect ratio mais baixo (cartão mais
        // baixo/largo em vez de quase quadrado).
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.4,
        children: [
          CartaoIndicador(label: '⛽ Postos GF', valor: formatarInt(k.totalGf), sub: '${k.estadosComPosto} estados', mini: true),
          CartaoIndicador(label: '🏙️ Municípios', valor: formatarInt(k.municipiosUnicos), sub: '${k.coberturaBr}% dos estados', mini: true),
          CartaoIndicador(
            label: '🚛 Diesel Médio GF',
            valor: k.dieselGf > 0 ? formatarMoeda(k.dieselGf) : '—',
            sub: k.dieselGf > 0 && k.deltaDieselPct != null ? '${k.deltaDieselPct! > 0 ? "+" : ""}${k.deltaDieselPct!.toStringAsFixed(1)}% vs ANP' : 'Sem dados',
            mini: true,
          ),
          CartaoIndicador(label: '💰 Saving/Ano', valor: 'R\$ ${(k.savingPotencialAno / 1e6).toStringAsFixed(1)}M', sub: 'base: 100L/sem', mini: true),
        ],
      ),
    );
  }
}
