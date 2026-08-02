import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Relatórios (cliente): só a aba "🗂️ Relatórios
// Personalizados" (pedido do Daniel) de relatorios/page.tsx, que é a
// única 100% client-side (monta gráfico/tabela a partir das fontes brutas
// já carregadas). RLS/RPCs conferidas antes de portar: as RPCs
// relatorio_*_bruto NÃO são SECURITY DEFINER — rodam com o privilégio de
// quem chama, então a RLS das tabelas de baixo protege os dados
// normalmente, mesmo passando p_empresa_id explícito. Todas já têm
// self-service completo pra empresa do usuário (via empresas_do_usuario),
// confirmado em pg_policies quando as 3 fontes originais foram portadas.
//
// Fase relatorios-mais-dimensoes (porte 02/08/2026, achado real: o Daniel
// reportou "novas dimensões e variáveis não foram implementadas no PWA
// Cliente") — as 6 fontes novas da web (notas_fiscais, fretes, financeiro,
// acoes_sugeridas, chamados, avaliacoes) e as dimensões novas das 3
// originais (município/meio de pagamento/tipo-marca-classificação de
// veículo/centro de custo em abastecimentos; origem/técnico/centro de
// custo em manutenção; período de lançamento/origem/centro de custo/
// recorrente em custos fixos) foram portadas nesta fase.
//
// Fora do escopo: as outras 4 abas de Relatórios (Executivo, Performance
// por Posto, Score × Performance, Anomalias — cada uma com seu próprio
// layout/gráficos fixos, não pedidas agora), export em CSV e PDF
// (RelatorioPersonalizadoPdf.tsx serializa o SVG do Recharts pra imagem
// e monta um PDF com @react-pdf/renderer — muito específico de browser,
// natural pra próxima fase se o Daniel precisar), o filtro de
// granularidade/intervalo de período e os totalizadores (Fases
// filtro-periodo-relatorios/totalizadores-relatorios da web, não pedidos
// agora), e o tipo de gráfico "Barras Horizontais" (fl_chart não tem
// orientação horizontal nativa — os 4 tipos restantes cobrem o essencial).
// Redução adicional: com 2+ métricas selecionadas, o GRÁFICO plota só a
// 1ª (mesmo comportamento que a pizza já tinha na web) — a TABELA (e a
// "pivot" fonte×dimensão em si) continua mostrando todas as métricas
// selecionadas.

class AbastecimentoBruto {
  final String? placa, motorista, produto, cnpjPosto, nomePosto, ufPosto;
  final double? litros, valor, precoLitro, hodometro;
  final String? data;
  // Fase relatorios-mais-dimensoes (porte 02/08/2026) — campos novos que a
  // web já tinha (RelatoriosPersonalizados.tsx) e o Flutter ainda não tinha.
  final String? municipioPosto, meioPagamento, tipoVeiculo, marcaVeiculo, modeloVeiculo, classificacaoVeiculo, centroCusto;
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
    this.municipioPosto,
    this.meioPagamento,
    this.tipoVeiculo,
    this.marcaVeiculo,
    this.modeloVeiculo,
    this.classificacaoVeiculo,
    this.centroCusto,
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
        municipioPosto: m['municipio_posto'] as String?,
        meioPagamento: m['meio_pagamento'] as String?,
        tipoVeiculo: m['tipo_veiculo'] as String?,
        marcaVeiculo: m['marca_veiculo'] as String?,
        modeloVeiculo: m['modelo_veiculo'] as String?,
        classificacaoVeiculo: m['classificacao_veiculo'] as String?,
        centroCusto: m['centro_custo'] as String?,
      );
}

class ManutencaoBruto {
  final String? placa, oficina, data;
  final double? custoTotal;
  // Fase relatorios-mais-dimensoes (porte 02/08/2026).
  final String? origem, tecnico, centroCusto;
  const ManutencaoBruto({this.placa, this.oficina, this.custoTotal, this.data, this.origem, this.tecnico, this.centroCusto});
  factory ManutencaoBruto.fromMap(Map<String, dynamic> m) => ManutencaoBruto(
        placa: m['placa'] as String?,
        oficina: m['oficina'] as String?,
        custoTotal: (m['custo_total'] as num?)?.toDouble(),
        data: m['data'] as String?,
        origem: m['origem'] as String?,
        tecnico: m['tecnico'] as String?,
        centroCusto: m['centro_custo'] as String?,
      );
}

class CustoFixoBruto {
  final String? placa, tipo, descricao, data, origem;
  final double? valor;
  final bool? recorrente;
  // Fase relatorios-mais-dimensoes (porte 02/08/2026).
  final String? dataLancamento, centroCusto;
  const CustoFixoBruto({
    this.placa,
    this.tipo,
    this.descricao,
    this.valor,
    this.data,
    this.recorrente,
    this.origem,
    this.dataLancamento,
    this.centroCusto,
  });
  factory CustoFixoBruto.fromMap(Map<String, dynamic> m) => CustoFixoBruto(
        placa: m['placa'] as String?,
        tipo: m['tipo'] as String?,
        descricao: m['descricao'] as String?,
        valor: (m['valor'] as num?)?.toDouble(),
        data: m['data'] as String?,
        recorrente: m['recorrente'] as bool?,
        origem: m['origem'] as String?,
        dataLancamento: m['data_lancamento'] as String?,
        centroCusto: m['centro_custo'] as String?,
      );
}

// Fase relatorios-mais-dimensoes (porte 02/08/2026) — 6 fontes novas, mesmo
// padrão snake_case (banco) -> camelCase (Dart) das 3 originais acima. Porte
// fiel de NotaFiscalBruto/FreteBruto/FinanceiroBruto/AcaoSugeridaBruto/
// ChamadoBruto/AvaliacaoBruto em RelatoriosPersonalizados.tsx.
class NotaFiscalBruto {
  final String? produto, nomePosto, cnpjPosto, data;
  final double? numeroNf, quantidade, valorTotal, valorUnitario;
  const NotaFiscalBruto({this.produto, this.nomePosto, this.cnpjPosto, this.numeroNf, this.quantidade, this.valorTotal, this.valorUnitario, this.data});
  factory NotaFiscalBruto.fromMap(Map<String, dynamic> m) => NotaFiscalBruto(
        produto: m['produto'] as String?,
        nomePosto: m['nome_posto'] as String?,
        cnpjPosto: m['cnpj_posto'] as String?,
        numeroNf: (m['numero_nf'] as num?)?.toDouble(),
        quantidade: (m['quantidade'] as num?)?.toDouble(),
        valorTotal: (m['valor_total'] as num?)?.toDouble(),
        valorUnitario: (m['valor_unitario'] as num?)?.toDouble(),
        data: m['data'] as String?,
      );
}

class FreteBruto {
  final String? titulo, status, tipoCarga, ufOrigem, ufDestino, motorista, data;
  final double? valorOferecido, kmEstimado, pesoCargaKg;
  const FreteBruto({
    this.titulo,
    this.status,
    this.tipoCarga,
    this.ufOrigem,
    this.ufDestino,
    this.motorista,
    this.valorOferecido,
    this.kmEstimado,
    this.pesoCargaKg,
    this.data,
  });
  factory FreteBruto.fromMap(Map<String, dynamic> m) => FreteBruto(
        titulo: m['titulo'] as String?,
        status: m['status'] as String?,
        tipoCarga: m['tipo_carga'] as String?,
        ufOrigem: m['uf_origem'] as String?,
        ufDestino: m['uf_destino'] as String?,
        motorista: m['motorista'] as String?,
        valorOferecido: (m['valor_oferecido'] as num?)?.toDouble(),
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        pesoCargaKg: (m['peso_carga_kg'] as num?)?.toDouble(),
        data: m['data'] as String?,
      );
}

class FinanceiroBruto {
  final String? movimento, status, contraparte, origem, data;
  final double? valorOriginal, valorPago;
  const FinanceiroBruto({this.movimento, this.status, this.contraparte, this.origem, this.valorOriginal, this.valorPago, this.data});
  factory FinanceiroBruto.fromMap(Map<String, dynamic> m) => FinanceiroBruto(
        movimento: m['movimento'] as String?,
        status: m['status'] as String?,
        contraparte: m['contraparte'] as String?,
        origem: m['origem'] as String?,
        valorOriginal: (m['valor_original'] as num?)?.toDouble(),
        valorPago: (m['valor_pago'] as num?)?.toDouble(),
        data: m['data'] as String?,
      );
}

class AcaoSugeridaBruto {
  final String? tipo, severidade, status, alvoLabel, data;
  const AcaoSugeridaBruto({this.tipo, this.severidade, this.status, this.alvoLabel, this.data});
  factory AcaoSugeridaBruto.fromMap(Map<String, dynamic> m) => AcaoSugeridaBruto(
        tipo: m['tipo'] as String?,
        severidade: m['severidade'] as String?,
        status: m['status'] as String?,
        alvoLabel: m['alvo_label'] as String?,
        data: m['data'] as String?,
      );
}

class ChamadoBruto {
  final String? tipo, prioridade, status, data;
  const ChamadoBruto({this.tipo, this.prioridade, this.status, this.data});
  factory ChamadoBruto.fromMap(Map<String, dynamic> m) => ChamadoBruto(
        tipo: m['tipo'] as String?,
        prioridade: m['prioridade'] as String?,
        status: m['status'] as String?,
        data: m['data'] as String?,
      );
}

class AvaliacaoBruto {
  final double? estrelas;
  final bool? temComentario;
  final String? data;
  const AvaliacaoBruto({this.estrelas, this.temComentario, this.data});
  factory AvaliacaoBruto.fromMap(Map<String, dynamic> m) => AvaliacaoBruto(
        estrelas: (m['estrelas'] as num?)?.toDouble(),
        temComentario: m['tem_comentario'] as bool?,
        data: m['data'] as String?,
      );
}

class RelatoriosBrutos {
  final List<AbastecimentoBruto> abastecimentos;
  final List<ManutencaoBruto> manutencoes;
  final List<CustoFixoBruto> custosFixos;
  final List<NotaFiscalBruto> notasFiscais;
  final List<FreteBruto> fretes;
  final List<FinanceiroBruto> financeiro;
  final List<AcaoSugeridaBruto> acoesSugeridas;
  final List<ChamadoBruto> chamados;
  final List<AvaliacaoBruto> avaliacoes;
  const RelatoriosBrutos({
    required this.abastecimentos,
    required this.manutencoes,
    required this.custosFixos,
    this.notasFiscais = const [],
    this.fretes = const [],
    this.financeiro = const [],
    this.acoesSugeridas = const [],
    this.chamados = const [],
    this.avaliacoes = const [],
  });
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
    // Fase relatorios-mais-dimensoes (porte 02/08/2026) — mesma janela padrão
    // de 365 dias retroativos das 3 fontes originais (relatorios/page.tsx).
    supabase.rpc('relatorio_notas_fiscais_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_fretes_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_financeiro_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_acoes_sugeridas_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_chamados_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
    supabase.rpc('relatorio_avaliacoes_bruto', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _fmtData(dataInicio),
      'p_data_fim': _fmtData(hoje),
    }),
  ]);

  final abastecimentos =
      ((resultados[0] as List?) ?? []).map((r) => AbastecimentoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final manutencoes = ((resultados[1] as List?) ?? []).map((r) => ManutencaoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final custosFixos = ((resultados[2] as List?) ?? []).map((r) => CustoFixoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final notasFiscais = ((resultados[3] as List?) ?? []).map((r) => NotaFiscalBruto.fromMap(r as Map<String, dynamic>)).toList();
  final fretes = ((resultados[4] as List?) ?? []).map((r) => FreteBruto.fromMap(r as Map<String, dynamic>)).toList();
  final financeiro = ((resultados[5] as List?) ?? []).map((r) => FinanceiroBruto.fromMap(r as Map<String, dynamic>)).toList();
  final acoesSugeridas = ((resultados[6] as List?) ?? []).map((r) => AcaoSugeridaBruto.fromMap(r as Map<String, dynamic>)).toList();
  final chamados = ((resultados[7] as List?) ?? []).map((r) => ChamadoBruto.fromMap(r as Map<String, dynamic>)).toList();
  final avaliacoes = ((resultados[8] as List?) ?? []).map((r) => AvaliacaoBruto.fromMap(r as Map<String, dynamic>)).toList();

  return RelatoriosBrutos(
    abastecimentos: abastecimentos,
    manutencoes: manutencoes,
    custosFixos: custosFixos,
    notasFiscais: notasFiscais,
    fretes: fretes,
    financeiro: financeiro,
    acoesSugeridas: acoesSugeridas,
    chamados: chamados,
    avaliacoes: avaliacoes,
  );
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

// Fase relatorios-mais-dimensoes (porte 02/08/2026) — 6 fontes novas
// adicionadas, mesma ordem/rótulos de FONTE_LABEL (RelatoriosPersonalizados.tsx).
const fontesRelatorio = [
  'abastecimentos',
  'manutencao',
  'custos_fixos',
  'notas_fiscais',
  'fretes',
  'financeiro',
  'acoes_sugeridas',
  'chamados',
  'avaliacoes',
];
const fonteLabel = {
  'abastecimentos': 'Abastecimentos',
  'manutencao': 'Manutenção',
  'custos_fixos': 'Custos Fixos',
  'notas_fiscais': 'Notas Fiscais',
  'fretes': 'Fretes',
  'financeiro': 'Financeiro (Contas a Receber/Pagar)',
  'acoes_sugeridas': 'Ações Sugeridas',
  'chamados': 'Chamados',
  'avaliacoes': 'Avaliações',
};

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

// Porta fiel de DIMENSOES (RelatoriosPersonalizados.tsx). Fase
// relatorios-mais-dimensoes (porte 02/08/2026): as 3 fontes originais
// ganharam as dimensões novas que a web já tinha; 6 fontes novas adicionadas.
final Map<String, List<DimensaoRelatorio>> dimensoesPorFonte = {
  'abastecimentos': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (por mês)', extrator: (r) => mesRef((r as AbastecimentoBruto).data)),
    DimensaoRelatorio(id: 'produto', label: 'Combustível', extrator: (r) => (r as AbastecimentoBruto).produto ?? '—'),
    DimensaoRelatorio(id: 'placa', label: 'Veículo (Placa)', extrator: (r) => (r as AbastecimentoBruto).placa ?? '—'),
    DimensaoRelatorio(id: 'motorista', label: 'Motorista', extrator: (r) => (r as AbastecimentoBruto).motorista ?? '—'),
    DimensaoRelatorio(id: 'nome_posto', label: 'Posto', extrator: (r) => (r as AbastecimentoBruto).nomePosto ?? '—'),
    DimensaoRelatorio(id: 'uf_posto', label: 'Estado (UF)', extrator: (r) => (r as AbastecimentoBruto).ufPosto ?? '—'),
    DimensaoRelatorio(id: 'municipio_posto', label: 'Município do Posto', extrator: (r) => (r as AbastecimentoBruto).municipioPosto ?? '—'),
    DimensaoRelatorio(id: 'meio_pagamento', label: 'Meio de Pagamento', extrator: (r) => (r as AbastecimentoBruto).meioPagamento ?? '—'),
    DimensaoRelatorio(id: 'tipo_veiculo', label: 'Tipo de Veículo', extrator: (r) => (r as AbastecimentoBruto).tipoVeiculo ?? '—'),
    DimensaoRelatorio(id: 'marca_veiculo', label: 'Marca do Veículo', extrator: (r) => (r as AbastecimentoBruto).marcaVeiculo ?? '—'),
    DimensaoRelatorio(
      id: 'classificacao_veiculo',
      label: 'Classificação (Próprio/Agregado)',
      extrator: (r) => (r as AbastecimentoBruto).classificacaoVeiculo ?? '—',
    ),
    DimensaoRelatorio(id: 'centro_custo', label: 'Centro de Custo', extrator: (r) => (r as AbastecimentoBruto).centroCusto ?? '—'),
  ],
  'manutencao': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (por mês)', extrator: (r) => mesRef((r as ManutencaoBruto).data)),
    DimensaoRelatorio(id: 'placa', label: 'Veículo (Placa)', extrator: (r) => (r as ManutencaoBruto).placa ?? '—'),
    DimensaoRelatorio(id: 'oficina', label: 'Oficina', extrator: (r) => (r as ManutencaoBruto).oficina ?? '—'),
    DimensaoRelatorio(
      id: 'origem',
      label: 'Origem',
      extrator: (r) => (r as ManutencaoBruto).origem == 'api' ? 'Integração' : 'Manual',
    ),
    DimensaoRelatorio(id: 'tecnico', label: 'Técnico', extrator: (r) => (r as ManutencaoBruto).tecnico ?? '—'),
    DimensaoRelatorio(id: 'centro_custo', label: 'Centro de Custo', extrator: (r) => (r as ManutencaoBruto).centroCusto ?? '—'),
  ],
  'custos_fixos': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (competência)', extrator: (r) => mesRef((r as CustoFixoBruto).data)),
    DimensaoRelatorio(id: 'periodo_lancamento', label: 'Período (lançamento)', extrator: (r) => mesRef((r as CustoFixoBruto).dataLancamento)),
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
    DimensaoRelatorio(id: 'centro_custo', label: 'Centro de Custo', extrator: (r) => (r as CustoFixoBruto).centroCusto ?? '—'),
    DimensaoRelatorio(id: 'recorrente', label: 'Recorrente?', extrator: (r) => (r as CustoFixoBruto).recorrente == true ? 'Sim' : 'Não'),
  ],
  'notas_fiscais': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (emissão)', extrator: (r) => mesRef((r as NotaFiscalBruto).data)),
    DimensaoRelatorio(id: 'produto', label: 'Produto (ANP)', extrator: (r) => (r as NotaFiscalBruto).produto ?? '—'),
    DimensaoRelatorio(id: 'nome_posto', label: 'Posto Emitente', extrator: (r) => (r as NotaFiscalBruto).nomePosto ?? '—'),
  ],
  'fretes': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período', extrator: (r) => mesRef((r as FreteBruto).data)),
    DimensaoRelatorio(id: 'status', label: 'Status', extrator: (r) => (r as FreteBruto).status ?? '—'),
    DimensaoRelatorio(id: 'tipo_carga', label: 'Tipo de Carga', extrator: (r) => (r as FreteBruto).tipoCarga ?? '—'),
    DimensaoRelatorio(id: 'uf_origem', label: 'UF de Origem', extrator: (r) => (r as FreteBruto).ufOrigem ?? '—'),
    DimensaoRelatorio(id: 'uf_destino', label: 'UF de Destino', extrator: (r) => (r as FreteBruto).ufDestino ?? '—'),
    DimensaoRelatorio(id: 'motorista', label: 'Motorista', extrator: (r) => (r as FreteBruto).motorista ?? '—'),
  ],
  'financeiro': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (vencimento)', extrator: (r) => mesRef((r as FinanceiroBruto).data)),
    DimensaoRelatorio(id: 'movimento', label: 'Movimento (Receber/Pagar)', extrator: (r) => (r as FinanceiroBruto).movimento ?? '—'),
    DimensaoRelatorio(id: 'status', label: 'Status', extrator: (r) => (r as FinanceiroBruto).status ?? '—'),
    DimensaoRelatorio(id: 'contraparte', label: 'Cliente/Fornecedor', extrator: (r) => (r as FinanceiroBruto).contraparte ?? '—'),
    DimensaoRelatorio(id: 'origem', label: 'Origem', extrator: (r) => (r as FinanceiroBruto).origem ?? '—'),
  ],
  'acoes_sugeridas': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período (detecção)', extrator: (r) => mesRef((r as AcaoSugeridaBruto).data)),
    DimensaoRelatorio(id: 'tipo', label: 'Tipo', extrator: (r) => (r as AcaoSugeridaBruto).tipo ?? '—'),
    DimensaoRelatorio(id: 'severidade', label: 'Severidade', extrator: (r) => (r as AcaoSugeridaBruto).severidade ?? '—'),
    DimensaoRelatorio(id: 'status', label: 'Status', extrator: (r) => (r as AcaoSugeridaBruto).status ?? '—'),
    DimensaoRelatorio(id: 'alvo', label: 'Alvo', extrator: (r) => (r as AcaoSugeridaBruto).alvoLabel ?? '—'),
  ],
  'chamados': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período', extrator: (r) => mesRef((r as ChamadoBruto).data)),
    DimensaoRelatorio(id: 'tipo', label: 'Tipo', extrator: (r) => (r as ChamadoBruto).tipo ?? '—'),
    DimensaoRelatorio(id: 'prioridade', label: 'Prioridade', extrator: (r) => (r as ChamadoBruto).prioridade ?? '—'),
    DimensaoRelatorio(id: 'status', label: 'Status', extrator: (r) => (r as ChamadoBruto).status ?? '—'),
  ],
  'avaliacoes': [
    DimensaoRelatorio(id: 'periodo_mes', label: 'Período', extrator: (r) => mesRef((r as AvaliacaoBruto).data)),
    DimensaoRelatorio(id: 'estrelas', label: 'Estrelas', extrator: (r) => (r as AvaliacaoBruto).estrelas?.round().toString() ?? '—'),
    DimensaoRelatorio(id: 'tem_comentario', label: 'Com comentário?', extrator: (r) => (r as AvaliacaoBruto).temComentario == true ? 'Sim' : 'Não'),
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
  // Fase relatorios-mais-dimensoes (porte 02/08/2026) — 6 fontes novas.
  'notas_fiscais': [
    MetricaRelatorio(
      id: 'nf_valor',
      label: 'Valor Total (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as NotaFiscalBruto).valorTotal ?? 0)),
    ),
    MetricaRelatorio(id: 'nf_qtd', label: 'Nº de Notas', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'nf_quantidade',
      label: 'Quantidade Total (L)',
      formato: 'dec',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as NotaFiscalBruto).quantidade ?? 0)),
    ),
    MetricaRelatorio(
      id: 'nf_valor_unit_med',
      label: 'Valor Unitário Médio (R\$/L)',
      formato: 'money3',
      calcular: (l) {
        final validos = l.where((r) => ((r as NotaFiscalBruto).valorUnitario ?? 0) > 0).toList();
        if (validos.isEmpty) return 0;
        return validos.fold(0.0, (s, r) => s + ((r as NotaFiscalBruto).valorUnitario ?? 0)) / validos.length;
      },
    ),
  ],
  'fretes': [
    MetricaRelatorio(id: 'fr_qtd', label: 'Nº de Fretes', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'fr_valor',
      label: 'Valor Ofertado Total (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as FreteBruto).valorOferecido ?? 0)),
    ),
    MetricaRelatorio(
      id: 'fr_valor_med',
      label: 'Valor Ofertado Médio (R\$)',
      formato: 'money',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as FreteBruto).valorOferecido ?? 0)) / l.length,
    ),
    MetricaRelatorio(
      id: 'fr_km',
      label: 'Km Estimado Total',
      formato: 'dec',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as FreteBruto).kmEstimado ?? 0)),
    ),
    MetricaRelatorio(
      id: 'fr_peso',
      label: 'Peso da Carga Total (kg)',
      formato: 'dec',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as FreteBruto).pesoCargaKg ?? 0)),
    ),
  ],
  'financeiro': [
    MetricaRelatorio(
      id: 'fin_valor_orig',
      label: 'Valor Original (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as FinanceiroBruto).valorOriginal ?? 0)),
    ),
    MetricaRelatorio(
      id: 'fin_valor_pago',
      label: 'Valor Pago (R\$)',
      formato: 'money',
      calcular: (l) => l.fold(0.0, (s, r) => s + ((r as FinanceiroBruto).valorPago ?? 0)),
    ),
    MetricaRelatorio(id: 'fin_qtd', label: 'Nº de Lançamentos', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'fin_valor_med',
      label: 'Valor Médio (R\$)',
      formato: 'money',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as FinanceiroBruto).valorOriginal ?? 0)) / l.length,
    ),
  ],
  'acoes_sugeridas': [
    MetricaRelatorio(id: 'as_qtd', label: 'Nº de Ações', formato: 'int', calcular: (l) => l.length.toDouble()),
  ],
  'chamados': [
    MetricaRelatorio(id: 'ch_qtd', label: 'Nº de Chamados', formato: 'int', calcular: (l) => l.length.toDouble()),
  ],
  'avaliacoes': [
    MetricaRelatorio(id: 'av_qtd', label: 'Nº de Avaliações', formato: 'int', calcular: (l) => l.length.toDouble()),
    MetricaRelatorio(
      id: 'av_nota_media',
      label: 'Nota Média (estrelas)',
      formato: 'dec',
      calcular: (l) => l.isEmpty ? 0 : l.fold(0.0, (s, r) => s + ((r as AvaliacaoBruto).estrelas ?? 0)) / l.length,
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
