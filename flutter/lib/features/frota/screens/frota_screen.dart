import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class FrotaScreen extends StatefulWidget {
  const FrotaScreen({super.key});
  @override State<FrotaScreen> createState() => _State();
}

class _State extends State<FrotaScreen> {
  List<dynamic> _veiculos = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get(ApiConstants.frotaVeiculos);
      setState(() => _veiculos = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const MenuButton(),title: Text('Frota (${_veiculos.length} veiculos)')),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _veiculos.length,
            itemBuilder: (_, i) {
              final v = _veiculos[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.directions_car, color: Colors.orange),
                  ),
                  title: Text(v['veiculo_placa'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(v['combustivel'] ?? '-'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(v["ultimo_hodometro"] ?? 0).toStringAsFixed(0)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${v["n_abastecimentos"]} abast.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  onTap: () => context.go('/veiculos'),
                ),
              );
            },
          )),
  );
}
