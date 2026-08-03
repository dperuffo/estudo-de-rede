import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/patrimonio_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Grupo 2 (Rodopar/Datapar, item 6, 03/08/2026) — Patrimônio (cliente),
// porta de patrimonio/page.tsx. Ver escopo em patrimonio_provider.dart.
class PatrimonioScreen extends ConsumerStatefulWidget {
  const PatrimonioScreen({super.key});

  @override
  ConsumerState<PatrimonioScreen> createState() => _PatrimonioScreenState();
}

class _PatrimonioScreenState extends ConsumerState<PatrimonioScreen> {
  final _buscaCtrl = TextEditingController();
  String? _busca;
  String _ordenar = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _aplicarFiltros() {
    setState(() => _busca = _buscaCtrl.text.trim().isEmpty ? null : _buscaCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final filtros = (busca: _busca, ordenar: _ordenar);
    final resumoAsync = ref.watch(patrimonioResumoProvider(filtros));

    return Scaffold(
      appBar: AppBar(title: const Text('Patrimônio')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(patrimonioResumoProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Registro formal de ativo imobilizado: valor de aquisição, depreciação contábil (linha reta pela '
              'vida útil) e correções (reavaliação, melhoria, baixa) — complementa o TCO, que usa depreciação '
              'econômica (curva FIPE) só pra custo/km.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Placa, marca ou modelo...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _aplicarFiltros(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _aplicarFiltros, child: const Text('Filtrar')),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _ordenar,
              decoration: const InputDecoration(labelText: 'Ordenar por', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: '', child: Text('Placa')),
                DropdownMenuItem(value: 'valor_contabil_asc', child: Text('Menor valor contábil primeiro')),
                DropdownMenuItem(value: 'percentual_desc', child: Text('Mais depreciado primeiro')),
              ],
              onChanged: (v) => setState(() => _ordenar = v ?? ''),
            ),
            const SizedBox(height: 16),
            resumoAsync.when(
              data: (lista) => _corpo(lista),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(List<VeiculoPatrimonio> lista) {
    if (lista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nenhum veículo encontrado para esse filtro.', style: TextStyle(color: Colors.grey))),
      );
    }

    final comAquisicao = lista.where((v) => v.patrimonioCompleto).toList();
    final semAquisicao = lista.length - comAquisicao.length;
    final valorAquisicaoTotal = comAquisicao.fold<double>(0, (s, v) => s + (v.valorAquisicao ?? 0));
    final depreciacaoTotal = comAquisicao.fold<double>(0, (s, v) => s + (v.depreciacaoAcumulada ?? 0));
    final valorContabilTotal = comAquisicao.fold<double>(0, (s, v) => s + (v.valorContabilLiquido ?? 0));
    final vidaUtilEsgotada = comAquisicao.where((v) => !v.baixado && (v.percentualDepreciado ?? 0) >= 100).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _indicador('Valor de aquisição', _moeda.format(valorAquisicaoTotal)),
            const SizedBox(width: 8),
            _indicador('Depreciação acumulada', _moeda.format(depreciacaoTotal)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _indicador('Valor contábil líquido', _moeda.format(valorContabilTotal)),
            const SizedBox(width: 8),
            _indicador('Vida útil esgotada', '$vidaUtilEsgotada', destaque: vidaUtilEsgotada > 0),
          ],
        ),
        if (semAquisicao > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Text(
              '⚠️ $semAquisicao veículo(s) sem valor/data de aquisição cadastrado — não entram no Patrimônio. '
              'Complete o cadastro em Veículos.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...lista.map(_cardVeiculo),
      ],
    );
  }

  Widget _indicador(String label, String valor, {bool destaque = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: destaque ? const Color(0xFFFFFBEB) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: destaque ? const Color(0xFFFDE68A) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFF92400E) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _cardVeiculo(VeiculoPatrimonio v) {
    final Color corBadge;
    final String textoBadge;
    if (v.baixado) {
      corBadge = Colors.grey.shade200;
      textoBadge = 'Baixado';
    } else if (!v.patrimonioCompleto) {
      corBadge = const Color(0xFFFFFBEB);
      textoBadge = 'Sem aquisição';
    } else if ((v.percentualDepreciado ?? 0) >= 100) {
      corBadge = const Color(0xFFFFF7ED);
      textoBadge = 'Vida útil esgotada';
    } else {
      corBadge = const Color(0xFFECFDF5);
      textoBadge = 'Em depreciação';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/patrimonio/${v.placa}'),
        title: Row(
          children: [
            Expanded(child: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Text(
              v.valorContabilLiquido != null ? _moeda.format(v.valorContabilLiquido!) : '—',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' '),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (v.depreciacaoAcumulada != null)
                    Text(
                      '${_moeda.format(v.depreciacaoAcumulada!)} depreciados'
                      '${v.percentualDepreciado != null ? ' (${v.percentualDepreciado}%)' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: corBadge, borderRadius: BorderRadius.circular(10)),
                    child: Text(textoBadge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
