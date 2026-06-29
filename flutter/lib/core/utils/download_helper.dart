@JS()
library download_helper;

import 'dart:js_interop';

@JS('downloadBase64')
external void _downloadBase64JS(String base64, String filename, String mime);

void downloadBase64File(String base64str, String nome, String mime) {
  _downloadBase64JS(base64str, nome, mime);
}
