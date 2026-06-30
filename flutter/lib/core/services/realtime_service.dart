import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Evento de mudanca recebido via WebSocket
class RealtimeEvento {
  final String tabela;
  final String evento; // INSERT, UPDATE, DELETE
  final dynamic registroId;
  final String? descricao;
  final DateTime timestamp;

  RealtimeEvento({
    required this.tabela,
    required this.evento,
    required this.registroId,
    required this.descricao,
    required this.timestamp,
  });

  factory RealtimeEvento.fromJson(Map<String, dynamic> json) {
    return RealtimeEvento(
      tabela: json['tabela'] ?? '',
      evento: json['evento'] ?? '',
      registroId: json['registro_id'],
      descricao: json['descricao'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  /// Texto amigavel para exibir em toast
  String get mensagemAmigavel {
    final acao = {
      'INSERT': 'criado',
      'UPDATE': 'atualizado',
      'DELETE': 'removido',
    }[evento] ?? 'alterado';

    final tipoLabel = {
      'cadastro_veiculos': 'Veiculo',
      'profrotas_abastecimentos': 'Abastecimento',
      'manutencoes_realizadas': 'Manutencao',
      'centros_custo': 'Centro de custo',
    }[tabela] ?? 'Registro';

    if (descricao != null && descricao!.isNotEmpty) {
      return '$tipoLabel $descricao foi $acao';
    }
    return '$tipoLabel foi $acao';
  }
}

/// Servico de conexao WebSocket para notificacoes em tempo real.
/// Uso: conectar por tela, escutando apenas as tabelas relevantes.
class RealtimeService {
  WebSocketChannel? _channel;
  StreamController<RealtimeEvento>? _controller;
  final _storage = const FlutterSecureStorage();
  Timer? _pingTimer;

  /// Conecta ao WebSocket e retorna um Stream de eventos.
  /// [tabelas] filtra localmente quais tabelas a tela quer escutar (vazio = todas).
  Future<Stream<RealtimeEvento>> conectar({List<String> tabelas = const []}) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      throw Exception('Usuario nao autenticado');
    }

    _controller = StreamController<RealtimeEvento>.broadcast();

    final wsUrl = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/notificacoes?token=$token'),
    );

    _channel!.stream.listen(
      (mensagem) {
        try {
          final json = jsonDecode(mensagem) as Map<String, dynamic>;
          final evento = RealtimeEvento.fromJson(json);
          if (tabelas.isEmpty || tabelas.contains(evento.tabela)) {
            _controller?.add(evento);
          }
        } catch (_) {
          // Ignora mensagens que nao sao JSON valido (ex: pong)
        }
      },
      onError: (_) {
        _controller?.close();
      },
      onDone: () {
        _controller?.close();
      },
    );

    // Mantem a conexao viva enviando um ping a cada 25s
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        _channel?.sink.add('ping');
      } catch (_) {}
    });

    return _controller!.stream;
  }

  void desconectar() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }
}
