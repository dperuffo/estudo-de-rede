import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/documentos_provider.dart';
import '../services/documentos_service.dart';

const _statusCor = <String, Color>{
  'nao_iniciada': Color(0xFF64748B),
  'pendente': Color(0xFFB45309),
  'aprovada': Color(0xFF15803D),
  'rejeitada': Color(0xFFB91C1C),
};

const _statusFundo = <String, Color>{
  'nao_iniciada': Color(0xFFF1F5F9),
  'pendente': Color(0xFFFFFBEB),
  'aprovada': Color(0xFFF0FDF4),
  'rejeitada': Color(0xFFFEF2F2),
};

// Fase FLT-2 — Documentos (documentação societária self-service), porta de
// documentos/page.tsx (ver comentário completo em documentos_provider.dart
// e documentos_service.dart). Sem o seletor de empresa (mesma razão de
// sempre: o shell /posto resolve uma única empresa atual por vez).
class DocumentosScreen extends ConsumerStatefulWidget {
  const DocumentosScreen({super.key});

  @override
  ConsumerState<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends ConsumerState<DocumentosScreen> {
  bool _ocupado = false;
  String? _erroGeral;
  String? _sucessoGeral;

  final _nomeSocioCtrl = TextEditingController();
  final _cpfSocioCtrl = TextEditingController();
  bool _formularioSocioAberto = false;

  @override
  void dispose() {
    _nomeSocioCtrl.dispose();
    _cpfSocioCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherEEnviar({required String tipo, String? socioId}) async {
    final resultado = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: [
      'pdf',
      'jpg',
      'jpeg',
      'png',
    ]);
    if (resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;
    if (arquivo.bytes == null) return;

    setState(() {
      _ocupado = true;
      _erroGeral = null;
      _sucessoGeral = null;
    });

    final dados = ref.read(documentosProvider).value;
    if (dados == null) {
      setState(() => _ocupado = false);
      return;
    }

    final erro = await DocumentosService().enviarDocumento(
      empresaId: dados.empresaId,
      tipo: tipo,
      socioId: socioId,
      bytes: arquivo.bytes!,
      nomeArquivo: arquivo.name,
      mimeType: _mimeDe(arquivo.extension),
    );

    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (erro != null) {
        _erroGeral = erro;
      } else {
        _sucessoGeral = 'Documento enviado.';
      }
    });
    if (erro == null) ref.invalidate(documentosProvider);
  }

  String? _mimeDe(String? extensao) {
    switch (extensao?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return null;
    }
  }

  Future<void> _removerDocumento(DocumentoEmpresa doc) async {
    setState(() {
      _ocupado = true;
      _erroGeral = null;
      _sucessoGeral = null;
    });
    final erro = await DocumentosService().removerDocumento(doc.id, doc.storagePath);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (erro != null) _erroGeral = erro;
    });
    if (erro == null) ref.invalidate(documentosProvider);
  }

  Future<void> _adicionarSocio() async {
    final dados = ref.read(documentosProvider).value;
    if (dados == null) return;
    setState(() {
      _ocupado = true;
      _erroGeral = null;
      _sucessoGeral = null;
    });
    final erro = await DocumentosService().adicionarSocio(
      empresaId: dados.empresaId,
      nome: _nomeSocioCtrl.text,
      cpf: _cpfSocioCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (erro != null) {
        _erroGeral = erro;
      } else {
        _nomeSocioCtrl.clear();
        _cpfSocioCtrl.clear();
        _formularioSocioAberto = false;
      }
    });
    if (erro == null) ref.invalidate(documentosProvider);
  }

  Future<void> _removerSocio(String socioId) async {
    setState(() {
      _ocupado = true;
      _erroGeral = null;
      _sucessoGeral = null;
    });
    final erro = await DocumentosService().removerSocio(socioId);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (erro != null) _erroGeral = erro;
    });
    if (erro == null) ref.invalidate(documentosProvider);
  }

  Future<void> _enviarParaAnalise(SituacaoDocumentacao dados) async {
    setState(() {
      _ocupado = true;
      _erroGeral = null;
      _sucessoGeral = null;
    });
    final erro = await DocumentosService().enviarParaAnalise(dados);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (erro != null) {
        _erroGeral = erro;
      } else {
        _sucessoGeral = 'Enviado! Aguarde a análise do admin.';
      }
    });
    if (erro == null) ref.invalidate(documentosProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(documentosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          return _buildConteudo(context, dados);
        },
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, SituacaoDocumentacao dados) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusFundo[dados.status],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusDocumentacaoLabel[dados.status] ?? dados.status,
                style: TextStyle(color: _statusCor[dados.status], fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
        if (dados.status == 'rejeitada' && dados.motivoRejeicao != null) ...[
          const SizedBox(height: 10),
          _banner('Motivo da rejeição: ${dados.motivoRejeicao}', const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
        ],
        if (dados.status == 'pendente') ...[
          const SizedBox(height: 10),
          _banner('Documentação enviada, aguardando análise do admin.', const Color(0xFFFFFBEB), const Color(0xFF92400E)),
        ],
        if (dados.status == 'aprovada') ...[
          const SizedBox(height: 10),
          _banner('Documentação aprovada — nenhuma pendência.', const Color(0xFFF0FDF4), const Color(0xFF15803D)),
        ],
        const SizedBox(height: 16),
        const Text('Documentos da empresa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...tiposDocumentoEmpresa.map((tipo) => _slotDocumento(
              label: labelTipoDocumento[tipo]!,
              doc: dados.documentoDe(tipo),
              onEscolher: () => _escolherEEnviar(tipo: tipo),
              onRemover: (d) => _removerDocumento(d),
            )),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sócios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              onPressed: () => setState(() => _formularioSocioAberto = !_formularioSocioAberto),
              icon: Icon(_formularioSocioAberto ? Icons.close : Icons.add),
              label: Text(_formularioSocioAberto ? 'Fechar' : 'Adicionar sócio'),
            ),
          ],
        ),
        if (_formularioSocioAberto) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nomeSocioCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do sócio', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cpfSocioCtrl,
                    decoration: const InputDecoration(labelText: 'CPF (11 dígitos)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _ocupado ? null : _adicionarSocio,
                      child: const Text('Salvar sócio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (dados.socios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhum sócio cadastrado.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...dados.socios.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${s.nome} — ${_cpfFormatado(s.cpf)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          TextButton(
                            onPressed: _ocupado ? null : () => _removerSocio(s.id),
                            child: const Text('Remover', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...tiposDocumentoSocio.map((tipo) => _slotDocumento(
                            label: labelTipoDocumento[tipo]!,
                            doc: dados.documentoDe(tipo, socioId: s.id),
                            onEscolher: () => _escolherEEnviar(tipo: tipo, socioId: s.id),
                            onRemover: (d) => _removerDocumento(d),
                            compacto: true,
                          )),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 20),
        if (_erroGeral != null) ...[_banner(_erroGeral!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)), const SizedBox(height: 10)],
        if (_sucessoGeral != null) ...[
          _banner(_sucessoGeral!, const Color(0xFFF0FDF4), const Color(0xFF15803D)),
          const SizedBox(height: 10),
        ],
        if (dados.status == 'nao_iniciada' || dados.status == 'rejeitada')
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _ocupado ? null : () => _enviarParaAnalise(dados),
              child: Text(_ocupado ? 'Enviando...' : 'Enviar para análise'),
            ),
          )
        else if (dados.status == 'pendente')
          const Text('Sua documentação está em análise — assim que o admin decidir, você será avisado aqui.',
              style: TextStyle(fontSize: 12, color: Colors.grey))
        else if (dados.status == 'aprovada')
          const Text('Documentação aprovada. Se precisar corrigir algum documento, envie novamente acima.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _slotDocumento({
    required String label,
    required DocumentoEmpresa? doc,
    required VoidCallback onEscolher,
    required void Function(DocumentoEmpresa) onRemover,
    bool compacto = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: compacto ? 8 : 10),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (doc == null)
                const Text('Não enviado', style: TextStyle(fontSize: 12, color: Color(0xFFB45309)))
              else
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: doc.urlAssinada == null ? null : () => launchUrl(Uri.parse(doc.urlAssinada!)),
                        child: Text(doc.nomeArquivo,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _ocupado ? null : onEscolher,
                    child: Text(doc == null ? 'Enviar arquivo' : 'Substituir'),
                  ),
                  if (doc != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _ocupado ? null : () => onRemover(doc),
                      child: const Text('Remover', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String texto, Color fundo, Color cor) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: TextStyle(color: cor, fontSize: 13)),
      );

  String _cpfFormatado(String cpf) {
    if (cpf.length != 11) return cpf;
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }
}
