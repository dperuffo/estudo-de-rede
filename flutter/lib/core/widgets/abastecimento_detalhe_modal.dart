import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AbastecimentoDetalheModal {
  static void show(BuildContext context, Map abastecimento) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalheSheet(abastecimento: abastecimento),
    );
  }
}

class _DetalheSheet extends StatefulWidget {
  final Map abastecimento;
  const _DetalheSheet({required this.abastecimento});
  @override State<_DetalheSheet> createState() => _State();
}

class _State extends State<_DetalheSheet> {
  Map<String, dynamic>? _detalhes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.abastecimento['id'];
    if (id == null) {
      setState(() { _detalhes = Map<String, dynamic>.from(widget.abastecimento); _loading = false; });
      return;
    }
    try {
      final r = await ApiService().get('/abastecimentos/$id');
      setState(() { _detalhes = r; _loading = false; });
    } catch (_) {
      setState(() { _detalhes = Map<String, dynamic>.from(widget.abastecimento); _loading = false; });
    }
  }

  void _abrirMapa() async {
    final lat = _detalhes?['pv_latitude'];
    final lon = _detalhes?['pv_longitude'];
    if (lat == null || lon == null) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final d = _detalhes ?? {};

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2D6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_gas_station, color: Color(0xFF0D2D6B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['veiculo_placa'] ?? '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
              Text(d['item_nome'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ])),
            if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (d['pv_latitude'] != null) IconButton(
              icon: const Icon(Icons.map, color: Colors.green),
              onPressed: _abrirMapa,
            ),
          ]),
        ),
        const Divider(height: 24),

        // Conteúdo
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [

                // Card valores principais
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _valorCard('Valor Total', fmt.format(d['item_valor_total'] ?? 0), Colors.white),
                    _valorCard('Litros', '${(d['item_quantidade'] ?? 0).toStringAsFixed(0)} L', Colors.white70),
                    _valorCard('Preco/L', fmt.format(d['item_valor_unitario'] ?? 0), Colors.white70),
                  ]),
                ),
                const SizedBox(height: 16),

                // Informações do abastecimento
                _secao('Abastecimento'),
                _linha('Data', _formatarData(d['data_abastecimento'])),
                _linha('Identificador', d['identificador']?.toString() ?? '-'),
                _linha('Status', d['status_autorizacao'] ?? '-',
                    cor: _corStatus(d['status_autorizacao'])),
                if (d['abastecimento_estornado'] == 1)
                  _linha('Estornado', 'Sim', cor: Colors.red),
                if (d['motivo_recusa'] != null && d['motivo_recusa'].toString().isNotEmpty)
                  _linha('Motivo recusa', d['motivo_recusa']),
                const SizedBox(height: 16),

                // Veículo
                _secao('Veiculo'),
                _linha('Placa', d['veiculo_placa'] ?? '-'),
                if (d['hodometro'] != null && (d['hodometro'] as num) > 0)
                  _linha('Hodometro', '${(d['hodometro'] as num).toStringAsFixed(0)} km'),
                if (d['horimetro'] != null && (d['horimetro'] as num) > 0)
                  _linha('Horimetro', '${(d['horimetro'] as num).toStringAsFixed(0)} h'),
                const SizedBox(height: 16),

                // Motorista
                if (d['motorista_nome'] != null) ...[
                  _secao('Motorista'),
                  _linha('Nome', d['motorista_nome'] ?? '-'),
                  if (d['motorista_id'] != null)
                    _linha('ID', d['motorista_id']?.toString() ?? '-'),
                  const SizedBox(height: 16),
                ],

                // Posto
                _secao('Posto de Abastecimento'),
                _linha('Razao Social', d['pv_razao_social'] ?? '-'),
                _linha('CNPJ', _formatarCnpj(d['pv_cnpj'])),
                _linha('Municipio', '${d['pv_municipio'] ?? '-'}/${d['pv_uf'] ?? '-'}'),
                if (d['pv_posto_interno'] != null)
                  _linha('Posto Interno', d['pv_posto_interno'].toString()),
                if (d['pv_latitude'] != null && d['pv_longitude'] != null)
                  _linhaAcao('Ver no mapa', Icons.map, Colors.green, _abrirMapa),
                const SizedBox(height: 16),

                // Empresa
                if (d['frota_razao_social'] != null) ...[
                  _secao('Empresa'),
                  _linha('Razao Social', d['frota_razao_social'] ?? '-'),
                  const SizedBox(height: 16),
                ],

                // Timestamps
                _secao('Registro'),
                _linha('Importado em', _formatarData(d['importado_em'])),
                _linha('Criado em', _formatarData(d['criado_em'])),
                const SizedBox(height: 32),
              ])),
      ]),
    );
  }

  Widget _secao(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titulo, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.bold,
        color: Color(0xFF0D2D6B), letterSpacing: 0.5)),
  );

  Widget _linha(String label, String valor, {Color? cor}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
      Expanded(child: Text(valor,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: cor ?? Colors.black87))),
    ]),
  );

  Widget _linhaAcao(String label, IconData icon, Color cor, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 16, color: cor),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: cor, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _valorCard(String label, String valor, Color cor) => Column(children: [
    Text(label, style: TextStyle(color: cor.withOpacity(0.7), fontSize: 11)),
    const SizedBox(height: 4),
    Text(valor, style: TextStyle(color: cor, fontSize: 16, fontWeight: FontWeight.bold)),
  ]);

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      final dt = DateTime.parse(data.toString()).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return data.toString(); }
  }

  String _formatarCnpj(dynamic cnpj) {
    if (cnpj == null) return '-';
    final s = cnpj.toString().replaceAll(RegExp(r'\D'), '').padLeft(14, '0');
    if (s.length != 14) return cnpj.toString();
    return '${s.substring(0,2)}.${s.substring(2,5)}.${s.substring(5,8)}/${s.substring(8,12)}-${s.substring(12)}';
  }

  Color _corStatus(dynamic status) {
    if (status == null) return Colors.grey;
    final s = status.toString().toLowerCase();
    if (s.contains('aprovad') || s.contains('autorizado')) return Colors.green;
    if (s.contains('recusad') || s.contains('negado')) return Colors.red;
    if (s.contains('cancel')) return Colors.orange;
    return Colors.grey[700]!;
  }
}
