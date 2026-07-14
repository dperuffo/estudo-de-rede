import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/documentos_empresas_admin_provider.dart';

final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

const _corStatus = {
  'nao_iniciada': Color(0xFF64748B),
  'pendente': Color(0xFFB45309),
  'aprovada': Color(0xFF15803D),
  'rejeitada': Color(0xFFDC2626),
};
const _fundoStatus = {
  'nao_iniciada': Color(0xFFF1F5F9),
  'pendente': Color(0xFFFEF3C7),
  'aprovada': Color(0xFFDCFCE7),
  'rejeitada': Color(0xFFFEE2E2),
};

// Fase FLT-4 — Aprovação de Documentos (admin): fila por status, porta de
// documentos-empresas/page.tsx. Ver escopo em
// documentos_empresas_admin_provider.dart.
class DocumentosEmpresasListaScreen extends ConsumerStatefulWidget {
  const DocumentosEmpresasListaScreen({super.key});

  @override
  ConsumerState<DocumentosEmpresasListaScreen> createState() => _DocumentosEmpresasListaScreenState();
}

class _DocumentosEmpresasListaScreenState extends ConsumerState<DocumentosEmpresasListaScreen> {
  String _status = 'pendente';

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovação de Documentos')),
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
    final contagemAsync = ref.watch(documentosEmpresasContagemProvider);
    final listaAsync = ref.watch(documentosEmpresasListaProvider(_status));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Documentação societária/cadastral enviada por postos e clientes — aprovada, libera criar/aderir '
          'a Redes de Postos ou Grupos Econômicos e aceitar/criar negociações.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        contagemAsync.when(
          data: (contagem) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in statusDocumentacao)
                ChoiceChip(
                  label: Text('${statusDocumentacaoLabel[s] ?? s} (${contagem[s] ?? 0})', style: const TextStyle(fontSize: 12)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 16),
        listaAsync.when(
          data: (lista) {
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhuma empresa com documentação "${(statusDocumentacaoLabel[_status] ?? _status).toLowerCase()}".',
                    style: TextStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Column(children: lista.map(_cardEmpresa).toList());
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        ),
      ],
    );
  }

  Widget _cardEmpresa(EmpresaDocumentacaoResumo e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/documentos-empresas/${e.id}'),
        title: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${e.cnpj ?? '—'} · ${e.segmento == 'Revenda' ? 'Posto' : 'Cliente'}'
                '${e.documentacaoEnviadaEm != null ? ' · Enviada em ${_dataHora.format(DateTime.parse(e.documentacaoEnviadaEm!).toLocal())}' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _fundoStatus[e.documentacaoStatus], borderRadius: BorderRadius.circular(10)),
                child: Text(
                  statusDocumentacaoLabel[e.documentacaoStatus] ?? e.documentacaoStatus,
                  style: TextStyle(fontSize: 10, color: _corStatus[e.documentacaoStatus], fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
