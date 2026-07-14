// Fase FLT-3 — porta fiel de src/lib/roteirizacaoAlgoritmo.ts
// (otimizarAbastecimento — algoritmo guloso com "olhar à frente" que
// decide ONDE parar pra abastecer e QUANTOS litros colocar, dado um
// conjunto de postos candidatos ao longo de uma rota).

class CandidatoAbastecimento {
  final String cnpj;
  final double km;
  final double desvioKm;
  final double preco;
  final String? grade; // A | B | C | D
  final String label;
  final double lat;
  final double lon;
  final String? bandeira;
  final String? uf;
  final String origem; // proprio | anp

  const CandidatoAbastecimento({
    required this.cnpj,
    required this.km,
    required this.desvioKm,
    required this.preco,
    this.grade,
    required this.label,
    required this.lat,
    required this.lon,
    this.bandeira,
    this.uf,
    required this.origem,
  });
}

class ParadaSugerida {
  final CandidatoAbastecimento candidato;
  final String motivo; // otimizado | estrategico | emergencia
  final double fuelChegadaL;
  final double pctChegada;
  final double litrosSugeridos;
  final double custoAbastecimento;
  final double fuelAposL;
  final double pctApos;
  final double metricaValor;

  const ParadaSugerida({
    required this.candidato,
    required this.motivo,
    required this.fuelChegadaL,
    required this.pctChegada,
    required this.litrosSugeridos,
    required this.custoAbastecimento,
    required this.fuelAposL,
    required this.pctApos,
    required this.metricaValor,
  });
}

class PesosOtimizacao {
  final double preco;
  final double score;
  final double desvio;
  const PesosOtimizacao({required this.preco, required this.score, required this.desvio});
}

class PerfilPeso {
  final String chave;
  final String nome;
  final String icone;
  final PesosOtimizacao pesos;
  final String fillMode; // normal | minimo
  final String descricao;
  const PerfilPeso({
    required this.chave,
    required this.nome,
    required this.icone,
    required this.pesos,
    required this.fillMode,
    required this.descricao,
  });
}

// Porta de PERFIS_PESO (src/lib/roteirizacaoScore.ts).
const perfisPeso = [
  PerfilPeso(
    chave: 'economia',
    nome: 'Economia',
    icone: '💰',
    pesos: PesosOtimizacao(preco: 0.8, score: 0.1, desvio: 0.1),
    fillMode: 'normal',
    descricao: 'Minimiza custo total — prioriza sempre o posto mais barato.',
  ),
  PerfilPeso(
    chave: 'equilibrio',
    nome: 'Equilíbrio',
    icone: '⚖️',
    pesos: PesosOtimizacao(preco: 0.5, score: 0.3, desvio: 0.2),
    fillMode: 'normal',
    descricao: 'Pondera preço, qualidade do posto (score A-D) e distância da rota.',
  ),
  PerfilPeso(
    chave: 'qualidade',
    nome: 'Qualidade',
    icone: '⭐',
    pesos: PesosOtimizacao(preco: 0.3, score: 0.5, desvio: 0.2),
    fillMode: 'normal',
    descricao: 'Prioriza postos com score A e B — pode custar um pouco mais.',
  ),
  PerfilPeso(
    chave: 'minimas_paradas',
    nome: 'Mínimas Paradas',
    icone: '🛑',
    pesos: PesosOtimizacao(preco: 0.8, score: 0.1, desvio: 0.1),
    fillMode: 'minimo',
    descricao: 'Para o mínimo de vezes — abastece só o necessário a cada parada.',
  ),
];

const _gradePeso = {'A': 1.0, 'B': 0.75, 'C': 0.5, 'D': 0.25};
const _nivelMinimoPct = 0.25;
const _pctBaixo = 0.65;
const _vantagemPrecoMinima = 0.03;
const _vantagemMetricaMinima = 1.05;
const _litrosMinimos = 5;

List<ParadaSugerida> otimizarAbastecimento({
  required List<CandidatoAbastecimento> candidatos,
  required double capacidadeTanqueL,
  required double autonomiaKmPorL,
  required double distanciaTotalRotaKm,
  required PesosOtimizacao pesos,
  String fillMode = 'normal',
  double? combustivelInicialL,
  int maxParadas = 30,
}) {
  final rcap = capacidadeTanqueL;
  final raut = autonomiaKmPorL;
  final rd = distanciaTotalRotaKm;

  if (candidatos.isEmpty || raut <= 0 || rcap <= 0) return [];

  final rmin = rcap * _nivelMinimoPct;
  final alcanceEfetivoKm = (rcap - rmin) * raut;

  final precos = candidatos.map((c) => c.preco).where((p) => p.isFinite).toList();
  final pmin = precos.isEmpty ? 0.0 : precos.reduce((a, b) => a < b ? a : b);
  final pmax = precos.isEmpty ? 1.0 : precos.reduce((a, b) => a > b ? a : b);

  double metrica(CandidatoAbastecimento c) {
    final p = 1 - (c.preco - pmin) / (pmax - pmin > 0.01 ? (pmax - pmin) : 0.01);
    final g = _gradePeso[c.grade ?? 'D'] ?? 0.25;
    final d = 1 - (c.desvioKm / 5).clamp(0, 1);
    return pesos.preco * p + pesos.score * g + pesos.desvio * d;
  }

  final paradas = <ParadaSugerida>[];
  var pos = 0.0;
  var fuel = combustivelInicialL ?? rcap;
  final vistos = <String>{};
  double? ultimoPreco;

  for (var iter = 0; iter < maxParadas; iter++) {
    if (pos >= rd) break;

    final podeIr = (fuel - rmin) * raut;
    final alcancaSem = pos + podeIr;
    if (alcancaSem >= rd) break;

    final janela = candidatos.where((c) => pos < c.km && c.km <= alcancaSem && !vistos.contains(c.cnpj)).toList();
    final janelaEstendida = candidatos
        .where((c) => alcancaSem < c.km && c.km <= pos + alcanceEfetivoKm * 1.85 && !vistos.contains(c.cnpj))
        .toList();

    CandidatoAbastecimento best;
    String motivo;
    double? fillAlvoKm;

    if (janela.isEmpty) {
      final alemDoAlcance = candidatos.where((c) => c.km > pos && !vistos.contains(c.cnpj)).toList()
        ..sort((a, b) => a.km.compareTo(b.km));
      if (alemDoAlcance.isEmpty) break;
      best = alemDoAlcance.first;
      motivo = 'emergencia';
    } else {
      final bestObrigatorio = janela.reduce((m, c) => metrica(c) > metrica(m) ? c : m);
      if (janelaEstendida.isNotEmpty) {
        final bestEstendido = janelaEstendida.reduce((m, c) => metrica(c) > metrica(m) ? c : m);
        if (metrica(bestEstendido) > metrica(bestObrigatorio) * _vantagemMetricaMinima &&
            bestEstendido.preco < bestObrigatorio.preco * (1 - _vantagemPrecoMinima)) {
          fillAlvoKm = bestEstendido.km;
        }
      }
      best = bestObrigatorio;
      motivo = fillAlvoKm != null ? 'estrategico' : 'otimizado';
    }

    final kmAte = best.km - pos;
    final fuelChegada = (fuel - kmAte / raut).clamp(0, double.infinity).toDouble();
    final pctChegada = fuelChegada / rcap * 100;

    if (motivo != 'emergencia' &&
        pctChegada >= _pctBaixo * 100 &&
        ultimoPreco != null &&
        best.preco >= ultimoPreco * (1 - _vantagemPrecoMinima) &&
        fillAlvoKm == null) {
      pos = best.km;
      fuel = fuelChegada;
      vistos.add(best.cnpj);
      continue;
    }

    final distRestante = rd - best.km;
    double litrosNecessarios;

    if (fillMode == 'minimo') {
      final restantes = candidatos.where((c) => c.km > best.km && !vistos.contains(c.cnpj)).toList()
        ..sort((a, b) => a.km.compareTo(b.km));
      if (restantes.isNotEmpty) {
        final distProx = restantes.first.km - best.km;
        litrosNecessarios = (distProx / raut) * 1.1 + rmin - fuelChegada;
      } else {
        litrosNecessarios = (distRestante / raut) * 1.15 + rmin - fuelChegada;
      }
    } else if (fillAlvoKm != null) {
      final distAlvo = fillAlvoKm - best.km;
      litrosNecessarios = (distAlvo / raut) * 1.1 + rmin - fuelChegada;
    } else if (distRestante <= alcanceEfetivoKm) {
      litrosNecessarios = (distRestante / raut) * 1.15 + rmin - fuelChegada;
    } else {
      litrosNecessarios = rcap - fuelChegada;
    }

    var litrosFill = litrosNecessarios < 0 ? 0.0 : litrosNecessarios;
    litrosFill = litrosFill > (rcap - fuelChegada) ? (rcap - fuelChegada) : litrosFill;
    litrosFill = litrosFill.ceilToDouble();

    if (litrosFill < _litrosMinimos) {
      pos = best.km;
      fuel = fuelChegada;
      vistos.add(best.cnpj);
      continue;
    }

    final fuelApos = (fuelChegada + litrosFill).clamp(0, rcap).toDouble();
    final pctApos = fuelApos / rcap * 100;
    final custoAbastecimento = ((litrosFill * best.preco) * 100).round() / 100;

    paradas.add(ParadaSugerida(
      candidato: best,
      motivo: motivo,
      fuelChegadaL: (fuelChegada * 10).round() / 10,
      pctChegada: (pctChegada * 10).round() / 10,
      litrosSugeridos: litrosFill,
      custoAbastecimento: custoAbastecimento,
      fuelAposL: (fuelApos * 10).round() / 10,
      pctApos: (pctApos * 10).round() / 10,
      metricaValor: (metrica(best) * 1000).round() / 1000,
    ));

    vistos.add(best.cnpj);
    ultimoPreco = best.preco;
    fuel = fuelApos;
    pos = best.km;
  }

  return paradas;
}
