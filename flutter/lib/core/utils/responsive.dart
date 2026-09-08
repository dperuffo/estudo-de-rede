import 'package:flutter/material.dart';

/// Fase Auditoria-UX-Responsividade (08/09/2026, pedido do Daniel: auditoria
/// UX apontou que os PWAs Flutter praticamente não se adaptavam a telas
/// maiores — só ~9% das ~172 telas deste app usavam MediaQuery/LayoutBuilder).
/// Breakpoints alinhados de propósito com o `lg:` (1024px) do Tailwind usado
/// no painel web (tailwind.config.ts não tem override de `screens`), pra
/// manter a mesma noção de "desktop" nos dois lados da aplicação.
class Responsive {
  Responsive._();

  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 1024;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointDesktop;

  /// Largura máxima confortável de leitura/conteúdo pra telas muito largas —
  /// evita listas/formulários esticando de ponta a ponta num monitor grande
  /// (mesmo problema que o menu retrátil resolveu no painel web, aqui pro
  /// conteúdo em si). Sem efeito em telas menores que o valor (o
  /// ConstrainedBox só limita, nunca força a largura mínima).
  static const double larguraMaximaConteudo = 1400;

  /// Envolve o conteúdo do shell com o limite de largura acima, centralizado,
  /// só quando a tela é larga o bastante pra fazer diferença — em telas
  /// estreitas (celular) devolve o filho sem nenhuma modificação.
  static Widget conteudoCentralizado(BuildContext context, Widget child) {
    if (!isDesktop(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: larguraMaximaConteudo),
        child: child,
      ),
    );
  }

  /// Largura máxima pra formulários de 1 coluna só (ex.: Novo Veículo, Novo
  /// Motorista) — bem mais estreita que [larguraMaximaConteudo]: um campo de
  /// texto esticado até 1400px fica difícil de usar/ler, então formulários
  /// usam o próprio limite, mais parecido com a largura de uma folha.
  static const double larguraMaximaFormulario = 720;

  /// Mesma ideia de [conteudoCentralizado], só que com o limite de largura
  /// acima — pensado pro `body` de telas de cadastro/edição (Form + ListView
  /// de campos empilhados).
  static Widget formularioCentralizado(BuildContext context, Widget child) {
    if (!isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: larguraMaximaFormulario),
        child: child,
      ),
    );
  }

  /// Nº de colunas pra uma grade de indicadores/KPIs conforme a largura —
  /// pensado pra `GridView.count(crossAxisCount: ...)` já existentes no app,
  /// que hoje ficam com o mesmo nº de colunas fixo em qualquer tela (cartões
  /// enormes e vazios num monitor largo). Só troca o número de colunas — o
  /// `childAspectRatio`/conteúdo de cada card continua exatamente igual.
  static int colunasGrade(
    BuildContext context, {
    required int mobile,
    int? tablet,
    required int desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }

  /// Transforma uma lista de cards de altura variável (ex.: 1 Card por
  /// veículo/motorista, hoje empilhados numa ListView) numa grade que se
  /// adapta à largura disponível: em celular continua exatamente a mesma
  /// lista vertical de sempre (1 coluna); a partir de [breakpointTablet]
  /// passa a lado a lado, quantas colunas couberem. Cada item mantém o
  /// próprio conteúdo/altura intactos — só a disposição ao redor muda, por
  /// isso funciona com qualquer Card já existente sem precisar reescrevê-lo.
  static Widget grade(
    BuildContext context, {
    required List<Widget> itens,
    double larguraMinimaCartao = 340,
    double espacamento = 12,
  }) {
    if (!isTablet(context)) {
      return Column(children: itens);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final colunas = (constraints.maxWidth / (larguraMinimaCartao + espacamento))
          .floor()
          .clamp(1, 4);
      if (colunas <= 1) return Column(children: itens);
      final larguraCartao =
          (constraints.maxWidth - espacamento * (colunas - 1)) / colunas;
      return Wrap(
        spacing: espacamento,
        runSpacing: espacamento,
        children:
            itens.map((w) => SizedBox(width: larguraCartao, child: w)).toList(),
      );
    });
  }
}
