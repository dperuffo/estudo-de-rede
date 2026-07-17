import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/parcerias_locais_provider.dart';
import '../services/parcerias_locais_service.dart';

// Fase PWA-Parcerias-Locais — porta de parcerias-locais/page.tsx. Mesma
// tela pra posto e cliente (ver comentário no provider).
class ParceriasLocaisScreen extends ConsumerStatefulWidget {
  const ParceriasLocaisScreen({super.key});

  @override
  ConsumerState<ParceriasLocaisScreen> createState() => _ParceriasLocaisScreenState();
}

class _ParceriasLocaisScreenState extends ConsumerState<ParceriasLocaisScreen> {
  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final itensAsync = ref.watch(itensParceriaProvider);
    final resgatesAsync = ref.watch(resgatesBeneficiosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🎟️ Parcerias Locais')),
      floatingActionButton: sessao?.empresaId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/parcerias-locais/novo').then((_) => _recarregar()),
              icon: const Icon(Icons.add),
              label: const Text('Novo Benefício'),
            ),
      body: RefreshIndicator(
        onRefresh: () async => _recarregar(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Crie benefícios próprios pro catálogo de fidelidade "Estrada que Cuida" — vale-refeição, lavagem, '
              'treinamentos, telemedicina, o que fizer sentido pro seu negócio. Motoristas de toda a rede enxergam '
              'e resgatam com os pontos que acumulam.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            itensAsync.when(
              data: (itens) => _blocoItens(itens),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar benefícios: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 20),
            if (sessao?.empresaId != null) _QueimarVoucherCard(empresaId: sessao!.empresaId!, onQueimado: _recarregar),
            const SizedBox(height: 20),
            resgatesAsync.when(
              data: (resgates) => _blocoResgates(resgates),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar resgates: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recarregar() {
    ref.invalidate(itensParceriaProvider);
    ref.invalidate(resgatesBeneficiosProvider);
  }

  Widget _blocoItens(List<ItemParceria> itens) {
    if (itens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Nenhum benefício criado ainda. Toque em "Novo Benefício" pra começar.',
              style: TextStyle(color: Colors.black45)),
        ),
      );
    }
    return Column(
      children: itens.map((item) => _CardItemParceria(item: item, onAlterado: _recarregar)).toList(),
    );
  }

  Widget _blocoResgates(List<ResgateBeneficio> resgates) {
    final kpis = calcularKpisParceriasLocais(resgates);
    final pendentes = resgates.where((r) => r.status == 'solicitado' || r.status == 'em_andamento').toList();
    final queimados = resgates.where((r) => r.status == 'concluido').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _kpiCard('Pendentes', '${kpis.pendentes}')),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard('Queimados', '${kpis.queimados}')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _kpiCard('Pontos queimados', '${kpis.pontosQueimados}')),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard('Cancelados', '${kpis.cancelados}')),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Pendentes de atendimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        if (pendentes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum voucher pendente de atendimento.', style: TextStyle(color: Colors.black45)),
          )
        else
          ...pendentes.map((r) => _CardResgate(resgate: r, onAlterado: _recarregar)),
        const SizedBox(height: 20),
        const Text('🔥 Vouchers queimados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        if (queimados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum voucher queimado ainda.', style: TextStyle(color: Colors.black45)),
          )
        else
          ...queimados.map((r) => _CardResgate(resgate: r, onAlterado: _recarregar)),
      ],
    );
  }

  Widget _kpiCard(String label, String valor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}

class _CardItemParceria extends ConsumerWidget {
  final ItemParceria item;
  final VoidCallback onAlterado;
  const _CardItemParceria({required this.item, required this.onAlterado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imagemUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(item.imagemUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(labelCategoriaFidelidade[item.categoria] ?? item.categoria,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (item.descricao != null) ...[
              const SizedBox(height: 4),
              Text(item.descricao!, style: const TextStyle(fontSize: 12.5)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${item.pontosNecessarios} pontos', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.ativo ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(fontSize: 11, color: item.ativo ? Colors.green.shade700 : Colors.black54)),
                ),
              ],
            ),
            Text(
              item.validadeDias != null ? 'Válido por ${item.validadeDias} dias' : 'Sem validade',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            const Divider(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => context.push('/parcerias-locais/${item.id}/editar').then((_) => onAlterado()),
                  child: const Text('Editar'),
                ),
                TextButton(
                  onPressed: () async {
                    await ParceriasLocaisService().alternarAtivo(item.id, !item.ativo);
                    onAlterado();
                  },
                  child: Text(item.ativo ? 'Desativar' : 'Ativar'),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmou = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Excluir benefício'),
                        content: Text('Excluir "${item.titulo}"? Essa ação não pode ser desfeita.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
                        ],
                      ),
                    );
                    if (confirmou == true) {
                      await ParceriasLocaisService().excluir(item.id);
                      onAlterado();
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _labelStatusResgate = {
  'solicitado': 'Solicitado',
  'em_andamento': 'Em andamento',
  'concluido': 'Queimado',
  'cancelado': 'Cancelado',
};

class _CardResgate extends StatelessWidget {
  final ResgateBeneficio resgate;
  final VoidCallback onAlterado;
  const _CardResgate({required this.resgate, required this.onAlterado});

  @override
  Widget build(BuildContext context) {
    final podeAlterar = resgate.status == 'solicitado' || resgate.status == 'em_andamento';
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
                  child: Text(resgate.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                Text('${resgate.pontosGastos} pts', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            Text('Motorista: ${resgate.nomeMotorista}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (resgate.numeroVoucher != null)
              Text('Voucher: ${resgate.numeroVoucher}',
                  style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Colors.black45)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_labelStatusResgate[resgate.status] ?? resgate.status,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (podeAlterar)
                  DropdownButton<String>(
                    value: resgate.status,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'solicitado', enabled: false, child: Text('Solicitado')),
                      DropdownMenuItem(value: 'em_andamento', child: Text('Em andamento')),
                      DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                    ],
                    onChanged: (novo) async {
                      if (novo == null || novo == resgate.status) return;
                      await ParceriasLocaisService().atualizarStatusResgate(resgate.id, novo);
                      onAlterado();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueimarVoucherCard extends StatefulWidget {
  final String empresaId;
  final VoidCallback onQueimado;
  const _QueimarVoucherCard({required this.empresaId, required this.onQueimado});

  @override
  State<_QueimarVoucherCard> createState() => _QueimarVoucherCardState();
}

class _QueimarVoucherCardState extends State<_QueimarVoucherCard> {
  final _controller = TextEditingController();
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _queimar() async {
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      final resultado =
          await ParceriasLocaisService().queimarVoucher(empresaId: widget.empresaId, codigo: _controller.text);
      setState(() {
        _sucesso = 'Voucher "${resultado.titulo}" entregue a ${resultado.motorista}.';
        _controller.clear();
      });
      widget.onQueimado();
    } catch (e) {
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Queimar voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Digite o código exibido no app do motorista pra dar baixa no voucher.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Código do voucher', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(88, 48)),
                  onPressed: _enviando ? null : _queimar,
                  child: Text(_enviando ? '...' : 'Queimar'),
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 6),
              Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_sucesso != null) ...[
              const SizedBox(height: 6),
              Text(_sucesso!, style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
