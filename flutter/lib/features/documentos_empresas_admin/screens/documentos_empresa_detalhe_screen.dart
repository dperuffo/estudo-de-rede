import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/documentos_empresas_admin_provider.dart';
import '../services/documentos_empresas_admin_service.dart';

// Fase FLT-4 — Aprovação de Documentos (admin): detalhe de uma empresa +
// painel de decisão, porta de documentos-empresas/[id]/page.tsx +
// _components/PainelRevisao.tsx. Ver escopo em
// documentos_empresas_admin_provider.dart.
class DocumentosEmpresaDetalheScreen extends ConsumerStatefulWidget {
  final String empresaId;
  const DocumentosEmpresaDetalheScreen({super.key, required this.empresaId});

  @override
  ConsumerState<DocumentosEmpresaDetalheScreen> createState() => _DocumentosEmpresaDetalheScreenState();
}

class _DocumentosEmpresaDetalheScreenState extends ConsumerState<DocumentosEmpresaDetalheScreen> {
  final _motivoCtrl = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _decidir(String decisao) async {
    setState(() => _erro = null);
    final sessao = await ref.read(sessaoProvider.future);
    setState(() => _enviando = true);
    try {
      await DocumentosEmpresasAdminService().revisar(
        empresaId: widget.empresaId,
        decisao: decisao,
        motivo: _motivoCtrl.text,
        revisadoPor: sessao.email,
      );
      ref.invalidate(documentacaoEmpresaDetalheProvider(widget.empresaId));
      ref.invalidate(documentosEmpresasContagemProvider);
      ref.invalidate(documentosEmpresasListaProvider);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar Documentação')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Esta tela é exclusiva do time interno (perfil administrador).', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final detalheAsync = ref.watch(documentacaoEmpresaDetalheProvider(widget.empresaId));
    return detalheAsync.when(
      data: (d) {
        if (d == null) return const Center(child: Text('Empresa não encontrada.'));
        return _corpo(d);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }

  Widget _corpo(EmpresaDocumentacaoDetalhe d) {
    final situacao = d.situacao;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(d.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          'CNPJ ${d.cnpj ?? '—'} · ${d.segmento == 'Revenda' ? 'Posto' : 'Cliente'} · '
          'Status: ${statusDocumentacaoLabel[situacao.status] ?? situacao.status}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Documentos da empresa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                for (final tipo in tiposDocumentoEmpresa) _linhaDocumento(tipo, situacao.documentoDe(tipo)),
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
                const Text('Sócios', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (situacao.socios.isEmpty)
                  Text('Nenhum sócio cadastrado.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  ...situacao.socios.map((s) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('CPF: ${s.cpf}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            for (final tipo in tiposDocumentoSocio) _linhaDocumento(tipo, situacao.documentoDe(tipo, socioId: s.id)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),

        if (situacao.status == 'rejeitada' && situacao.motivoRejeicao != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                children: [
                  const TextSpan(text: 'Motivo da rejeição anterior: ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: situacao.motivoRejeicao),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        _painelDecisao(situacao.status),
      ],
    );
  }

  Widget _linhaDocumento(String tipo, DocumentoEmpresa? doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: Text(labelTipoDocumento[tipo] ?? tipo, style: const TextStyle(fontSize: 12))),
          if (doc != null)
            TextButton(
              onPressed: doc.urlAssinada == null ? null : () => launchUrl(Uri.parse(doc.urlAssinada!)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('Ver ${doc.nomeArquivo}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            )
          else
            const Text('Não enviado', style: TextStyle(fontSize: 12, color: Color(0xFFD97706))),
        ],
      ),
    );
  }

  Widget _painelDecisao(String status) {
    if (status == 'aprovada') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Documentação já aprovada.', style: TextStyle(fontSize: 13, color: Color(0xFF15803D))),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decisão', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: _motivoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (obrigatório se rejeitar)',
                hintText: 'Ex: comprovante de endereço da empresa vencido, envie um mais recente.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: _enviando ? null : () => _decidir('aprovada'),
                  child: Text(_enviando ? 'Enviando...' : 'Aprovar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _enviando ? null : () => _decidir('rejeitada'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('Rejeitar'),
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(_erro!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
