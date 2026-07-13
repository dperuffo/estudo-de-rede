import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Privacidade (LGPD) da visão Posto, porta de
// src/app/(dashboard)/lgpd/page.tsx + actions.ts. Na web esta é UMA ÚNICA
// rota (/lgpd) compartilhada por cliente/posto — o conteúdo é idêntico
// pros dois, só o link no menu muda de lugar; a única bifurcação real de
// UI na web é admin x não-admin (o bloco "todas as solicitações de
// exclusão" só aparece pro admin). Como o shell Flutter /posto NUNCA é
// acessado por admin, portamos só os 4 blocos "não-admin": dados
// cadastrais, revogar consentimento, solicitar exclusão dos meus dados
// (com histórico) e histórico de consentimento.
//
// Achado real: a Server Action `registrarRevogacaoConsentimento` da web
// captura IP/user-agent a partir dos HEADERS DA REQUISIÇÃO (só possível
// num Server Action rodando no servidor Next.js) — não tem equivalente
// direto no Flutter, que fala direto com o Supabase pelo client. Os
// registros de consentimento gravados pelo app ficam com `ip`/`user_agent`
// nulos; o que importa legalmente (e-mail + tipo + timestamp) continua
// gravado normalmente.

const tipoConsentimentoLabel = <String, String>{
  'cadastro': 'Aceite no cadastro',
  'revogacao': 'Revogação de consentimento',
};

const statusExclusaoLabel = <String, String>{
  'pendente': 'Pendente',
  'executado': 'Executado',
};

class DadosCadastrais {
  final String? nome;
  final String? email;
  final String? cpf;
  final String? telefone;
  final String? empresaNome;
  final String? perfil;
  final bool mfaHabilitado;
  final String? criadoEm;

  const DadosCadastrais({
    this.nome,
    this.email,
    this.cpf,
    this.telefone,
    this.empresaNome,
    this.perfil,
    required this.mfaHabilitado,
    this.criadoEm,
  });

  factory DadosCadastrais.fromMap(Map<String, dynamic> m) => DadosCadastrais(
        nome: m['nome'] as String?,
        email: m['email'] as String?,
        cpf: m['cpf'] as String?,
        telefone: m['telefone'] as String?,
        empresaNome: m['empresa_nome'] as String?,
        perfil: m['perfil'] as String?,
        mfaHabilitado: m['mfa_habilitado'] as bool? ?? false,
        criadoEm: m['created_at'] as String?,
      );
}

class ConsentimentoLgpd {
  final String id;
  final String tipo;
  final String? ip;
  final String timestamp;

  const ConsentimentoLgpd({required this.id, required this.tipo, this.ip, required this.timestamp});

  factory ConsentimentoLgpd.fromMap(Map<String, dynamic> m) => ConsentimentoLgpd(
        id: m['id'].toString(),
        tipo: m['tipo'] as String? ?? '',
        ip: m['ip'] as String?,
        timestamp: m['timestamp'] as String? ?? '',
      );
}

class ExclusaoLgpd {
  final String id;
  final String? empresaId;
  final String status;
  final String? solicitadoEm;
  final String? executadoEm;

  const ExclusaoLgpd({
    required this.id,
    this.empresaId,
    required this.status,
    this.solicitadoEm,
    this.executadoEm,
  });

  factory ExclusaoLgpd.fromMap(Map<String, dynamic> m) => ExclusaoLgpd(
        id: m['id'].toString(),
        empresaId: m['empresa_id'] as String?,
        status: m['status'] as String? ?? 'pendente',
        solicitadoEm: m['solicitado_em'] as String?,
        executadoEm: m['executado_em'] as String?,
      );
}

class LgpdDetalhe {
  final DadosCadastrais? dados;
  final List<ConsentimentoLgpd> consentimentos;
  final List<ExclusaoLgpd> exclusoes;
  final List<({String id, String nome})> empresasVinculadas;

  const LgpdDetalhe({
    required this.dados,
    required this.consentimentos,
    required this.exclusoes,
    required this.empresasVinculadas,
  });
}

final lgpdProvider = FutureProvider.autoDispose<LgpdDetalhe>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final supabase = SupabaseService.client;
  final email = sessao.email;

  final dadosRaw = await supabase
      .from('usuarios_app')
      .select('nome, email, cpf, telefone, empresa_nome, perfil, mfa_habilitado, created_at')
      .eq('email', email)
      .maybeSingle();
  final dados = dadosRaw == null ? null : DadosCadastrais.fromMap(dadosRaw);

  final consentimentosRaw = await supabase
      .from('lgpd_consents')
      .select('id, tipo, ip, timestamp')
      .eq('email', email)
      .order('timestamp', ascending: false) as List;
  final consentimentos =
      consentimentosRaw.map((m) => ConsentimentoLgpd.fromMap(m as Map<String, dynamic>)).toList();

  final exclusoesRaw = await supabase
      .from('lgpd_exclusoes')
      .select('id, empresa_id, status, solicitado_em, executado_em')
      .eq('email', email)
      .order('solicitado_em', ascending: false) as List;
  final exclusoes = exclusoesRaw.map((m) => ExclusaoLgpd.fromMap(m as Map<String, dynamic>)).toList();

  var empresasVinculadas = <({String id, String nome})>[];
  if (sessao.empresasIds.isNotEmpty) {
    final empresasRaw = await supabase
        .from('empresas')
        .select('id, nome')
        .inFilter('id', sessao.empresasIds)
        .order('nome') as List;
    empresasVinculadas = empresasRaw
        .map((m) => (m as Map<String, dynamic>))
        .map((m) => (id: m['id'] as String, nome: m['nome'] as String? ?? '—'))
        .toList();
  }

  return LgpdDetalhe(
    dados: dados,
    consentimentos: consentimentos,
    exclusoes: exclusoes,
    empresasVinculadas: empresasVinculadas,
  );
});
