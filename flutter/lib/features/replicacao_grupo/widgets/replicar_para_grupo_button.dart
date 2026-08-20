import 'package:flutter/material.dart';
import '../services/replicacao_grupo_service.dart';

// Fase Replicação-Grupo — botão genérico e reutilizável (mesma ideia do
// ReplicarParaGrupoButton.tsx na web): qualquer tela que edite algo ligado a
// uma "chaveTabela" cadastrada em replicacao_tabelas_registro pode soltar
// este widget e ganhar de graça o "Replicar para o grupo". Sem registroId,
// replica TODOS os registros elegíveis da empresa de origem para aquela
// tabela.
class ReplicarParaGrupoButton extends StatelessWidget {
  final String chaveTabela;
  final String empresaId;
  final String? registroId;
  final String rotuloRegistro;

  const ReplicarParaGrupoButton({
    super.key,
    required this.chaveTabela,
    required this.empresaId,
    this.registroId,
    this.rotuloRegistro = 'este cadastro',
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => _DialogReplicarParaGrupo(
          chaveTabela: chaveTabela,
          empresaId: empresaId,
          registroId: registroId,
          rotuloRegistro: rotuloRegistro,
        ),
      ),
      icon: const Icon(Icons.sync, size: 16),
      label:
          const Text('Replicar para o grupo', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
    );
  }
}

class _DialogReplicarParaGrupo extends StatefulWidget {
  final String chaveTabela;
  final String empresaId;
  final String? registroId;
  final String rotuloRegistro;

  const _DialogReplicarParaGrupo({
    required this.chaveTabela,
    required this.empresaId,
    required this.registroId,
    required this.rotuloRegistro,
  });

  @override
  State<_DialogReplicarParaGrupo> createState() =>
      _DialogReplicarParaGrupoState();
}

class _DialogReplicarParaGrupoState extends State<_DialogReplicarParaGrupo> {
  final _service = ReplicacaoGrupoService();
  bool _carregandoAlvos = true;
  List<EmpresaAlvoReplicacao> _alvos = [];
  bool _processando = false;
  ResultadoReplicacao? _resultado;

  @override
  void initState() {
    super.initState();
    _carregarAlvos();
  }

  Future<void> _carregarAlvos() async {
    final lista = await _service.buscarEmpresasAlvo(widget.empresaId);
    if (!mounted) return;
    setState(() {
      _alvos = lista;
      _carregandoAlvos = false;
    });
  }

  Future<void> _confirmar() async {
    setState(() => _processando = true);
    final resultado = await _service.replicar(
      chaveTabela: widget.chaveTabela,
      empresaOrigemId: widget.empresaId,
      registroOrigemId: widget.registroId,
    );
    if (!mounted) return;
    setState(() {
      _processando = false;
      _resultado = resultado;
    });
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'sucesso':
        return Colors.green.shade700;
      case 'erro':
        return Colors.red.shade700;
      default:
        return Colors.black45;
    }
  }

  String _rotuloStatus(String status) {
    switch (status) {
      case 'sucesso':
        return 'Atualizado';
      case 'erro':
        return 'Erro';
      default:
        return 'Já existia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;

    return AlertDialog(
      title: const Text('Replicar para o grupo'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: resultado == null
              ? _conteudoConfirmacao()
              : _conteudoResultado(resultado),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(resultado != null ? 'Fechar' : 'Cancelar'),
        ),
        if (resultado == null)
          FilledButton(
            onPressed: (_processando || _carregandoAlvos || _alvos.isEmpty)
                ? null
                : _confirmar,
            child: Text(_processando ? 'Replicando…' : 'Replicar'),
          ),
      ],
    );
  }

  Widget _conteudoConfirmacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Isso vai copiar ${widget.rotuloRegistro} para as demais empresas do seu Grupo Econômico ou Rede de '
          'Postos. Registros que já existirem na empresa destino não são alterados.',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_carregandoAlvos)
          const Text('Buscando empresas do grupo…',
              style: TextStyle(color: Colors.black45)),
        if (!_carregandoAlvos && _alvos.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Não encontramos outras empresas no seu grupo — nada para replicar.',
              style: TextStyle(fontSize: 12, color: Colors.brown),
            ),
          ),
        if (!_carregandoAlvos && _alvos.isNotEmpty) ...[
          Text('Empresas que vão receber a cópia (${_alvos.length}):',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _alvos.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child:
                    Text(_alvos[i].nome, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _conteudoResultado(ResultadoReplicacao resultado) {
    if (resultado.erro != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text(resultado.erro!,
            style: TextStyle(fontSize: 13, color: Colors.red.shade800)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${resultado.totalSucesso} empresa(s) atualizada(s), ${resultado.totalPulado} já estava(m) em dia'
          '${resultado.totalErro > 0 ? ", ${resultado.totalErro} com erro" : ""}.',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...resultado.itens.map((i) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(i.nomeEmpresa,
                          style: const TextStyle(fontSize: 13))),
                  Text(
                    _rotuloStatus(i.status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _corStatus(i.status)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
