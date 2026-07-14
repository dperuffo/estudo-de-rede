import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Helpers e widgets pequenos reaproveitados pelas 10 abas de Inteligência
// de Rede — mesmo papel que os vários `formatarMoeda`/`MiniKpi`/
// `BarraHorizontal` duplicados em cada _components/*.tsx da web, só que
// centralizados aqui uma vez.

final _moeda3 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 3);
final _moeda2 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
final _inteiro = NumberFormat.decimalPattern('pt_BR');

String formatarMoeda(double v, {int casas = 3}) => casas == 2 ? _moeda2.format(v) : _moeda3.format(v);
String formatarInt(num v) => _inteiro.format(v);

String truncarTexto(String texto, int tamanho) => texto.length > tamanho ? '${texto.substring(0, tamanho)}…' : texto;

double media(List<double> valores) => valores.isEmpty ? 0 : valores.reduce((a, b) => a + b) / valores.length;

double desvioPadraoAmostral(List<double> valores) {
  if (valores.length < 2) return 0;
  final m = media(valores);
  final somaQuad = valores.fold<double>(0, (s, v) => s + (v - m) * (v - m));
  return _sqrt(somaQuad / (valores.length - 1));
}

double _sqrt(double v) {
  if (v <= 0) return 0;
  double x = v;
  double y = 1;
  const eps = 1e-10;
  while (x - y > eps) {
    x = (x + y) / 2;
    y = v / x;
  }
  return x;
}

double quantil(List<double> valores, double q) {
  if (valores.isEmpty) return 0;
  final sorted = [...valores]..sort();
  final pos = (sorted.length - 1) * q;
  final base = pos.floor();
  final resto = pos - base;
  if (base + 1 < sorted.length) return sorted[base] + resto * (sorted[base + 1] - sorted[base]);
  return sorted[base];
}

// Cartão de indicador — visão geral (KPIs grandes no topo da tela) e mini
// versão usada dentro das abas.
class CartaoIndicador extends StatelessWidget {
  final String label;
  final String valor;
  final String? sub;
  final bool mini;
  const CartaoIndicador({super.key, required this.label, required this.valor, this.sub, this.mini = false});

  @override
  Widget build(BuildContext context) {
    // Achado real (reportado pelo Daniel com print): com 4 cartões por
    // linha (cabeçalho de KPIs) e textos como "Diesel Médio GF" / "R$
    // 6.926", o card ficava estreito demais e o conteúdo vazava pra fora
    // da borda arredondada — Card não corta conteúdo por padrão. Corrigido
    // com FittedBox no valor (nunca estoura, só encolhe a fonte se
    // precisar) e maxLines/ellipsis no rótulo e no complemento.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: TextStyle(fontSize: mini ? 16 : 20, fontWeight: FontWeight.w700)),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

// Barra horizontal simples (div-based na web) — usada em vários rankings
// (top desvios, top distribuidoras, clusters etc.) onde um BarChart do
// fl_chart ficaria pesado demais pra uma lista longa e rolável.
class BarraHorizontalItem {
  final String label;
  final double valor;
  final Color cor;
  final String texto;
  const BarraHorizontalItem({required this.label, required this.valor, required this.cor, required this.texto});
}

class BarraHorizontal extends StatelessWidget {
  final List<BarraHorizontalItem> dados;
  final String? eixoX;
  const BarraHorizontal({super.key, required this.dados, this.eixoX});

  @override
  Widget build(BuildContext context) {
    final maxValor = dados.fold<double>(1e-9, (m, d) => d.valor > m ? d.valor : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dados.map((d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(d.label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (d.valor / maxValor).clamp(0.02, 1.0),
                        child: Container(decoration: BoxDecoration(color: d.cor, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 62,
                    child: Text(d.texto, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ),
                ],
              ),
            )),
        if (eixoX != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(eixoX!.toUpperCase(), textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
          ),
      ],
    );
  }
}

// Bloco de "insight" textual (fundo azul claro) — usado nas abas Tendência
// & Sazonalidade e Cobertura x Demanda.
class BlocoInsight extends StatelessWidget {
  final String texto;
  final Color? corFundo;
  const BlocoInsight({super.key, required this.texto, this.corFundo});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: corFundo ?? const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: const TextStyle(fontSize: 13, height: 1.35)),
    );
  }
}

// Tabela simples baseada em Card/ListView (em vez de <table>, que não
// funciona bem em telas estreitas) — cabeçalho fixo + linhas roláveis.
class TabelaSimples extends StatelessWidget {
  final List<String> colunas;
  final List<List<String>> linhas;
  final List<int>? flexColunas;
  final double? maxHeight;
  const TabelaSimples({super.key, required this.colunas, required this.linhas, this.flexColunas, this.maxHeight});

  @override
  Widget build(BuildContext context) {
    final flex = flexColunas ?? List.filled(colunas.length, 1);
    Widget linha(List<String> valores, {bool cabecalho = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(colunas.length, (i) {
            return Expanded(
              flex: flex[i],
              child: Text(
                valores[i],
                style: cabecalho
                    ? TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)
                    : const TextStyle(fontSize: 12),
              ),
            );
          }),
        ),
      );
    }

    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        linha(colunas, cabecalho: true),
        const Divider(height: 1),
        ...linhas.expand((l) => [linha(l), const Divider(height: 1, color: Color(0xFFF1F5F9))]),
      ],
    );

    final scrollable = SingleChildScrollView(child: conteudo);
    if (maxHeight != null) {
      return SizedBox(height: maxHeight, child: scrollable);
    }
    return scrollable;
  }
}

class SeletorChips<T> extends StatelessWidget {
  final List<T> opcoes;
  final T selecionado;
  final String Function(T) rotulo;
  final ValueChanged<T> onSelecionar;
  const SeletorChips({super.key, required this.opcoes, required this.selecionado, required this.rotulo, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opcoes.map((o) {
        final sel = o == selecionado;
        return ChoiceChip(
          label: Text(rotulo(o), style: const TextStyle(fontSize: 12)),
          selected: sel,
          onSelected: (_) => onSelecionar(o),
        );
      }).toList(),
    );
  }
}
