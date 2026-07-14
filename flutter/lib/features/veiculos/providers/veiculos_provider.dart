import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Veículos (cliente), porta de veiculos/page.tsx +
// [id]/page.tsx + actions.ts. CRUD completo (RLS conferida direto no
// banco antes de portar: `cadastro_veiculos`/`centros_custo_veiculos` têm
// self-service completo pra empresa do usuário, igual à web). Achado real
// do schema: `cadastro_veiculos` NÃO tem `empresa_id` (o vínculo é por
// `cnpj_frota`, normalizado) — por isso a lista usa a RPC
// `veiculos_da_empresa` (mesma da web), que já resolve essa normalização,
// em vez de um filtro direto.
//
// Escopo reduzido: sem paginação de verdade (a web pagina em memória
// depois de trazer a frota inteira; aqui traz até 1000 e cap por aí — mais
// que suficiente pro celular) e sem importação por planilha
// (`/veiculos/importar`).
const classificacoesVeiculo = ['Próprio', 'Agregado'];
const tiposVeiculo = ['Cavalo Mecânico', 'Carreta', 'Truck', 'Toco', 'VUC', 'Utilitário', 'Outro'];
const tiposPorteVeiculo = ['Leve', 'Pesado'];
const ciclosCombustivel = ['Diesel S10', 'Diesel S500', 'Gasolina', 'Etanol', 'GNV', 'Flex'];

class Veiculo {
  final String id;
  final String placa;
  final String? marca;
  final String? modelo;
  final String? motor;
  final int? anoModelo;
  final int? anoFabricacao;
  final double? hodometroAtual;
  final String? combustivel;
  final double? tanque;
  final double? autonomia;
  final String? cor;
  final String? chassi;
  final String? renavam;
  final bool ativo;
  final String? municipio;
  final String? tipoVeiculo;
  final String? ufVeiculo;
  final int? numeroEixos;
  final String classificacao;
  final String? tipo;
  final String? centroCustoId;
  final String? centroCustoNome;
  final String cnpjFrota;

  const Veiculo({
    required this.id,
    required this.placa,
    this.marca,
    this.modelo,
    this.motor,
    this.anoModelo,
    this.anoFabricacao,
    this.hodometroAtual,
    this.combustivel,
    this.tanque,
    this.autonomia,
    this.cor,
    this.chassi,
    this.renavam,
    required this.ativo,
    this.municipio,
    this.tipoVeiculo,
    this.ufVeiculo,
    this.numeroEixos,
    required this.classificacao,
    this.tipo,
    this.centroCustoId,
    this.centroCustoNome,
    required this.cnpjFrota,
  });

  factory Veiculo.fromMap(Map<String, dynamic> m) {
    return Veiculo(
      id: m['id'] as String,
      placa: m['placa'] as String? ?? '—',
      marca: m['marca'] as String?,
      modelo: m['modelo'] as String?,
      motor: m['motor'] as String?,
      anoModelo: (m['ano_modelo'] as num?)?.toInt(),
      anoFabricacao: (m['ano_fabricacao'] as num?)?.toInt(),
      hodometroAtual: (m['hodometro_atual'] as num?)?.toDouble(),
      combustivel: m['combustivel'] as String?,
      tanque: (m['tanque'] as num?)?.toDouble(),
      autonomia: (m['autonomia'] as num?)?.toDouble(),
      cor: m['cor'] as String?,
      chassi: m['chassi'] as String?,
      renavam: m['renavam'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      municipio: m['municipio'] as String?,
      tipoVeiculo: m['tipo_veiculo'] as String?,
      ufVeiculo: m['uf_veiculo'] as String?,
      numeroEixos: (m['numero_eixos'] as num?)?.toInt(),
      classificacao: m['classificacao'] as String? ?? 'Próprio',
      tipo: m['tipo'] as String?,
      centroCustoId: m['centro_custo_id'] as String?,
      centroCustoNome: m['centro_custo_nome'] as String?,
      cnpjFrota: m['cnpj_frota'] as String? ?? '',
    );
  }
}

final veiculosClienteProvider = FutureProvider.autoDispose<List<Veiculo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('veiculos_da_empresa', params: {'p_empresa_id': empresaId}) as List;
  final veiculos = rows.map((m) => Veiculo.fromMap(m as Map<String, dynamic>)).toList()
    ..sort((a, b) => a.placa.compareTo(b.placa));
  return veiculos.take(1000).toList();
});

final veiculoDetalheProvider = FutureProvider.autoDispose.family<Veiculo?, String>((ref, id) async {
  final lista = await ref.watch(veiculosClienteProvider.future);
  for (final v in lista) {
    if (v.id == id) return v;
  }
  return null;
});
