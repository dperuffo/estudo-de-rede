import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase Financeiro-ERP (26/07/2026, pedido do Daniel) — "Aba de Piso mínimo
// ANTT tem que estar na visão do cliente, web e PWA". Porta de
// /administracao/pisos-antt (page.tsx), só a parte de LEITURA: a tabela
// `pisos_antt` é NACIONAL (Res. ANTT 5.867/2020, não é por tenant — ver
// migração fase_p0_5_pisos_antt) e tem RLS `pisos_antt_leitura` liberada
// pra qualquer usuário autenticado (qual = true); só INSERT/UPDATE/DELETE
// continuam restritos a perfil admin — por isso não existe formulário nem
// botão de excluir aqui, diferente de outras features portadas (ex:
// Parâmetros de NF) que são self-service completo.
class PisoAntt {
  final String id;
  final String tipoCarga;
  final int numeroEixos;
  final double coeficienteDeslocamento;
  final double coeficienteCargaDescarga;
  final String vigenciaInicio;

  const PisoAntt({
    required this.id,
    required this.tipoCarga,
    required this.numeroEixos,
    required this.coeficienteDeslocamento,
    required this.coeficienteCargaDescarga,
    required this.vigenciaInicio,
  });

  factory PisoAntt.fromMap(Map<String, dynamic> m) => PisoAntt(
        id: m['id'] as String,
        tipoCarga: m['tipo_carga'] as String,
        numeroEixos: (m['numero_eixos'] as num).toInt(),
        coeficienteDeslocamento: (m['coeficiente_deslocamento'] as num).toDouble(),
        coeficienteCargaDescarga: (m['coeficiente_carga_descarga'] as num).toDouble(),
        vigenciaInicio: m['vigencia_inicio'] as String,
      );
}

final pisosAnttProvider = FutureProvider.autoDispose<List<PisoAntt>>((ref) async {
  final rows = await SupabaseService.client
      .from('pisos_antt')
      .select('id, tipo_carga, numero_eixos, coeficiente_deslocamento, coeficiente_carga_descarga, vigencia_inicio')
      .order('tipo_carga', ascending: true)
      .order('numero_eixos', ascending: true) as List;
  return rows.map((m) => PisoAntt.fromMap(m as Map<String, dynamic>)).toList();
});
