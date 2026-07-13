import 'package:dio/dio.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/assistente/actions.ts +
// src/lib/assistenteIA.ts pro Flutter. Diferente de TODAS as outras telas
// do app (que falam direto com o Supabase — RLS cuida da segurança), o
// Assistente FNI usa a API da Anthropic com uma chave secreta
// (ANTHROPIC_API_KEY) — essa chave NUNCA pode ir pro bundle do app. Por
// isso esta chamada não vai direto no Supabase: vai numa rota nova do site
// (`/api/assistente`, ver route.ts no repo Gestão de Frotas), autenticada
// com o próprio access_token da sessão Supabase do usuário (o mesmo token
// que supabase_flutter já guarda depois do login) em vez de cookies — o
// app não compartilha domínio com o site. A rota valida esse token, monta
// um client Supabase "como" o usuário (RLS aplica normalmente) e chama a
// MESMA função perguntarAssistente da web.
const _baseUrlSite = 'https://fxgestaodefrotasonline.com';

class MensagemChat {
  final String role; // 'user' | 'assistant'
  final String content;
  const MensagemChat({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ConsultaExecutada {
  final String sql;
  final int linhas;
  final String? erro;
  const ConsultaExecutada({required this.sql, required this.linhas, this.erro});
  factory ConsultaExecutada.fromMap(Map<String, dynamic> m) => ConsultaExecutada(
        sql: m['sql'] as String? ?? '',
        linhas: (m['linhas'] as num?)?.toInt() ?? 0,
        erro: m['erro'] as String?,
      );
}

class RespostaAssistente {
  final String? resposta;
  final List<ConsultaExecutada> consultas;
  final String? erro;
  const RespostaAssistente.ok(this.resposta, this.consultas) : erro = null;
  const RespostaAssistente.erro(this.erro)
      : resposta = null,
        consultas = const [];
}

class AssistenteService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrlSite,
    connectTimeout: const Duration(seconds: 15),
    // O modelo pode fazer várias rodadas de consulta ao banco antes de
    // responder (até MAX_RODADAS_FERRAMENTA=6 na web) — dá tempo de sobra.
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<RespostaAssistente> perguntar(String pergunta, List<MensagemChat> historico) async {
    final perguntaLimpa = pergunta.trim();
    if (perguntaLimpa.isEmpty) return const RespostaAssistente.erro('Digite uma pergunta.');
    if (perguntaLimpa.length > 2000) {
      return const RespostaAssistente.erro('Pergunta muito longa (máximo 2000 caracteres).');
    }

    final token = SupabaseService.client.auth.currentSession?.accessToken;
    if (token == null) {
      return const RespostaAssistente.erro('Sessão expirada, faça login novamente.');
    }

    try {
      final resposta = await _dio.post(
        '/api/assistente',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'pergunta': perguntaLimpa,
          'historico': historico.map((m) => m.toJson()).toList(),
        },
      );
      final corpo = resposta.data as Map<String, dynamic>;
      if (corpo['erro'] != null) return RespostaAssistente.erro(corpo['erro'] as String);
      final consultasRaw = corpo['consultas'] as List? ?? const [];
      final consultas = consultasRaw.map((c) => ConsultaExecutada.fromMap(c as Map<String, dynamic>)).toList();
      return RespostaAssistente.ok(corpo['resposta'] as String?, consultas);
    } on DioException catch (e) {
      final corpo = e.response?.data;
      if (corpo is Map && corpo['erro'] != null) return RespostaAssistente.erro(corpo['erro'] as String);
      return RespostaAssistente.erro('Não foi possível falar com o Assistente FNI agora. Tente novamente.');
    }
  }
}
