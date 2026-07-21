import 'package:flutter/material.dart';
import '../providers/rotograma_provider.dart';

// Fase FLT-3 — porta fiel de LinhaDoTempoRotograma.tsx (SVG na web) usando
// CustomPainter — mesmo cálculo geométrico (origem à esquerda, destino à
// direita, riscos acima da linha, paradas abaixo, posicionados pelo Km via
// resolverLinhaDoTempo).
class LinhaDoTempoRotograma extends StatelessWidget {
  final String origem, destino;
  final List<RotogramaRisco> riscos;
  final List<RotogramaParada> paradas;
  const LinhaDoTempoRotograma({super.key, required this.origem, required this.destino, required this.riscos, required this.paradas});

  @override
  Widget build(BuildContext context) {
    final pontos = resolverLinhaDoTempo(riscos, paradas);
    if (pontos.isEmpty) return const SizedBox.shrink();

    final temEstimado = pontos.any((p) => p.kmEstimado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinhaDoTempoPainter(origem: origem, destino: destino, pontos: pontos),
          ),
        ),
        if (temEstimado)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Pontos com linha tracejada tiveram o Km estimado (não informado nem encontrado no texto do local) — edite '
              'o Rotograma e preencha o campo Km de cada ponto para uma posição exata.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final c in categoriasRisco) _legendaItem(corRisco(c.valor), c.label),
            _legendaItem(corParadaHex, 'Abastecimento / Alimentação / Pernoite / Pedágio'),
          ],
        ),
      ],
    );
  }

  Widget _legendaItem(Color cor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }
}

class _LinhaDoTempoPainter extends CustomPainter {
  final String origem, destino;
  final List<PontoLinhaDoTempo> pontos;
  _LinhaDoTempoPainter({required this.origem, required this.destino, required this.pontos});

  String _truncar(String texto, int max) => texto.length > max ? '${texto.substring(0, max - 1)}…' : texto;

  void _texto(Canvas canvas, String texto, Offset centro, double fontSize, Color cor, {FontWeight peso = FontWeight.normal}) {
    final tp = TextPainter(
      text: TextSpan(text: texto, style: TextStyle(fontSize: fontSize, color: cor, fontWeight: peso)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centro.dx - tp.width / 2, centro.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const largura = 1000.0;
    const altura = 260.0;
    final escala = size.width / largura;
    canvas.save();
    canvas.scale(escala, escala);

    const yLinha = altura / 2;
    const margem = 60.0;
    final kmMaximo = pontos.map((p) => p.km).fold<double>(1, (a, b) => a > b ? a : b);

    double x(double km) {
      final fracao = (km / kmMaximo).clamp(0.0, 1.0);
      return margem + fracao * (largura - margem * 2);
    }

    final linhaBase = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(margem, yLinha), const Offset(largura - margem, yLinha), linhaBase);

    canvas.drawCircle(const Offset(margem, yLinha), 7, Paint()..color = const Color(0xFF16A34A));
    _texto(canvas, 'Origem', const Offset(margem, yLinha + 34), 13, const Color(0xFF166534), peso: FontWeight.w600);
    _texto(canvas, _truncar(origem, 20), const Offset(margem, yLinha + 50), 10, const Color(0xFF64748B));

    canvas.drawCircle(const Offset(largura - margem, yLinha), 7, Paint()..color = const Color(0xFFDC2626));
    _texto(canvas, 'Destino', const Offset(largura - margem, yLinha + 34), 13, const Color(0xFF991B1B), peso: FontWeight.w600);
    _texto(canvas, _truncar(destino, 20), const Offset(largura - margem, yLinha + 50), 10, const Color(0xFF64748B));

    final riscos = pontos.where((p) => p.tipo == 'risco').toList();
    final paradas = pontos.where((p) => p.tipo == 'parada').toList();

    for (var i = 0; i < riscos.length; i++) {
      final p = riscos[i];
      final cx = x(p.km);
      final stemAltura = 46 + (i % 2) * 26;
      final cor = corRisco(p.categoria);
      final paint = Paint()
        ..color = cor
        ..strokeWidth = 1.5;
      if (p.kmEstimado) {
        _linhaTracejada(canvas, Offset(cx, yLinha), Offset(cx, yLinha - stemAltura), paint);
      } else {
        canvas.drawLine(Offset(cx, yLinha), Offset(cx, yLinha - stemAltura), paint);
      }
      canvas.drawCircle(Offset(cx, yLinha - stemAltura), 6, Paint()..color = cor);
      _texto(canvas, _truncar(p.local, 18), Offset(cx, yLinha - stemAltura - 16), 10, const Color(0xFF334155), peso: FontWeight.w600);
      _texto(canvas, '${p.km.round()} km', Offset(cx, yLinha - stemAltura - 28), 9, const Color(0xFF64748B));
    }

    for (var i = 0; i < paradas.length; i++) {
      final p = paradas[i];
      final cx = x(p.km);
      final stemAltura = 46 + (i % 2) * 26;
      final paint = Paint()
        ..color = corParadaHex
        ..strokeWidth = 1.5;
      if (p.kmEstimado) {
        _linhaTracejada(canvas, Offset(cx, yLinha), Offset(cx, yLinha + stemAltura), paint);
      } else {
        canvas.drawLine(Offset(cx, yLinha), Offset(cx, yLinha + stemAltura), paint);
      }
      canvas.drawCircle(Offset(cx, yLinha + stemAltura), 6, Paint()..color = corParadaHex);
      _texto(canvas, _truncar(p.local, 18), Offset(cx, yLinha + stemAltura + 16), 10, const Color(0xFF334155), peso: FontWeight.w600);
      _texto(canvas, '${p.km.round()} km', Offset(cx, yLinha + stemAltura + 28), 9, const Color(0xFF64748B));
    }

    canvas.restore();
  }

  void _linhaTracejada(Canvas canvas, Offset a, Offset b, Paint paint) {
    const tracoLen = 3.0, espacoLen = 3.0;
    final total = (b - a).distance;
    final direcao = (b - a) / total;
    var percorrido = 0.0;
    while (percorrido < total) {
      final fim = (percorrido + tracoLen).clamp(0, total);
      canvas.drawLine(a + direcao * percorrido, a + direcao * fim.toDouble(), paint);
      percorrido += tracoLen + espacoLen;
    }
  }

  @override
  bool shouldRepaint(covariant _LinhaDoTempoPainter oldDelegate) =>
      oldDelegate.origem != origem || oldDelegate.destino != destino || oldDelegate.pontos != pontos;
}
