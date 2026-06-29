import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/date_helper.dart';

class VeiculoDetalheModal {
  static void show(BuildContext context, String placa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VeiculoSheet(placa: placa),
    );
  }
}

class _VeiculoSheet extends StatefulWidget {
  final String placa;
  const _VeiculoSheet({required this.placa});
  @override State<_VeiculoSheet> createState() => _State();
}

class _State extends State<_VeiculoSheet> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await ApiService().get('/veiculos/${widget.placa}/detalhe');
      setState(() { _dados = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadastro = _dados?['cadastro'] as Map? ?? {};
    final fipe     = _dados?['fipe']     as Map? ?? {};
    final ultAbast = _dados?['ultimo_abastecimento'] as Map? ?? {};
    final resAbast = _dados?['resumo_abastecimentos_30d'] as Map? ?? {};
    final ultManut = _dados?['ultima_manutencao'] as Map? ?? {};
    final totalManut = (_dados?['total_manutencao_30d'] as num? ?? 0).toDouble();

    final marca  = cadastro['marca']  ?? fipe['marca']  ?? '-';
    final modelo = cadastro['modelo'] ?? fipe['modelo'] ?? '-';
    final ano    = cadastro['ano_modelo'] ?? fipe['ano_modelo'] ?? '';
    final cor    = cadastro['cor']    ?? fipe['cor']    ?? '';
    final comb   = cadastro['combustivel'] ?? fipe['combustivel_fipe'] ?? '';
    final valorFipe = (fipe['valor_fipe'] as num?)?.toDouble();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),

        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.placa, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              if (marca != '-') Text('$marca ${modelo != '-' ? modelo : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (ano.isNotEmpty || cor.isNotEmpty)
                Text('${ano.isNotEmpty ? ano : ''} ${cor.isNotEmpty ? "· $cor" : ""}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            if (valorFipe != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('FIPE', style: TextStyle(color: Colors.white60, fontSize: 10)),
              Text(fmt.format(valorFipe),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),

        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [

              // KPIs 30 dias
              if (resAbast.isNotEmpty) ...[
                _secao('Ultimos 30 dias'),
                Row(children: [
                  _kpi('Abastecimentos', '${resAbast["n_abastecimentos"] ?? 0}', Colors.blue),
                  const SizedBox(width: 8),
                  _kpi('Gasto Comb.', fmt.format(resAbast['total_gasto'] ?? 0), Colors.green),
                  const SizedBox(width: 8),
                  _kpi('Litros', '${(resAbast["total_litros"] ?? 0).toStringAsFixed(0)} L', Colors.cyan),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpi('Preco Medio/L', fmt.format(resAbast['preco_medio'] ?? 0), Colors.orange),
                  const SizedBox(width: 8),
                  _kpi('Manutencao', fmt.format(totalManut), Colors.red),
                  const SizedBox(width: 8),
                  _kpi('Total Geral', fmt.format((resAbast['total_gasto'] as num? ?? 0) + totalManut), const Color(0xFF0D2D6B)),
                ]),
                const SizedBox(height: 16),
              ],

              // Dados do veículo
              if (cadastro.isNotEmpty || fipe.isNotEmpty) ...[
                _secao('Dados do Veiculo'),
                if (marca != '-') _linha('Marca', marca),
                if (modelo != '-') _linha('Modelo', modelo),
                if (ano.isNotEmpty) _linha('Ano', ano),
                if (cor.isNotEmpty) _linha('Cor', cor),
                if (comb.isNotEmpty) _linha('Combustivel', comb),
                if (cadastro['chassi'] != null) _linha('Chassi', cadastro['chassi']),
                if (cadastro['renavam'] != null) _linha('RENAVAM', cadastro['renavam']),
                if (cadastro['hodometro_atual'] != null)
                  _linha('Hodometro', '${NumberFormat("#,##0").format(cadastro["hodometro_atual"])} km'),
                const SizedBox(height: 16),
              ],

              // FIPE
              if (fipe.isNotEmpty) ...[
                _secao('Tabela FIPE'),
                if (fipe['codigo_fipe'] != null) _linha('Codigo FIPE', fipe['codigo_fipe']),
                if (fipe['valor_fipe'] != null) _linha('Valor FIPE', fmt.format(fipe['valor_fipe'])),
                if (fipe['mes_referencia'] != null) _linha('Referencia', fipe['mes_referencia']),
                const SizedBox(height: 16),
              ],

              // Último abastecimento
              if (ultAbast.isNotEmpty) ...[
                _secao('Ultimo Abastecimento'),
                _linha('Data', dataBr(ultAbast['data_abastecimento'], comHora: true)),
                _linha('Combustivel', ultAbast['item_nome'] ?? '-'),
                _linha('Litros', '${(ultAbast["item_quantidade"] ?? 0).toStringAsFixed(1)} L'),
                _linha('Valor', fmt.format(ultAbast['item_valor_total'] ?? 0)),
                _linha('Preco/L', fmt.format(ultAbast['item_valor_unitario'] ?? 0)),
                if (ultAbast['hodometro'] != null && (ultAbast['hodometro'] as num) > 0)
                  _linha('Hodometro', '${NumberFormat("#,##0").format(ultAbast["hodometro"])} km'),
                _linha('Posto', '${ultAbast["pv_razao_social"] ?? "-"}'),
                _linha('Local', '${ultAbast["pv_municipio"] ?? "-"}/${ultAbast["pv_uf"] ?? "-"}'),
                const SizedBox(height: 16),
              ],

              // Última manutenção
              if (ultManut.isNotEmpty) ...[
                _secao('Ultima Manutencao'),
                _linha('Data', dataBr(ultManut['data_manutencao'])),
                _linha('Oficina', ultManut['oficina'] ?? '-'),
                _linha('Custo', fmt.format(ultManut['custo_total'] ?? 0)),
                if (ultManut['hodometro'] != null)
                  _linha('Hodometro', '${NumberFormat("#,##0").format(ultManut["hodometro"])} km'),
                if ((ultManut['itens_realizados'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  const Text('Servicos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ...(ultManut['itens_realizados'] as List).map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(children: [
                      const Icon(Icons.check, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(item.toString(), style: const TextStyle(fontSize: 12)),
                    ]),
                  )),
                ],
              ],
            ])),
      ]),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _linha(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
      Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}
