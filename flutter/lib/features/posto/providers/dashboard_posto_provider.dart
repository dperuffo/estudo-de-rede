import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Dashboard/Painel real da visão Posto, espelhando
// DashboardPosto.tsx da web (src/app/(dashboard)/dashboard/_components/).
// Mesmas fontes de dados (negociacoes_postos + RPC
// resumo_vendas_diarias_posto), só que via Supabase direto no Flutter em
// vez de Server Component. O gráfico evolutivo diário (GraficoEvolutivoPostos)
// fica pra uma próxima iteração — aqui entram os indicadores e tabelas.

const janelaDesempenhoDias = 30;

class DesempenhoCombustivel {
  final String combustivel;
  final double volume;
  final double receita;
  final double participacao;
  const DesempenhoCombustivel({
    required this.combustivel,
    required this.volume,
    required this.receita,
    required this.participacao,
  });
  double get precoMedio => volume > 0 ? receita / volume : 0;
}

class NegociacaoResumo {
  final String id;
  final String status;
  final String? clienteNome;
  final String? combustivel;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final double? volumeMinimoMensal;
  final double? precoUnitario;
  const NegociacaoResumo({
    required this.id,
    required this.status,
    this.clienteNome,
    this.combustivel,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.volumeMinimoMensal,
    this.precoUnitario,
  });

  factory NegociacaoResumo.fromMap(Map<String, dynamic> m) => NegociacaoResumo(
        id: m['id'].toString(),
        status: m['status'] as String? ?? '',
        clienteNome: m['cliente_nome'] as String?,
        combustivel: m['combustivel'] as String?,
        vigenciaInicio: m['vigencia_inicio'] as String?,
        vigenciaFim: m['vigencia_fim'] as String?,
        volumeMinimoMensal: (m['volume_minimo_mensal'] as num?)?.toDouble(),
        precoUnitario: (m['preco_unitario'] as num?)?.toDouble(),
      );
}

class DashboardPostoDados {
  final int totalAbastecimentos;
  final double volumeVendido;
  final double receitaVendida;
  final double precoMedioGeral;
  final double ticketMedio;
  final List<DesempenhoCombustivel> desempenhoPorCombustivel;
  final int pendentes;
  final int vigentes;
  final int clientesAtivos;
  final double volumeContratado;
  final List<NegociacaoResumo> vigentesLista;
  final List<NegociacaoResumo> pendentesLista;
  const DashboardPostoDados({
    required this.totalAbastecimentos,
    required this.volumeVendido,
    required this.receitaVendida,
    required this.precoMedioGeral,
    required this.ticketMedio,
    required this.desempenhoPorCombustivel,
    required this.pendentes,
    required this.vigentes,
    required this.clientesAtivos,
    required this.volumeContratado,
    required this.vigentesLista,
    required this.pendentesLista,
  });

  static const vazio = DashboardPostoDados(
    totalAbastecimentos: 0,
    volumeVendido: 0,
    receitaVendida: 0,
    precoMedioGeral: 0,
    ticketMedio: 0,
    desempenhoPorCombustivel: [],
    pendentes: 0,
    vigentes: 0,
    clientesAtivos: 0,
    volumeContratado: 0,
    vigentesLista: [],
    pendentesLista: [],
  );
}

final dashboardPostoProvider = FutureProvider.autoDispose<DashboardPostoDados>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return DashboardPostoDados.vazio;

  final supabase = SupabaseService.client;
  // UTC pra espelhar o `new Date().toISOString()` que a web usa em
  // DashboardPosto.tsx (JS toISOString() é sempre UTC).
  final agoraUtc = DateTime.now().toUtc();
  final hojeIso = DateFormat('yyyy-MM-dd').format(agoraUtc);
  final desdeIso = agoraUtc.subtract(const Duration(days: janelaDesempenhoDias)).toIso8601String();

  // Fase FLT-2 — chamadas sequenciais (não Future.wait): os 4 retornos têm
  // tipos diferentes (PostgrestResponse dos counts, List do select, Map? do
  // maybeSingle), e Future.wait com uma lista literal de tipos diferentes
  // não compila (o Dart não consegue inferir um Future<T> comum pra lista).
  final pendentesResp = await supabase
      .from('negociacoes_postos')
      .select('id')
      .eq('empresa_posto_id', empresaId)
      .eq('status', 'pendente_posto')
      .count(CountOption.exact);

  final vigentesResp = await supabase
      .from('negociacoes_postos')
      .select('id')
      .eq('empresa_posto_id', empresaId)
      .eq('status', 'aceita')
      .lte('vigencia_inicio', hojeIso)
      .gte('vigencia_fim', hojeIso)
      .count(CountOption.exact);

  final negociacoesRaw = await supabase
      .from('negociacoes_postos')
      .select(
        'id, status, cliente_nome, combustivel, vigencia_inicio, vigencia_fim, volume_minimo_mensal, preco_unitario, atualizado_em',
      )
      .eq('empresa_posto_id', empresaId)
      .order('atualizado_em', ascending: false)
      .limit(200);

  final empresaPosto =
      await supabase.from('empresas').select('cnpj').eq('id', empresaId).maybeSingle();

  final pendentes = pendentesResp.count;
  final vigentes = vigentesResp.count;

  final listaNegociacoes = negociacoesRaw
      .map((m) => NegociacaoResumo.fromMap(m as Map<String, dynamic>))
      .toList();

  final clientesAtivos = listaNegociacoes
      .where((n) => n.status == 'aceita')
      .map((n) => n.clienteNome ?? '')
      .toSet()
      .length;

  bool vigenteAgora(NegociacaoResumo n) =>
      n.status == 'aceita' &&
      n.vigenciaInicio != null &&
      n.vigenciaFim != null &&
      n.vigenciaInicio!.compareTo(hojeIso) <= 0 &&
      n.vigenciaFim!.compareTo(hojeIso) >= 0;

  final volumeContratado = listaNegociacoes
      .where(vigenteAgora)
      .fold<double>(0, (soma, n) => soma + (n.volumeMinimoMensal ?? 0));

  final vigentesLista = listaNegociacoes.where(vigenteAgora).take(10).toList();
  final pendentesLista =
      listaNegociacoes.where((n) => n.status == 'pendente_posto').take(10).toList();

  // Desempenho de vendas via resumo_vendas_diarias_posto (mesma RPC da web
  // — agrega dia+combustível direto no banco, evita o corte de 1000 linhas
  // do PostgREST que já mordeu a web antes — ver Fase 27.69).
  final cnpj = empresaPosto?['cnpj'] as String?;
  List<Map<String, dynamic>> resumoDiario = const [];
  if (cnpj != null && cnpj.isNotEmpty) {
    final resp = await supabase.rpc('resumo_vendas_diarias_posto', params: {
      'p_pv_cnpj': cnpj,
      'p_desde': desdeIso,
    });
    resumoDiario = (resp as List?)?.cast<Map<String, dynamic>>() ?? const [];
  }

  var totalAbastecimentos = 0;
  var volumeVendido = 0.0;
  var receitaVendida = 0.0;
  final porCombustivel = <String, ({double volume, double receita})>{};
  for (final r in resumoDiario) {
    final quantidade = (r['quantidade'] as num?)?.toInt() ?? 0;
    final volume = (r['volume'] as num?)?.toDouble() ?? 0;
    final receita = (r['receita'] as num?)?.toDouble() ?? 0;
    final itemNome = r['item_nome'] as String? ?? '—';
    totalAbastecimentos += quantidade;
    volumeVendido += volume;
    receitaVendida += receita;
    final acumulado = porCombustivel[itemNome] ?? (volume: 0.0, receita: 0.0);
    porCombustivel[itemNome] = (
      volume: acumulado.volume + volume,
      receita: acumulado.receita + receita,
    );
  }
  final precoMedioGeral = volumeVendido > 0 ? receitaVendida / volumeVendido : 0.0;
  final ticketMedio = totalAbastecimentos > 0 ? receitaVendida / totalAbastecimentos : 0.0;

  final desempenhoPorCombustivel = porCombustivel.entries
      .map((e) => DesempenhoCombustivel(
            combustivel: e.key,
            volume: e.value.volume,
            receita: e.value.receita,
            participacao: volumeVendido > 0 ? (e.value.volume / volumeVendido) * 100 : 0,
          ))
      .toList()
    ..sort((a, b) => b.volume.compareTo(a.volume));

  return DashboardPostoDados(
    totalAbastecimentos: totalAbastecimentos,
    volumeVendido: volumeVendido,
    receitaVendida: receitaVendida,
    precoMedioGeral: precoMedioGeral,
    ticketMedio: ticketMedio,
    desempenhoPorCombustivel: desempenhoPorCombustivel,
    pendentes: pendentes,
    vigentes: vigentes,
    clientesAtivos: clientesAtivos,
    volumeContratado: volumeContratado,
    vigentesLista: vigentesLista,
    pendentesLista: pendentesLista,
  );
});
