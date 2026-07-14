import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Relatórios (cliente): só a aba "🗂️ Relatórios
// Personalizados" (pedido do Daniel) de relatorios/page.tsx, que é a
// única 100% client-side (monta gráfico/tabela a partir de 3 fontes brutas
// já carregadas). RLS/RPCs conferidas antes de portar: as 3 RPCs
// (relatorio_abastecimentos_bruto/relatorio_manutencoes_bruto/
// relatorio_custos_fixos_bruto) NÃO são SECURITY DEFINER — rodam com o
// privilégio de quem chama, então a RLS das tabelas de baixo
// (abastecimentos_unificado → profrotas_abastecimentos +
// abastecimentos_externos; manutencoes_realizadas; custos_fixos) protege
// os dados normalmente, mesmo passando p_empresa_id explícito. Todas já
// têm self-service completo pra empresa do usuário (via
// empresas_do_usuario), confirmado em pg_policies.
//
// Fora do escopo: as outras 4 abas de Relatórios (Executivo, Performance
// por Posto, Score × Performance, Anomalias — cada uma com seu próprio
// layout/gráficos fixos, não pedidas agora), export em CSV e PDF
// (RelatorioPersonalizadoPdf.tsx serializa o SVG do Recharts pra imagem
// e monta um PDF com @react-pdf/renderer — muito específico de browser,
// natural pra próxima fase se o Daniel precisar), e o tipo de gráfico
// "Barras Horizontais" (fl_chart não tem orientação horizontal nativa —
// os 4 tipos restantes cobrem o essencial). Redução adicional: com 2+
// métricas selecionadas, o GRÁFICO plota só a 1ª (mesmo comportamento que
// a pizza já tinha na web) — a TABELA (e a "pivot" fonte×dimensão em si)
// continua mostrando todas as métricas selecionadas.

class AbastecimentoBruto {
  final String? placa, motorista, produto, cnpjPosto, nomePosto, ufPosto;
  final double? litros, valor, precoLitro, hodometro;
  final String? data;
  const AbastecimentoBruto({
    this.placa,
    this.motorista,
    this.produto,
    this.cnpjPosto,
    this.nomePosto,
    this.ufPosto,
    this.litros,
    this.valor,
    this.precoLitro,
    this.hodometro,
    this.data,
  });
  factory AbastecimentoBruto.fromMap(Map<String, dynamic> m) => AbastecimentoBruto(
        placa: m['placa'] as String?,
        motorista: m['motorista'] as String?,
        produto: m['produto'] as String?,
        cnpjPosto: m['cnpj_posto'] as String?,
        nomePosto: m['nome_posto'] as String?,
        ufPosto: m['uf_posto'] as String?,
        litros: (m['litros'] as num?)?.toDouble(),
        valor: (m['valor'] as num?)?.toDouble(),
        precoLitro: (m['preco_litro'] as num?)?.toDouble(),
        hodometro: (m['hodometro'] as num?)?.toDouble(),
        data: m['data'] as String?,
      );
}

class ManutencaoBruto {
  final String? placa, oficina, data;
  final double? custoTotal;
  const ManutencaoBruto({this.placa, this.oficina, this.custoTotal, this.data});
  factory ManutencaoBruto.fromMap(Map<String, dynamic> m) => ManutencaoBruto(
        placa: m['placa'] as String?,
        oficina: m['oficina'] as String?,
        custoTotal: (m['custo_total'] as num?)?.toDouble(),
        data: m['data'] as String?,
      );
}

class CustoFixoBruto {
  final String? placa, tipo, descricao, data, origem;
  final double? valor;
  final bool? recorrente;
  const CustoFixoBruto({this.placa, this.tipo, this.descricao, this.valor, this.data, this.recorrente, this.origem});
  factory CustoFixoBruto.fromMap(Map<String, dynamic> m) => CustoFixoBruto(
        placa: m['placa'] as String?,
        tipo: m['tipo'] as String?,
        descricao: m['descricao'] as String?,
        valor: (m['valor'] as num?)?.toDouble(),
        data: m['data'] as String?,
        recorrente: m['recorrente'] as bool?,
        origem: m['origem'] as String?,
      );
}

class RelatoriosBrutos {
  final List<AbastecimentoBruto> abastecimentos;
  final List<ManutencaoBruto> manutencoes;
  final List<CustoFixoBruto> custosFixos;
  const RelatoriosBrutos({required this.abastecimentos, required this.manutencoes, required this.custosFixos});
}

String _fmtData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Mesma janela padrão da web: últimos 365 dias pra abastecimentos/
// manutenção; custos fixos também olha 365 dias PRA FRENTE (seguro/IPVA
// costumam ser lançados com competência futura).
final relatoriosBrutosProvider = FutureProvider.autoDispose<RelatoriosBrutos>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) {
    return const RelatoriosBrutos(abastecimentos: [], manutencoes: [], custosFixos: []);
  }
  final supabase = SupabaseService.client;
  final hoje = DateTime.now();
  final dataInicio = hoje.subtract(const Duration(days: 365));
  final dataFimCustos = hoje.add(const Duration(days: 365));

  final resultados = await Future.wait([
    supabase.rpc('relatorio_abastecimentos_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_manutencoes_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_custos_fixos_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(dataFimCustos),
    }),
  ]);

  final abastecimentos =
      ((resultados[0] as List?) ?? []).map((r) => AbastecimentoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final manutencoes = ((resultados[1] as List?) ?? []).map((r) => ManutencaoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final custosFixos = ((resultados[2] as List?) ?? []).map((r) => CustoFixoBruto.fromMap(r as Map<String, dynamic>)).toList();

  return RelatoriosBrutos(abastecimentos: abastecimentos, manutencoes: manutencoes, custosFixos: custosFixos);
});

// Porta de TIPO_CUSTO_FIXO_LABEL (src/lib/financeiro.ts).
const tipoCustoFixoLabel = {
  'seguro': 'Seguro',
  'ipva': 'IPVA',
  'licenciamento': 'Licenciamento',
  'rastreamento': 'Rastreamento',
  'multa': 'Multa',
  'pedagio': 'Pedágio',
  'outro': 'Outro',
};

const fontesRelatorio = ['abastecimentos', 'manutencao', 'custos_fixos'];
const fonteLabel = {'abastecimentos': 'Abastecimentos', 'manutencao': 'Manutenção', 'custos_fixos': 'Custos Fixos'};

String mesRef(String? data) {
  if (data == null || data.length < 7) return '—';
  return data.substring(0, 7); // YYYY-MM
}

typedef ExtratorDimensao = String Function(Object linha);
typedef CalculadoraMetrica = double Function(List<Object> linhas);

class DimensaoRelatorio {
  final String id;
  final String label;
  final ExtratorDimensao extrator;
  const DimensaoRelatorio({required this.id, required this.label, required this.extrator});
}

class MetricaRelatorio {
  final String id;
  final String label;
  final String formato; // int | dec | money | money3
  final CalculadoraMetrica calcular;
  const MetricaRelatorio({required this.id, required this.label, required this.formato, required this.calcular});
}

// Porta fiel de DIMENSOES (RelatoriosPersonalizados.tsx).
final Map<String, List<DimensaoRelatorio>> dimensoesPorFonte = {
  'abastecimentos': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (por mês)', extrator: (r) => mesRef((r as AbastecimentoBruto).data)),
    DimensaoRelatorio(id: 'produto', label: 'Combustível', extrator: (r) => (r as AbastecimentoBruto).produto ?? '—'),
    DimensaoRelatorio(id: 'placa', label: 'Veículo (Placa)', extrator: (r) => (r as AbastecimentoBruto).placa ?? '—'),
    DimensaoRelatorio(id: 'motorista', label: 'Motorista', extrator: (r) => (r as AbastecimentoBruto).motorista ?? '—'),
    DimensaoRelatorio(id: 'nome_posto', label: 'Posto', extrator: (r) => (r as AbastecimentoBruto).nomePosto ?? '—'),
    DimensaoRelatorio(id: 'uf_posto', label: 'Estado (UF)', extrator: (r) => (r as AbastecimentoBruto).ufPosto ?? '—'),
  ],
  'manutencao': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (por mês)', extrator: (r) => mesRef((r as ManutencaoBruto).data)),
    DimensaoRelatorio(id: 'placa', label: 'Veículo (Placa)', extrator: (r) => (r as ManutencaoBruto).placa ?? '—'),
    DimensaoRelatorio(id: 'oficina', label: 'Oficina', extrator: (r) => (r as ManutencaoBruto).oficina ?? '—'),
  ],
  'custos_fixos': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (por mês)', extrator: (r) => mesRef((r as CustoFixoBruto).data)),
    DimensaoRelatorio(
      id: 'tipo',
      label: 'Tipo de custo',
      extrator: (r) {
        final tipo = (r as CustoFixoBruto).tipo;
        return (tipo != null ? tipoCustoFixoLabel[tipo] : null) ?? tipo ?? '—';
      },
    ),
    DimensaoRelatorio(id: 'placa', label: 'Veículo (Placa)', extrator: (r) => (r as CustoFixoBruto).placa ?? '—'),
    DimensaoRelatorio(
      id: 'origem',
      label: 'Origem',
      extrator: (r) => (r as CustoFixoBruto).origem == 'api' ? 'Integração' : 'Manual',
    ),
  ],
};

// Porta fiel de METRICAS (RelatoriosPersonalizados.tsx).
final Map<String, List<MetricaRelatorio>> metricasPorFonte = {
  'abastecimentos': [
    MetricaRelatorio(id: 'qtd', label: 'Nº de Abastecimentos', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'volume',
      label: 'Volume Total (L)',
      formato: 'dec',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as AbastecimentoBruto).litros ?? 0)),
    ),
    MetricaRelatorio(
      id: 'valor',
      label: 'Valor Total (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as AbastecimentoBruto).valor ?? 0)),
    ),
    MetricaRelatorio(
      id: 'ticket_med',
      label: 'Ticket Médio (R\$)',
      formato: 'money',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as AbastecimentoBruto).valor ?? 0)) / l.length,
    ),
    MetricaRelatorio(
      id: 'preco_med',
      label: 'Preço Médio (R\$/L)',
      formato: 'money3',
      calcular: (l) {
        final validos = l.where((r) => ((r as AbastecimentoBruto).precoLitro ?? 0) > 0).toList();
        if (validos.isEmpty) return 0;
        return validos.fold(0.0, (s, r) => s + ((r as AbastecimentoBruto).precoLitro ?? 0)) / validos.length;
      },
    ),
  ],
  'manutencao': [
    MetricaRelatorio(
      id: 'man_custo',
      label: 'Custo Total (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as ManutencaoBruto).custoTotal ?? 0)),
    ),
    MetricaRelatorio(id: 'man_qtd', label: 'Nº de Registros', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'man_custo_med',
      label: 'Custo Médio (R\$)',
      formato: 'money',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as ManutencaoBruto).custoTotal ?? 0)) / l.length,
    ),
  ],
  'custos_fixos': [
    MetricaRelatorio(
      id: 'cf_valor',
      label: 'Valor Total (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as CustoFixoBruto).valor ?? 0)),
    ),
    MetricaRelatorio(id: 'cf_qtd', label: 'Nº de Lançamentos', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'cf_valor_med',
      label: 'Valor Médio (R\$)',
      formato: 'money',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as CustoFixoBruto).valor ?? 0)) / l.length,
    ),
  ],
};

class GrupoRelatorio {
  final String chave;
  final Map<String, double> valores;
  final int qtdLinhas;
  const GrupoRelatorio({required this.chave, required this.valores, required this.qtdLinhas});
}

// Porta fiel do `resultado` (useMemo em RelatoriosPersonalizados.tsx):
// agrupa pela dimensão, calcula cada métrica selecionada por grupo, ordena
// desc pela 1ª métrica.
List<GrupoRelatorio> calcularResultado(List<Object> linhas, DimensaoRelatorio dimensao, List<MetricaRelatorio> metricas) {
  final grupos = <String, List<Object>>{};
  for (final r in linhas) {
    final chave = dimensao.extrator(r);
    grupos.putIfAbsent(chave, () => []).add(r);
  }
  final resultado = grupos.entries.map((e) {
    final valores = <String, double>{};
    for (final m in metricas) {
      valores[m.id] = m.calcular(e.value);
    }
    return GrupoRelatorio(chave: e.key, valores: valores, qtdLinhas: e.value.length);
  }).toList();

  if (metricas.isNotEmpty) {
    final ordenacaoId = metricas.first.id;
    resultado.sort((a, b) => (b.valores[ordenacaoId] ?? 0).compareTo(a.valores[ordenacaoId] ?? 0));
  }
  return resultado;
}

String formatarValorMetrica(double v, String formato) {
  switch (formato) {
    case 'int':
      return v.round().toString();
    case 'dec':
      return v.toStringAsFixed(1);
    case 'money3':
      return 'R\$ ${v.toStringAsFixed(3)}';
    default:
      return 'R\$ ${v.toStringAsFixed(2)}';
  }
}
