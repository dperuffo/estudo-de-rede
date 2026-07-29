import 'package:dio/dio.dart';
import '../../../core/services/supabase_service.dart';

// Fase TCO 2 (29/07/2026) — porta de src/lib/fipe.ts + fipeActions.ts.
// Chama a API pública FIPE Parallelum/FipeOnline v2 direto do cliente
// (mesmo padrão de geo_service.dart pra Nominatim/OSRM — não tem
// server-side no PWA, então a integração com serviço externo é sempre
// direta do Dart) e grava o resultado direto nas tabelas Supabase (mesmo
// padrão de veiculos_service.dart), respeitando a RLS de
// cadastro_veiculos/cadastro_veiculos_fipe_historico.

typedef TipoVeiculoFipe = String; // 'cars' | 'motorcycles' | 'trucks'

const tiposVeiculoFipe = <(TipoVeiculoFipe, String)>[
  ('cars', 'Carro'),
  ('trucks', 'Caminhão'),
  ('motorcycles', 'Moto'),
];

class FipeOpcao {
  final String code;
  final String name;
  const FipeOpcao({required this.code, required this.name});
  factory FipeOpcao.fromMap(Map<String, dynamic> m) => FipeOpcao(code: m['code'] as String, name: m['name'] as String);
}

class FipePreco {
  final String codeFipe, brand, model, fuel, referenceMonth, price;
  const FipePreco({
    required this.codeFipe,
    required this.brand,
    required this.model,
    required this.fuel,
    required this.referenceMonth,
    required this.price,
  });
  factory FipePreco.fromMap(Map<String, dynamic> m) => FipePreco(
        codeFipe: m['codeFipe'] as String,
        brand: m['brand'] as String? ?? '',
        model: m['model'] as String? ?? '',
        fuel: m['fuel'] as String? ?? '',
        referenceMonth: m['referenceMonth'] as String,
        price: m['price'] as String,
      );
}

class FipeHistoricoItem {
  final String price, month, reference;
  const FipeHistoricoItem({required this.price, required this.month, required this.reference});
  factory FipeHistoricoItem.fromMap(Map<String, dynamic> m) =>
      FipeHistoricoItem(price: m['price'] as String, month: m['month'] as String, reference: m['reference'] as String);
}

// "R$ 119.329,00" → 119329.00
double parsePrecoFipe(String texto) {
  final limpo = texto.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(limpo) ?? 0;
}

const _baseUrlFipe = 'https://fipe.parallelum.com.br/api/v2';
final _dio = Dio();

Options _opcoesFipe() => Options(sendTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15));

Future<List<FipeOpcao>> listarMarcasFipe(TipoVeiculoFipe tipo) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/brands', options: _opcoesFipe());
  return (resp.data as List).map((e) => FipeOpcao.fromMap(e as Map<String, dynamic>)).toList();
}

Future<List<FipeOpcao>> listarModelosFipe(TipoVeiculoFipe tipo, String marcaCode) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/brands/$marcaCode/models', options: _opcoesFipe());
  return (resp.data as List).map((e) => FipeOpcao.fromMap(e as Map<String, dynamic>)).toList();
}

Future<List<FipeOpcao>> listarAnosFipe(TipoVeiculoFipe tipo, String marcaCode, String modeloCode) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/brands/$marcaCode/models/$modeloCode/years', options: _opcoesFipe());
  return (resp.data as List).map((e) => FipeOpcao.fromMap(e as Map<String, dynamic>)).toList();
}

Future<FipePreco> buscarPrecoFipe(TipoVeiculoFipe tipo, String marcaCode, String modeloCode, String anoCode) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/brands/$marcaCode/models/$modeloCode/years/$anoCode', options: _opcoesFipe());
  return FipePreco.fromMap(resp.data as Map<String, dynamic>);
}

Future<FipePreco> buscarPrecoFipePorCodigo(TipoVeiculoFipe tipo, String codigoFipe, String anoCode) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/$codigoFipe/years/$anoCode', options: _opcoesFipe());
  return FipePreco.fromMap(resp.data as Map<String, dynamic>);
}

Future<List<FipeHistoricoItem>> buscarHistoricoFipe(TipoVeiculoFipe tipo, String codigoFipe, String anoCode) async {
  final resp = await _dio.get('$_baseUrlFipe/$tipo/$codigoFipe/years/$anoCode/history', options: _opcoesFipe());
  final lista = (resp.data as Map<String, dynamic>)['priceHistory'] as List? ?? [];
  return lista.map((e) => FipeHistoricoItem.fromMap(e as Map<String, dynamic>)).toList();
}

// Vincula o veículo + backfill de histórico (best-effort) + custo de
// capital — mesma lógica de fipeActions.ts::vincularFipeAcao, só que
// gravando direto nas tabelas via client Supabase (sem "use server").
class FipeVinculoService {
  final _supabase = SupabaseService.client;

  Future<String?> vincular({
    required String veiculoId,
    required TipoVeiculoFipe tipo,
    required String marcaCode,
    required String modeloCode,
    required String anoCode,
  }) async {
    try {
      final veiculo = await _supabase.from('cadastro_veiculos').select('cnpj_frota, placa').eq('id', veiculoId).maybeSingle();
      final cnpjFrota = veiculo?['cnpj_frota'] as String?;
      final placa = veiculo?['placa'] as String?;
      if (cnpjFrota == null || placa == null) return 'Veículo não encontrado.';

      final preco = await buscarPrecoFipe(tipo, marcaCode, modeloCode, anoCode);
      final valorAtual = parsePrecoFipe(preco.price);

      await _supabase.from('cadastro_veiculos').update({
        'codigo_fipe': preco.codeFipe,
        'valor_fipe': valorAtual,
        'combustivel_fipe': preco.fuel,
        'mes_referencia': preco.referenceMonth,
        'fipe_tipo_veiculo': tipo,
        'fipe_ano_codigo': anoCode,
      }).eq('id', veiculoId);

      try {
        final historico = await buscarHistoricoFipe(tipo, preco.codeFipe, anoCode);
        await _gravarHistorico(
          veiculoId: veiculoId,
          cnpjFrota: cnpjFrota,
          placa: placa,
          codigoFipe: preco.codeFipe,
          historico: historico,
        );
      } catch (_) {
        // best-effort — o vínculo principal já foi salvo.
      }
      return null;
    } catch (e) {
      return 'Não foi possível vincular à FIPE: $e';
    }
  }

  Future<String?> atualizarAgora(String veiculoId) async {
    try {
      final veiculo = await _supabase
          .from('cadastro_veiculos')
          .select('cnpj_frota, placa, codigo_fipe, fipe_tipo_veiculo, fipe_ano_codigo')
          .eq('id', veiculoId)
          .maybeSingle();
      final cnpjFrota = veiculo?['cnpj_frota'] as String?;
      final placa = veiculo?['placa'] as String?;
      final codigoFipe = veiculo?['codigo_fipe'] as String?;
      final tipo = veiculo?['fipe_tipo_veiculo'] as String?;
      final anoCode = veiculo?['fipe_ano_codigo'] as String?;
      if (cnpjFrota == null || placa == null || codigoFipe == null || tipo == null || anoCode == null) {
        return 'Este veículo ainda não está vinculado a um código FIPE.';
      }

      final preco = await buscarPrecoFipePorCodigo(tipo, codigoFipe, anoCode);
      final valorAtual = parsePrecoFipe(preco.price);

      await _supabase.from('cadastro_veiculos').update({
        'valor_fipe': valorAtual,
        'combustivel_fipe': preco.fuel,
        'mes_referencia': preco.referenceMonth,
      }).eq('id', veiculoId);

      try {
        final historico = await buscarHistoricoFipe(tipo, codigoFipe, anoCode);
        await _gravarHistorico(veiculoId: veiculoId, cnpjFrota: cnpjFrota, placa: placa, codigoFipe: codigoFipe, historico: historico);
      } catch (_) {
        // best-effort — o valor atual já foi salvo.
      }
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<void> _gravarHistorico({
    required String veiculoId,
    required String cnpjFrota,
    required String placa,
    required String codigoFipe,
    required List<FipeHistoricoItem> historico,
  }) async {
    if (historico.isEmpty) return;
    await _supabase.from('cadastro_veiculos_fipe_historico').upsert(
      historico
          .map((item) => {
                'cadastro_veiculo_id': veiculoId,
                'cnpj_frota': cnpjFrota,
                'placa': placa,
                'codigo_fipe': codigoFipe,
                'mes_referencia': item.month,
                'referencia_codigo': int.tryParse(item.reference),
                'valor': parsePrecoFipe(item.price),
              })
          .toList(),
      onConflict: 'cadastro_veiculo_id,mes_referencia',
    );
  }
}
