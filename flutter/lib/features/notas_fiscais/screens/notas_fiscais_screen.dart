import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/notas_fiscais_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dataBr = DateFormat('dd/MM/yyyy');

String _fmtData(String iso) {
  try {
    return _dataBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Interpola vermelho -> âmbar -> verde conforme o percentual sobe — mesma
// lógica de corDoPercentual() (IndicadorNotasFiscais.tsx).
Color _corDoPercentual(double p) {
  final pc = p.clamp(0, 100);
  const vermelho = Color(0xFFDC2626);
  const ambar = Color(0xFFD97706);
  const verde = Color(0xFF16A34A);
  if (pc <= 50) return Color.lerp(vermelho, ambar, pc / 50)!;
  return Color.lerp(ambar, verde, (pc - 50) / 50)!;
}

class NotasFiscaisScreen extends ConsumerStatefulWidget {
  const NotasFiscaisScreen({super.key});

  @override
  ConsumerState<NotasFiscaisScreen> createState() => _NotasFiscaisScreenState();
}

class _NotasFiscaisScreenState extends ConsumerState<NotasFiscaisScreen> {
  final _buscaCtrl = TextEditingController();
  String? _status;
  String _buscaAplicada = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicadorAsync = ref.watch(indicadorNotasFiscaisProvider);
    final filtros = FiltrosNotasFiscais(status: _status, busca: _buscaAplicada.isEmpty ? null : _buscaAplicada);
    final linhasAsync = ref.watch(linhasNotasFiscaisProvider(filtros));

    return Scaffold(
      appBar: AppBar(title: const Text('Notas Fiscais')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(indicadorNotasFiscaisProvider);
          ref.invalidate(linhasNotasFiscaisProvider(filtros));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            indicadorAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro ao carregar indicadores: $e'),
              data: (ind) => _cardIndicador(ind),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _buscaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por ID, placa, posto ou cliente...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _buscaCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _buscaAplicada = '');
                        },
                      ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _buscaAplicada = v.trim()),
            ),
            const SizedBox(height: 10),
            indicadorAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (ind) => Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Todos (${ind.total})'),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  ChoiceChip(
                    label: Text('Emitida (${ind.comNota})'),
                    selected: _status == 'emitida',
                    onSelected: (_) => setState(() => _status = 'emitida'),
                  ),
                  ChoiceChip(
                    label: Text('Rejeitada (${ind.rejeitadas})'),
                    selected: _status == 'rejeitada',
                    onSelected: (_) => setState(() => _status = 'rejeitada'),
                  ),
                  ChoiceChip(
                    label: Text('Pendente (${ind.pendentes})'),
                    selected: _status == 'pendente',
                    onSelected: (_) => setState(() => _status = 'pendente'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Abastecimentos (últimos 90 dias)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            linhasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro ao carregar: $e'),
              data: (linhas) {
                if (linhas.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum abastecimento encontrado nos últimos 90 dias.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  );
                }
                return Column(
                  children: linhas.map(_cardLinha).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardIndicador(IndicadorNotasFiscais ind) {
    final cor = _corDoPercentual(ind.percentual);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Recolha de notas fiscais', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Text('${ind.percentual.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: cor)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Últimos 90 dias · ${ind.comNota} de ${ind.total} abastecimento${ind.total == 1 ? '' : 's'} com NF-e vinculada'
              '${ind.rejeitadas > 0 ? ' · ${ind.rejeitadas} rejeitada${ind.rejeitadas == 1 ? '' : 's'}' : ''}'
              '${ind.pendentes > 0 ? ' · ${ind.pendentes} pendente${ind.pendentes == 1 ? '' : 's'}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (ind.percentual.clamp(0, 100)) / 100,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(cor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardLinha(LinhaNotaFiscal l) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: l.notaId != null ? () => context.push('/notas-fiscais/${l.notaId}') : null,
        title: Text(
          [
            if (l.codigoAbastecimento != null) '#${l.codigoAbastecimento}',
            _fmtData(l.dataAbastecimento),
          ].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (l.postoNome != null) l.postoNome!,
                if (l.veiculoPlaca != null) l.veiculoPlaca!,
                if (l.itemNome != null) l.itemNome!,
                if (l.itemValorTotal != null) _moeda.format(l.itemValorTotal),
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _badgeStatus(l),
          ],
        ),
        isThreeLine: true,
        trailing: l.notaId != null ? const Icon(Icons.chevron_right, size: 18) : null,
      ),
    );
  }

  Widget _badgeStatus(LinhaNotaFiscal l) {
    if (l.notaId != null) {
      return _chip('Emitida${l.notaNumero != null ? ' · Nº ${l.notaNumero}' : ''}', const Color(0xFF16A34A));
    }
    if (l.pendenciaMotivo != null) {
      final detalhe = l.pendenciaMotivo == 'erro_leitura_xml' && l.pendenciaDetalheTexto != null
          ? l.pendenciaDetalheTexto!
          : mensagemMotivoPendencia(l.pendenciaMotivo);
      final extra = [
        if (l.pendenciaNomeArquivo != null) 'Arquivo: ${l.pendenciaNomeArquivo}',
        if (l.pendenciaCnpjEmitente != null) 'CNPJ emitente ${l.pendenciaCnpjEmitente}',
        if (l.pendenciaProdutoNomeXml != null) l.pendenciaProdutoNomeXml!,
      ].join(' · ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chip('Rejeitada', const Color(0xFFDC2626)),
          const SizedBox(height: 3),
          Text(detalhe, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          if (extra.isNotEmpty) Text(extra, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
    }
    return _chip('Pendente', const Color(0xFFD97706));
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
    );
  }
}
