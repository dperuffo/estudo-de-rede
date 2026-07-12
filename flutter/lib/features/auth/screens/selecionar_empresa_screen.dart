import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 (achado real) — quando o usuário está vinculado a 2+ empresas
// (Rede de Postos/grupo econômico), a "empresa atual" não pode ser
// escolhida sozinha (ver comentário em sessao_provider.dart) — precisa de
// seleção explícita, mesmo espírito do seletor "Empresa" que já existe em
// várias telas da web (clientes-posto/page.tsx, precos-postos/page.tsx
// etc.), só que centralizado aqui numa tela própria em vez de repetido em
// cada uma.
class SelecionarEmpresaScreen extends ConsumerStatefulWidget {
  const SelecionarEmpresaScreen({super.key});

  @override
  ConsumerState<SelecionarEmpresaScreen> createState() => _SelecionarEmpresaScreenState();
}

class _SelecionarEmpresaScreenState extends ConsumerState<SelecionarEmpresaScreen> {
  Future<List<({String id, String nome})>>? _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<List<({String id, String nome})>> _carregar() async {
    final sessao = await ref.read(sessaoProvider.future);
    if (sessao.empresasIds.isEmpty) return [];
    final rows = await SupabaseService.client
        .from('empresas')
        .select('id, nome')
        .inFilter('id', sessao.empresasIds)
        .order('nome');
    return rows.map((m) => (id: m['id'] as String, nome: m['nome'] as String? ?? '—')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecione a empresa')),
      body: FutureBuilder<List<({String id, String nome})>>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final empresas = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Seu usuário está vinculado a mais de uma empresa (Rede de Postos). '
                'Escolha com qual empresa você quer trabalhar agora.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...empresas.map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.nome),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref.read(empresaSelecionadaProvider.notifier).state = e.id;
                      context.go('/');
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
