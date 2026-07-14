import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart' show Veiculo, veiculosClienteProvider;
import '../providers/roteirizacao_provider.dart';
import '../services/geo_service.dart' as geo;
import '../services/roteirizacao_algoritmo.dart';
import 'mapa_postos.dart';

// Fase FLT-3 — Roteirização (cliente): 3 modos ("Por UF/Município",
// "Consulta por Posto" e "Roteirizador Inteligente") num só toggle, em vez
// de abas separadas — ver escopo completo em roteirizacao_provider.dart.
// Mapa interativo (flutter_map + tiles OSM, ver mapa_postos.dart) plotado
// nos 3 modos.
class RoteirizacaoScreen extends ConsumerStatefulWidget {
  const RoteirizacaoScreen({super.key});

  @override
  ConsumerState<RoteirizacaoScreen> createState() => _RoteirizacaoScreenState();
}

class _RoteirizacaoScreenState extends ConsumerState<RoteirizacaoScreen> {
  String _modo = 'uf';
  String? _uf;
  final _municipioCtrl = TextEditingController();
  final _termoCtrl = TextEditingController();

  bool _buscando = false;
  String? _erro;
  List<PostoComScore>? _resultado;

  // ── Modo "Roteirizador Inteligente" ──────────────────────────────────
  final _origemCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  geo.SugestaoGeocoding? _origemSel;
  geo.SugestaoGeocoding? _destinoSel;
  List<geo.SugestaoGeocoding> _sugestoesOrigem = [];
  List<geo.SugestaoGeocoding> _sugestoesDestino = [];
  Veiculo? _veiculo;
  List<String> _opcoesCombustivel = produtosPosto;
  String? _combustivelEscolhido;
  String? _avisoCombustivel;
  String _perfilChave = perfisPeso.first.chave;
  ResultadoRoteirizacaoInteligente? _resultadoPlanejar;

  // Porta de onVeiculoSelecionado (FormRoteirizacao.tsx) — o campo
  // `combustivel` do veículo guarda o tipo de motor ("Diesel S10",
  // "Flex" etc.), não o produto vendido no posto. Resolve pra lista de
  // produtos compatíveis via produtosPorTipoVeiculo; se o veículo for Flex
  // (mais de 1 produto compatível), pede pro usuário escolher.
  void _onVeiculoSelecionado(Veiculo? v) {
    setState(() {
      _veiculo = v;
      if (v == null) {
        _opcoesCombustivel = produtosPosto;
        _combustivelEscolhido = null;
        _avisoCombustivel = null;
        return;
      }
      final chave = (v.combustivel ?? '').trim().toLowerCase();
      final compativeis = produtosPorTipoVeiculo[chave];
      if (compativeis != null && compativeis.length == 1) {
        _opcoesCombustivel = compativeis;
        _combustivelEscolhido = compativeis.first;
        _avisoCombustivel = null;
      } else if (compativeis != null && compativeis.length > 1) {
        _opcoesCombustivel = compativeis;
        _combustivelEscolhido = null;
        _avisoCombustivel = 'Veículo ${v.combustivel} — escolha o combustível desta viagem.';
      } else {
        _opcoesCombustivel = produtosPosto;
        _combustivelEscolhido = null;
        _avisoCombustivel =
            v.combustivel != null ? 'Não reconheço "${v.combustivel}" — escolha o combustível manualmente.' : null;
      }
    });
  }

  @override
  void dispose() {
    _municipioCtrl.dispose();
    _termoCtrl.dispose();
    _origemCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarSugestoes(String texto, bool origem) async {
    final sugestoes = await geo.geocodificar(texto);
    if (!mounted) return;
    setState(() {
      if (origem) {
        _sugestoesOrigem = sugestoes;
      } else {
        _sugestoesDestino = sugestoes;
      }
    });
  }

  Future<void> _planejar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }
    if (_origemSel == null || _destinoSel == null) {
      setState(() => _erro = 'Escolha origem e destino nas sugestões de busca.');
      return;
    }
    if (_veiculo == null || _veiculo!.tanque == null || _veiculo!.autonomia == null) {
      setState(() => _erro = 'Escolha um veículo com tanque e autonomia cadastrados.');
      return;
    }
    if (_combustivelEscolhido == null || _combustivelEscolhido!.isEmpty) {
      setState(() => _erro = 'Escolha o combustível desta viagem.');
      return;
    }

    setState(() {
      _buscando = true;
      _erro = null;
      _resultadoPlanejar = null;
    });

    try {
      final perfil = perfisPeso.firstWhere((p) => p.chave == _perfilChave);
      final resultado = await RoteirizacaoService().calcularRoteirizacao(
        empresaId: empresaId,
        origem: geo.Ponto(_origemSel!.lat, _origemSel!.lon),
        destino: geo.Ponto(_destinoSel!.lat, _destinoSel!.lon),
        capacidadeTanqueL: _veiculo!.tanque!,
        autonomiaKmPorL: _veiculo!.autonomia!,
        combustivel: _combustivelEscolhido!,
        perfil: perfil,
      );
      if (!mounted) return;
      setState(() {
        _resultadoPlanejar = resultado;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível calcular a rota: $e';
        _buscando = false;
      });
    }
  }

  Future<void> _buscar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }
    if (_modo == 'uf' && (_uf == null || _uf!.isEmpty)) {
      setState(() => _erro = 'Escolha uma UF para começar.');
      return;
    }
    if (_modo == 'posto' && _termoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Digite um CNPJ ou parte do nome do posto.');
      return;
    }

    setState(() {
      _buscando = true;
      _erro = null;
    });

    try {
      final lista = _modo == 'uf'
          ? await RoteirizacaoService().buscarPostosPorUf(
              empresaId: empresaId,
              uf: _uf,
              municipio: _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
            )
          : await RoteirizacaoService().buscarPostoPorTermo(empresaId: empresaId, termo: _termoCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _resultado = lista;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível buscar: $e';
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roteirização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Consulte a rede de postos por UF/Município, busque um posto específico ou monte um roteiro '
            'inteligente com paradas de abastecimento otimizadas — mistura os postos próprios cadastrados '
            'com a base pública de preços ANP.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'uf', label: Text('Por UF/Município')),
              ButtonSegment(value: 'posto', label: Text('Consulta por Posto')),
              ButtonSegment(value: 'planejar', label: Text('Roteirizador Inteligente')),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() {
              _modo = s.first;
              _resultado = null;
              _resultadoPlanejar = null;
              _erro = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_modo == 'uf')
            ..._formUf()
          else if (_modo == 'posto')
            ..._formPosto()
          else
            ..._formPlanejar(),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          if (_buscando) const Center(child: CircularProgressIndicator()),
          if (!_buscando && _modo != 'planejar' && _resultado != null) ..._resultados(),
          if (!_buscando && _modo == 'planejar' && _resultadoPlanejar != null) ..._resultadosPlanejar(),
        ],
      ),
    );
  }

  List<Widget> _formUf() {
    return [
      Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _uf,
              decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione...')),
                for (final uf in ufsRoteirizacao) DropdownMenuItem(value: uf, child: Text(uf)),
              ],
              onChanged: (v) => setState(() => _uf = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _municipioCtrl,
              decoration:
                  const InputDecoration(labelText: 'Município (opcional)', border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _buscando ? null : _buscar, child: const Text('Buscar')),
      ),
    ];
  }

  List<Widget> _formPosto() {
    return [
      TextField(
        controller: _termoCtrl,
        decoration: const InputDecoration(
          labelText: 'CNPJ ou nome do posto',
          hintText: 'Ex.: 12.345.678/0001-99 ou Posto Ipiranga',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _buscar(),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _buscando ? null : _buscar, child: const Text('Buscar')),
      ),
    ];
  }

  List<Widget> _resultados() {
    final lista = _resultado!;
    if (lista.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nenhum posto encontrado.', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      ];
    }
    return [
      MapaPostos(postos: lista),
      const SizedBox(height: 12),
      Text('Postos (${lista.length})', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      ...lista.map(_cardPosto),
    ];
  }

  Widget _campoBusca({
    required TextEditingController controller,
    required String label,
    required List<geo.SugestaoGeocoding> sugestoes,
    required void Function(String) onChanged,
    required void Function(geo.SugestaoGeocoding) onSelecionado,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          onChanged: onChanged,
        ),
        if (sugestoes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sugestoes
                  .map((s) => ListTile(
                        dense: true,
                        title: Text(s.label, style: const TextStyle(fontSize: 13)),
                        onTap: () => onSelecionado(s),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  List<Widget> _formPlanejar() {
    final veiculosAsync = ref.watch(veiculosClienteProvider);
    return [
      _campoBusca(
        controller: _origemCtrl,
        label: 'Origem',
        sugestoes: _sugestoesOrigem,
        onChanged: (t) {
          _origemSel = null;
          _buscarSugestoes(t, true);
        },
        onSelecionado: (s) => setState(() {
          _origemSel = s;
          _origemCtrl.text = s.label;
          _sugestoesOrigem = [];
        }),
      ),
      const SizedBox(height: 10),
      _campoBusca(
        controller: _destinoCtrl,
        label: 'Destino',
        sugestoes: _sugestoesDestino,
        onChanged: (t) {
          _destinoSel = null;
          _buscarSugestoes(t, false);
        },
        onSelecionado: (s) => setState(() {
          _destinoSel = s;
          _destinoCtrl.text = s.label;
          _sugestoesDestino = [];
        }),
      ),
      const SizedBox(height: 10),
      veiculosAsync.when(
        data: (veiculos) => DropdownButtonFormField<Veiculo>(
          value: _veiculo,
          decoration: const InputDecoration(labelText: 'Veículo', border: OutlineInputBorder(), isDense: true),
          items: veiculos
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                        '${v.placa}${v.combustivel != null ? ' · ${v.combustivel}' : ''}${v.tanque != null ? ' · ${v.tanque!.toStringAsFixed(0)}L' : ''}'),
                  ))
              .toList(),
          onChanged: _onVeiculoSelecionado,
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Erro ao carregar veículos: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _combustivelEscolhido,
        decoration: const InputDecoration(labelText: 'Combustível desta viagem', border: OutlineInputBorder(), isDense: true),
        items: [
          const DropdownMenuItem(value: null, child: Text('Selecione...')),
          for (final c in _opcoesCombustivel) DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() => _combustivelEscolhido = v),
      ),
      if (_avisoCombustivel != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_avisoCombustivel!, style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
        ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _perfilChave,
        decoration: const InputDecoration(labelText: 'Perfil de otimização', border: OutlineInputBorder(), isDense: true),
        items: perfisPeso
            .map((p) => DropdownMenuItem(value: p.chave, child: Text('${p.icone} ${p.nome}')))
            .toList(),
        onChanged: (v) => setState(() => _perfilChave = v ?? _perfilChave),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          perfisPeso.firstWhere((p) => p.chave == _perfilChave).descricao,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _buscando ? null : _planejar, child: const Text('Calcular roteiro')),
      ),
    ];
  }

  List<Widget> _resultadosPlanejar() {
    final r = _resultadoPlanejar!;
    // Plota só as paradas sugeridas no mapa (não os milhares de candidatos
    // do corredor inteiro — poluiria demais e pesaria no navegador).
    final postosParaMapa = r.paradas
        .map((p) => PostoComScore(
              cnpj: p.candidato.cnpj,
              razaoSocial: p.candidato.label,
              municipio: null,
              uf: p.candidato.uf,
              bandeira: p.candidato.bandeira,
              lat: p.candidato.lat,
              lon: p.candidato.lon,
              precos: [PrecoPosto(combustivel: _combustivelEscolhido ?? '', preco: p.candidato.preco)],
              score: ScorePosto(
                score: 0,
                grade: p.candidato.grade ?? 'D',
                detalhePreco: '',
                detalheServicos: '',
                detalheDistancia: '',
              ),
              origem: p.candidato.origem,
            ))
        .toList();

    return [
      if (r.linhaReta)
        Card(
          color: Colors.amber.shade50,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Não foi possível calcular a rota real pelos servidores OSRM públicos — usando estimativa em linha reta.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      if (r.candidatosEncontrados == 0)
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'Nenhum posto da rede — nem da base pública ANP — tem preço registrado para "${_combustivelEscolhido ?? ''}" '
              'dentro do corredor de 5 km da rota.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      MapaPostos(postos: postosParaMapa, rota: r.coordenadas, paradas: r.paradas, height: 320),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _resumoItem('Distância', '${r.distanciaKm.toStringAsFixed(0)} km'),
              _resumoItem('Duração', '${(r.duracaoMin / 60).toStringAsFixed(1)} h'),
              _resumoItem('Paradas', '${r.paradas.length}'),
              _resumoItem('Custo total', 'R\$ ${r.custoTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('Paradas sugeridas (${r.paradas.length})', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (r.paradas.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nenhuma parada necessária para esse trajeto com o tanque atual.',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        )
      else
        ...r.paradas.map(_cardParada),
    ];
  }

  Widget _resumoItem(String label, String valor) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _cardParada(ParadaSugerida p) {
    final coresMotivo = {
      'otimizado': const Color(0xFF10B981),
      'estrategico': const Color(0xFF0EA5E9),
      'emergencia': const Color(0xFFDC2626),
    };
    final cor = coresMotivo[p.motivo] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(p.motivo, style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.candidato.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                Text('km ${p.candidato.km.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${p.litrosSugeridos.toStringAsFixed(0)} L · R\$ ${p.candidato.preco.toStringAsFixed(3)}/L · custo R\$ ${p.custoAbastecimento.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Chegada: ${p.pctChegada.toStringAsFixed(0)}% tanque · Saída: ${p.pctApos.toStringAsFixed(0)}% tanque',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPosto(PostoComScore p) {
    final coresGrade = {
      'A': const Color(0xFF10B981),
      'B': const Color(0xFF0EA5E9),
      'C': const Color(0xFFD97706),
      'D': const Color(0xFFDC2626),
    };
    final cor = coresGrade[p.score.grade] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text('${p.score.grade} ${p.score.score.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.razaoSocial ?? p.cnpj,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (p.origem == 'anp' ? const Color(0xFF0284C7) : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.origem == 'anp' ? 'Base ANP' : 'Próprio',
                      style: TextStyle(
                          fontSize: 10,
                          color: p.origem == 'anp' ? const Color(0xFF0284C7) : Colors.grey.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.municipio ?? '—'} - ${p.uf ?? '—'}${p.bandeira != null ? ' · ${p.bandeira}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (p.precos.isEmpty)
              Text('Sem preço registrado', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.precos
                    .map((preco) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                          child: Text('${preco.combustivel} R\$ ${preco.preco.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
