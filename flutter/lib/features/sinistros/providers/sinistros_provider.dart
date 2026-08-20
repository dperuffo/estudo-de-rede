import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — registro de sinistros/
// acidentes (cliente), porta de sinistros/page.tsx + nova/page.tsx +
// actions.ts + src/lib/checklist.ts (TIPOS_SINISTRO/GRAVIDADES_SINISTRO).
// Alimenta o KPI indice_sinistralidade em Indicadores da Frota.

const tiposSinistro = ['Colisão', 'Furto/Roubo', 'Incêndio', 'Avaria', 'Outro'];
const gravidadesSinistro = ['Leve', 'Moderada', 'Grave'];

const gravidadeSinistroCor = {
  'Leve': (fundo: Color(0xFFDCFCE7), texto: Color(0xFF166534)),
  'Moderada': (fundo: Color(0xFFFFFBEB), texto: Color(0xFF92400E)),
  'Grave': (fundo: Color(0xFFFEE2E2), texto: Color(0xFF991B1B)),
};

class Sinistro {
  final int id;
  final String placa;
  final String? motoristaNome;
  final String dataSinistro;
  final String tipo;
  final String? gravidade;
  final bool houveVitima;
  final double? custoEstimado;
  final String? localOcorrencia;
  final String? descricao;
  const Sinistro({
    required this.id,
    required this.placa,
    this.motoristaNome,
    required this.dataSinistro,
    required this.tipo,
    this.gravidade,
    required this.houveVitima,
    this.custoEstimado,
    this.localOcorrencia,
    this.descricao,
  });
  factory Sinistro.fromMap(Map<String, dynamic> m) => Sinistro(
        id: (m['id'] as num).toInt(),
        placa: m['placa'] as String,
        motoristaNome: m['motorista_nome'] as String?,
        dataSinistro: m['data_sinistro'] as String,
        tipo: m['tipo'] as String,
        gravidade: m['gravidade'] as String?,
        houveVitima: m['houve_vitima'] as bool? ?? false,
        custoEstimado: (m['custo_estimado'] as num?)?.toDouble(),
        localOcorrencia: m['local_ocorrencia'] as String?,
        descricao: m['descricao'] as String?,
      );
}

final sinistrosListProvider =
    FutureProvider.autoDispose<List<Sinistro>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('sinistros_veiculos')
      .select(
          'id, placa, motorista_nome, data_sinistro, tipo, gravidade, houve_vitima, custo_estimado, local_ocorrencia, descricao')
      .eq('empresa_id', empresaId)
      .order('data_sinistro', ascending: false)
      .limit(200) as List;
  return rows.map((r) => Sinistro.fromMap(r as Map<String, dynamic>)).toList();
});
