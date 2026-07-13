import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta reduzida de src/app/(dashboard)/clientes/page.tsx +
// clientes/[id]/page.tsx pro Flutter (visão Cliente). Achado real olhando
// a RLS de `empresas` (`empresas_select_membro`): o SELECT sem filtro que
// a página web faz só devolve a(s) própria(s) empresa(s) do usuário
// logado — pra um cliente comum, `/clientes` NUNCA mostra outras
// empresas; é, na prática, uma tela de "cadastro da minha empresa", não
// uma lista de clientes de verdade (isso só existe pro admin). Por isso a
// porta aqui é bem mais simples: mostra o cadastro da empresa atual
// (`sessao.empresaId`), read-only.
//
// Fora do escopo desta v1 (igual ao espírito das outras portas FLT-3):
// - Edição do cadastro (`ClienteForm`) — os campos editáveis pelo
//   próprio cliente na web são poucos (telefone/e-mail de contato,
//   basicamente) e o resto (ciclo/prazo, bypass de frota) é admin-only;
//   fica pra uma iteração própria com validação.
// - O widget `CicloAbastecimentoPagamento` (resumo cruzando TODOS os
//   postos que este cliente já negociou) — dado redundante com a seção
//   "Cobrança em Aberto" que o Painel Financeiro (cliente) já mostra
//   (mesmas tabelas: negociacoes_postos + faturas_postos + ciclos
//   abertos), então não duplicamos aqui.
// - Tudo que é admin-only na página original (lista de TODOS os
//   clientes, "+ Novo Cliente", toggle Ativar/Suspender, "Últimos
//   acessos") — não se aplica a um usuário cliente de verdade.

const statusEmpresaLabel = <String, String>{
  'trial': 'Em teste (trial)',
  'ativo': 'Ativo',
  'suspenso': 'Suspenso',
  'cancelado': 'Cancelado',
};

const planoLabel = <String, String>{
  'gratuito': 'Gratuito',
  'basico': 'Básico',
  'profissional': 'Profissional',
  'enterprise': 'Enterprise',
};

class ClienteCadastro {
  final String id;
  final String nome;
  final String? cnpj;
  final String status;
  final String? plano;
  final String? municipio;
  final String? uf;
  final String? segmentoTransporte;
  final String? porte;
  final int? maxUsuarios;
  final int? maxVeiculos;
  final String? telefoneContato;
  final String? emailContato;

  const ClienteCadastro({
    required this.id,
    required this.nome,
    this.cnpj,
    required this.status,
    this.plano,
    this.municipio,
    this.uf,
    this.segmentoTransporte,
    this.porte,
    this.maxUsuarios,
    this.maxVeiculos,
    this.telefoneContato,
    this.emailContato,
  });

  factory ClienteCadastro.fromMap(Map<String, dynamic> m) => ClienteCadastro(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '—',
        cnpj: m['cnpj'] as String?,
        status: m['status'] as String? ?? 'ativo',
        plano: m['plano'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        segmentoTransporte: m['segmento_transporte'] as String?,
        porte: m['porte'] as String?,
        maxUsuarios: (m['max_usuarios'] as num?)?.toInt(),
        maxVeiculos: (m['max_veiculos'] as num?)?.toInt(),
        telefoneContato: m['telefone_contato'] as String?,
        emailContato: m['email_contato'] as String?,
      );
}

final clienteCadastroProvider = FutureProvider.autoDispose<ClienteCadastro?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final row = await SupabaseService.client
      .from('empresas')
      .select(
          'id, nome, cnpj, status, plano, municipio, uf, segmento_transporte, porte, max_usuarios, max_veiculos, telefone_contato, email_contato')
      .eq('id', empresaId)
      .maybeSingle();
  return row == null ? null : ClienteCadastro.fromMap(row);
});
