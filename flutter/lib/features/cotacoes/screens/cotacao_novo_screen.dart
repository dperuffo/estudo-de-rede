import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../roteirizacao/services/geo_service.dart';
import '../providers/cotacoes_provider.dart';
import '../services/cotacoes_service.dart';

// Fase FLT-Cotações (02/09/2026) — porta de cotacoes/novo/page.tsx +
// CotacaoForm.tsx. Sem cálculo automático de distância (OSRM) — km_estimado
// é digitado manualmente, igual à web (só usado no alerta de piso ANTT).
// Geocodificação reaproveita geo_service.dart (mesmo Nominatim da web),
// já usado em /fretes/novo.
class CotacaoNovoScreen extends ConsumerStatefulWidget {
  const CotacaoNovoScreen({super.key});

  @override
  ConsumerState<CotacaoNovoScreen> createState() => _CotacaoNovoScreenState();
}

class _CotacaoNovoScreenState extends ConsumerState<CotacaoNovoScreen> {
  final _service = CotacoesService();
  String? _tabelaFreteId;
  SugestaoGeocoding? _origem;
  SugestaoGeocoding? _destino;
  final _kmCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _valorCargaCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  String? _tipoCarga;
  int? _numeroEixos;
  List<String> _tiposCarga = [];
  List<int> _eixosDisponiveis = [];
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarTiposCarga();
  }

  Future<void> _carregarTiposCarga() async {
    final tipos = await _service.buscarTiposCarga();
    if (mounted) setState(() => _tiposCarga = tipos);
  }

  Future<void> _selecionarTipoCarga(String? tipo) async {
    setState(() {
      _tipoCarga = tipo;
      _numeroEixos = null;
      _eixosDisponiveis = [];
    });
    if (tipo == null) return;
    final eixos = await _service.buscarEixosPorTipo(tipo);
    if (mounted) setState(() => _eixosDisponiveis = eixos);
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _pesoCtrl.dispose();
    _valorCargaCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _simular() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    if (_tabelaFreteId == null) {
      setState(() => _erro = 'Selecione uma tabela de frete.');
      return;
    }
    if (_origem == null || _destino == null) {
      setState(() => _erro = 'Informe origem e destino.');
      return;
    }
    final peso = double.tryParse(_pesoCtrl.text.trim().replaceAll(',', '.'));
    if (peso == null || peso <= 0) {
      setState(() => _erro = 'Informe um peso válido.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final resultado = await _service.criarCotacao(
      empresaId: empresaId,
      tabelaFreteId: _tabelaFreteId!,
      origemLabel: _origem!.label,
      origemLat: _origem!.lat,
      origemLon: _origem!.lon,
      destinoLabel: _destino!.label,
      destinoLat: _destino!.lat,
      destinoLon: _destino!.lon,
      kmEstimado: double.tryParse(_kmCtrl.text.trim().replaceAll(',', '.')),
      pesoKg: peso,
      valorCarga:
          double.tryParse(_valorCargaCtrl.text.trim().replaceAll(',', '.')) ?? 0,
      tipoCarga: _tipoCarga,
      numeroEixos: _numeroEixos,
      observacoes: _observacoesCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (resultado.erro != null) {
      setState(() => _erro = resultado.erro);
      return;
    }
    ref.invalidate(cotacoesClienteProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tabelas = ref.watch(tabelasFreteAtivasProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('🧮 Nova cotação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          tabelas.when(
            data: (lista) {
              if (lista.isEmpty) {
                return const Text(
                    'Nenhuma tabela de frete ativa cadastrada. Cadastre uma em Tabelas de Frete antes de simular.',
                    style: TextStyle(color: Colors.orange));
              }
              return DropdownButtonFormField<String>(
                initialValue: _tabelaFreteId,
                decoration: const InputDecoration(
                    labelText: 'Tabela de frete *',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: lista
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nome)))
                    .toList(),
                onChanged: (v) => setState(() => _tabelaFreteId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Não deu pra carregar tabelas: $e'),
          ),
          const SizedBox(height: 16),
          _CampoLocal(
              label: 'Origem *',
              valor: _origem,
              onEscolhido: (s) => setState(() => _origem = s)),
          const SizedBox(height: 12),
          _CampoLocal(
              label: 'Destino *',
              valor: _destino,
              onEscolhido: (s) => setState(() => _destino = s)),
          const SizedBox(height: 12),
          TextField(
            controller: _kmCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Km estimado',
                hintText: 'Opcional — usado no alerta de piso ANTT',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pesoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Peso (kg) *',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _valorCargaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor da carga (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tipoCarga,
            decoration: const InputDecoration(
                labelText: 'Tipo de carga (piso ANTT)',
                border: OutlineInputBorder(),
                isDense: true),
            items: _tiposCarga
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: _selecionarTipoCarga,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _numeroEixos,
            decoration: const InputDecoration(
                labelText: 'Número de eixos',
                border: OutlineInputBorder(),
                isDense: true),
            items: _eixosDisponiveis
                .map((e) => DropdownMenuItem(value: e, child: Text('$e eixos')))
                .toList(),
            onChanged: (v) => setState(() => _numeroEixos = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacoesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _salvando ? null : _simular,
            child: _salvando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simular e salvar cotação'),
          ),
        ],
      ),
    );
  }
}

class _CampoLocal extends StatefulWidget {
  final String label;
  final SugestaoGeocoding? valor;
  final ValueChanged<SugestaoGeocoding> onEscolhido;

  const _CampoLocal(
      {required this.label, required this.valor, required this.onEscolhido});

  @override
  State<_CampoLocal> createState() => _CampoLocalState();
}

class _CampoLocalState extends State<_CampoLocal> {
  final _controller = TextEditingController();
  List<SugestaoGeocoding> _sugestoes = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    if (widget.valor != null) _controller.text = widget.valor!.label;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (_controller.text.trim().length < 3) return;
    setState(() => _buscando = true);
    final opcoes = await geocodificar(_controller.text);
    if (!mounted) return;
    setState(() {
      _sugestoes = opcoes;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                    hintText: 'Digite a cidade e busque...',
                    isDense: true,
                    border: OutlineInputBorder()),
                onSubmitted: (_) => _buscar(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _buscando ? null : _buscar,
              child: _buscando
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Buscar'),
            ),
          ],
        ),
        if (_sugestoes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: ListView(
              shrinkWrap: true,
              children: _sugestoes
                  .map((s) => ListTile(
                        dense: true,
                        title:
                            Text(s.label, style: const TextStyle(fontSize: 13)),
                        onTap: () {
                          widget.onEscolhido(s);
                          setState(() {
                            _controller.text = s.label;
                            _sugestoes = [];
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
