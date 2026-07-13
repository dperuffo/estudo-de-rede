import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rede_posto_provider.dart';
import '../services/rede_postos_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/rede-postos/novo/page.tsx +
// NovaRedeForm.tsx. Escopo reduzido: aqui só existe o caminho self-service
// (posto criando a própria Rede) — o caminho admin (escolher qualquer posto
// Revenda como fundador) não se aplica, porque o Flutter só existe pro
// shell /posto.
class NovaRedeScreen extends ConsumerStatefulWidget {
  const NovaRedeScreen({super.key});

  @override
  ConsumerState<NovaRedeScreen> createState() => _NovaRedeScreenState();
}

class _NovaRedeScreenState extends ConsumerState<NovaRedeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  String? _empresaFundadoraId;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_empresaFundadoraId == null) {
      setState(() => _erro = 'Selecione o posto fundador.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final resultado = await RedePostosService().criarRede(
      nome: _nomeCtrl.text,
      cnpjMatriz: _cnpjCtrl.text,
      empresaId: _empresaFundadoraId!,
    );

    if (!mounted) return;
    if (resultado.erro != null) {
      setState(() {
        _salvando = false;
        _erro = resultado.erro;
      });
      return;
    }

    ref.invalidate(redePostoProvider);
    context.pushReplacement('/posto/rede-postos');
  }

  @override
  Widget build(BuildContext context) {
    final postosAsync = ref.watch(postosProprioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nova Rede de Postos')),
      body: postosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (postos) {
          if (postos.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Você precisa ter um posto cadastrado antes de criar uma Rede de Postos. '
                'Cadastre em "Meu Posto" e volte aqui em seguida.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          _empresaFundadoraId ??= postos.first.id;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_erro != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C))),
                  ),
                const Text('Posto fundador *', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _empresaFundadoraId,
                  items: postos
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _empresaFundadoraId = v),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Você poderá vincular outros postos a esta Rede depois de criá-la.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Nome da Rede *', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                const Text('CNPJ da Matriz (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cnpjCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: Text(_salvando ? 'Salvando...' : 'Salvar Rede'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
