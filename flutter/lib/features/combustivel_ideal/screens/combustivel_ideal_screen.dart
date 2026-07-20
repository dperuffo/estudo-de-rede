import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inteligencia_rede/widgets/inteligencia_shared.dart';
import '../providers/combustivel_ideal_provider.dart';
import '../providers/diesel_ideal_provider.dart';

// Fase Onda-2 (benchmark TicketLog, item #6) — porta de
// combustivel-ideal/page.tsx (web). Pedido do Daniel: "Implementar estas
// duas iniciativas na web e PWA cliente".
// Fase Filtro-Placa — pedido do Daniel: "Colocar um filtro para seleção de
// placa nas visões de cliente, web e pwa, e admin". Filtro client-side (sem
// nova chamada à RPC) por placa/marca/modelo, mesma ideia da versão web.
// Fase Diesel — pedido do Daniel: "Aba de combustível ideal tem que estar
// disponível para a família Diesel também". Virou 2 abas (Flex / Diesel),
// mesma estrutura de DefaultTabController já usada em Fretes/Manutenção.
class CombustivelIdealScreen extends StatelessWidget {
  const CombustivelIdealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Combustível Ideal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '🌱⛽ Flex'),
              Tab(text: '🛢️✨ Diesel'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AbaFlex(), _AbaDiesel()],
        ),
      ),
    );
  }
}

class _AbaFlex extends ConsumerStatefulWidget {
  const _AbaFlex();

  @override
  ConsumerState<_AbaFlex> createState() => _AbaFlexState();
}

class _AbaFlexState extends ConsumerState<_AbaFlex> {
  String _busca = '';

  List<ItemComparadorCombustivel> _filtrar(List<ItemComparadorCombustivel> itens) {
    final q = _busca.trim().toUpperCase();
    if (q.isEmpty) return itens;
    return itens.where((i) {
      final alvo = '${i.placa} ${i.marca ?? ''} ${i.modelo ?? ''}'.toUpperCase();
      return alvo.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(combustivelIdealProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(combustivelIdealProvider),
      child: itensAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [Text('Erro ao carregar: $e')],
        ),
        data: (itens) {
          final totalEtanol = itens.where((i) => i.recomendacao == 'etanol').length;
          final totalGasolina = itens.where((i) => i.recomendacao == 'gasolina').length;
          final itensFiltrados = _filtrar(itens);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Pra cada veículo flex, qual combustível compensa mais agora — comparando o custo por km '
                'rodado (preço do litro ÷ rendimento real do veículo), não só o preço do litro.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _kpi('Veículos', itens.length.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _kpi('Etanol compensa', totalEtanol.toString(), destaque: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _kpi('Gasolina compensa', totalGasolina.toString())),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFF8FAFC),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Custo por km = preço do litro ÷ rendimento (km/l). O rendimento real vem do histórico de '
                    'abastecimentos da placa; quando falta histórico de um dos dois combustíveis, o que falta é '
                    'estimado a partir do outro (etanol ≈ 70% do rendimento da gasolina) — veículos nessa '
                    'situação aparecem com "(estimado)".',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (itens.isNotEmpty)
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Buscar por placa, marca ou modelo...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixText: _busca.isNotEmpty ? '${itensFiltrados.length}/${itens.length}' : null,
                  ),
                ),
              const SizedBox(height: 12),
              if (itens.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum veículo flex encontrado.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else if (itensFiltrados.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Nenhum veículo encontrado para "$_busca".', style: const TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...itensFiltrados.map(_cardVeiculo),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String valor, {bool destaque = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 0.2)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: destaque ? const Color(0xFF16A34A) : null)),
          ],
        ),
      ),
    );
  }

  Widget _cardVeiculo(ItemComparadorCombustivel i) {
    final veiculo = [i.marca, i.modelo].where((s) => s != null && s.isNotEmpty).join(' ');
    Color? corBadge;
    String? textoBadge;
    if (i.recomendacao == 'etanol') {
      corBadge = const Color(0xFF16A34A);
      textoBadge = '🌱 Etanol${i.economiaPct != null ? ' (${i.economiaPct}% mais barato)' : ''}';
    } else if (i.recomendacao == 'gasolina') {
      corBadge = const Color(0xFFD97706);
      textoBadge = '⛽ Gasolina${i.economiaPct != null ? ' (${i.economiaPct}% mais barato)' : ''}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${i.placa}${veiculo.isNotEmpty ? ' — $veiculo' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (i.uf != null) Text(i.uf!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            TabelaSimples(
              colunas: const ['', 'Gasolina', 'Etanol'],
              flexColunas: const [2, 3, 3],
              linhas: [
                [
                  'Preço',
                  i.precoGasolina != null ? 'R\$ ${i.precoGasolina!.toStringAsFixed(3)}' : '—',
                  i.precoEtanol != null ? 'R\$ ${i.precoEtanol!.toStringAsFixed(3)}' : '—',
                ],
                [
                  'Rendimento',
                  i.rendimentoGasolina != null ? '${i.rendimentoGasolina!.toStringAsFixed(2)} km/l' : '—',
                  i.rendimentoEtanol != null ? '${i.rendimentoEtanol!.toStringAsFixed(2)} km/l' : '—',
                ],
                [
                  'Custo/km',
                  i.custoKmGasolina != null ? 'R\$ ${i.custoKmGasolina!.toStringAsFixed(3)}' : '—',
                  i.custoKmEtanol != null ? 'R\$ ${i.custoKmEtanol!.toStringAsFixed(3)}' : '—',
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (textoBadge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: corBadge!.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '$textoBadge${i.rendimentoEstimado ? ' · rendimento estimado' : ''}',
                  style: TextStyle(fontSize: 11, color: corBadge, fontWeight: FontWeight.w600),
                ),
              )
            else
              const Text('Dados insuficientes para recomendar', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _AbaDiesel extends ConsumerStatefulWidget {
  const _AbaDiesel();

  @override
  ConsumerState<_AbaDiesel> createState() => _AbaDieselState();
}

class _AbaDieselState extends ConsumerState<_AbaDiesel> {
  String _busca = '';

  List<ItemComparadorDiesel> _filtrar(List<ItemComparadorDiesel> itens) {
    final q = _busca.trim().toUpperCase();
    if (q.isEmpty) return itens;
    return itens.where((i) {
      final alvo = '${i.placa} ${i.marca ?? ''} ${i.modelo ?? ''}'.toUpperCase();
      return alvo.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(dieselIdealProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dieselIdealProvider),
      child: itensAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [Text('Erro ao carregar: $e')],
        ),
        data: (itens) {
          final totalAditivado = itens.where((i) => i.recomendacao == 'aditivado').length;
          final totalComum = itens.where((i) => i.recomendacao == 'comum').length;
          final itensFiltrados = _filtrar(itens);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Pra cada veículo/família de diesel, mostra se compensa usar o aditivado ou o comum, comparando '
                'o custo por km. Diferente do flex, não existe uma razão física universal pra estimar rendimento '
                'faltante — a recomendação só aparece quando a placa tem histórico dos dois; sem isso, mostramos '
                'o prêmio de preço do aditivado.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              if (itens.isNotEmpty)
                Row(
                  children: [
                    Expanded(child: _kpi('Veículo × família', itens.length.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _kpi('Aditivado compensa', totalAditivado.toString(), destaque: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _kpi('Comum compensa', totalComum.toString())),
                  ],
                ),
              const SizedBox(height: 12),
              if (itens.isNotEmpty)
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Buscar por placa, marca ou modelo...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixText: _busca.isNotEmpty ? '${itensFiltrados.length}/${itens.length}' : null,
                  ),
                ),
              const SizedBox(height: 12),
              if (itens.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum veículo com histórico de abastecimento a diesel encontrado.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else if (itensFiltrados.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Nenhum veículo encontrado para "$_busca".', style: const TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...itensFiltrados.map(_cardVeiculo),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String valor, {bool destaque = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 0.2)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: destaque ? const Color(0xFF0284C7) : null)),
          ],
        ),
      ),
    );
  }

  Widget _cardVeiculo(ItemComparadorDiesel i) {
    final veiculo = [i.marca, i.modelo].where((s) => s != null && s.isNotEmpty).join(' ');

    Widget rodape;
    if (i.recomendacao != null) {
      final cor = i.recomendacao == 'aditivado' ? const Color(0xFF0284C7) : Colors.grey.shade700;
      rodape = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(
          i.recomendacao == 'aditivado' ? '✨ Aditivado compensa' : '🛢️ Comum compensa',
          style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600),
        ),
      );
    } else if (i.premioAditivadoPct != null) {
      final sinal = i.premioAditivadoPct! > 0 ? '+' : '';
      rodape = Text(
        'Aditivado $sinal${i.premioAditivadoPct}% no preço — sem histórico de rendimento pra comparar',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    } else {
      rodape = const Text('Dados insuficientes', style: TextStyle(fontSize: 11, color: Colors.grey));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${i.placa}${veiculo.isNotEmpty ? ' — $veiculo' : ''} · Diesel ${i.familia}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (i.uf != null) Text(i.uf!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            TabelaSimples(
              colunas: const ['', 'Comum', 'Aditivado'],
              flexColunas: const [2, 3, 3],
              linhas: [
                [
                  'Preço',
                  i.precoComum != null ? 'R\$ ${i.precoComum!.toStringAsFixed(3)}' : '—',
                  i.precoAditivado != null ? 'R\$ ${i.precoAditivado!.toStringAsFixed(3)}' : '—',
                ],
                [
                  'Rendimento',
                  i.rendimentoComum != null ? '${i.rendimentoComum!.toStringAsFixed(2)} km/l' : '—',
                  i.rendimentoAditivado != null ? '${i.rendimentoAditivado!.toStringAsFixed(2)} km/l' : '—',
                ],
                [
                  'Custo/km',
                  i.custoKmComum != null ? 'R\$ ${i.custoKmComum!.toStringAsFixed(4)}' : '—',
                  i.custoKmAditivado != null ? 'R\$ ${i.custoKmAditivado!.toStringAsFixed(4)}' : '—',
                ],
              ],
            ),
            const SizedBox(height: 8),
            rodape,
          ],
        ),
      ),
    );
  }
}
