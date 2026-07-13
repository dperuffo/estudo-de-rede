import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/meus_dados_provider.dart';
import '../services/meus_dados_service.dart';

// Fase FLT-2 — "Meus Dados / PIX", porta de minha-empresa/page.tsx (só a
// parte de PIX + dados bancários — nome/CNPJ/endereço do posto já são
// editados em "Meu Posto", `meu_posto_screen.dart`, então aqui são só
// exibidos como referência, somente leitura). Sem o seletor de posto (a
// web mostra um <select> quando o usuário tem mais de um posto Revenda ou
// quando é admin — o shell /posto só resolve UMA empresa atual por vez,
// via `sessao.empresaId`, com troca pelo seletor já existente no shell).
class MeusDadosScreen extends ConsumerWidget {
  const MeusDadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meusDadosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Dados / PIX')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (empresa) {
          if (empresa == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum posto vinculado a este usuário.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          return _MeusDadosConteudo(empresa: empresa);
        },
      ),
    );
  }
}

class _MeusDadosConteudo extends ConsumerStatefulWidget {
  final Map<String, dynamic> empresa;
  const _MeusDadosConteudo({required this.empresa});

  @override
  ConsumerState<_MeusDadosConteudo> createState() => _MeusDadosConteudoState();
}

class _MeusDadosConteudoState extends ConsumerState<_MeusDadosConteudo> {
  late final TextEditingController _pixChave;

  late final TextEditingController _bancoCodigo;
  late final TextEditingController _bancoNome;
  late final TextEditingController _agencia;
  late final TextEditingController _agenciaDigito;
  late final TextEditingController _conta;
  late final TextEditingController _contaDigito;
  String _tipoConta = '';
  late final TextEditingController _titularNome;
  late final TextEditingController _titularDocumento;

  bool _salvandoPix = false;
  String? _erroPix;
  String? _sucessoPix;

  bool _salvandoBancarios = false;
  String? _erroBancarios;
  String? _sucessoBancarios;

  String get _empresaId => widget.empresa['id'] as String;

  String _texto(String chave) => (widget.empresa[chave] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _pixChave = TextEditingController(text: _texto('pix_chave'));
    _bancoCodigo = TextEditingController(text: _texto('banco_codigo'));
    _bancoNome = TextEditingController(text: _texto('banco_nome'));
    _agencia = TextEditingController(text: _texto('agencia'));
    _agenciaDigito = TextEditingController(text: _texto('agencia_digito'));
    _conta = TextEditingController(text: _texto('conta'));
    _contaDigito = TextEditingController(text: _texto('conta_digito'));
    _tipoConta = _texto('tipo_conta');
    _titularNome = TextEditingController(text: _texto('titular_nome'));
    _titularDocumento = TextEditingController(text: _texto('titular_documento'));
  }

  @override
  void dispose() {
    for (final c in [
      _pixChave,
      _bancoCodigo,
      _bancoNome,
      _agencia,
      _agenciaDigito,
      _conta,
      _contaDigito,
      _titularNome,
      _titularDocumento,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvarPix() async {
    setState(() {
      _salvandoPix = true;
      _erroPix = null;
      _sucessoPix = null;
    });
    final erro = await MeusDadosService().atualizarPixChave(empresaId: _empresaId, pixChave: _pixChave.text);
    if (!mounted) return;
    setState(() {
      _salvandoPix = false;
      if (erro != null) {
        _erroPix = erro;
      } else {
        _sucessoPix = 'Chave PIX salva.';
      }
    });
    if (erro == null) ref.invalidate(meusDadosProvider);
  }

  Future<void> _salvarBancarios() async {
    setState(() {
      _salvandoBancarios = true;
      _erroBancarios = null;
      _sucessoBancarios = null;
    });
    final erro = await MeusDadosService().atualizarDadosBancarios(
      empresaId: _empresaId,
      bancoCodigo: _bancoCodigo.text,
      bancoNome: _bancoNome.text,
      agencia: _agencia.text,
      agenciaDigito: _agenciaDigito.text,
      conta: _conta.text,
      contaDigito: _contaDigito.text,
      tipoConta: _tipoConta,
      titularNome: _titularNome.text,
      titularDocumento: _titularDocumento.text,
    );
    if (!mounted) return;
    setState(() {
      _salvandoBancarios = false;
      if (erro != null) {
        _erroBancarios = erro;
      } else {
        _sucessoBancarios = 'Dados bancários salvos.';
      }
    });
    if (erro == null) ref.invalidate(meusDadosProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Posto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Nome/CNPJ/endereço se editam em "Meu Posto". Aqui é só referência.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                _linhaDado('Nome', _texto('nome')),
                _linhaDado('CNPJ', _texto('cnpj')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chave PIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Usada como cedente no boleto/documento de cobrança enviado aos clientes.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pixChave,
                  decoration: const InputDecoration(
                    labelText: 'Chave PIX (CPF, CNPJ, e-mail, telefone ou aleatória)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erroPix != null) ...[const SizedBox(height: 10), _bannerErro(_erroPix!)],
                if (_sucessoPix != null) ...[const SizedBox(height: 10), _bannerSucesso(_sucessoPix!)],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _salvandoPix ? null : _salvarPix,
                    child: Text(_salvandoPix ? 'Salvando...' : 'Salvar chave PIX'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados bancários', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Captura pra uso futuro — ainda não usado em nenhum boleto.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: _bancoCodigo,
                  decoration: const InputDecoration(labelText: 'Código do banco', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bancoNome,
                  decoration: const InputDecoration(labelText: 'Nome do banco', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _agencia,
                        decoration: const InputDecoration(labelText: 'Agência', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _agenciaDigito,
                        decoration: const InputDecoration(labelText: 'Dígito', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _conta,
                        decoration: const InputDecoration(labelText: 'Conta', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _contaDigito,
                        decoration: const InputDecoration(labelText: 'Dígito', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipoConta.isEmpty ? null : _tipoConta,
                  decoration: const InputDecoration(labelText: 'Tipo de conta', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'corrente', child: Text('Corrente')),
                    DropdownMenuItem(value: 'poupanca', child: Text('Poupança')),
                  ],
                  onChanged: (v) => setState(() => _tipoConta = v ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titularNome,
                  decoration: const InputDecoration(labelText: 'Titular da conta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titularDocumento,
                  decoration:
                      const InputDecoration(labelText: 'CPF/CNPJ do titular', border: OutlineInputBorder()),
                ),
                if (_erroBancarios != null) ...[const SizedBox(height: 10), _bannerErro(_erroBancarios!)],
                if (_sucessoBancarios != null) ...[const SizedBox(height: 10), _bannerSucesso(_sucessoBancarios!)],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _salvandoBancarios ? null : _salvarBancarios,
                    child: Text(_salvandoBancarios ? 'Salvando...' : 'Salvar dados bancários'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linhaDado(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(valor.isEmpty ? '—' : valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _bannerErro(String texto) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
      );

  Widget _bannerSucesso(String texto) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
      );
}
