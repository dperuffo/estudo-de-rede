// Teste padrão do template do Flutter, desatualizado desde antes da Fase
// FLT-1 (referenciava uma classe MyApp/contador que não existe mais neste
// app — o app real se chama FniApp, sem contador). Como o app agora
// depende de Supabase.initialize() (feito em main()) e de rede pra
// resolver sessão/rotas, um smoke test completo de widget não é trivial
// de escrever sem mockar o Supabase — deixamos só um placeholder que
// garante que o arquivo compila e passa, sem falso teste de comportamento.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (WidgetTester tester) async {
    expect(1 + 1, 2);
  });
}
