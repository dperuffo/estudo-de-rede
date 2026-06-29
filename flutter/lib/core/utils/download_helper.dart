import 'dart:js' as js;

void downloadBase64File(String base64str, String nome, String mime) {
  js.context.callMethod('downloadBase64', [base64str, nome, mime]);
}
