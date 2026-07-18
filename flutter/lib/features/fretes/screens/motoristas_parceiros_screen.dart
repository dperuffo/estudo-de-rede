import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/fretes_provider.dart';
import '../services/motoristas_parceiros_service.dart';
import 'chips_reputacao_motorista.dart';

// Fase PWA-Fretes — porta de motoristas-parceiros/page.tsx: busca por
// CPF/telefone + convite + tabela de status.
class MotoristasParceirosScreen extends ConsumerWidget {
  const MotoristasParceirosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final empresaId = sessao?.empresaId;
    final parceirosAsync = ref.watch(parceirosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Motoristas Parceiros')),
      body: empresaId == null
          ? const Center(child: Text('Selecione uma empresa primeiro.'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(parceirosProvider),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Motoristas agregados/terceiros com quem você já tem relação — convide pra poder atribuir frete '
                    'direto a eles, sem abrir pro mercado aberto.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _FormConvidarParceiro(empresaId: empresaId, onConvidado: () => ref.invalidate(parceirosProvider)),
                  const SizedBox(height: 20),
                  const Text('Parceiros', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  parceirosAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Erro: $e'),
                    data: (parceiros) {
                      if (parceiros.isEmpty) return const Text('Nenhum parceiro convidado ainda.', style: TextStyle(color: Colors.black45));
                      return Column(children: parceiros.map((p) => _CardParceiro(parceiro: p)).toList());
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _CardParceiro extends StatelessWidget {
  final ParceiroRow parceiro;
  const _CardParceiro({required this.parceiro});

  static const _labelStatus = {
    'convidado': 'Convidado (aguardando resposta)',
    'ativo': 'Ativo',
    'recusado': 'Recusou o convite',
    'removido': 'Removido',
  };

  @override
  Widget build(BuildContext context) {
    final cor = switch (parceiro.status) {
      'ativo' => Colors.green,
      'convidado' => Colors.orange,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          title: Text(parceiro.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parceiro.telefone ?? '—'),
                const SizedBox(height: 4),
                ChipsReputacaoMotorista(reputacao: parceiro.reputacao),
              ],
            ),
          ),
          isThreeLine: true,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(
              _labelStatus[parceiro.status] ?? parceiro.status,
              style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormConvidarParceiro extends StatefulWidget {
  final String empresaId;
  final VoidCallback onConvidado;
  const _FormConvidarParceiro({required this.empresaId, required this.onConvidado});

  @override
  State<_FormConvidarParceiro> createState() => _FormConvidarParceiroState();
}

class _FormConvidarParceiroState extends State<_FormConvidarParceiro> {
  final _documentoCtrl = TextEditingController();
  bool _buscando = false;
  bool _convidando = false;
  bool _convidado = false;
  String? _erro;
  MotoristaEncontrado? _encontrado;

  @override
  void dispose() {
    _documentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _erro = null;
      _encontrado = null;
      _convidado = false;
    });
    final resultado = await MotoristasParceirosService().buscarMotoristaPorDocumento(_documentoCtrl.text);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _erro = resultado.erro;
      _encontrado = resultado.encontrado;
    });
  }

  Future<void> _convidar() async {
    final encontrado = _encontrado;
    if (encontrado == null) return;
    setState(() {
      _convidando = true;
      _erro = null;
    });
    final erro = await MotoristasParceirosService().convidarParceiro(empresaId: widget.empresaId, motoristaId: encontrado.motoristaId);
    if (!mounted) return;
    setState(() {
      _convidando = false;
      _erro = erro;
      _convidado = erro == null;
    });
    if (erro == null) widget.onConvidado();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Convidar motorista parceiro', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Busque pelo CPF ou telefone — o motorista precisa já ter conta no app "Estrada que Cuida". Ele recebe o '
              'convite lá e decide se aceita entrar na sua rede.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _documentoCtrl,
                    decoration: const InputDecoration(labelText: 'CPF ou telefone', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Buscar'),
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_encontrado != null && !_convidado) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_encontrado!.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(_encontrado!.telefone ?? 'sem telefone cadastrado', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _convidando ? null : _convidar,
                      child: Text(_convidando ? 'Convidando...' : 'Convidar'),
                    ),
                  ],
                ),
              ),
            ],
            if (_convidado) ...[
              const SizedBox(height: 10),
              const Text('Convite enviado! Aparece como "Convidado" até o motorista responder.', style: TextStyle(color: Colors.green, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}
