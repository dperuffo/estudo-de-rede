import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — checklist de inspeção veicular
// (cliente), porta de checklist-veiculos/page.tsx + [placa]/page.tsx +
// actions.ts + src/lib/checklist.ts. Alimenta os KPIs conformidade_pct e
// tmrnc_horas em Indicadores da Frota.

const itensInspecao = [
  'Pneus',
  'Freios',
  'Luzes',
  'Óleo e fluidos',
  'Cintos de segurança',
  'Extintor de incêndio',
  'Documentação (CRLV)',
  'Retrovisores',
  'Buzina',
  'Limpador de para-brisa',
  'Estepe',
  'Triângulo e macaco',
];

const itensCriticos = ['Pneus', 'Freios'];

class VeiculoChecklist {
  final String placa;
  final String? marca;
  final String? modelo;
  final String? centroCustoNome;
  final String? ultimaInspecao;
  final int pendenciasAbertas;
  const VeiculoChecklist({
    required this.placa,
    this.marca,
    this.modelo,
    this.centroCustoNome,
    this.ultimaInspecao,
    required this.pendenciasAbertas,
  });
  factory VeiculoChecklist.fromMap(Map<String, dynamic> m) => VeiculoChecklist(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        ultimaInspecao: m['ultima_inspecao'] as String?,
        pendenciasAbertas: (m['pendencias_abertas'] as num?)?.toInt() ?? 0,
      );
}

final checklistVeiculosListProvider = FutureProvider.autoDispose.family<List<VeiculoChecklist>, String?>((ref, busca) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('checklist_veiculos_resumo', params: {
    'p_empresa_id': empresaId,
    'p_busca': busca,
  }) as List;
  return rows.map((r) => VeiculoChecklist.fromMap(r as Map<String, dynamic>)).toList();
});

class ItemInspecao {
  final int id;
  final String item;
  final bool critico;
  final bool conforme;
  final String? observacao;
  final String? resolvidoEm;
  final String? resolvidoPor;
  const ItemInspecao({
    required this.id,
    required this.item,
    required this.critico,
    required this.conforme,
    this.observacao,
    this.resolvidoEm,
    this.resolvidoPor,
  });
  factory ItemInspecao.fromMap(Map<String, dynamic> m) => ItemInspecao(
        id: (m['id'] as num).toInt(),
        item: m['item'] as String,
        critico: m['critico'] as bool? ?? false,
        conforme: m['conforme'] as bool? ?? false,
        observacao: m['observacao'] as String?,
        resolvidoEm: m['resolvido_em'] as String?,
        resolvidoPor: m['resolvido_por'] as String?,
      );
}

class Inspecao {
  final int id;
  final String dataInspecao;
  final double? hodometro;
  final String? responsavel;
  final List<ItemInspecao> itens;
  const Inspecao({required this.id, required this.dataInspecao, this.hodometro, this.responsavel, required this.itens});
  factory Inspecao.fromMap(Map<String, dynamic> m) => Inspecao(
        id: (m['id'] as num).toInt(),
        dataInspecao: m['data_inspecao'] as String,
        hodometro: (m['hodometro'] as num?)?.toDouble(),
        responsavel: m['responsavel'] as String?,
        itens: ((m['inspecoes_veiculos_itens'] as List?) ?? [])
            .map((i) => ItemInspecao.fromMap(i as Map<String, dynamic>))
            .toList(),
      );
}

final inspecoesVeiculoProvider = FutureProvider.autoDispose.family<List<Inspecao>, String>((ref, placa) async {
  final rows = await SupabaseService.client
      .from('inspecoes_veiculos')
      .select(
          'id, data_inspecao, hodometro, responsavel, criado_por, inspecoes_veiculos_itens(id, item, critico, conforme, observacao, resolvido_em, resolvido_por)')
      .eq('placa', placa)
      .order('data_inspecao', ascending: false)
      .limit(50) as List;
  return rows.map((r) => Inspecao.fromMap(r as Map<String, dynamic>)).toList();
});

final ultimoHodometroProvider = FutureProvider.autoDispose.family<double?, String>((ref, placa) async {
  final row = await SupabaseService.client
      .from('abastecimentos_unificado')
      .select('hodometro')
      .eq('placa', placa)
      .order('hodometro', ascending: false)
      .limit(1)
      .maybeSingle();
  return (row?['hodometro'] as num?)?.toDouble();
});
