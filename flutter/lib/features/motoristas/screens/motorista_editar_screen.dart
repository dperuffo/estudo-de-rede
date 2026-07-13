import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/motoristas_provider.dart';
import '../services/motoristas_service.dart';

final _dataIso = DateFormat('yyyy-MM-dd');

// Fase FLT-3 — editar motorista existente + ativar/inativar, porta de
// MotoristaForm.tsx (modo edição). Sem troca de cliente (fixo, igual à
// web: "não pode ser alterado aqui").
class MotoristaEditarScreen extends ConsumerStatefulWidget {
  final String id;
  const MotoristaEditarScreen({super.key, required this.id});

  @override
  ConsumerState<MotoristaEditarScreen> createState() => _MotoristaEditarScreenState();
}

class _MotoristaEditarScreenState extends ConsumerState<MotoristaEditarScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cnhCtrl = TextEditingController();
  final _cnhVencCtrl = TextEditingController();
  String _classificacao = 'Próprio';
  String? _centroCustoId;
  bool _ativo = true;
  bool _inicializado = false;
  bool _salvando = false;
  String? _erro;
  String? _sucesso;

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

  void _inicializar(Motorista m) {
    if (_inicializado) return;
    _inicializado = true;
    _nomeCtrl.text = m.nomeCompleto;
    _cpfCtrl.text = m.cpf;
    _telefoneCtrl.text = m.telefone ?? '';
    _emailCtrl.text = m.email ?? '';
    _cnhCtrl.text = m.cnh ?? '';
    _cnhVencCtrl.text = m.cnhVencimento ?? '';
    _classificacao = m.classificacao;
    _centroCustoId = m.centroCustoId;
    _ativo = m.ativo;
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
      _salvando = true;
      _erro = null;
      _sucesso = null;
    });
    final erro = await MotoristasService().atualizarMotorista(
      id: widget.id,
      empresaId: empresaId,
      nomeCompleto: _nomeCtrl.text,
      cpf: _cpfCtrl.text,
      telefone: _telefoneCtrl.text,
      email: _emailCtrl.text,
      classificacao: _classificacao,
      cnh: _cnhCtrl.text,
      cnhVencimento: _cnhVencCtrl.text,
      centroCustoId: _centroCustoId,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) {
        _erro = erro;
      } else {
        _sucesso = 'Salvo.';
      }
    });
    if (erro == null) ref.invalidate(motoristasClienteProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(motoristaDetalheProvider(widget.id));
    final centrosAsync = ref.watch(centrosCustoOpcoesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar motorista')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (m) {
          if (m == null) return const Center(child: Text('Motorista não encontrado.'));
          _inicializar(m);
          return ListView(
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
              ),
              const SizedBox(height: 10),
              centrosAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (centros) {
                  if (centros.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    value: centros.any((c) => c.id == _centroCustoId) ? _centroCustoId : null,
                    decoration: const InputDecoration(labelText: 'Centro de custo', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Nenhum')),
                      ...centros.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome))),
                    ],
                    onChanged: (v) => setState(() => _centroCustoId = v),
                  );
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
                title: const Text('Motorista ativo'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                ),
              ],
              if (_sucesso != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: Text(_sucesso!, style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
