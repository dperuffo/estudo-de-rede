import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Fase Central-Avisos (28/07/2026) — port do parser "markdown simples" da
// web (src/lib/markdownSimples.tsx): **negrito**, [texto](url), "- " lista,
// "# " título. Mesma filosofia: parser próprio, sem dependência de pacote
// markdown novo, pra ficar 1:1 com o que o admin digita na web.
List<Widget> renderMarkdownSimples(String texto, {TextStyle? baseStyle}) {
  final estiloBase = baseStyle ?? const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4);
  final linhas = texto.split('\n');
  final blocos = <Widget>[];
  var paragrafoAtual = <String>[];
  var listaAtual = <String>[];

  void fecharParagrafo() {
    if (paragrafoAtual.isEmpty) return;
    blocos.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(text: TextSpan(style: estiloBase, children: _inlineComQuebras(paragrafoAtual, estiloBase))),
      ),
    );
    paragrafoAtual = [];
  }

  void fecharLista() {
    if (listaAtual.isEmpty) return;
    blocos.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: listaAtual
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: estiloBase),
                        Expanded(child: RichText(text: TextSpan(style: estiloBase, children: _inline(item, estiloBase)))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
    listaAtual = [];
  }

  for (final linhaRaw in linhas) {
    final linha = linhaRaw.trimRight();
    if (linha.trim().isEmpty) {
      fecharParagrafo();
      fecharLista();
      continue;
    }
    if (linha.startsWith('# ')) {
      fecharParagrafo();
      fecharLista();
      blocos.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(linha.substring(2), style: estiloBase.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
      ));
      continue;
    }
    if (linha.startsWith('- ')) {
      fecharParagrafo();
      listaAtual.add(linha.substring(2));
      continue;
    }
    fecharLista();
    paragrafoAtual.add(linha);
  }
  fecharParagrafo();
  fecharLista();

  return blocos;
}

List<InlineSpan> _inlineComQuebras(List<String> linhas, TextStyle base) {
  final spans = <InlineSpan>[];
  for (var i = 0; i < linhas.length; i++) {
    if (i > 0) spans.add(const TextSpan(text: '\n'));
    spans.addAll(_inline(linhas[i], base));
  }
  return spans;
}

final _regexInline = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((https?://[^\s)]+)\)');

List<InlineSpan> _inline(String linha, TextStyle base) {
  final spans = <InlineSpan>[];
  var ultimoIndice = 0;
  for (final match in _regexInline.allMatches(linha)) {
    if (match.start > ultimoIndice) {
      spans.add(TextSpan(text: linha.substring(ultimoIndice, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (match.group(2) != null && match.group(3) != null) {
      final url = match.group(3)!;
      spans.add(TextSpan(
        text: match.group(2),
        style: const TextStyle(color: Color(0xFF1D4ED8), decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
    }
    ultimoIndice = match.end;
  }
  if (ultimoIndice < linha.length) {
    spans.add(TextSpan(text: linha.substring(ultimoIndice)));
  }
  return spans;
}
