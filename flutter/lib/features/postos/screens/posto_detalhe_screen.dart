import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/postos_provider.dart';
import '../services/postos_service.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String _fmtData(String iso) {
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

// Fase FLT-3 — detalhe do Posto Revendedor (cliente). Porta reduzida de
// postos/[cnpj]/page.tsx: dados de origem (importação/ANP), toggle
// bloqueado/liberado, remover da rede, registrar/excluir preço. Sem
// PostoForm completo (edição de perfil de venda/horário/ARLA etc. — ver
// comentário em postos_provider.dart) e sem o cascateamento completo de
// fontes de preço (meios de pagamento/Meus Preços/ANP) que
// resolverPrecosVigentes calcula na web — aqui mostra direto o histórico
// de historico_precos (fonte "manual", cadastrado por aqui mesmo).
class PostoDetalheScreen extends ConsumerStatefulWidget {
  final String cnpj;
  const PostoDetalheScreen({super.key, required this.cnpj});

  @override
  ConsumerState<PostoDetalheScreen> createState() => _PostoDetalheScreenState();
}

class _PostoDetalheScreenState extends ConsumerState<PostoDetalheScreen> {
  bool _alternandoAtivo = false;
  bool _removendo = false;

  Future<void> _alternarAtivo(bool ativoAtual) async {
    setState(() => _alternandoAtivo = true);
    final erro = await PostosService().alternarAtivo(cnpj: widget.cnpj, ativo: !ativoAtual);
    if (!mounted) return;
    setState(() => _alternandoAtivo = false);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(postosClienteProvider);
  }

  Future<void> _remover() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remover posto da rede'),
        content: const Text('O posto sai da sua rede negociada. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _removendo = true);
    final erro = await PostosService().excluirPosto(widget.cnpj);
    if (!mounted) return;
    setState(() => _removendo = false);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(postosClienteProvider);
    if (mounted) context.pop();
  }

  Future<void> _abrirFormularioPreco() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    String? combustivel;
    final precoCtrl = TextEditingController();
    var dataRef = DateTime.now().toIso8601String().slice(10);
    String? erroLocal;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Registrar preço'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (erroLocal != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(erroLocal!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                DropdownButtonFormField<String>(
                  value: combustivel,
                  decoration: const InputDecoration(labelText: 'Combustível'),
                  items: produtosPostoRevendedor
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => combustivel = v),
                ),
                TextField(
                  controller: precoCtrl,
                  decoration: const InputDecoration(labelText: 'Preço (R\$/L)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data: ${_fmtData(dataRef)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: dialogCtx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (escolhida != null) {
                      setDialogState(() => dataRef = escolhida.toIso8601String().slice(10));
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final preco = double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0;
                if (combustivel == null) {
                  setDialogState(() => erroLocal = 'Selecione o combustível.');
                  return;
                }
                final erro = await PostosService().registrarPreco(
                  cnpj: widget.cnpj,
                  empresaId: empresaId,
                  combustivel: combustivel!,
                  preco: preco,
                  dataRef: dataRef,
                );
                if (erro != null) {
                  setDialogState(() => erroLocal = erro);
                  return;
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                ref.invalidate(precosPostoProvider(widget.cnpj));
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirPreco(int id) async {
    final erro = await PostosService().excluirPreco(id);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(precosPostoProvider(widget.cnpj));
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(postoDetalheProvider(widget.cnpj));
    final precosAsync = ref.watch(precosPostoProvider(widget.cnpj));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do Posto')),
      body: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (p) {
          if (p == null) return const Center(child: Text('Posto não encontrado.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.razaoSocial ?? p.cnpj, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(p.cnpj, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (p.ativo ? const Color(0xFF16A34A) : const Color(0xFFD97706)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          p.ativo ? 'Liberado para abastecimento' : 'Bloqueado pelo gestor',
                          style: TextStyle(
                              fontSize: 12,
                              color: p.ativo ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _alternandoAtivo ? null : () => _alternarAtivo(p.ativo),
                              child: Text(_alternandoAtivo
                                  ? 'Salvando...'
                                  : (p.ativo ? 'Bloquear' : 'Desbloquear')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: _removendo ? null : _remover,
                              child: Text(_removendo ? 'Removendo...' : 'Remover da rede'),
                            ),
                          ),
                        ],
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
                      Text('Dados de origem', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _linha('Município/UF', [p.municipio, p.uf].where((v) => v != null && v.isNotEmpty).join('/')),
                      _linha('Bandeira', p.bandeira),
                      _linha('Distribuidora', p.distribuidora),
                      _linha('Grupo econômico', p.grupoEconomico),
                      _linha('Rede', p.rede),
                      _linha('Endereço', p.enderecoCompleto.isEmpty ? null : p.enderecoCompleto),
                      _linha('Contato', [p.nomeContato, p.telefoneContato].where((v) => v != null && v.isNotEmpty).join(' — ')),
                      _linha('Responsável',
                          [p.nomeResponsavel, p.telefoneResponsavel].where((v) => v != null && v.isNotEmpty).join(' — ')),
                      _linha('Status na origem', [p.statusPdv, p.situacaoPdv].where((v) => v != null && v.isNotEmpty).join(' / ')),
                      _linha('Habilitado em', p.dataHabilitacao == null ? null : _fmtData(p.dataHabilitacao!)),
                      _linha('Outros serviços', p.outrosServicos),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (p.possuiRestaurante) _chip('Restaurante'),
                          if (p.possuiBanheiro) _chip('Banheiro'),
                          if (p.possuiEstacionamento) _chip('Estacionamento'),
                          if (p.possuiTrocaOleo) _chip('Troca de óleo'),
                          if (p.possuiInternet) _chip('Internet'),
                          if (p.arla) _chip('ARLA 32${p.tipoArla != null ? " (${p.tipoArla})" : ""}'),
                        ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Combustíveis e preços', style: Theme.of(context).textTheme.titleSmall),
                          TextButton.icon(
                            onPressed: _abrirFormularioPreco,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Registrar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      precosAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                        error: (e, _) => Text('Erro ao carregar preços: $e'),
                        data: (precos) {
                          if (precos.isEmpty) {
                            return const Text('Nenhum preço registrado ainda para este posto.', style: TextStyle(color: Colors.grey));
                          }
                          return Column(
                            children: precos
                                .map((preco) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(preco.combustivel, style: const TextStyle(fontSize: 13)),
                                      subtitle: Text('${_fmtData(preco.dataRef)} · ${preco.fonte ?? "—"}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_moeda.format(preco.preco),
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _excluirPreco(preco.id),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          );
                        },
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

  Widget _linha(String label, String? valor) {
    if (valor == null || valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
    );
  }
}

extension _StringSlice on String {
  String slice(int end) => substring(0, end > length ? length : end);
}
