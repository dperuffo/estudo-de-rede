import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../posto/services/abastecimentos_posto_service.dart' show produtosPosto;
import '../services/postos_internos_service.dart';

// Fase FLT-Postos-Internos (02/09/2026) — porta de postos-internos/page.tsx
// + FormPostoInterno.tsx. Igual às outras telas "por empresa" do PWA
// (AbastecimentosScreen etc.), usa a empresa já resolvida por
// sessaoProvider em vez de reimplementar o seletor matriz/filial da web —
// quem tem mais de 1 empresa já escolhe em /selecionar-empresa antes de
// chegar aqui.
class PostosInternosScreen extends ConsumerStatefulWidget {
  const PostosInternosScreen({super.key});

  @override
  ConsumerState<PostosInternosScreen> createState() =>
      _PostosInternosScreenState();
}

class _PostosInternosScreenState extends ConsumerState<PostosInternosScreen> {
  final _service = PostosInternosService();
  final _nomeCtrl = TextEditingController();
  final Map<String, TextEditingController> _precoCtrls = {
    for (final c in [...produtosPosto, arla32]) c: TextEditingController(),
  };

  Future<PostoInterno?>? _futuro;
  bool _ativo = true;
  bool _salvandoDados = false;
  bool _salvandoPrecos = false;
  String? _msgDados;
  String? _msgDadosErro;
  String? _msgPrecos;
  String? _msgPrecosErro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    for (final c in _precoCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() => _futuro = Future.value(null));
      return;
    }
    setState(() {
      _futuro = _service.obterOuCriar(empresaId).then((posto) async {
        if (posto != null) {
          _nomeCtrl.text = posto.nome ?? '';
          _ativo = posto.ativo;
          final precos = await _service.buscarPrecos(posto.id);
          for (final entry in precos.entries) {
            _precoCtrls[entry.key]?.text = _fmtPreco(entry.value);
          }
        }
        return posto;
      });
    });
  }

  String _fmtPreco(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(2) : v.toString();

  Future<void> _salvarDados(PostoInterno posto) async {
    setState(() {
      _salvandoDados = true;
      _msgDados = null;
      _msgDadosErro = null;
    });
    final erro = await _service.salvarDados(
      postoInternoId: posto.id,
      empresaId: posto.empresaId,
      nome: _nomeCtrl.text,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() {
      _salvandoDados = false;
      if (erro != null) {
        _msgDadosErro = erro;
      } else {
        _msgDados = 'Dados do posto interno salvos.';
      }
    });
  }

  Future<void> _salvarPrecos(PostoInterno posto) async {
    setState(() {
      _salvandoPrecos = true;
      _msgPrecos = null;
      _msgPrecosErro = null;
    });
    final erro = await _service.salvarPrecos(
      postoInternoId: posto.id,
      precosPorCombustivel: {
        for (final entry in _precoCtrls.entries) entry.key: entry.value.text,
      },
    );
    if (!mounted) return;
    setState(() {
      _salvandoPrecos = false;
      if (erro != null) {
        _msgPrecosErro = erro;
      } else {
        _msgPrecos = 'Preços atualizados.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessaoProvider, (prev, next) {
      final idAnterior = prev?.valueOrNull?.empresaId;
      final idAtual = next.valueOrNull?.empresaId;
      if (idAtual != null && idAtual != idAnterior) _carregar();
    });
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Postos Internos')),
      body: FutureBuilder<PostoInterno?>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator()),
            );
          }
          final posto = snap.data;
          if (posto == null) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  snap.hasError
                      ? 'Não deu pra carregar: ${snap.error}'
                      : 'Não foi possível carregar/criar o posto interno desta empresa. Tente novamente ou fale com o suporte.',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Abastecimento feito na garagem própria (matriz ou filial), antes do veículo sair pra rota — '
                'entra no custo total da Roteirização junto com os postos externos.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Posto interno',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Representa a garagem/tanque próprio desta empresa. Enquanto estiver ativo, ele aparece '
                        'como opção de empresa no app do motorista (aba Abastecimento Interno) e entra no cálculo '
                        'de custo da Roteirização.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (_msgDadosErro != null) ...[
                        const SizedBox(height: 10),
                        _mensagem(_msgDadosErro!, erro: true),
                      ],
                      if (_msgDados != null) ...[
                        const SizedBox(height: 10),
                        _mensagem(_msgDados!, erro: false),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome (opcional)',
                          hintText: 'Ex.: Garagem Matriz, Pátio Filial SP...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Posto interno ativo'),
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _salvandoDados ? null : () => _salvarDados(posto),
                          child: Text(_salvandoDados ? 'Salvando...' : 'Salvar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Preços por combustível',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Preencha só os combustíveis realmente abastecidos aqui. O preço unitário informado é o '
                        'que vale no abastecimento manual e no que o motorista confirma pelo app — ele nunca '
                        'digita o preço.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (_msgPrecosErro != null) ...[
                        const SizedBox(height: 10),
                        _mensagem(_msgPrecosErro!, erro: true),
                      ],
                      if (_msgPrecos != null) ...[
                        const SizedBox(height: 10),
                        _mensagem(_msgPrecos!, erro: false),
                      ],
                      const SizedBox(height: 12),
                      for (final c in produtosPosto) _linhaPreco(c),
                      _linhaPreco(arla32,
                          sufixo: ' (aditivo, junto do Diesel)'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _salvandoPrecos
                              ? null
                              : () => _salvarPrecos(posto),
                          child: Text(
                              _salvandoPrecos ? 'Salvando...' : 'Salvar preços'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _linhaPreco(String combustivel, {String sufixo = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: combustivel),
                  if (sufixo.isNotEmpty)
                    TextSpan(
                        text: sufixo,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                ]),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _precoCtrls[combustivel],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _mensagem(String texto, {required bool erro}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: erro ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          texto,
          style: TextStyle(
              fontSize: 12,
              color: erro ? const Color(0xFFB91C1C) : const Color(0xFF15803D)),
        ),
      );
}
