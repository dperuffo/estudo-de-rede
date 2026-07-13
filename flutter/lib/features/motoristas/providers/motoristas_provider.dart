import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Motoristas (cliente), porta de
// src/app/(dashboard)/motoristas/page.tsx + [id]/page.tsx + actions.ts.
// Conceito só existe do lado Frota (posto não tem motoristas, tem
// Usuários) — feature nova, sem equivalente FLT-2 pra reaproveitar.
// Escopo reduzido: sem paginação (a web pagina de 30 em 30 — aqui traz
// até 500, suficiente pra uso no celular; mesmo limite usado em outras
// listas do app) nem importação por planilha (`/motoristas/importar`).
const classificacoesMotorista = ['Próprio', 'Agregado'];

class Motorista {
  final String id;
  final String nomeCompleto;
  final String cpf;
  final String? telefone;
  final String? email;
  final String classificacao;
  final String status;
  final String? cnh;
  final String? cnhVencimento;
  final String? centroCustoId;
  final String? centroCustoNome;

  const Motorista({
    required this.id,
    required this.nomeCompleto,
    required this.cpf,
    this.telefone,
    this.email,
    required this.classificacao,
    required this.status,
    this.cnh,
    this.cnhVencimento,
    this.centroCustoId,
    this.centroCustoNome,
  });

  bool get ativo => status == 'Ativo';

  factory Motorista.fromMap(Map<String, dynamic> m) {
    final centro = m['centros_custo'] as Map<String, dynamic>?;
    return Motorista(
      id: m['id'] as String,
      nomeCompleto: m['nome_completo'] as String? ?? '—',
      cpf: m['cpf'] as String? ?? '',
      telefone: m['telefone'] as String?,
      email: m['email'] as String?,
      classificacao: m['classificacao'] as String? ?? 'Próprio',
      status: m['status'] as String? ?? 'Ativo',
      cnh: m['cnh'] as String?,
      cnhVencimento: m['cnh_vencimento'] as String?,
      centroCustoId: m['centro_custo_id'] as String?,
      centroCustoNome: centro?['nome'] as String?,
    );
  }
}

final motoristasClienteProvider = FutureProvider.autoDispose<List<Motorista>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('motoristas')
      .select(
          'id, nome_completo, cpf, telefone, email, classificacao, status, cnh, cnh_vencimento, centro_custo_id, centros_custo(nome)')
      .eq('empresa_id', empresaId)
      .order('nome_completo')
      .limit(500) as List;
  return rows.map((m) => Motorista.fromMap(m as Map<String, dynamic>)).toList();
});

final motoristaDetalheProvider = FutureProvider.autoDispose.family<Motorista?, String>((ref, id) async {
  final lista = await ref.watch(motoristasClienteProvider.future);
  for (final m in lista) {
    if (m.id == id) return m;
  }
  return null;
});

final centrosCustoOpcoesProvider = FutureProvider.autoDispose<List<({String id, String nome})>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('centros_custo')
      .select('id, nome')
      .eq('empresa_id', empresaId)
      .eq('ativo', true)
      .order('nome') as List;
  return rows
      .map((m) => (m as Map<String, dynamic>))
      .map((m) => (id: m['id'] as String, nome: m['nome'] as String? ?? '—'))
      .toList();
});
