import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase PWA-Parcerias-Locais — porta de parcerias-locais/page.tsx +
// actions.ts. Mesma tela pra posto e cliente (RLS já escopa por
// criador_empresa_id, ver fidelidade_catalogo_itens_dono_gerencia) — igual
// à web, uma única implementação usada nas duas rotas (/parcerias-locais no
// shell cliente e /posto/parcerias-locais no shell posto).

const categoriasFidelidade = [
  ('conveniencia_posto', 'Conveniência do Posto'),
  ('economia_imediata', 'Economia Imediata'),
  ('marketplace_cabine', 'Marketplace da Cabine'),
  ('saude_estrada', 'Saúde na Estrada'),
  ('universidade_estrada', 'Universidade da Estrada'),
  ('clube_caminhao', 'Clube do Caminhão'),
  ('volte_para_casa', 'Volte para Casa'),
];

const labelCategoriaFidelidade = {
  'conveniencia_posto': 'Conveniência do Posto',
  'economia_imediata': 'Economia Imediata',
  'marketplace_cabine': 'Marketplace da Cabine',
  'saude_estrada': 'Saúde na Estrada',
  'universidade_estrada': 'Universidade da Estrada',
  'clube_caminhao': 'Clube do Caminhão',
  'volte_para_casa': 'Volte para Casa',
};

class ItemParceria {
  final String id;
  final String categoria;
  final String titulo;
  final String? descricao;
  final String? parceiroNome;
  final int pontosNecessarios;
  final bool ativo;
  final String? imagemUrl;
  final int? validadeDias;

  const ItemParceria({
    required this.id,
    required this.categoria,
    required this.titulo,
    this.descricao,
    this.parceiroNome,
    required this.pontosNecessarios,
    required this.ativo,
    this.imagemUrl,
    this.validadeDias,
  });

  factory ItemParceria.fromMap(Map<String, dynamic> m) => ItemParceria(
        id: m['id'] as String,
        categoria: m['categoria'] as String? ?? 'economia_imediata',
        titulo: m['titulo'] as String? ?? '',
        descricao: m['descricao'] as String?,
        parceiroNome: m['parceiro_nome'] as String?,
        pontosNecessarios: (m['pontos_necessarios'] as num?)?.toInt() ?? 0,
        ativo: m['ativo'] as bool? ?? true,
        imagemUrl: m['imagem_url'] as String?,
        validadeDias: (m['validade_dias'] as num?)?.toInt(),
      );
}

class ResgateBeneficio {
  final String id;
  final String titulo;
  final String categoria;
  final int pontosGastos;
  final String status;
  final String? numeroVoucher;
  final String? validoAte;
  final String solicitadoEm;
  final String atualizadoEm;
  final String nomeMotorista;

  const ResgateBeneficio({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.pontosGastos,
    required this.status,
    this.numeroVoucher,
    this.validoAte,
    required this.solicitadoEm,
    required this.atualizadoEm,
    required this.nomeMotorista,
  });

  factory ResgateBeneficio.fromMap(Map<String, dynamic> m) => ResgateBeneficio(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        categoria: m['categoria'] as String? ?? '',
        pontosGastos: (m['pontos_gastos'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? 'solicitado',
        numeroVoucher: m['numero_voucher'] as String?,
        validoAte: m['valido_ate'] as String?,
        solicitadoEm: m['solicitado_em'] as String? ?? '',
        atualizadoEm: m['atualizado_em'] as String? ?? '',
        nomeMotorista: m['nome_motorista'] as String? ?? 'motorista',
      );
}

final itensParceriaProvider = FutureProvider.autoDispose<List<ItemParceria>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .from('fidelidade_catalogo_itens')
      .select('id, categoria, titulo, descricao, parceiro_nome, pontos_necessarios, ativo, imagem_url, validade_dias')
      .eq('criador_empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((r) => ItemParceria.fromMap(r as Map<String, dynamic>)).toList();
});

final itemParceriaDetalheProvider = FutureProvider.autoDispose.family<ItemParceria?, String>((ref, id) async {
  final row = await SupabaseService.client.from('fidelidade_catalogo_itens').select('*').eq('id', id).maybeSingle();
  if (row == null) return null;
  return ItemParceria.fromMap(row);
});

// resgates_beneficios_empresa é SECURITY DEFINER — junta o nome do
// motorista, que a RLS de `motoristas` não libera pra empresa dona do
// BENEFÍCIO (só pra empresa dona do motorista), mesmo motivo documentado
// na web (parcerias-locais/page.tsx).
final resgatesBeneficiosProvider = FutureProvider.autoDispose<List<ResgateBeneficio>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .rpc('resgates_beneficios_empresa', params: {'p_empresa_id': empresaId}) as List;
  return rows.map((r) => ResgateBeneficio.fromMap(r as Map<String, dynamic>)).toList();
});

class KpisParceriasLocais {
  final int pendentes;
  final int queimados;
  final int pontosQueimados;
  final int cancelados;
  const KpisParceriasLocais({
    required this.pendentes,
    required this.queimados,
    required this.pontosQueimados,
    required this.cancelados,
  });
}

KpisParceriasLocais calcularKpisParceriasLocais(List<ResgateBeneficio> resgates) {
  final pendentes = resgates.where((r) => r.status == 'solicitado' || r.status == 'em_andamento').toList();
  final queimados = resgates.where((r) => r.status == 'concluido').toList();
  final cancelados = resgates.where((r) => r.status == 'cancelado').toList();
  final pontosQueimados = queimados.fold<int>(0, (s, r) => s + r.pontosGastos);
  return KpisParceriasLocais(
    pendentes: pendentes.length,
    queimados: queimados.length,
    pontosQueimados: pontosQueimados,
    cancelados: cancelados.length,
  );
}
