import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override State<AdminScreen> createState() => _State();
}

class _State extends State<AdminScreen> {
  List<dynamic> _usuarios = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/admin/usuarios');
      setState(() => _usuarios = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAtivo(String email, bool ativo) async {
    try {
      await ApiService().put('/admin/usuarios/$email', data: {'ativo': !ativo});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  String _inicial(Map u) {
    final nome = (u['nome'] ?? '').toString().trim();
    final email = (u['email'] ?? '').toString().trim();
    if (nome.isNotEmpty) return nome[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final cores = {'admin': Colors.red, 'analista': Colors.blue,
                   'gestor_frota': Colors.green, 'posto': Colors.orange};
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Admin — Usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoUsuario,
        child: const Icon(Icons.person_add),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _usuarios.isEmpty
              ? const Center(child: Text('Nenhum usuario encontrado'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usuarios.length,
                  itemBuilder: (_, i) {
                    final u = _usuarios[i];
                    final cor = cores[u['perfil']] ?? Colors.grey;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cor.withOpacity(0.15),
                          child: Text(_inicial(u),
                              style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          (u['nome'] ?? u['email'] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${u["email"] ?? "-"}\n${u["perfil"] ?? "-"}'),
                        isThreeLine: true,
                        trailing: Switch(
                          value: u['ativo'] == true,
                          onChanged: (_) => _toggleAtivo(u['email'] ?? '', u['ativo'] == true),
                        ),
                      ),
                    );
                  },
                )),
    );
  }

  Future<void> _novoUsuario() async {
    final emailCtrl = TextEditingController();
    final nomeCtrl  = TextEditingController();
    String perfil = 'gestor_frota';
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Novo Usuario'),
      content: StatefulBuilder(builder: (ctx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: nomeCtrl,  decoration: const InputDecoration(labelText: 'Nome')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: perfil,
          items: ['admin','analista','gestor_frota','posto']
              .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setSt(() => perfil = v!),
          decoration: const InputDecoration(labelText: 'Perfil'),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            try {
              await ApiService().post('/admin/usuarios', data: {
                'email': emailCtrl.text.toLowerCase().trim(),
                'nome': nomeCtrl.text.trim(),
                'perfil': perfil,
                'ativo': true,
              });
              if (mounted) { Navigator.pop(context); _load(); }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
          child: const Text('Criar'),
        ),
      ],
    ));
  }
}
