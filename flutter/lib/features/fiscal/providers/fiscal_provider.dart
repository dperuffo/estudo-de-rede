import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/fiscal_service.dart';

final fiscalDetalheProvider =
    FutureProvider.autoDispose<({DadosEmpresaFiscal? empresa, EmpresaFiscal? fiscal})>(
        (ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return (empresa: null, fiscal: null);
  final service = FiscalService();
  final empresa = await service.buscarDadosEmpresa(empresaId);
  final fiscal = await service.buscar(empresaId);
  return (empresa: empresa, fiscal: fiscal);
});
