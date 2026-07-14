import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Rotograma de Segurança (cliente), porta de rotograma/
// page.tsx + novo/page.tsx + [id]/page.tsx + [id]/editar/page.tsx +
// actions.ts + tipos.ts. RLS conferida antes de portar: `rotogramas` tem
// self-service COMPLETO via `empresa_id` (ALL) — CRUD direto, sem RPC,
// igual à web.
//
// Fora do escopo: export em PDF (RotogramaPdf.tsx desenha tudo de novo com
// @react-pdf/renderer — natural pra próxima fase); "Importar de uma rota
// salva" no formulário de criação (depende de `rotas_salvas`, já fora do
// escopo da Roteirização portada — ver roteirizacao_provider.dart); campo
// "Cliente" do formulário (só aparece pra quem vê mais de uma empresa —
// aqui sempre usa a empresa da sessão, mesmo padrão do resto do app).

const categoriasRisco = [
  (valor: 'perigo', label: 'Área de perigo', icone: '⚠️'),
  (valor: 'crime', label: 'Zona de crime', icone: '🚨'),
  (valor: 'radar', label: 'Lombada / Radar', icone: '📸'),
];

const categoriasParada = [
  (valor: 'abastecimento', label: 'Abastecimento', icone: '⛽'),
  (valor: 'alimentacao', label: 'Alimentação', icone: '🍽️'),
  (valor: 'pernoite', label: 'Pernoite', icone: '🛏️'),
];

const contatosEmergencia = [
  (nome: 'PRF', numero: '191'),
  (nome: 'SAMU', numero: '192'),
  (nome: 'Bombeiros', numero: '193'),
  (nome: 'PM', numero: '190'),
  (nome: 'ANTT', numero: '166'),
];

const _corRiscoHex = {
  'perigo': Color(0xFFEF4444),
  'crime': Color(0xFFBE123C),
  'radar': Color(0xFFF59E0B),
};
const corParadaHex = Color(0xFF06B6D4);

Color corRisco(String categoria) => _corRiscoHex[categoria] ?? _corRiscoHex['perigo']!;

Color corRiscoFundo(String categoria) {
  switch (categoria) {
    case 'crime':
      return const Color(0xFFFFE4E6);
    case 'radar':
      return const Color(0xFFFFFBEB);
    default:
      return const Color(0xFFFEF2F2);
  }
}

String categoriaRiscoLabel(String c) => categoriasRisco.firstWhere((x) => x.valor == c, orElse: () => categoriasRisco.first).label;
String categoriaRiscoIcone(String c) => categoriasRisco.firstWhere((x) => x.valor == c, orElse: () => categoriasRisco.first).icone;
String categoriaParadaLabel(String c) => categoriasParada.firstWhere((x) => x.valor == c, orElse: () => categoriasParada.first).label;
String categoriaParadaIcone(String c) => categoriasParada.firstWhere((x) => x.valor == c, orElse: () => categoriasParada.first).icone;

// Porta fiel de extrairKmDoLocal (tipos.ts).
double? extrairKmDoLocal(String local) {
  final m = RegExp(r'km\s*(\d+(?:[.,]\d+)?)', caseSensitive: false).firstMatch(local);
  if (m == null) return null;
  final valor = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  return valor;
}

class RotogramaRisco {
  final String local, categoria, descricao;
  final double? km;
  const RotogramaRisco({required this.local, required this.categoria, required this.descricao, this.km});
  factory RotogramaRisco.fromMap(Map<String, dynamic> m) => RotogramaRisco(
        local: m['local'] as String? ?? '',
        categoria: m['categoria'] as String? ?? 'perigo',
        descricao: m['descricao'] as String? ?? '',
        km: (m['km'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toMap() => {'local': local, 'categoria': categoria, 'descricao': descricao, 'km': km};
}

class RotogramaParada {
  final String local, categoria, descricao;
  final double? km;
  const RotogramaParada({required this.local, required this.categoria, required this.descricao, this.km});
  factory RotogramaParada.fromMap(Map<String, dynamic> m) => RotogramaParada(
        local: m['local'] as String? ?? '',
        categoria: m['categoria'] as String? ?? 'abastecimento',
        descricao: m['descricao'] as String? ?? '',
        km: (m['km'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toMap() => {'local': local, 'categoria': categoria, 'descricao': descricao, 'km': km};
}

class PontoLinhaDoTempo {
  final String tipo; // risco | parada
  final String local, descricao, categoria;
  final double km;
  final bool kmEstimado;
  const PontoLinhaDoTempo({
    required this.tipo,
    required this.local,
    required this.descricao,
    required this.categoria,
    required this.km,
    required this.kmEstimado,
  });
}

// Porta fiel de resolverLinhaDoTempo (tipos.ts).
List<PontoLinhaDoTempo> resolverLinhaDoTempo(List<RotogramaRisco> riscos, List<RotogramaParada> paradas) {
  final todos = <({String tipo, String local, String categoria, String descricao, double? km})>[
    for (final r in riscos) (tipo: 'risco', local: r.local, categoria: r.categoria, descricao: r.descricao, km: r.km),
    for (final p in paradas) (tipo: 'parada', local: p.local, categoria: p.categoria, descricao: p.descricao, km: p.km),
  ];
  if (todos.isEmpty) return [];

  final kmConhecidos = todos.map((item) => item.km ?? extrairKmDoLocal(item.local)).whereType<double>().toList();
  final kmMaximoConhecido = kmConhecidos.isNotEmpty ? kmConhecidos.reduce((a, b) => a > b ? a : b) : 100.0;

  final resultado = <PontoLinhaDoTempo>[];
  for (var i = 0; i < todos.length; i++) {
    final item = todos[i];
    final kmExplicito = item.km ?? extrairKmDoLocal(item.local);
    final km = kmExplicito ?? ((i + 1) / (todos.length + 1)) * kmMaximoConhecido;
    resultado.add(PontoLinhaDoTempo(
      tipo: item.tipo,
      local: item.local,
      descricao: item.descricao,
      categoria: item.categoria,
      km: km,
      kmEstimado: kmExplicito == null,
    ));
  }
  resultado.sort((a, b) => a.km.compareTo(b.km));
  return resultado;
}

class RotogramaResumo {
  final String id;
  final int numero;
  final String? origem, destino, motorista, placa, dataViagem;
  final String criadoEm;
  const RotogramaResumo({
    required this.id,
    required this.numero,
    this.origem,
    this.destino,
    this.motorista,
    this.placa,
    this.dataViagem,
    required this.criadoEm,
  });
  factory RotogramaResumo.fromMap(Map<String, dynamic> m) => RotogramaResumo(
        id: m['id'] as String,
        numero: (m['numero'] as num).toInt(),
        origem: m['origem'] as String?,
        destino: m['destino'] as String?,
        motorista: m['motorista'] as String?,
        placa: m['placa'] as String?,
        dataViagem: m['data_viagem'] as String?,
        criadoEm: m['criado_em'] as String,
      );
}

final rotogramasListaProvider = FutureProvider.autoDispose<List<RotogramaResumo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('rotogramas')
      .select('id, numero, origem, destino, motorista, placa, data_viagem, criado_em')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((r) => RotogramaResumo.fromMap(r as Map<String, dynamic>)).toList();
});

class RotogramaDetalhe {
  final String id;
  final int numero;
  final String? origem, destino, veiculo, motorista, placa, dataViagem, carga, observacoes;
  final String criadoEm;
  final List<RotogramaRisco> riscos;
  final List<RotogramaParada> paradas;
  const RotogramaDetalhe({
    required this.id,
    required this.numero,
    this.origem,
    this.destino,
    this.veiculo,
    this.motorista,
    this.placa,
    this.dataViagem,
    this.carga,
    this.observacoes,
    required this.criadoEm,
    required this.riscos,
    required this.paradas,
  });
  factory RotogramaDetalhe.fromMap(Map<String, dynamic> m) => RotogramaDetalhe(
        id: m['id'] as String,
        numero: (m['numero'] as num).toInt(),
        origem: m['origem'] as String?,
        destino: m['destino'] as String?,
        veiculo: m['veiculo'] as String?,
        motorista: m['motorista'] as String?,
        placa: m['placa'] as String?,
        dataViagem: m['data_viagem'] as String?,
        carga: m['carga'] as String?,
        observacoes: m['observacoes'] as String?,
        criadoEm: m['criado_em'] as String,
        riscos: ((m['riscos'] as List?) ?? []).map((r) => RotogramaRisco.fromMap(r as Map<String, dynamic>)).toList(),
        paradas: ((m['paradas'] as List?) ?? []).map((p) => RotogramaParada.fromMap(p as Map<String, dynamic>)).toList(),
      );
}

final rotogramaDetalheProvider = FutureProvider.autoDispose.family<RotogramaDetalhe?, String>((ref, id) async {
  final row = await SupabaseService.client.from('rotogramas').select('*').eq('id', id).maybeSingle();
  if (row == null) return null;
  return RotogramaDetalhe.fromMap(row);
});
