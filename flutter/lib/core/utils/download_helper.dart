import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBase64File(String base64str, String nome, String mime) {
  final bytes = base64Decode(base64str);
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nome)
    ..click();
  html.Url.revokeObjectUrl(url);
}
