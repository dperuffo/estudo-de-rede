import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/motoristas_provider.dart';
import '../services/motoristas_service.dart';

final _dataIso = DateFormat('yyyy-MM-dd');

// Fase FLT-3 — cadastrar novo motorista, porta de MotoristaForm.tsx (modo
// criação). Sem seletor de "Cliente" (a web deixa admin escolher; aqui é
// sempre a empresa atual da sessão).
class MotoristaNovoScreen extends ConsumerStatefulWidget {
  const MotoristaNovoScreen({super.key});

  @override
  ConsumerState<MotoristaNovoScreen> createState() => _MotoristaNovoScreenState();
}

class _MotoristaNovoScreenState extends ConsumerState<MotoristaNovoScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cnhCtrl = TextEditingController();
  final _cnhVencCtrl = TextEditingController();
  String _classificacao = 'Próprio';
  String? _centroCustoId;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _cnhCtrl.dispose();
    _cnhVencCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_cnhVencCtrl.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => _cnhVencCtrl.text = _dataIso.format(escolhida));
    }
  }

  Future<void> _salvar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    final resultado = await MotoristasService().criarMotorista(
      empresaId: empresaId,
      nomeCompleto: _nomeCtrl.text,
      cpf: _cpfCtrl.text,
      telefone: _telefoneCtrl.text,
      email: _emailCtrl.text,
      classificacao: _classificacao,
      cnh: _cnhCtrl.text,
      cnhVencimento: _cnhVencCtrl.text,
      centroCustoId: _centroCustoId,
    );

    if (!mounted) return;
    if (resultado.erro != null) {
      setState(() {
        _enviando = false;
        _erro = resultado.erro;
      });
      return;
    }

    ref.invalidate(motoristasClienteProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final centrosAsync = ref.watch(centrosCustoOpcoesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo motorista')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome completo *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cpfCtrl,
            decoration: const InputDecoration(labelText: 'CPF *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _telefoneCtrl,
            decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _classificacao,
            decoration: const InputDecoration(labelText: 'Classificação', border: OutlineInputBorder()),
            items: classificacoesMotorista.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _classificacao = v ?? 'Próprio'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cnhCtrl,
            decoration: const InputDecoration(labelText: 'CNH (número)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cnhVencCtrl,
            readOnly: true,
            onTap: _selecionarData,
            decoration: const InputDecoration(
              labelText: 'CNH — vencimento',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          centrosAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (centros) {
              if (centros.isEmpty) return const SizedBox.shrink();
              return DropdownButtonFormField<String>(
                value: _centroCustoId,
                decoration: const InputDecoration(labelText: 'Centro de custo', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhum')),
                  ...centros.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome))),
                ],
                onChanged: (v) => setState(() => _centroCustoId = v),
              );
            },
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _enviando ? null : _salvar,
              child: Text(_enviando ? 'Salvando...' : 'Cadastrar motorista'),
            ),
          ),
        ],
      ),
    );
  }
}
