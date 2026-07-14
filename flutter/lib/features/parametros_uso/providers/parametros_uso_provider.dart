import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Parâmetros de Uso (cliente), porta de parametros-uso/
// page.tsx + novo/[id]/editar (Vínculo) + actions.ts. RLS conferida antes
// de portar: as 9 tabelas (`parametros_vinculo_motorista_veiculo` +
// as 8 de regra) têm self-service COMPLETO (ALL) via `empresas_do_usuario`
// — CRUD direto, sem RPC, igual à web.
//
// Escopo reduzido — a web tem 11 abas (Vínculo + 10 tipos de regra); 1 tipo
// ficou de fora do v1: "Serviços" (`parametros_limite_servicos`), porque o
// campo `limites` é um array JSONB de objetos (serviço/qtd/valor) montado
// por um formulário repetível na web — a UI de "adicionar linha" pra um
// array de objetos é bem mais trabalho que os outros 9 tipos (todos têm
// campos fixos) e é o tipo de regra menos comum no dia a dia, então ficou
// pra uma próxima fase. Os outros 9 (Vínculo + Intervalo + Valor Diário +
// Volume Diário + Produto + Hodômetro Leve/Pesado + Dias/Horários +
// Postos + Cotas) têm CRUD completo aqui.
const diasSemanaParametro = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const combustiveisParametro = ['Diesel', 'Arla 32 + Diesel', 'Gasolina', 'Etanol', 'Flex', 'GNV', 'GLP', 'Elétrico'];
const periodicidadeLabel = {
  'Abastecimento': 'Por abastecimento',
  'Semana': 'Por semana',
  'Quinzena': 'Por quinzena',
  'Mes': 'Por mês',
};

String? _txt(Map<String, dynamic> m, String campo) => m[campo] as String?;
String? _motoristaNome(Map<String, dynamic> m) => (m['motoristas'] as Map<String, dynamic>?)?['nome_completo'] as String?;

class PostoOpcao {
  final String cnpj;
  final String nome;
  const PostoOpcao({required this.cnpj, required this.nome});
}

final postosNegociadosOpcoesProvider = FutureProvider.autoDispose<List<PostoOpcao>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('negociacoes_postos')
      .select('posto_cnpj, posto_nome')
      .eq('empresa_cliente_id', empresaId)
      .eq('status', 'aceita') as List;
  final vistos = <String>{};
  final resultado = <PostoOpcao>[];
  for (final r in rows) {
    final m = r as Map<String, dynamic>;
    final cnpj = m['posto_cnpj'] as String?;
    if (cnpj == null || vistos.contains(cnpj)) continue;
    vistos.add(cnpj);
    resultado.add(PostoOpcao(cnpj: cnpj, nome: m['posto_nome'] as String? ?? cnpj));
  }
  return resultado;
});

// ── Vínculo Motorista ↔ Veículo ────────────────────────────────────────
class VinculoRow {
  final String id;
  final String placa;
  final String motoristaId;
  final String? motoristaNome;
  final String? motoristaCpf;
  final String dataInicio;
  final String? dataFim;
  final String status;
  final String? observacao;

  const VinculoRow({
    required this.id,
    required this.placa,
    required this.motoristaId,
    this.motoristaNome,
    this.motoristaCpf,
    required this.dataInicio,
    this.dataFim,
    required this.status,
    this.observacao,
  });

  bool get ativo => status == 'Ativo';

  factory VinculoRow.fromMap(Map<String, dynamic> m) {
    final mot = m['motoristas'] as Map<String, dynamic>?;
    return VinculoRow(
      id: m['id'] as String,
      placa: m['placa'] as String? ?? '',
      motoristaId: m['motorista_id'] as String? ?? '',
      motoristaNome: mot?['nome_completo'] as String?,
      motoristaCpf: mot?['cpf'] as String?,
      dataInicio: m['data_inicio'] as String,
      dataFim: m['data_fim'] as String?,
      status: m['status'] as String? ?? 'Ativo',
      observacao: m['observacao'] as String?,
    );
  }
}

final vinculosProvider = FutureProvider.autoDispose<List<VinculoRow>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_vinculo_motorista_veiculo')
      .select('id, placa, motorista_id, data_inicio, data_fim, status, observacao, motoristas(nome_completo, cpf)')
      .eq('empresa_id', empresaId)
      .order('placa') as List;
  return rows.map((m) => VinculoRow.fromMap(m as Map<String, dynamic>)).toList();
});

final vinculoDetalheProvider = FutureProvider.autoDispose.family<VinculoRow?, String>((ref, id) async {
  final lista = await ref.watch(vinculosProvider.future);
  for (final v in lista) {
    if (v.id == id) return v;
  }
  return null;
});

// ── Intervalo entre Abastecimentos ──────────────────────────────────────
class RegraIntervalo {
  final String id;
  final String tipo; // Veiculo | Motorista
  final String? placa;
  final String? motoristaId;
  final String? motoristaNome;
  final num intervaloMinimo;
  final String unidade;
  final String status;
  final String? observacao;
  const RegraIntervalo({
    required this.id,
    required this.tipo,
    this.placa,
    this.motoristaId,
    this.motoristaNome,
    required this.intervaloMinimo,
    required this.unidade,
    required this.status,
    this.observacao,
  });
  factory RegraIntervalo.fromMap(Map<String, dynamic> m) => RegraIntervalo(
        id: m['id'] as String,
        tipo: m['tipo'] as String? ?? 'Veiculo',
        placa: _txt(m, 'placa'),
        motoristaId: m['motorista_id'] as String?,
        motoristaNome: _motoristaNome(m),
        intervaloMinimo: m['intervalo_minimo'] as num? ?? 0,
        unidade: m['unidade'] as String? ?? 'Horas',
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final intervalosProvider = FutureProvider.autoDispose<List<RegraIntervalo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_intervalo_abastecimento')
      .select('id, tipo, placa, intervalo_minimo, unidade, status, observacao, motoristas(nome_completo)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraIntervalo.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Valor Diário Permitido — Motorista ──────────────────────────────────
class RegraValorDiario {
  final String id;
  final String? motoristaId;
  final String? motoristaNome;
  final num valorMaximo;
  final String status;
  final String? observacao;
  const RegraValorDiario({
    required this.id,
    this.motoristaId,
    this.motoristaNome,
    required this.valorMaximo,
    required this.status,
    this.observacao,
  });
  factory RegraValorDiario.fromMap(Map<String, dynamic> m) => RegraValorDiario(
        id: m['id'] as String,
        motoristaId: m['motorista_id'] as String?,
        motoristaNome: _motoristaNome(m),
        valorMaximo: m['valor_maximo'] as num? ?? 0,
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final valoresDiariosProvider = FutureProvider.autoDispose<List<RegraValorDiario>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_valor_diario_motorista')
      .select('id, valor_maximo, status, observacao, motoristas(nome_completo)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraValorDiario.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Volume Diário Permitido — Veículo ───────────────────────────────────
class RegraVolumeDiario {
  final String id;
  final String? placa;
  final num volumeMaximo;
  final String status;
  final String? observacao;
  const RegraVolumeDiario({
    required this.id,
    this.placa,
    required this.volumeMaximo,
    required this.status,
    this.observacao,
  });
  factory RegraVolumeDiario.fromMap(Map<String, dynamic> m) => RegraVolumeDiario(
        id: m['id'] as String,
        placa: _txt(m, 'placa'),
        volumeMaximo: m['volume_maximo'] as num? ?? 0,
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final volumesDiariosProvider = FutureProvider.autoDispose<List<RegraVolumeDiario>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_volume_diario_veiculo')
      .select('id, placa, volume_maximo, status, observacao')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraVolumeDiario.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Produto Abastecido ──────────────────────────────────────────────────
class RegraProduto {
  final String id;
  final String? placa;
  final List<String> combustiveisPermitidos;
  final String status;
  final String? observacao;
  const RegraProduto({
    required this.id,
    this.placa,
    required this.combustiveisPermitidos,
    required this.status,
    this.observacao,
  });
  factory RegraProduto.fromMap(Map<String, dynamic> m) => RegraProduto(
        id: m['id'] as String,
        placa: _txt(m, 'placa'),
        combustiveisPermitidos: (m['combustiveis_permitidos'] as List? ?? []).cast<String>(),
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final produtosProvider = FutureProvider.autoDispose<List<RegraProduto>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_produto_abastecido')
      .select('id, placa, combustiveis_permitidos, status, observacao')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraProduto.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Variação Máx. de Hodômetro (Leve/Pesado) ────────────────────────────
class RegraVariacaoHodometro {
  final String id;
  final String? placa;
  final String classificacao;
  final num variacaoMaximaKm;
  final String status;
  final String? observacao;
  const RegraVariacaoHodometro({
    required this.id,
    this.placa,
    required this.classificacao,
    required this.variacaoMaximaKm,
    required this.status,
    this.observacao,
  });
  factory RegraVariacaoHodometro.fromMap(Map<String, dynamic> m) => RegraVariacaoHodometro(
        id: m['id'] as String,
        placa: _txt(m, 'placa'),
        classificacao: m['classificacao'] as String? ?? 'Leve',
        variacaoMaximaKm: m['variacao_maxima_km'] as num? ?? 0,
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final variacoesHodometroProvider =
    FutureProvider.autoDispose.family<List<RegraVariacaoHodometro>, String>((ref, classificacao) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_variacao_hodometro')
      .select('id, placa, classificacao, variacao_maxima_km, status, observacao')
      .eq('empresa_id', empresaId)
      .eq('classificacao', classificacao)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraVariacaoHodometro.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Dias e Horários Permitidos ───────────────────────────────────────────
class RegraDiasHorarios {
  final String id;
  final String? classificacao;
  final String? placa;
  final String? motoristaId;
  final String? motoristaNome;
  final List<String> diasPermitidos;
  final String horaInicio;
  final String horaFim;
  final String status;
  final String? observacao;
  const RegraDiasHorarios({
    required this.id,
    this.classificacao,
    this.placa,
    this.motoristaId,
    this.motoristaNome,
    required this.diasPermitidos,
    required this.horaInicio,
    required this.horaFim,
    required this.status,
    this.observacao,
  });
  factory RegraDiasHorarios.fromMap(Map<String, dynamic> m) => RegraDiasHorarios(
        id: m['id'] as String,
        classificacao: _txt(m, 'classificacao'),
        placa: _txt(m, 'placa'),
        motoristaId: m['motorista_id'] as String?,
        motoristaNome: _motoristaNome(m),
        diasPermitidos: (m['dias_permitidos'] as List? ?? []).cast<String>(),
        horaInicio: m['hora_inicio'] as String? ?? '',
        horaFim: m['hora_fim'] as String? ?? '',
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final diasHorariosProvider = FutureProvider.autoDispose<List<RegraDiasHorarios>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_dias_horarios')
      .select(
          'id, classificacao, placa, motorista_id, dias_permitidos, hora_inicio, hora_fim, status, observacao, motoristas(nome_completo)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraDiasHorarios.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Postos Permitidos para Abastecimento ─────────────────────────────────
class RegraPostosPermitidos {
  final String id;
  final String? classificacao;
  final String? placa;
  final String? motoristaId;
  final String? motoristaNome;
  final List<String> postosCnpj;
  final String tipoLimite;
  final num? valorMaximo;
  final String status;
  final String? observacao;
  const RegraPostosPermitidos({
    required this.id,
    this.classificacao,
    this.placa,
    this.motoristaId,
    this.motoristaNome,
    required this.postosCnpj,
    required this.tipoLimite,
    this.valorMaximo,
    required this.status,
    this.observacao,
  });
  factory RegraPostosPermitidos.fromMap(Map<String, dynamic> m) => RegraPostosPermitidos(
        id: m['id'] as String,
        classificacao: _txt(m, 'classificacao'),
        placa: _txt(m, 'placa'),
        motoristaId: m['motorista_id'] as String?,
        motoristaNome: _motoristaNome(m),
        postosCnpj: (m['postos_cnpj'] as List? ?? []).cast<String>(),
        tipoLimite: m['tipo_limite'] as String? ?? 'Sem limite',
        valorMaximo: m['valor_maximo'] as num?,
        status: m['status'] as String? ?? 'Ativo',
        observacao: _txt(m, 'observacao'),
      );
}

final postosPermitidosProvider = FutureProvider.autoDispose<List<RegraPostosPermitidos>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_postos_permitidos')
      .select(
          'id, classificacao, placa, motorista_id, postos_cnpj, tipo_limite, valor_maximo, status, observacao, motoristas(nome_completo)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => RegraPostosPermitidos.fromMap(m as Map<String, dynamic>)).toList();
});

// ── Cota por Veículo ──────────────────────────────────────────────────────
class RegraCota {
  final String id;
  final String placa;
  final String tipo; // Valor | Volume
  final num limite;
  final String periodicidade;
  final String status;
  final String? observacao;
  final num consumido;
  const RegraCota({
    required this.id,
    required this.placa,
    required this.tipo,
    required this.limite,
    required this.periodicidade,
    required this.status,
    this.observacao,
    required this.consumido,
  });
}

// Porta fiel de inicioDoPeriodo (page.tsx) — início do período corrente
// pra somar o consumo já realizado.
DateTime _inicioDoPeriodo(String periodicidade, DateTime hoje) {
  final h = DateTime.utc(hoje.year, hoje.month, hoje.day);
  if (periodicidade == 'Semana') {
    final diaSemana = h.weekday; // 1=segunda...7=domingo
    final offset = diaSemana - 1;
    return h.subtract(Duration(days: offset));
  }
  if (periodicidade == 'Quinzena') {
    return DateTime.utc(h.year, h.month, h.day <= 15 ? 1 : 16);
  }
  if (periodicidade == 'Abastecimento') {
    return h;
  }
  return DateTime.utc(h.year, h.month, 1);
}

final cotasProvider = FutureProvider.autoDispose<List<RegraCota>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final supabase = SupabaseService.client;
  final rows = await supabase
      .from('parametros_cota_veiculo')
      .select('id, placa, tipo, limite, periodicidade, status, observacao')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;

  final hoje = DateTime.now().toUtc();
  final amanha = hoje.add(const Duration(days: 1));
  final fimExclusivo = DateTime.utc(amanha.year, amanha.month, amanha.day).toIso8601String().substring(0, 10);

  final resultado = <RegraCota>[];
  for (final r in rows) {
    final m = r as Map<String, dynamic>;
    final periodicidade = m['periodicidade'] as String? ?? 'Mes';
    final tipo = m['tipo'] as String? ?? 'Valor';
    final placa = m['placa'] as String? ?? '';
    final inicio = _inicioDoPeriodo(periodicidade, hoje).toIso8601String().substring(0, 10);

    final abastecimentos = await supabase
        .from('abastecimentos_unificado')
        .select('valor_total, litros')
        .eq('empresa_id', empresaId)
        .eq('placa', placa)
        .gte('data_abastecimento', inicio)
        .lt('data_abastecimento', fimExclusivo) as List;

    num consumido = 0;
    for (final a in abastecimentos) {
      final am = a as Map<String, dynamic>;
      consumido += (tipo == 'Valor' ? (am['valor_total'] as num?) : (am['litros'] as num?)) ?? 0;
    }

    resultado.add(RegraCota(
      id: m['id'] as String,
      placa: placa,
      tipo: tipo,
      limite: m['limite'] as num? ?? 0,
      periodicidade: periodicidade,
      status: m['status'] as String? ?? 'Ativo',
      observacao: _txt(m, 'observacao'),
      consumido: consumido,
    ));
  }
  return resultado;
});
