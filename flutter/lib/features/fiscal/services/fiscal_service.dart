import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Fiscal (02/09/2026, pedido do Daniel: "equalizar o PWA Cliente
// com as funcionalidades construídas para a web cliente") — porta de
// fiscal/page.tsx + actions.ts (dados fiscais do emitente de CT-e/MDF-e).
//
// Corte de escopo desta v1 mobile: a web chama `obterProvedorFiscal(...)`
// (código TypeScript rodando no servidor Next.js, não é uma RPC Postgres)
// antes de gravar — isso cadastra o emitente no provedor fiscal e retorna
// `provedor_ref`. Esse código não é alcançável a partir do Flutter (não
// existe RPC equivalente). Por isso esta tela mobile faz só a parte que
// dá pra fazer com segurança via Supabase direto: ler/editar os campos
// de `empresas_fiscal` (regime, série, ambiente, IE, RNTRC). Envio de
// certificado A1 e teste de conexão continuam exclusivos da web (exigem
// o provedor). O status de conexão/vencimento do certificado, quando já
// preenchidos pela web, são mostrados aqui em modo leitura.
class DadosEmpresaFiscal {
  final String cnpj;
  final String nome;

  const DadosEmpresaFiscal({required this.cnpj, required this.nome});
}

class EmpresaFiscal {
  final String empresaId;
  final String? inscricaoEstadual;
  final String? rntrc;
  final String regimeTributario; // simples | presumido | real
  final int serieCte;
  final int serieMdfe;
  final String ambiente; // homologacao | producao
  final String provedor; // mock | focusnfe | plugnotas
  final String? provedorRef;
  final String? certificadoVencimento;
  final String? statusConexao;
  final String? statusConexaoEm;

  const EmpresaFiscal({
    required this.empresaId,
    required this.inscricaoEstadual,
    required this.rntrc,
    required this.regimeTributario,
    required this.serieCte,
    required this.serieMdfe,
    required this.ambiente,
    required this.provedor,
    required this.provedorRef,
    required this.certificadoVencimento,
    required this.statusConexao,
    required this.statusConexaoEm,
  });

  factory EmpresaFiscal.fromMap(Map<String, dynamic> m) => EmpresaFiscal(
        empresaId: m['empresa_id'] as String,
        inscricaoEstadual: m['inscricao_estadual'] as String?,
        rntrc: m['rntrc'] as String?,
        regimeTributario: m['regime_tributario'] as String? ?? 'simples',
        serieCte: (m['serie_cte'] as num?)?.toInt() ?? 1,
        serieMdfe: (m['serie_mdfe'] as num?)?.toInt() ?? 1,
        ambiente: m['ambiente'] as String? ?? 'homologacao',
        provedor: m['provedor'] as String? ?? 'mock',
        provedorRef: m['provedor_ref'] as String?,
        certificadoVencimento: m['certificado_vencimento'] as String?,
        statusConexao: m['status_conexao'] as String?,
        statusConexaoEm: m['status_conexao_em'] as String?,
      );
}

class FiscalService {
  final _supabase = SupabaseService.client;

  Future<DadosEmpresaFiscal?> buscarDadosEmpresa(String empresaId) async {
    final m = await _supabase
        .from('empresas')
        .select('cnpj, nome')
        .eq('id', empresaId)
        .maybeSingle();
    if (m == null) return null;
    return DadosEmpresaFiscal(
      cnpj: m['cnpj'] as String? ?? '',
      nome: m['nome'] as String? ?? '',
    );
  }

  Future<EmpresaFiscal?> buscar(String empresaId) async {
    final m = await _supabase
        .from('empresas_fiscal')
        .select()
        .eq('empresa_id', empresaId)
        .maybeSingle();
    if (m == null) return null;
    return EmpresaFiscal.fromMap(m);
  }

  Future<String?> salvar({
    required String empresaId,
    String? inscricaoEstadual,
    String? rntrc,
    required String regimeTributario,
    required int serieCte,
    required int serieMdfe,
    required String ambiente,
  }) async {
    if (!['simples', 'presumido', 'real'].contains(regimeTributario)) {
      return 'Regime tributário inválido.';
    }
    if (!['homologacao', 'producao'].contains(ambiente)) {
      return 'Ambiente inválido.';
    }
    if (serieCte < 1 || serieMdfe < 1) {
      return 'Série do CT-e e do MDF-e devem ser maiores ou iguais a 1.';
    }
    try {
      final dados = await buscarDadosEmpresa(empresaId);
      if (dados == null || dados.cnpj.trim().isEmpty) {
        return 'Cadastre o CNPJ da empresa em Clientes antes de configurar os dados fiscais.';
      }
      await _supabase.from('empresas_fiscal').upsert({
        'empresa_id': empresaId,
        'inscricao_estadual': (inscricaoEstadual == null ||
                inscricaoEstadual.trim().isEmpty)
            ? null
            : inscricaoEstadual.trim(),
        'rntrc':
            (rntrc == null || rntrc.trim().isEmpty) ? null : rntrc.trim(),
        'regime_tributario': regimeTributario,
        'serie_cte': serieCte,
        'serie_mdfe': serieMdfe,
        'ambiente': ambiente,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        'atualizado_por': AuthService().emailAtual,
      }, onConflict: 'empresa_id');
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }
}
