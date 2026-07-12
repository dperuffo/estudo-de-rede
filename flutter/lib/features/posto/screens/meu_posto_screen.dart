import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/meu_posto_provider.dart';

class _StatusInfo {
  final String texto;
  final Color cor;
  final Color corTexto;
  const _StatusInfo(this.texto, this.cor, this.corTexto);
}

const _statusLabel = <String, _StatusInfo>{
  'pendente': _StatusInfo('Cadastro ainda não confirmado', Color(0xFFF1F5F9), Color(0xFF475569)),
  'confirmado': _StatusInfo('✓ CNPJ confirmado na base ANP', Color(0xFFF0FDF4), Color(0xFF15803D)),
  'novo_sem_anp':
      _StatusInfo('Posto novo — CNPJ não está na base ANP ainda', Color(0xFFEFF6FF), Color(0xFF1D4ED8)),
  'possivel_duplicidade':
      _StatusInfo('⚠ Possível duplicidade sinalizada — em revisão pela FNI', Color(0xFFFFFBEB), Color(0xFF92400E)),
};

const _motivoMensagem = <String, String>{
  'sem_permissao': 'Você não tem permissão para editar o cadastro deste posto.',
  'cnpj_invalido': 'CNPJ inválido — confira se digitou os 14 dígitos corretamente.',
  'cnpj_ja_vinculado_outro_posto':
      'Este CNPJ já está vinculado a outro posto cadastrado na plataforma. Se isso for um engano, fale com a FNI.',
};

// Fase FLT-2 — tela "Meu Posto", espelhando MeuPostoForm.tsx da web (Fase
// 27.137): cadastro do estabelecimento (CNPJ, razão social, endereço,
// contatos, lat/long), comparado com a base ANP via a mesma RPC
// verificar_e_registrar_posto_anp (SECURITY DEFINER) usada na web — nunca
// bloqueia o posto, mesmo com possível duplicidade sinalizada, entra numa
// fila de revisão do admin. O botão "usar minha localização atual" da web
// (Geolocation API do navegador) fica pra uma próxima iteração — aqui
// lat/long são preenchidos à mão.
class MeuPostoScreen extends ConsumerWidget {
  const MeuPostoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresaAsync = ref.watch(meuPostoProvider);

    return empresaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Não deu pra carregar: $e', textAlign: TextAlign.center),
        ),
      ),
      data: (empresa) {
        if (empresa == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum posto vinculado a este usuário.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return _MeuPostoForm(empresa: empresa);
      },
    );
  }
}

class _MeuPostoForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> empresa;
  const _MeuPostoForm({required this.empresa});

  @override
  ConsumerState<_MeuPostoForm> createState() => _MeuPostoFormState();
}

class _MeuPostoFormState extends ConsumerState<_MeuPostoForm> {
  late final TextEditingController _cnpj;
  late final TextEditingController _nome;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  late final TextEditingController _bairro;
  late final TextEditingController _cep;
  late final TextEditingController _municipio;
  late final TextEditingController _uf;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  bool _salvando = false;
  String? _erro;
  String? _resultadoStatus;

  String _texto(String chave) => (widget.empresa[chave] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _cnpj = TextEditingController(text: _texto('cnpj'));
    _nome = TextEditingController(text: _texto('nome'));
    _logradouro = TextEditingController(text: _texto('logradouro'));
    _numero = TextEditingController(text: _texto('numero'));
    _complemento = TextEditingController(text: _texto('complemento'));
    _bairro = TextEditingController(text: _texto('bairro'));
    _cep = TextEditingController(text: _texto('cep'));
    _municipio = TextEditingController(text: _texto('municipio'));
    _uf = TextEditingController(text: _texto('uf'));
    _telefone = TextEditingController(text: _texto('telefone_contato'));
    _email = TextEditingController(text: _texto('email_contato'));
    final lat = widget.empresa['latitude'];
    final lng = widget.empresa['longitude'];
    _latitude = TextEditingController(text: lat != null ? lat.toString() : '');
    _longitude = TextEditingController(text: lng != null ? lng.toString() : '');
  }

  @override
  void dispose() {
    for (final c in [
      _cnpj,
      _nome,
      _logradouro,
      _numero,
      _complemento,
      _bairro,
      _cep,
      _municipio,
      _uf,
      _telefone,
      _email,
      _latitude,
      _longitude,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final cnpj = _cnpj.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe a razão social.');
      return;
    }
    if (cnpj.isEmpty) {
      setState(() => _erro = 'Informe o CNPJ.');
      return;
    }

    double? latitude;
    double? longitude;
    if (_latitude.text.trim().isNotEmpty) {
      latitude = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
      if (latitude == null) {
        setState(() => _erro = 'Latitude precisa ser um número (ex: -23.5505).');
        return;
      }
    }
    if (_longitude.text.trim().isNotEmpty) {
      longitude = double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
      if (longitude == null) {
        setState(() => _erro = 'Longitude precisa ser um número (ex: -46.6333).');
        return;
      }
    }

    setState(() {
      _salvando = true;
      _erro = null;
      _resultadoStatus = null;
    });

    String? campo(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

    try {
      final resposta = await SupabaseService.client.rpc('verificar_e_registrar_posto_anp', params: {
        'p_empresa_id': widget.empresa['id'],
        'p_cnpj': cnpj,
        'p_razao_social': nome,
        'p_logradouro': campo(_logradouro),
        'p_numero': campo(_numero),
        'p_complemento': campo(_complemento),
        'p_bairro': campo(_bairro),
        'p_municipio': campo(_municipio),
        'p_uf': campo(_uf),
        'p_cep': campo(_cep),
        'p_telefone': campo(_telefone),
        'p_email': campo(_email),
        'p_latitude': latitude,
        'p_longitude': longitude,
      }) as Map<String, dynamic>;

      final ok = resposta['ok'] == true;
      if (!ok) {
        final motivo = resposta['motivo'] as String?;
        setState(() => _erro = _motivoMensagem[motivo] ?? 'Não foi possível salvar o cadastro.');
        return;
      }

      setState(() => _resultadoStatus = resposta['status'] as String?);
      ref.invalidate(meuPostoProvider);
    } catch (e) {
      setState(() => _erro = 'Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAtual = _statusLabel[widget.empresa['anp_status'] as String? ?? 'pendente'] ??
        _statusLabel['pendente']!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Meu Posto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Confirme os dados do seu estabelecimento — CNPJ, endereço e localização são comparados com a '
          'base nacional da ANP pra evitar cadastro duplicado, e alimentam os preços exibidos pros clientes '
          'nas consultas de postos e roteirização.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),

        _banner(statusAtual.texto, statusAtual.cor, statusAtual.corTexto),

        if (_erro != null) ...[
          const SizedBox(height: 12),
          _banner(_erro!, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
        ],
        if (_resultadoStatus != null) ...[
          const SizedBox(height: 12),
          _banner(
            'Cadastro salvo. ${_statusLabel[_resultadoStatus]?.texto ?? ''}'
            '${_resultadoStatus == 'possivel_duplicidade' ? ' — seus dados já foram salvos normalmente, a FNI vai revisar e entrar em contato se precisar de algo.' : ''}',
            _statusLabel[_resultadoStatus]?.cor ?? const Color(0xFFF1F5F9),
            _statusLabel[_resultadoStatus]?.corTexto ?? const Color(0xFF475569),
          ),
        ],

        const SizedBox(height: 20),
        _secao('Identificação', [
          _campo('CNPJ *', _cnpj, hint: '00.000.000/0001-00'),
          _campo('Razão Social *', _nome),
        ]),

        _secao('Endereço completo', [
          _campo('Logradouro', _logradouro),
          _campo('Número', _numero),
          _campo('Complemento', _complemento),
          _campo('Bairro', _bairro),
          _campo('CEP', _cep),
          _campo('Município', _municipio),
          _campo('UF', _uf, maxLength: 2),
        ]),

        _secao('Localização (latitude/longitude)', [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Usada pra comparar seu posto com a base da ANP e evitar cadastro duplicado, além de '
              'posicionar seu posto certinho no mapa de consultas/roteirização.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          _campo('Latitude', _latitude, hint: '-23.550520'),
          _campo('Longitude', _longitude, hint: '-46.633308'),
        ]),

        _secao('Contatos', [
          _campo('Telefone de contato', _telefone),
          _campo('E-mail de contato', _email),
        ]),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar e verificar com a ANP'),
          ),
        ),
      ],
    );
  }

  Widget _banner(String texto, Color fundo, Color corTexto) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
        child: Text(texto, style: TextStyle(color: corTexto, fontSize: 13)),
      );

  Widget _secao(String titulo, List<Widget> campos) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...campos,
              ],
            ),
          ),
        ),
      );

  Widget _campo(String label, TextEditingController controller, {String? hint, int? maxLength}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLength: maxLength,
          textCapitalization: maxLength == 2 ? TextCapitalization.characters : TextCapitalization.none,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
        ),
      );
}
