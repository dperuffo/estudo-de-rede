// Fase Fretes-CIOT-CTe (18/07) — porta manual de src/lib/cte.ts (Next.js).
// Mesmo aviso já dado nos outros *_service.dart deste app: não existe RPC
// pra essa lógica, é replicada à mão no Dart — a diferença aqui é que este
// app não tem um pacote de parsing XML nas dependências (só `file_picker`,
// ver pubspec.yaml) e não dá pra rodar `flutter pub get` neste ambiente pra
// adicionar um com segurança (pubspec.lock ficaria inconsistente). Em vez
// de um parser XML de verdade, isto usa RegExp nas tags específicas do
// layout nacional do CT-e (modelo 57) — funciona bem pra um XML "normal"
// (sem CDATA nem comentários no meio das tags relevantes), mas é menos
// robusto que um parser real. Se der problema com XML de verdade, considere
// adicionar o pacote `xml` (flutter pub add xml) e portar cte.ts de forma
// mais fiel, IGUAL foi feito no site.
//
// Mesma crítica rígida do site: só aceita CT-e com protocolo de autorização
// da SEFAZ anexado (protCTe/infProt/cStat = "100").

class CteExtraida {
  final String chaveAcesso;
  final String numeroCte;
  final String serieCte;
  final String cnpjEmitente;
  final String nomeEmitente;
  final double valorPrestacao;
  final String dataEmissao;
  final String? protocoloAutorizacao;
  final String statusCodigo;
  final String motivoStatus;

  CteExtraida({
    required this.chaveAcesso,
    required this.numeroCte,
    required this.serieCte,
    required this.cnpjEmitente,
    required this.nomeEmitente,
    required this.valorPrestacao,
    required this.dataEmissao,
    required this.protocoloAutorizacao,
    required this.statusCodigo,
    required this.motivoStatus,
  });
}

class ResultadoParseCte {
  final bool ok;
  final CteExtraida? cte;
  final String? erro;
  ResultadoParseCte.sucesso(this.cte)
      : ok = true,
        erro = null;
  ResultadoParseCte.falha(this.erro)
      : ok = false,
        cte = null;
}

String? _tag(String xml, String tag, [String? dentro]) {
  final fonte = dentro ?? xml;
  final match = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(fonte);
  return match?.group(1)?.trim();
}

String? _bloco(String xml, String tag) {
  final match = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(xml);
  return match?.group(0);
}

ResultadoParseCte parsearXmlCte(String xmlTexto) {
  final idMatch = RegExp(r'<infCte[^>]*\bId="([^"]*)"').firstMatch(xmlTexto);
  if (idMatch == null) {
    return ResultadoParseCte.falha('Estrutura do CT-e inválida: tag <infCte> com atributo Id não encontrada.');
  }
  final chaveAcesso = idMatch.group(1)!.replaceFirst(RegExp('^CTe', caseSensitive: false), '').trim();
  if (chaveAcesso.length != 44 || !RegExp(r'^\d{44}$').hasMatch(chaveAcesso)) {
    return ResultadoParseCte.falha('Chave de acesso inválida (esperado 44 dígitos, veio "$chaveAcesso").');
  }

  final ideBloco = _bloco(xmlTexto, 'ide');
  final emitBloco = _bloco(xmlTexto, 'emit');
  final vPrestBloco = _bloco(xmlTexto, 'vPrest');
  if (ideBloco == null || emitBloco == null) {
    return ResultadoParseCte.falha('Estrutura do CT-e inválida: faltam os grupos <ide> e/ou <emit>.');
  }

  final modelo = _tag(xmlTexto, 'mod', ideBloco) ?? '';
  final cnpjEmitente = (_tag(xmlTexto, 'CNPJ', emitBloco) ?? '').replaceAll(RegExp(r'\D'), '');
  if (modelo != '57') {
    return ResultadoParseCte.falha('Este XML não é um CT-e (modelo "$modelo", esperado "57").');
  }

  final protCteBloco = _bloco(xmlTexto, 'protCTe');
  final infProtBloco = protCteBloco != null ? _bloco(protCteBloco, 'infProt') : null;
  if (infProtBloco == null) {
    return ResultadoParseCte.falha(
        'Este XML não tem o protocolo de autorização da SEFAZ anexado (<protCTe>) — envie o XML completo (cteProc), não só o CT-e sem o protocolo.');
  }

  final statusCodigo = _tag(xmlTexto, 'cStat', infProtBloco) ?? '';
  final motivoStatus = _tag(xmlTexto, 'xMotivo', infProtBloco) ?? '';
  if (statusCodigo != '100') {
    return ResultadoParseCte.falha(
        'CT-e não autorizado pela SEFAZ (status ${statusCodigo.isEmpty ? "desconhecido" : statusCodigo}: ${motivoStatus.isEmpty ? "sem motivo informado" : motivoStatus}).');
  }

  final valorPrestacaoTxt = vPrestBloco != null ? _tag(xmlTexto, 'vTPrest', vPrestBloco) : null;
  final valorPrestacao = double.tryParse(valorPrestacaoTxt ?? '') ?? 0;

  return ResultadoParseCte.sucesso(CteExtraida(
    chaveAcesso: chaveAcesso,
    numeroCte: _tag(xmlTexto, 'nCT', ideBloco) ?? '',
    serieCte: _tag(xmlTexto, 'serie', ideBloco) ?? '',
    cnpjEmitente: cnpjEmitente,
    nomeEmitente: _tag(xmlTexto, 'xNome', emitBloco) ?? '',
    valorPrestacao: valorPrestacao,
    dataEmissao: _tag(xmlTexto, 'dhEmi', ideBloco) ?? '',
    protocoloAutorizacao: _tag(xmlTexto, 'nProt', infProtBloco),
    statusCodigo: statusCodigo,
    motivoStatus: motivoStatus,
  ));
}
