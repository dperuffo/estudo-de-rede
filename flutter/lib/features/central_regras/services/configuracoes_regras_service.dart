import '../../../core/services/supabase_service.dart';

// Fase FLT-Central-Regras (03/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de central-regras/configuracoes/page.tsx + actions.ts +
// src/lib/regrasConfiguraveis.ts.
//
// Achado da investigação: não existe um "motor de regras" genérico
// (criar regra com tipo/condição/ação/destinatários) — o que existe é
// uma tela de configurações com um catálogo FECHADO de 13 limiares
// numéricos (definidos em código, não no banco), cada um com valor
// padrão + override opcional por empresa em `configuracoes_regras`
// (chave/valor). Sem criar/excluir regra — só editar valor ou
// "restaurar padrão" (que apaga o override). Ambas operações passam
// pelas RPCs `salvar_configuracao_regra`/`restaurar_configuracao_regra_padrao`,
// que já revalidam a whitelist de chaves e a permissão no servidor.
class DefinicaoRegra {
  final String chave;
  final String grupo;
  final String label;
  final String ajuda;
  final double padrao;
  final double passo;
  final double min;

  const DefinicaoRegra({
    required this.chave,
    required this.grupo,
    required this.label,
    required this.ajuda,
    required this.padrao,
    required this.passo,
    required this.min,
  });
}

const catalogoRegrasConfiguraveis = <DefinicaoRegra>[
  // Anomalias de abastecimento
  DefinicaoRegra(
    chave: 'volume_tanque_percentual_max',
    grupo: 'Anomalias de abastecimento',
    label: 'Volume acima da capacidade do tanque (%)',
    ajuda:
        'Sinaliza abastecimento cujo volume excede este percentual da capacidade do tanque do veículo.',
    padrao: 1.15,
    passo: 0.01,
    min: 1,
  ),
  DefinicaoRegra(
    chave: 'geo_distancia_km_min',
    grupo: 'Anomalias de abastecimento',
    label: 'Distância mínima suspeita (km)',
    ajuda:
        'Distância mínima entre abastecimentos consecutivos do mesmo veículo pra considerar suspeito, junto com a velocidade implícita.',
    padrao: 25,
    passo: 1,
    min: 0,
  ),
  DefinicaoRegra(
    chave: 'geo_distancia_velocidade_kmh_min',
    grupo: 'Anomalias de abastecimento',
    label: 'Velocidade implícita mínima suspeita (km/h)',
    ajuda:
        'Velocidade média implícita entre dois abastecimentos, acima da qual o deslocamento é considerado fisicamente improvável.',
    padrao: 100,
    passo: 1,
    min: 0,
  ),
  DefinicaoRegra(
    chave: 'hodometro_dias_parado_max',
    grupo: 'Anomalias de abastecimento',
    label: 'Dias com hodômetro parado (máx.)',
    ajuda:
        'Quantidade de dias seguidos com o mesmo hodômetro registrado, acima da qual gera alerta.',
    padrao: 2,
    passo: 1,
    min: 0,
  ),
  DefinicaoRegra(
    chave: 'preco_regiao_desvios_padrao_max',
    grupo: 'Anomalias de abastecimento',
    label: 'Desvios-padrão de preço acima da região (máx.)',
    ajuda:
        'Quantos desvios-padrão acima da média regional de preço um abastecimento pode ter antes de virar alerta.',
    padrao: 2,
    passo: 0.1,
    min: 0,
  ),
  DefinicaoRegra(
    chave: 'posto_acima_media_percentual_max',
    grupo: 'Anomalias de abastecimento',
    label: 'Posto acima da média (%)',
    ajuda:
        'Percentual acima da média de preço da região que um posto pode praticar antes de virar alerta.',
    padrao: 0.15,
    passo: 0.01,
    min: 0,
  ),
  // Ações sugeridas — mínimo de ocorrências
  DefinicaoRegra(
    chave: 'minimo_ocorrencias_hodometro',
    grupo: 'Ações sugeridas — mínimo de ocorrências',
    label: 'Hodômetro parado — mínimo de ocorrências',
    ajuda:
        'Quantas vezes o padrão de hodômetro parado precisa se repetir antes de virar uma ação sugerida.',
    padrao: 2,
    passo: 1,
    min: 1,
  ),
  DefinicaoRegra(
    chave: 'minimo_ocorrencias_volume_tanque',
    grupo: 'Ações sugeridas — mínimo de ocorrências',
    label: 'Volume acima do tanque — mínimo de ocorrências',
    ajuda:
        'Quantas vezes o padrão de volume acima do tanque precisa se repetir antes de virar uma ação sugerida.',
    padrao: 1,
    passo: 1,
    min: 1,
  ),
  DefinicaoRegra(
    chave: 'minimo_ocorrencias_geo_distancia',
    grupo: 'Ações sugeridas — mínimo de ocorrências',
    label: 'Distância suspeita — mínimo de ocorrências',
    ajuda:
        'Quantas vezes o padrão de distância/velocidade suspeita precisa se repetir antes de virar uma ação sugerida.',
    padrao: 1,
    passo: 1,
    min: 1,
  ),
  DefinicaoRegra(
    chave: 'minimo_ocorrencias_preco_regiao',
    grupo: 'Ações sugeridas — mínimo de ocorrências',
    label: 'Preço acima da região — mínimo de ocorrências',
    ajuda:
        'Quantas vezes o padrão de preço acima da região precisa se repetir antes de virar uma ação sugerida.',
    padrao: 3,
    passo: 1,
    min: 1,
  ),
  // Exame toxicológico e ASO — alerta antecipado
  DefinicaoRegra(
    chave: 'exame_toxicologico_dias_antecedencia',
    grupo: 'Exame toxicológico e ASO — alerta antecipado',
    label: 'Exame toxicológico — dias de antecedência',
    ajuda:
        'Quantos dias antes do vencimento do exame toxicológico o alerta deve começar a aparecer.',
    padrao: 30,
    passo: 1,
    min: 0,
  ),
  DefinicaoRegra(
    chave: 'aso_dias_antecedencia',
    grupo: 'Exame toxicológico e ASO — alerta antecipado',
    label: 'ASO — dias de antecedência',
    ajuda:
        'Quantos dias antes do vencimento do ASO o alerta deve começar a aparecer.',
    padrao: 30,
    passo: 1,
    min: 0,
  ),
  // Aprovações
  DefinicaoRegra(
    chave: 'aprovacao_manutencao_valor_minimo',
    grupo: 'Aprovações',
    label: 'Manutenção — valor mínimo que exige aprovação',
    ajuda:
        'Valor de manutenção a partir do qual o lançamento exige aprovação antes de ser efetivado.',
    padrao: 2000,
    passo: 50,
    min: 0,
  ),
];

class ConfiguracoesRegrasService {
  final _supabase = SupabaseService.client;

  Future<Map<String, double>> buscarOverrides(String empresaId) async {
    final rows = await _supabase
        .from('configuracoes_regras')
        .select('chave, valor')
        .eq('empresa_id', empresaId);
    return {
      for (final m in rows)
        m['chave'] as String: (m['valor'] as num).toDouble(),
    };
  }

  Future<String?> salvar(
      {required String empresaId,
      required String chave,
      required double valor}) async {
    if (!valor.isFinite || valor < 0) {
      return 'Valor inválido.';
    }
    try {
      await _supabase.rpc('salvar_configuracao_regra', params: {
        'p_empresa_id': empresaId,
        'p_chave': chave,
        'p_valor': valor,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> restaurarPadrao(
      {required String empresaId, required String chave}) async {
    try {
      await _supabase.rpc('restaurar_configuracao_regra_padrao', params: {
        'p_empresa_id': empresaId,
        'p_chave': chave,
      });
      return null;
    } catch (e) {
      return 'Não foi possível restaurar: $e';
    }
  }
}
