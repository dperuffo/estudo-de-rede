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
//
// Fase FLT-2 (pedido do Daniel) — além do gate inicial (obrigatório,
// "Camada 3" em app_router.dart), esta tela também é acessível a qualquer
// momento pelo item "Trocar posto"/"Trocar empresa" no menu — a empresa
// atual fica destacada na lista, e dá pra voltar sem trocar (botão de
// voltar, só aparece quando há pra onde voltar).
//
// Fase FLT-4 — mesma tela e mesmo mecanismo (`empresaSelecionadaProvider`)
// reaproveitados pro admin escolher qual cliente ver: `sessao.empresasIds`
// já vem pré-filtrada (AuthService.carregarSessao) com todas as empresas
// segmento Frota quando `ehAdmin`, então nenhuma query nova foi necessária
// aqui — só o texto muda (admin não está "vinculado a um posto", está
// escolhendo entre todos os clientes) e ganhou um campo de busca, já que a
// lista do admin tende a crescer bem mais que a de um grupo econômico.
class SelecionarEmpresaScreen extends ConsumerStatefulWidget {
  const SelecionarEmpresaScreen({super.key});

  @override
  ConsumerState<SelecionarEmpresaScreen> createState() => _SelecionarEmpresaScreenState();
}

class _SelecionarEmpresaScreenState extends ConsumerState<SelecionarEmpresaScreen> {
  Future<List<({String id, String nome})>>? _futuro;
  String _busca = '';

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
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final empresaAtualId = sessao?.empresaId;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(ehAdmin ? 'Selecione o cliente' : 'Selecione o posto'),
        leading: context.canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())
            : null,
      ),
      body: FutureBuilder<List<({String id, String nome})>>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final todas = snap.data!;
          final empresas = _busca.trim().isEmpty
              ? todas
              : todas.where((e) => e.nome.toLowerCase().contains(_busca.trim().toLowerCase())).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                ehAdmin
                    ? 'Escolha qual cliente você quer visualizar. Dá pra trocar a qualquer momento pelo menu.'
                    : 'Seu usuário está vinculado a mais de um posto (Rede de Postos). '
                        'Escolha com qual posto você quer trabalhar agora.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (ehAdmin && todas.length > 6)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar cliente',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busca = v),
                  ),
                ),
              const SizedBox(height: 4),
              if (empresas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhum cliente encontrado.', style: TextStyle(color: Colors.grey.shade500))),
                ),
              ...empresas.map((e) {
                final atual = e.id == empresaAtualId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: atual ? const Color(0xFFEFF6FF) : null,
                  child: ListTile(
                    title: Text(e.nome, style: TextStyle(fontWeight: atual ? FontWeight.bold : FontWeight.normal)),
                    subtitle: atual ? Text(ehAdmin ? 'Cliente atual' : 'Posto atual', style: const TextStyle(color: Color(0xFF1D4ED8))) : null,
                    trailing: atual ? const Icon(Icons.check_circle, color: Color(0xFF1D4ED8)) : const Icon(Icons.chevron_right),
                    onTap: atual
                        ? null
                        : () {
                            ref.read(empresaSelecionadaProvider.notifier).state = e.id;
                            context.go('/');
                          },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
