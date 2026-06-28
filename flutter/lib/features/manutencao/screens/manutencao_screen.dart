import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class ManutencaoScreen extends StatefulWidget {
  const ManutencaoScreen({super.key});
  @override State<ManutencaoScreen> createState() => _State();
}

class _State extends State<ManutencaoScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _manutencoes = [];
  List<dynamic> _statusFrota = [];
  Map<String, dynamic> _resumoStatus = {};
  bool _loading = true;
  bool _loadingStatus = true;
  late TabController _tabCtrl;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
    _loadStatus();
  }
  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/manutencao', params: {'limit': 100});
      setState(() => _manutencoes = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final r = await ApiService().get('/manutencao/status-frota');
      setState(() {
        _statusFrota = r['status'] ?? [];
        _resumoStatus = r['resumo'] ?? {};
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  void _abrirDetalhe(Map m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalheManutencao(manutencao: m, fmt: _fmt),
    );
  }

  Future<void> _novoOuEditar([Map? dados]) async {
    final placaCtrl    = TextEditingController(text: dados?['placa'] ?? '');
    final dataCtrl     = TextEditingController(text: dados?['data_manutencao'] ?? DateTime.now().toIso8601String().substring(0,10));
    final hodCtrl      = TextEditingController(text: dados?['hodometro']?.toString() ?? '');
    final tecnicoCtrl  = TextEditingController(text: dados?['tecnico'] ?? '');
    final oficCtrl     = TextEditingController(text: dados?['oficina'] ?? '');
    final custoCtrl    = TextEditingController(text: dados?['custo_total']?.toString() ?? '');
    final obsCtrl      = TextEditingController(text: dados?['obs_gerais'] ?? '');
    final id = dados?['id'];
    
    const _itensOpcoes = [
      'Troca de óleo e filtro',
      'Revisão de freios',
      'Alinhamento e balanceamento',
      'Troca de pneus',
      'Revisão elétrica',
      'Troca de filtro de ar',
      'Troca de filtro de combustível',
      'Revisão de suspensão',
      'Troca de correia dentada',
      'Revisão do sistema de arrefecimento',
      'Troca de velas',
      'Revisão geral',
      'Troca de pastilhas de freio',
      'Troca de fluido de freio',
      'Revisão de transmissão',
      'Troca de amortecedores',
    ];
    final itensSelecionados = <String>{};


    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(id != null ? 'Editar Manutencao' : 'Nova Manutencao',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
          ),
          const Divider(height: 16),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            _campo(placaCtrl, 'Placa *', caps: TextCapitalization.characters),
            _campo(dataCtrl, 'Data (AAAA-MM-DD)'),
            _campo(hodCtrl, 'Hodometro (km)', tipo: TextInputType.number),
            _campo(tecnicoCtrl, 'Tecnico'),
            _campo(oficCtrl, 'Oficina'),
            _campo(custoCtrl, 'Custo Total (R\$)', tipo: TextInputType.number),
            _campo(obsCtrl, 'Observacoes', maxLines: 3),
            const SizedBox(height: 16),
            const Text('Servicos realizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2D6B))),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (ctx2, setStateLocal) => Wrap(
              spacing: 8, runSpacing: 8,
              children: _itensOpcoes.map((item) {
                final sel = itensSelecionados.contains(item);
                return FilterChip(
                  label: Text(item, style: TextStyle(fontSize: 11, color: sel ? Colors.white : Colors.black87)),
                  selected: sel,
                  onSelected: (v) => setStateLocal(() => v ? itensSelecionados.add(item) : itensSelecionados.remove(item)),
                  selectedColor: const Color(0xFF0D2D6B),
                  backgroundColor: Colors.grey[100],
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (placaCtrl.text.trim().isEmpty) return;
                try {
                  final body = {
                    'placa': placaCtrl.text.toUpperCase().trim(),
                    'data_manutencao': dataCtrl.text.trim(),
                    'hodometro': int.tryParse(hodCtrl.text),
                    'tecnico': tecnicoCtrl.text.trim(),
                    'oficina': oficCtrl.text.trim(),
                    'custo_total': double.tryParse(custoCtrl.text.replaceAll(',','.')),
                    'obs_gerais': obsCtrl.text.trim(),
                    'itens_realizados': itensSelecionados.toList(),
                  };
                  body.removeWhere((k, v) => v == null || v == '');
                  if (id != null) {
                    await ApiService().put('/manutencao/$id', data: body);
                  } else {
                    await ApiService().post('/manutencao', data: body);
                  }
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); _loadStatus(); }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2D6B), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(id != null ? 'Salvar' : 'Registrar', style: const TextStyle(fontSize: 16)),
            )),
          ]))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Manutencao'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'Registros'), Tab(text: 'Status Frota')],
        ),
      ),

      body: TabBarView(controller: _tabCtrl, children: [
        _buildRegistros(),
        _buildStatusFrota(),
      ]),
    );
  }

  Widget _buildRegistros() => _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: _manutencoes.isEmpty
              ? const Center(child: Text('Nenhuma manutencao registrada'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _manutencoes.length,
                  itemBuilder: (_, i) {
                    final m = _manutencoes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFEBEE),
                          child: const Icon(Icons.build, color: Colors.red, size: 20),
                        ),
                        title: Text(m['placa'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${m['data_manutencao'] ?? '-'} · ${m['oficina'] ?? '-'}'),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_fmt.format(m['custo_total'] ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                          Text('${m['hodometro'] ?? 0} km',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ]),
                        onTap: () => _abrirDetalhe(m),
                      ),
                    );
                  }),
        );

  Widget _buildStatusFrota() => _loadingStatus
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _loadStatus,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // Resumo
            Row(children: [
              _cardResumo('Critico', _resumoStatus['critico'] ?? 0, Colors.red),
              const SizedBox(width: 8),
              _cardResumo('Atencao', _resumoStatus['atencao'] ?? 0, Colors.orange),
              const SizedBox(width: 8),
              _cardResumo('OK', _resumoStatus['ok'] ?? 0, Colors.green),
            ]),
            const SizedBox(height: 16),
            ..._statusFrota.map((v) => _cardStatusVeiculo(v)),
          ]),
        );

  Widget _cardResumo(String label, int count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _cardStatusVeiculo(Map v) {
    final status = v['status'] as String? ?? 'ok';
    final cor = status == 'critico' ? Colors.red : status == 'atencao' ? Colors.orange : Colors.green;
    final icon = status == 'critico' ? Icons.warning : status == 'atencao' ? Icons.info : Icons.check_circle;

    return GestureDetector(
      onTap: () => _novoOuEditar({
        'placa': v['placa'],
        'hodometro': v['hodometro_atual'],
      }),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: cor, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v['placa'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(v['motivo'] ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (v['ultima_manutencao'] != null)
            Text('Ultima: ${v["ultima_manutencao"]}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          if ((v['itens_pendentes'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              ...(v['itens_pendentes'] as List).map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(item.toString(),
                    style: const TextStyle(fontSize: 9, color: Colors.orange)),
              )),
            ]),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (v['hodometro_atual'] != null)
            Text('${NumberFormat('#,##0').format(v["hodometro_atual"])} km',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(10)),
            child: Text(status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label,
      {TextInputType tipo = TextInputType.text,
       TextCapitalization caps = TextCapitalization.words,
       int maxLines = 1}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl, keyboardType: tipo,
        textCapitalization: caps, maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      ),
    );
}

class _DetalheManutencao extends StatelessWidget {
  final Map manutencao;
  final NumberFormat fmt;
  const _DetalheManutencao({required this.manutencao, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final m = manutencao;
    final itens = (m['itens_realizados'] as List?)?.cast<String>() ?? [];
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.build, color: Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['placa'] ?? '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
              Text(m['data_manutencao'] ?? '-', style: TextStyle(color: Colors.grey[600])),
            ])),
            Text(fmt.format(m['custo_total'] ?? 0),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
          ]),
        ),
        const Divider(height: 24),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          // Card valores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metrica('Custo', fmt.format(m['custo_total'] ?? 0)),
              _metrica('Hodometro', '${m["hodometro"] ?? 0} km'),
              _metrica('Data', m['data_manutencao'] ?? '-'),
            ]),
          ),
          const SizedBox(height: 16),
          _secao('Responsaveis'),
          _linha('Tecnico', m['tecnico'] ?? '-'),
          _linha('Oficina', m['oficina'] ?? '-'),
          const SizedBox(height: 16),
          if (itens.isNotEmpty) ...[
            _secao('Servicos realizados'),
            ...itens.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
              ]),
            )),
            const SizedBox(height: 16),
          ],
          if (m['obs_gerais'] != null && m['obs_gerais'].toString().isNotEmpty) ...[
            _secao('Observacoes'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2))),
              child: Text(m['obs_gerais'] ?? '', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ])),
      ]),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _linha(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
      Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _metrica(String label, String valor) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    const SizedBox(height: 4),
    Text(valor, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
  ]);
}
