import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — primeira tela real da visão Cliente, porta de
// src/app/(dashboard)/dashboard/page.tsx (ramo cliente/frota — o ramo
// posto, segmento "Revenda", já foi portado à parte na Fase FLT-2 como
// posto_dashboard_screen.dart). A página web é MUITO maior que isso: além
// do que está aqui, tem "Primeiros Passos" (onboarding), seção de Ajustes
// de Abastecimento, seletor de cliente+período no topo, Desempenho por
// Centro de Custo, KPIs de Manutenção Preditiva, e um bloco inteiro de
// "Indicadores avançados" com 8 gráficos (variação de preços, previsão de
// consumo, evolução de preço médio, evolutivo/ranking de postos, ranking
// de veículos/motoristas, eficiência real por veículo — cada um com sua
// própria RPC). **Escopo reduzido desta primeira versão:** só os 6 KPIs
// principais, consolidado por meio de pagamento no mês, gráfico de consumo
// dos últimos 6 meses, CNH vencendo em 30 dias e Top 5 clientes por gasto
// (rede toda). O resto fica para uma próxima iteração — cada indicador
// avançado é praticamente uma tela em si.
//
// Igual à web: nem todo perfil "cliente" (empresa da frota) tem
// necessariamente uma única empresa vinculada — a resolução de qual
// empresa mostrar já acontece antes desta tela (sessaoProvider +
// /selecionar-empresa, mesmo mecanismo usado no Posto pra "Rede de
// Postos") — aqui só usamos `sessao.empresaId` já resolvido, sem repetir
// o seletor de cliente que a web tem no topo da página.

const _janelaConsumoMeses = 6;
const _janelaCnhDias = 30;

const _mesesAbrev = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

class ProvedorValorMes {
  final String provedor;
  final double valor;
  const ProvedorValorMes({required this.provedor, required this.valor});
}

class PontoConsumoMensal {
  final String mesLabel; // "jan/25"
  final double litros;
  final double valor;
  const PontoConsumoMensal({required this.mesLabel, required this.litros, required this.valor});
}

class CnhVencendo {
  final String id;
  final String nome;
  final String vencimento;
  const CnhVencendo({required this.id, required this.nome, required this.vencimento});
}

class ClienteGasto {
  final String nome;
  final double valor;
  const ClienteGasto({required this.nome, required this.valor});
}

class DashboardClienteDados {
  final int totalClientes;
  final int clientesAtivos;
  final int totalMotoristas;
  final int motoristasAtivos;
  final int totalVeiculos;
  final int veiculosAtivos;
  final double litrosMes;
  final double valorMes;
  final double custoMedioLitroMes;
  final List<ProvedorValorMes> provedoresMes;
  final List<PontoConsumoMensal> serieConsumo;
  final List<CnhVencendo> cnhVencendo;
  final List<ClienteGasto> topClientes;

  const DashboardClienteDados({
    required this.totalClientes,
    required this.clientesAtivos,
    required this.totalMotoristas,
    required this.motoristasAtivos,
    required this.totalVeiculos,
    required this.veiculosAtivos,
    required this.litrosMes,
    required this.valorMes,
    required this.custoMedioLitroMes,
    required this.provedoresMes,
    required this.serieConsumo,
    required this.cnhVencendo,
    required this.topClientes,
  });

  static const vazio = DashboardClienteDados(
    totalClientes: 0,
    clientesAtivos: 0,
    totalMotoristas: 0,
    motoristasAtivos: 0,
    totalVeiculos: 0,
    veiculosAtivos: 0,
    litrosMes: 0,
    valorMes: 0,
    custoMedioLitroMes: 0,
    provedoresMes: [],
    serieConsumo: [],
    cnhVencendo: [],
    topClientes: [],
  );
}

final dashboardClienteProvider = FutureProvider.autoDispose<DashboardClienteDados>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return DashboardClienteDados.vazio;

  final supabase = SupabaseService.client;
  final agora = DateTime.now();
  final inicioMesAtual = DateTime(agora.year, agora.month, 1);
  final seisMesesAtras = DateTime(agora.year, agora.month - (_janelaConsumoMeses - 1), 1);
  final daqui30Dias = agora.add(const Duration(days: _janelaCnhDias));

  // Chamadas sequenciais (não Future.wait) — mesmo motivo do
  // dashboard_posto_provider.dart: tipos de retorno diferentes por consulta.
  final totalClientesResp = await supabase.from('empresas').select('id').count(CountOption.exact);
  final clientesAtivosResp =
      await supabase.from('empresas').select('id').eq('status', 'ativo').count(CountOption.exact);
  final totalMotoristasResp =
      await supabase.from('motoristas').select('id').eq('empresa_id', empresaId).count(CountOption.exact);
  final motoristasAtivosResp = await supabase
      .from('motoristas')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('status', 'Ativo')
      .count(CountOption.exact);

  final veiculosRaw = await supabase.rpc('veiculos_da_empresa', params: {'p_empresa_id': empresaId}) as List;
  final totalVeiculos = veiculosRaw.length;
  final veiculosAtivos =
      veiculosRaw.where((v) => (v as Map<String, dynamic>)['ativo'] == true).length;

  // Abastecimentos do CLIENTE selecionado — alimenta KPIs do mês, meios de
  // pagamento e o gráfico de consumo de 6 meses.
  final abastecimentosClienteRaw = await supabase
      .from('abastecimentos_unificado')
      .select('data_abastecimento, litros, valor_total, provedor')
      .eq('empresa_id', empresaId)
      .gte('data_abastecimento', seisMesesAtras.toIso8601String())
      .limit(5000) as List;

  // Fase FLT-3 (otimização em relação à web) — a página web busca os
  // abastecimentos de TODA a rede (sem filtro de empresa) só pra somar o
  // "Top 5 clientes por gasto", trazendo litros/data/provedor que esse
  // ranking não usa. Aqui filtramos só empresa_id+valor_total (payload bem
  // menor — relevante no celular). O resultado final é o mesmo, sempre em
  // nível de rede (não escopado ao cliente selecionado), igual à web.
  final abastecimentosRedeRaw = await supabase
      .from('abastecimentos_unificado')
      .select('empresa_id, valor_total')
      .gte('data_abastecimento', seisMesesAtras.toIso8601String())
      .limit(5000) as List;

  final cnhVencendoRaw = await supabase
      .from('motoristas')
      .select('id, nome_completo, cnh_vencimento')
      .eq('empresa_id', empresaId)
      .eq('status', 'Ativo')
      .not('cnh_vencimento', 'is', null)
      .lte('cnh_vencimento', _iso(daqui30Dias))
      .order('cnh_vencimento', ascending: true)
      .limit(5) as List;

  final totalClientes = totalClientesResp.count;
  final clientesAtivos = clientesAtivosResp.count;
  final totalMotoristas = totalMotoristasResp.count;
  final motoristasAtivos = motoristasAtivosResp.count;

  // KPIs do mês atual.
  final doMesAtual = abastecimentosClienteRaw.where((a) {
    final m = a as Map<String, dynamic>;
    final data = DateTime.tryParse(m['data_abastecimento'] as String? ?? '');
    return data != null && !data.isBefore(inicioMesAtual);
  }).toList();
  var litrosMes = 0.0;
  var valorMes = 0.0;
  final porProvedorMes = <String, double>{};
  for (final a in doMesAtual) {
    final m = a as Map<String, dynamic>;
    final litros = (m['litros'] as num?)?.toDouble() ?? 0;
    final valor = (m['valor_total'] as num?)?.toDouble() ?? 0;
    litrosMes += litros;
    valorMes += valor;
    final provedor = m['provedor'] as String?;
    if (provedor != null) {
      porProvedorMes[provedor] = (porProvedorMes[provedor] ?? 0) + valor;
    }
  }
  final custoMedioLitroMes = litrosMes > 0 ? valorMes / litrosMes : 0.0;
  final provedoresMes = porProvedorMes.entries
      .map((e) => ProvedorValorMes(provedor: e.key, valor: e.value))
      .toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));

  // Gráfico de consumo — agrupa por mês (últimos 6 meses, incluindo o
  // atual), na ordem certa mesmo com meses sem abastecimento.
  final porMes = <String, ({double litros, double valor})>{};
  final ordemMeses = <String>[];
  for (var i = _janelaConsumoMeses - 1; i >= 0; i--) {
    final d = DateTime(agora.year, agora.month - i, 1);
    final chave = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    ordemMeses.add(chave);
    porMes[chave] = (litros: 0, valor: 0);
  }
  for (final a in abastecimentosClienteRaw) {
    final m = a as Map<String, dynamic>;
    final data = DateTime.tryParse(m['data_abastecimento'] as String? ?? '');
    if (data == null) continue;
    final chave = '${data.year}-${data.month.toString().padLeft(2, '0')}';
    final atual = porMes[chave];
    if (atual == null) continue; // fora da janela de 6 meses (não deve acontecer, já filtrado na query)
    porMes[chave] = (
      litros: atual.litros + ((m['litros'] as num?)?.toDouble() ?? 0),
      valor: atual.valor + ((m['valor_total'] as num?)?.toDouble() ?? 0),
    );
  }
  final serieConsumo = ordemMeses.map((chave) {
    final partes = chave.split('-');
    final mesIdx = int.parse(partes[1]) - 1;
    final anoAbrev = partes[0].substring(2);
    final p = porMes[chave]!;
    return PontoConsumoMensal(mesLabel: '${_mesesAbrev[mesIdx]}/$anoAbrev', litros: p.litros, valor: p.valor);
  }).toList();

  // CNH vencendo.
  final cnhVencendo = cnhVencendoRaw.map((m) {
    final mm = m as Map<String, dynamic>;
    return CnhVencendo(
      id: mm['id'] as String,
      nome: mm['nome_completo'] as String? ?? '—',
      vencimento: mm['cnh_vencimento'] as String,
    );
  }).toList();

  // Top 5 clientes por gasto (rede toda, sempre — mesmo espírito da web).
  final gastoPorEmpresa = <String, double>{};
  for (final a in abastecimentosRedeRaw) {
    final m = a as Map<String, dynamic>;
    final id = m['empresa_id'] as String?;
    if (id == null) continue;
    gastoPorEmpresa[id] = (gastoPorEmpresa[id] ?? 0) + ((m['valor_total'] as num?)?.toDouble() ?? 0);
  }
  final idsTop = gastoPorEmpresa.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top5Ids = idsTop.take(5).toList();
  final topClientes = <ClienteGasto>[];
  for (final entry in top5Ids) {
    final nome = await supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': entry.key}) as String?;
    topClientes.add(ClienteGasto(nome: nome ?? entry.key, valor: entry.value));
  }

  return DashboardClienteDados(
    totalClientes: totalClientes,
    clientesAtivos: clientesAtivos,
    totalMotoristas: totalMotoristas,
    motoristasAtivos: motoristasAtivos,
    totalVeiculos: totalVeiculos,
    veiculosAtivos: veiculosAtivos,
    litrosMes: litrosMes,
    valorMes: valorMes,
    custoMedioLitroMes: custoMedioLitroMes,
    provedoresMes: provedoresMes,
    serieConsumo: serieConsumo,
    cnhVencendo: cnhVencendo,
    topClientes: topClientes,
  );
});
