import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase PWA-Fretes — porta de /fretes (+ [id]) da web pro PWA cliente. Só
// visão CLIENTE (publicar, negociar, acompanhar) — o motorista já tem seu
// próprio app (estrada-que-cuida). Mesma autenticação email+senha da web
// (RLS já protege por empresa_id via empresas_do_usuario), então quase
// tudo aqui é leitura/escrita direta nas tabelas — só onde a web usa RPC
// SECURITY DEFINER (negociação, avaliação, parceiros) que a gente também
// usa RPC.

const labelStatusFrete = <String, String>{
  'disponivel': 'Disponível (mercado aberto)',
  'aguardando_confirmacao': 'Aguardando confirmação do motorista',
  'aceito': 'Aceito',
  'em_andamento': 'Em andamento',
  'concluido': 'Concluído',
  'cancelado': 'Cancelado',
  'recusado': 'Recusado pelo motorista',
};

const labelEventoFrete = <String, String>{
  'saiu_origem': 'Saiu da origem',
  'chegou_posto': 'Chegou no posto',
  'abasteceu': 'Abasteceu',
  'parada': 'Parada',
  'chegou_destino': 'Chegou no destino',
  'ocorrencia': 'Ocorrência',
  'concluido': 'Concluiu o frete',
};

class FreteRow {
  final String id;
  final String titulo;
  final String status;
  final String origemLabel;
  final String destinoLabel;
  final double valorOferecido;
  final double? kmEstimado;
  final String? motoristaId;
  final String? nomeMotorista;
  final String? telefoneMotorista;
  final String criadoEm;

  const FreteRow({
    required this.id,
    required this.titulo,
    required this.status,
    required this.origemLabel,
    required this.destinoLabel,
    required this.valorOferecido,
    this.kmEstimado,
    this.motoristaId,
    this.nomeMotorista,
    this.telefoneMotorista,
    required this.criadoEm,
  });

  factory FreteRow.fromMap(Map<String, dynamic> m) => FreteRow(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        status: m['status'] as String? ?? '',
        origemLabel: m['origem_label'] as String? ?? '',
        destinoLabel: m['destino_label'] as String? ?? '',
        valorOferecido: (m['valor_oferecido'] as num?)?.toDouble() ?? 0,
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        motoristaId: m['motorista_id'] as String?,
        nomeMotorista: m['nome_motorista'] as String?,
        telefoneMotorista: m['telefone_motorista'] as String?,
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class Frete {
  final String id;
  final String empresaId;
  final String titulo;
  final String? descricao;
  final String status;
  final String origemLabel;
  final String destinoLabel;
  final String? tipoCarga;
  final double? pesoCargaKg;
  final String? dataSaidaPrevista;
  final String? prazoEntrega;
  final double? kmEstimado;
  final double valorOferecido;
  final String? motoristaId;
  // Fase Fretes-Dados-Completos — endereço completo e horário exato de
  // coleta/entrega, mais dimensões da carga, pra o motorista decidir se
  // aceita o frete (origemLabel/destinoLabel acima são só a cidade, usada
  // pro cálculo de km/mapa).
  final EnderecoFrete coleta;
  final EnderecoFrete entrega;
  final double? cargaComprimentoM;
  final double? cargaLarguraM;
  final double? cargaAlturaM;
  final List<String> veiculosAceitos;
  final List<String> carroceriasAceitas;

  const Frete({
    required this.id,
    required this.empresaId,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.origemLabel,
    required this.destinoLabel,
    this.tipoCarga,
    this.pesoCargaKg,
    this.dataSaidaPrevista,
    this.prazoEntrega,
    this.kmEstimado,
    required this.valorOferecido,
    this.motoristaId,
    required this.coleta,
    required this.entrega,
    this.cargaComprimentoM,
    this.cargaLarguraM,
    this.cargaAlturaM,
    this.veiculosAceitos = const [],
    this.carroceriasAceitas = const [],
  });

  factory Frete.fromMap(Map<String, dynamic> m) => Frete(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        titulo: m['titulo'] as String? ?? '',
        descricao: m['descricao'] as String?,
        status: m['status'] as String? ?? '',
        origemLabel: m['origem_label'] as String? ?? '',
        destinoLabel: m['destino_label'] as String? ?? '',
        tipoCarga: m['tipo_carga'] as String?,
        pesoCargaKg: (m['peso_carga_kg'] as num?)?.toDouble(),
        dataSaidaPrevista: m['data_saida_prevista'] as String?,
        prazoEntrega: m['prazo_entrega'] as String?,
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        valorOferecido: (m['valor_oferecido'] as num?)?.toDouble() ?? 0,
        motoristaId: m['motorista_id'] as String?,
        coleta: EnderecoFrete.fromMap(m, 'coleta'),
        entrega: EnderecoFrete.fromMap(m, 'entrega'),
        cargaComprimentoM: (m['carga_comprimento_m'] as num?)?.toDouble(),
        cargaLarguraM: (m['carga_largura_m'] as num?)?.toDouble(),
        cargaAlturaM: (m['carga_altura_m'] as num?)?.toDouble(),
        veiculosAceitos: (m['veiculos_aceitos'] as List?)?.map((v) => v as String).toList() ?? const [],
        carroceriasAceitas: (m['carrocerias_aceitas'] as List?)?.map((v) => v as String).toList() ?? const [],
      );
}

class EnderecoFrete {
  final String? rua;
  final String? numero;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final String? cep;
  final String? referencia;
  final String? data;
  final String? hora;
  final String? contatoNome;
  final String? contatoTelefone;

  const EnderecoFrete({
    this.rua,
    this.numero,
    this.bairro,
    this.cidade,
    this.uf,
    this.cep,
    this.referencia,
    this.data,
    this.hora,
    this.contatoNome,
    this.contatoTelefone,
  });

  bool get preenchido => rua != null || cidade != null;

  String get linhaEndereco {
    final partes = <String>[
      if (rua != null) (numero != null ? '$rua, $numero' : rua!),
      if (bairro != null) bairro!,
      if (cidade != null) (uf != null ? '$cidade/$uf' : cidade!),
    ];
    return partes.join(' — ');
  }

  factory EnderecoFrete.fromMap(Map<String, dynamic> m, String prefixo) => EnderecoFrete(
        rua: m['${prefixo}_rua'] as String?,
        numero: m['${prefixo}_numero'] as String?,
        bairro: m['${prefixo}_bairro'] as String?,
        cidade: m['${prefixo}_cidade'] as String?,
        uf: m['${prefixo}_uf'] as String?,
        cep: m['${prefixo}_cep'] as String?,
        referencia: m['${prefixo}_referencia'] as String?,
        data: m['${prefixo}_data'] as String?,
        hora: m['${prefixo}_hora'] as String?,
        contatoNome: m['${prefixo}_contato_nome'] as String?,
        contatoTelefone: m['${prefixo}_contato_telefone'] as String?,
      );
}

class Proposta {
  final String negociacaoId;
  final String motoristaId;
  final String nomeMotorista;
  final String? telefoneMotorista;
  final String status;
  final int rodadaAtual;
  final double ultimoValor;
  final String ultimoAutor;
  final ReputacaoMotorista reputacao;

  const Proposta({
    required this.negociacaoId,
    required this.motoristaId,
    required this.nomeMotorista,
    this.telefoneMotorista,
    required this.status,
    required this.rodadaAtual,
    required this.ultimoValor,
    required this.ultimoAutor,
    required this.reputacao,
  });

  factory Proposta.fromMap(Map<String, dynamic> m) => Proposta(
        negociacaoId: m['negociacao_id'] as String,
        motoristaId: m['motorista_id'] as String? ?? '',
        nomeMotorista: m['nome_motorista'] as String? ?? '',
        telefoneMotorista: m['telefone_motorista'] as String?,
        status: m['status'] as String? ?? '',
        rodadaAtual: (m['rodada_atual'] as num?)?.toInt() ?? 1,
        ultimoValor: (m['ultimo_valor'] as num?)?.toDouble() ?? 0,
        ultimoAutor: m['ultimo_autor'] as String? ?? '',
        reputacao: ReputacaoMotorista.fromMap(m),
      );
}

// Fase Fretes-Dados-Completos — pedido do Daniel: "cliente precisa de
// algumas garantias de que o motorista é idôneo". Consolida sinais que já
// existiam espalhados (avaliações, CNH+validade, telefone verificado, 2FA)
// num cartão só — ver _reputacao_motorista() no banco.
class ReputacaoMotorista {
  final double? mediaEstrelas;
  final int totalAvaliacoes;
  final int fretesConcluidos;
  final double? taxaConclusao;
  final bool cnhValida;
  final String? cnhVencimento;
  final bool telefoneVerificado;
  final bool seguranca2faAtivo;
  final int? diasCadastro;
  final bool seloVerificado;
  // Fase Destaques-Automaticos — tags marcadas pelo cliente na avaliação que
  // se repetiram em 2+ avaliações diferentes desse motorista (ver
  // _reputacao_motorista no banco).
  final List<TagDestaque> tagsDestaque;

  const ReputacaoMotorista({
    this.mediaEstrelas,
    required this.totalAvaliacoes,
    required this.fretesConcluidos,
    this.taxaConclusao,
    required this.cnhValida,
    this.cnhVencimento,
    required this.telefoneVerificado,
    required this.seguranca2faAtivo,
    this.diasCadastro,
    required this.seloVerificado,
    this.tagsDestaque = const [],
  });

  factory ReputacaoMotorista.fromMap(Map<String, dynamic> m) => ReputacaoMotorista(
        mediaEstrelas: (m['media_estrelas'] as num?)?.toDouble(),
        totalAvaliacoes: (m['total_avaliacoes'] as num?)?.toInt() ?? 0,
        fretesConcluidos: (m['fretes_concluidos'] as num?)?.toInt() ?? 0,
        taxaConclusao: (m['taxa_conclusao'] as num?)?.toDouble(),
        cnhValida: m['cnh_valida'] as bool? ?? false,
        cnhVencimento: m['cnh_vencimento'] as String?,
        telefoneVerificado: m['telefone_verificado'] as bool? ?? false,
        seguranca2faAtivo: m['seguranca_2fa_ativo'] as bool? ?? false,
        diasCadastro: (m['dias_cadastro'] as num?)?.toInt(),
        seloVerificado: m['selo_verificado'] as bool? ?? false,
        tagsDestaque: (m['tags_destaque'] as List<dynamic>? ?? [])
            .map((t) => TagDestaque.fromMap(t as Map<String, dynamic>))
            .toList(),
      );

  String get tempoCadastroFormatado {
    final dias = diasCadastro;
    if (dias == null) return '—';
    if (dias < 30) return '$dias dia${dias == 1 ? '' : 's'} na rede';
    if (dias < 365) return '${(dias / 30).floor()} mês(es) na rede';
    return '${(dias / 365).floor()} ano(s) na rede';
  }
}

class PostoRecomendado {
  final String id;
  final String nomePosto;
  final String? observacao;
  final String? itemCatalogoId;

  const PostoRecomendado({required this.id, required this.nomePosto, this.observacao, this.itemCatalogoId});

  factory PostoRecomendado.fromMap(Map<String, dynamic> m) => PostoRecomendado(
        id: m['id'] as String,
        nomePosto: m['nome_posto'] as String? ?? '',
        observacao: m['observacao'] as String?,
        itemCatalogoId: m['item_catalogo_id'] as String?,
      );
}

class EventoFrete {
  final String id;
  final String tipoEvento;
  final String? observacao;
  final DateTime criadoEm;
  final String? fotoPath;
  String? fotoUrlAssinada;

  EventoFrete({
    required this.id,
    required this.tipoEvento,
    this.observacao,
    required this.criadoEm,
    this.fotoPath,
    this.fotoUrlAssinada,
  });

  factory EventoFrete.fromMap(Map<String, dynamic> m) => EventoFrete(
        id: m['id'] as String,
        tipoEvento: m['tipo_evento'] as String? ?? '',
        observacao: m['observacao'] as String?,
        criadoEm: DateTime.parse(m['criado_em'] as String),
        fotoPath: m['foto_path'] as String?,
      );
}

class AvaliacaoFrete {
  final String avaliador;
  final int estrelas;
  final String? comentario;
  final List<String> tags;

  const AvaliacaoFrete({required this.avaliador, required this.estrelas, this.comentario, this.tags = const []});

  factory AvaliacaoFrete.fromMap(Map<String, dynamic> m) => AvaliacaoFrete(
        avaliador: m['avaliador'] as String? ?? '',
        estrelas: (m['estrelas'] as num?)?.toInt() ?? 0,
        comentario: m['comentario'] as String?,
        tags: (m['tags'] as List<dynamic>? ?? []).map((t) => t as String).toList(),
      );
}

// Fase Destaques-Automaticos — {tag, quantidade} vindo de
// _reputacao_motorista.tags_destaque (jsonb).
class TagDestaque {
  final String tag;
  final int quantidade;

  const TagDestaque({required this.tag, required this.quantidade});

  factory TagDestaque.fromMap(Map<String, dynamic> m) => TagDestaque(
        tag: m['tag'] as String? ?? '',
        quantidade: (m['quantidade'] as num?)?.toInt() ?? 0,
      );
}

class ItemParceriaOpcao {
  final String id;
  final String titulo;
  final String? parceiroNome;

  const ItemParceriaOpcao({required this.id, required this.titulo, this.parceiroNome});

  factory ItemParceriaOpcao.fromMap(Map<String, dynamic> m) => ItemParceriaOpcao(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        parceiroNome: m['parceiro_nome'] as String?,
      );
}

class MotoristaOpcao {
  final String id;
  final String nome;
  final String origem; // 'proprio' | 'parceiro'

  const MotoristaOpcao({required this.id, required this.nome, required this.origem});
}

class ParceiroRow {
  final String id;
  final String motoristaId;
  final String nomeCompleto;
  final String? telefone;
  final String status;
  final String convidadoEm;
  final ReputacaoMotorista reputacao;

  const ParceiroRow({
    required this.id,
    required this.motoristaId,
    required this.nomeCompleto,
    this.telefone,
    required this.status,
    required this.convidadoEm,
    required this.reputacao,
  });

  factory ParceiroRow.fromMap(Map<String, dynamic> m) => ParceiroRow(
        id: m['id'] as String,
        motoristaId: m['motorista_id'] as String? ?? '',
        nomeCompleto: m['nome_completo'] as String? ?? '',
        telefone: m['telefone'] as String?,
        status: m['status'] as String? ?? '',
        convidadoEm: m['convidado_em'] as String? ?? '',
        reputacao: ReputacaoMotorista.fromMap(m),
      );
}

final meusFretesProvider = FutureProvider.autoDispose<List<FreteRow>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('meus_fretes_empresa', params: {'p_empresa_id': empresaId});
  return (rows as List).map((r) => FreteRow.fromMap(r as Map<String, dynamic>)).toList();
});

final freteDetalheProvider = FutureProvider.autoDispose.family<Frete?, String>((ref, freteId) async {
  final row = await SupabaseService.client
      .from('fretes')
      .select(
          'id, empresa_id, titulo, descricao, status, origem_label, destino_label, tipo_carga, peso_carga_kg, data_saida_prevista, prazo_entrega, km_estimado, valor_oferecido, motorista_id, '
          'coleta_rua, coleta_numero, coleta_bairro, coleta_cidade, coleta_uf, coleta_cep, coleta_referencia, coleta_data, coleta_hora, coleta_contato_nome, coleta_contato_telefone, '
          'entrega_rua, entrega_numero, entrega_bairro, entrega_cidade, entrega_uf, entrega_cep, entrega_referencia, entrega_data, entrega_hora, entrega_contato_nome, entrega_contato_telefone, '
          'carga_comprimento_m, carga_largura_m, carga_altura_m, veiculos_aceitos, carrocerias_aceitas')
      .eq('id', freteId)
      .maybeSingle();
  return row == null ? null : Frete.fromMap(row);
});

final propostasFreteProvider = FutureProvider.autoDispose.family<List<Proposta>, String>((ref, freteId) async {
  final rows = await SupabaseService.client.rpc('negociacoes_frete_empresa', params: {'p_frete_id': freteId});
  return (rows as List).map((r) => Proposta.fromMap(r as Map<String, dynamic>)).toList();
});

final postosRecomendadosProvider = FutureProvider.autoDispose.family<List<PostoRecomendado>, String>((ref, freteId) async {
  final rows = await SupabaseService.client
      .from('fretes_postos_recomendados')
      .select('id, nome_posto, observacao, item_catalogo_id')
      .eq('frete_id', freteId)
      .order('ordem', ascending: true);
  return (rows as List).map((r) => PostoRecomendado.fromMap(r as Map<String, dynamic>)).toList();
});

// Fase foto-evidência-checkpoints — bucket privado `fretes-evidencias`;
// gera signed URL por foto (1h), best-effort (foto ausente/corrompida não
// pode derrubar a tela — mesmo tratamento de ticket_anexos).
final eventosFreteProvider = FutureProvider.autoDispose.family<List<EventoFrete>, String>((ref, freteId) async {
  final rows = await SupabaseService.client
      .from('fretes_eventos')
      .select('id, tipo_evento, observacao, criado_em, foto_path')
      .eq('frete_id', freteId)
      .order('criado_em', ascending: true);
  final eventos = (rows as List).map((r) => EventoFrete.fromMap(r as Map<String, dynamic>)).toList();
  for (final e in eventos) {
    if (e.fotoPath == null) continue;
    try {
      e.fotoUrlAssinada = await SupabaseService.client.storage.from('fretes-evidencias').createSignedUrl(e.fotoPath!, 3600);
    } catch (_) {}
  }
  return eventos;
});

final avaliacoesFreteProvider = FutureProvider.autoDispose.family<List<AvaliacaoFrete>, String>((ref, freteId) async {
  final rows =
      await SupabaseService.client.from('fretes_avaliacoes').select('avaliador, estrelas, comentario, tags').eq('frete_id', freteId);
  return (rows as List).map((r) => AvaliacaoFrete.fromMap(r as Map<String, dynamic>)).toList();
});

final itensConvenienciaPostoProvider = FutureProvider.autoDispose<List<ItemParceriaOpcao>>((ref) async {
  final rows = await SupabaseService.client
      .from('fidelidade_catalogo_itens')
      .select('id, titulo, parceiro_nome')
      .eq('categoria', 'conveniencia_posto')
      .eq('ativo', true);
  return (rows as List).map((r) => ItemParceriaOpcao.fromMap(r as Map<String, dynamic>)).toList();
});

final motoristasOpcaoProvider = FutureProvider.autoDispose.family<List<MotoristaOpcao>, String>((ref, empresaId) async {
  final proprios = await SupabaseService.client
      .from('motoristas')
      .select('id, nome_completo')
      .eq('empresa_id', empresaId)
      .eq('status', 'Ativo');
  final parceiros = await SupabaseService.client.rpc('meus_parceiros_empresa', params: {'p_empresa_id': empresaId});

  final lista = <MotoristaOpcao>[
    ...(proprios as List).map((m) => MotoristaOpcao(id: m['id'] as String, nome: m['nome_completo'] as String? ?? '', origem: 'proprio')),
    ...(parceiros as List)
        .where((p) => (p as Map<String, dynamic>)['status'] == 'ativo')
        .map((p) => MotoristaOpcao(
              id: (p as Map<String, dynamic>)['motorista_id'] as String,
              nome: p['nome_completo'] as String? ?? '',
              origem: 'parceiro',
            )),
  ];
  return lista;
});

final parceirosProvider = FutureProvider.autoDispose<List<ParceiroRow>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('meus_parceiros_empresa', params: {'p_empresa_id': empresaId});
  return (rows as List).map((r) => ParceiroRow.fromMap(r as Map<String, dynamic>)).toList();
});
