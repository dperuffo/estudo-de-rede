import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Programacao-Frota (03/08/2026, benchmark FNI vs Rodopar/Datapar,
// Grupo 1 item 1) — porta de programacao/page.tsx (web) pro PWA Cliente.
// Mesma RPC (programacao_frota_empresa, SECURITY DEFINER): cruza o vínculo
// motorista-veículo com os fretes aceitos/em_andamento pra mostrar quem
// está livre e quem está em viagem (e até quando). Sem GPS/telemetria.
class VeiculoProgramacao {
  final String veiculoId;
  final String placa;
  final String? marca;
  final String? modelo;
  final String? tipoVeiculo;
  final bool ativo;
  final String? motoristaId;
  final String? nomeMotorista;
  final String? freteId;
  final String? freteTitulo;
  final String? freteStatus;
  final String? freteDestinoLabel;
  final DateTime? disponivelAPartir;

  const VeiculoProgramacao({
    required this.veiculoId,
    required this.placa,
    this.marca,
    this.modelo,
    this.tipoVeiculo,
    required this.ativo,
    this.motoristaId,
    this.nomeMotorista,
    this.freteId,
    this.freteTitulo,
    this.freteStatus,
    this.freteDestinoLabel,
    this.disponivelAPartir,
  });

  factory VeiculoProgramacao.fromMap(Map<String, dynamic> m) => VeiculoProgramacao(
        veiculoId: m['veiculo_id'] as String,
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        tipoVeiculo: m['tipo_veiculo'] as String?,
        ativo: (m['ativo'] as bool?) ?? false,
        motoristaId: m['motorista_id'] as String?,
        nomeMotorista: m['nome_motorista'] as String?,
        freteId: m['frete_id'] as String?,
        freteTitulo: m['frete_titulo'] as String?,
        freteStatus: m['frete_status'] as String?,
        freteDestinoLabel: m['frete_destino_label'] as String?,
        disponivelAPartir: m['disponivel_a_partir'] != null ? DateTime.parse(m['disponivel_a_partir'] as String) : null,
      );
}

final programacaoFrotaProvider = FutureProvider.autoDispose<List<VeiculoProgramacao>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('programacao_frota_empresa', params: {
    'p_empresa_id': empresaId,
  }) as List;
  return rows.map((r) => VeiculoProgramacao.fromMap(r as Map<String, dynamic>)).toList();
});
