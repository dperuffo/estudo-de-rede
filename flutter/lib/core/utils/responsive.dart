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
}
