import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart' show motoristasClienteProvider;
import '../../veiculos/providers/veiculos_provider.dart' show veiculosClienteProvider;
import '../providers/parametros_uso_provider.dart';
import '../services/parametros_uso_service.dart';
import 'regras_forms.dart';

// Fase FLT-3 — Parâmetros de Uso (cliente): shell com seletor de aba (chips
// horizontais, mesmo padrão da web) + conteúdo por tipo. Ver escopo
// completo (o que ficou de fora — "Serviços") em
// parametros_uso_provider.dart.
const _abasParametros = [
  ('vinculo', 'Vínculo'),
  ('intervalo', 'Intervalo'),
  ('valor-diario', 'Valor Diário'),
  ('volume-diario', 'Vol. Diário'),
  ('produto', 'Produto'),
  ('hodometro-leve', 'Hodôm. Leve'),
  ('hodometro-pesado', 'Hodôm. Pesado'),
  ('dias-horarios', 'Dias/Horários'),
  ('postos', 'Postos'),
  ('cotas', 'Cotas'),
];

class ParametrosUsoScreen extends ConsumerStatefulWidget {
  const ParametrosUsoScreen({super.key});

  @override
  ConsumerState<ParametrosUsoScreen> createState() => _ParametrosUsoScreenState();
}

class _ParametrosUsoScreenState extends ConsumerState<ParametrosUsoScreen> {
  String _aba = 'vinculo';
  String? _statusFiltroVinculo;

  Future<void> _confirmarExcluir(String tabela, String id, ProviderOrFamily providerParaInvalidar) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir regra?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await ParametrosUsoService().excluir(tabela: tabela, id: id);
    ref.invalidate(providerParaInvalidar);
  }

  Future<void> _alternarStatus(String tabela, String id, bool ativo, ProviderOrFamily providerParaInvalidar) async {
    await ParametrosUsoService().alternarStatus(tabela: tabela, id: id, ativo: ativo);
    ref.invalidate(providerParaInvalidar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parâmetros de Uso')),
      floatingActionButton: _fab(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final a in _abasParametros)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(a.$2),
                        selected: _aba == a.$1,
                        onSelected: (_) => setState(() => _aba = a.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _conteudoAba()),
        ],
      ),
    );
  }

  Widget? _fab() {
    if (_aba == 'vinculo') {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/parametros-uso/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Vínculo'),
      );
    }
    return FloatingActionButton.extended(
      onPressed: _abrirFormRegra,
      icon: const Icon(Icons.add),
      label: const Text('Nova Regra'),
    );
  }

  Future<void> _abrirFormRegra() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;
    final veiculos = await ref.read(veiculosClienteProvider.future);
    final motoristas = await ref.read(motoristasClienteProvider.future);
    if (!mounted) return;

    switch (_aba) {
      case 'intervalo':
        await mostrarFormIntervalo(context, ref, empresaId, veiculos, motoristas);
        break;
      case 'valor-diario':
        await mostrarFormValorDiario(context, ref, empresaId, motoristas);
        break;
      case 'volume-diario':
        await mostrarFormVolumeDiario(context, ref, empresaId, veiculos);
        break;
      case 'produto':
        await mostrarFormProduto(context, ref, empresaId, veiculos);
        break;
      case 'hodometro-leve':
        await mostrarFormHodometro(context, ref, empresaId, 'Leve', veiculos);
        break;
      case 'hodometro-pesado':
        await mostrarFormHodometro(context, ref, empresaId, 'Pesado', veiculos);
        break;
      case 'dias-horarios':
        await mostrarFormDiasHorarios(context, ref, empresaId, veiculos, motoristas);
        break;
      case 'postos':
        final postos = await ref.read(postosNegociadosOpcoesProvider.future);
        if (!mounted) return;
        await mostrarFormPostos(context, ref, empresaId, veiculos, motoristas, postos);
        break;
      case 'cotas':
        await mostrarFormCota(context, ref, empresaId, veiculos);
        break;
    }
  }

  Widget _conteudoAba() {
    switch (_aba) {
      case 'vinculo':
        return _listaVinculos();
      case 'intervalo':
        return _listaIntervalo();
      case 'valor-diario':
        return _listaValorDiario();
      case 'volume-diario':
        return _listaVolumeDiario();
      case 'produto':
        return _listaProduto();
      case 'hodometro-leve':
        return _listaHodometro('Leve');
      case 'hodometro-pesado':
        return _listaHodometro('Pesado');
      case 'dias-horarios':
        return _listaDiasHorarios();
      case 'postos':
        return _listaPostos();
      default:
        return _listaCotas();
    }
  }

  Widget _card({required List<Widget> linhas, required String status, required VoidCallback onToggle, required VoidCallback onExcluir}) {
    final ativo = status == 'Ativo';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...linhas,
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11,
                          color: ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                TextButton(onPressed: onToggle, child: Text(ativo ? 'Desativar' : 'Ativar')),
                TextButton(onPressed: onExcluir, child: const Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaTexto(String texto, {bool destaque = false}) => Text(texto,
      style: TextStyle(fontSize: destaque ? 13 : 12, fontWeight: destaque ? FontWeight.w600 : FontWeight.normal, color: destaque ? null : Colors.grey.shade700));

  Widget _vazio(String texto) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(texto, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );

  // ── Vínculo ────────────────────────────────────────────────────────
  Widget _listaVinculos() {
    final async = ref.watch(vinculosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (lista) {
        final filtrados = _statusFiltroVinculo == null
            ? lista
            : lista.where((v) => v.status == _statusFiltroVinculo).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            const Text(
              'Associa um motorista a um veículo específico. Abastecimentos feitos em postos ou soluções de '
              'automação integradas via API podem ser autorizados apenas quando o par estiver ativo.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Todos (${lista.length})'),
                  selected: _statusFiltroVinculo == null,
                  onSelected: (_) => setState(() => _statusFiltroVinculo = null),
                ),
                ChoiceChip(
                  label: const Text('Ativos'),
                  selected: _statusFiltroVinculo == 'Ativo',
                  onSelected: (_) => setState(() => _statusFiltroVinculo = 'Ativo'),
                ),
                ChoiceChip(
                  label: const Text('Inativos'),
                  selected: _statusFiltroVinculo == 'Inativo',
                  onSelected: (_) => setState(() => _statusFiltroVinculo = 'Inativo'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtrados.isEmpty) _vazio('Nenhum vínculo encontrado.'),
            ...filtrados.map((v) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => context.push('/parametros-uso/${v.id}/editar'),
                    title: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(v.motoristaNome ?? '—', style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (v.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(v.status,
                          style: TextStyle(
                              fontSize: 11,
                              color: v.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  // ── Intervalo ──────────────────────────────────────────────────────
  Widget _listaIntervalo() {
    final async = ref.watch(intervalosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma regra de intervalo cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_intervalo_abastecimento', r.id, r.status != 'Ativo', intervalosProvider),
                onExcluir: () => _confirmarExcluir('parametros_intervalo_abastecimento', r.id, intervalosProvider),
                linhas: [
                  _linhaTexto('${r.tipo == 'Veiculo' ? 'Veículo' : 'Motorista'}: ${r.tipo == 'Veiculo' ? (r.placa ?? 'Todos') : (r.motoristaNome ?? 'Todos')}', destaque: true),
                  _linhaTexto('${r.intervaloMinimo} ${r.unidade == 'Horas' ? 'hora(s)' : 'dia(s)'}'),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Valor Diário ───────────────────────────────────────────────────
  Widget _listaValorDiario() {
    final async = ref.watch(valoresDiariosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma regra cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_valor_diario_motorista', r.id, r.status != 'Ativo', valoresDiariosProvider),
                onExcluir: () => _confirmarExcluir('parametros_valor_diario_motorista', r.id, valoresDiariosProvider),
                linhas: [
                  _linhaTexto(r.motoristaNome ?? 'Todos os motoristas', destaque: true),
                  _linhaTexto('Máximo diário: R\$ ${r.valorMaximo.toStringAsFixed(2)}'),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Volume Diário ──────────────────────────────────────────────────
  Widget _listaVolumeDiario() {
    final async = ref.watch(volumesDiariosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma regra cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_volume_diario_veiculo', r.id, r.status != 'Ativo', volumesDiariosProvider),
                onExcluir: () => _confirmarExcluir('parametros_volume_diario_veiculo', r.id, volumesDiariosProvider),
                linhas: [
                  _linhaTexto(r.placa ?? 'Todos os veículos', destaque: true),
                  _linhaTexto('Máximo diário: ${r.volumeMaximo} L'),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Produto ────────────────────────────────────────────────────────
  Widget _listaProduto() {
    final async = ref.watch(produtosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma regra cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_produto_abastecido', r.id, r.status != 'Ativo', produtosProvider),
                onExcluir: () => _confirmarExcluir('parametros_produto_abastecido', r.id, produtosProvider),
                linhas: [
                  _linhaTexto(r.placa ?? 'Todos os veículos', destaque: true),
                  _linhaTexto(r.combustiveisPermitidos.isEmpty ? 'Do cadastro' : r.combustiveisPermitidos.join(', ')),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Hodômetro ──────────────────────────────────────────────────────
  Widget _listaHodometro(String classificacao) {
    final async = ref.watch(variacoesHodometroProvider(classificacao));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma regra cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_variacao_hodometro', r.id, r.status != 'Ativo', variacoesHodometroProvider(classificacao)),
                onExcluir: () => _confirmarExcluir('parametros_variacao_hodometro', r.id, variacoesHodometroProvider(classificacao)),
                linhas: [
                  _linhaTexto(r.placa ?? 'Todos os veículos', destaque: true),
                  _linhaTexto('Variação máxima: ${r.variacaoMaximaKm} km'),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Dias/Horários ──────────────────────────────────────────────────
  Widget _listaDiasHorarios() {
    final async = ref.watch(diasHorariosProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma restrição cadastrada.'),
          ...lista.map((r) => _card(
                status: r.status,
                onToggle: () => _alternarStatus('parametros_dias_horarios', r.id, r.status != 'Ativo', diasHorariosProvider),
                onExcluir: () => _confirmarExcluir('parametros_dias_horarios', r.id, diasHorariosProvider),
                linhas: [
                  _linhaTexto(
                      '${r.classificacao ?? 'Todos'} · ${r.placa ?? 'Todos os veículos'} · ${r.motoristaNome ?? 'Todos os motoristas'}',
                      destaque: true),
                  _linhaTexto(r.diasPermitidos.join(', ')),
                  _linhaTexto('${r.horaInicio.substring(0, 5)}–${r.horaFim.substring(0, 5)}'),
                  if (r.observacao != null) _linhaTexto(r.observacao!),
                ],
              )),
        ],
      ),
    );
  }

  // ── Postos ─────────────────────────────────────────────────────────
  Widget _listaPostos() {
    final async = ref.watch(postosPermitidosProvider);
    final postosOpcoesAsync = ref.watch(postosNegociadosOpcoesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) {
        final nomes = postosOpcoesAsync.maybeWhen(
          data: (postos) => {for (final p in postos) p.cnpj: p.nome},
          orElse: () => <String, String>{},
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            if (lista.isEmpty) _vazio('Nenhuma restrição cadastrada.'),
            ...lista.map((r) => _card(
                  status: r.status,
                  onToggle: () => _alternarStatus('parametros_postos_permitidos', r.id, r.status != 'Ativo', postosPermitidosProvider),
                  onExcluir: () => _confirmarExcluir('parametros_postos_permitidos', r.id, postosPermitidosProvider),
                  linhas: [
                    _linhaTexto(
                        '${r.classificacao ?? 'Todos'} · ${r.placa ?? 'Todos os veículos'} · ${r.motoristaNome ?? 'Todos os motoristas'}',
                        destaque: true),
                    _linhaTexto(r.postosCnpj.map((c) => nomes[c] ?? c).join(', ')),
                    _linhaTexto(r.tipoLimite == 'Sem limite'
                        ? 'Sem limite'
                        : '${r.tipoLimite == 'Valor' ? 'R\$' : 'L'} ${r.valorMaximo ?? '—'}'),
                    if (r.observacao != null) _linhaTexto(r.observacao!),
                  ],
                )),
          ],
        );
      },
    );
  }

  // ── Cotas ──────────────────────────────────────────────────────────
  Widget _listaCotas() {
    final async = ref.watch(cotasProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          if (lista.isEmpty) _vazio('Nenhuma cota cadastrada.'),
          ...lista.map((r) {
            final pct = r.limite > 0 ? (r.consumido / r.limite * 100).clamp(0, 100).round() : 0;
            final formatarValor = r.tipo == 'Valor' ? 'R\$ ${r.consumido.toStringAsFixed(2)}' : '${r.consumido} L';
            final formatarLimite = r.tipo == 'Valor' ? 'R\$ ${r.limite.toStringAsFixed(2)}' : '${r.limite} L';
            return _card(
              status: r.status,
              onToggle: () => _alternarStatus('parametros_cota_veiculo', r.id, r.status != 'Ativo', cotasProvider),
              onExcluir: () => _confirmarExcluir('parametros_cota_veiculo', r.id, cotasProvider),
              linhas: [
                _linhaTexto('${r.placa} · ${r.tipo == 'Valor' ? 'Valor (R\$)' : 'Volume (L)'}', destaque: true),
                _linhaTexto('Limite: $formatarLimite · ${periodicidadeLabel[r.periodicidade] ?? r.periodicidade}'),
                _linhaTexto('Consumido: $formatarValor ($pct%)'),
                if (r.observacao != null) _linhaTexto(r.observacao!),
              ],
            );
          }),
        ],
      ),
    );
  }
}
