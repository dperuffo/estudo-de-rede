import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/postos_duplicados_provider.dart';
import '../services/postos_duplicados_service.dart';

final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

// Fase FLT-4 — Possíveis Duplicados (Postos, admin), porta de
// postos-duplicados/page.tsx + _components/BotoesDuplicata.tsx. Ver
// escopo completo em postos_duplicados_provider.dart.
class PostosDuplicadosScreen extends ConsumerStatefulWidget {
  const PostosDuplicadosScreen({super.key});

  @override
  ConsumerState<PostosDuplicadosScreen> createState() => _PostosDuplicadosScreenState();
}

class _PostosDuplicadosScreenState extends ConsumerState<PostosDuplicadosScreen> {
  final Set<String> _enviando = {};
  final Map<String, String> _resolvidos = {}; // id -> 'descartado' | 'confirmado_duplicata'
  final Map<String, String> _erros = {};

  Future<void> _descartar(String id) async {
    await _decidir(id, (svc, email) => svc.descartar(id: id, revisadoPor: email), 'descartado');
  }

  Future<void> _confirmar(String id) async {
    await _decidir(id, (svc, email) => svc.confirmar(id: id, revisadoPor: email), 'confirmado_duplicata');
  }

  Future<void> _decidir(
    String id,
    Future<String?> Function(PostosDuplicadosService, String) acao,
    String resultado,
  ) async {
    setState(() {
      _enviando.add(id);
      _erros.remove(id);
    });
    final sessao = await ref.read(sessaoProvider.future);
    final erro = await acao(PostosDuplicadosService(), sessao.email);
    if (!mounted) return;
    setState(() {
      _enviando.remove(id);
      if (erro != null) {
        _erros[id] = erro;
      } else {
        _resolvidos[id] = resultado;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Possíveis Duplicados')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acesso restrito', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 8),
              Text('Esta tela é exclusiva do time interno (perfil administrador).', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final listaAsync = ref.watch(postosDuplicadosProvider);

    return listaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (lista) {
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum possível duplicado pendente de revisão.', style: TextStyle(color: Colors.grey))),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Postos que se auto-cadastraram em "Meu Posto" com endereço/coordenadas muito próximos de '
              'outro posto já existente, mas com CNPJ diferente. O cadastro já foi salvo normalmente — decida '
              'se é mesmo o mesmo estabelecimento (duplicata) ou dois postos legitimamente vizinhos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...lista.map(_cardDuplicata),
          ],
        );
      },
    );
  }

  Widget _cardDuplicata(PossivelDuplicata d) {
    final resolvido = _resolvidos[d.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('POSTO RECÉM-CADASTRADO', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(d.empresaNome ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('CNPJ: ${d.cnpjInformado ?? '—'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('POSSÍVEL DUPLICATA (${d.candidato?.fonte ?? '—'})',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(d.candidato?.razaoSocial ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                        'CNPJ: ${d.candidato?.cnpj ?? '—'}'
                        '${d.candidato?.municipio != null ? ' — ${d.candidato!.municipio}/${d.candidato!.uf ?? ''}' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distância estimada: ${d.distanciaMetros != null ? '${d.distanciaMetros} m' : '—'} · '
              'Sinalizado em ${d.criadoEm != null ? _dataHora.format(DateTime.parse(d.criadoEm!).toLocal()) : '—'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            if (resolvido == 'descartado')
              const Text('✓ Descartado — não é duplicata.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))
            else if (resolvido == 'confirmado_duplicata')
              const Text('✓ Confirmado como duplicata.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)))
            else ...[
              if (_erros[d.id] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(_erros[d.id]!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _enviando.contains(d.id) ? null : () => _descartar(d.id),
                    child: const Text('Não é duplicata'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _enviando.contains(d.id) ? null : () => _confirmar(d.id),
                    child: const Text('Confirmar duplicata'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
