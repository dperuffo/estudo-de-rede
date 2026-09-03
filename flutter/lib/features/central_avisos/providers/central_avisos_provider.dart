import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/central_avisos_service.dart';

final meusAvisosProvider =
    FutureProvider.autoDispose<List<AvisoEmpresa>>((ref) async {
  return CentralAvisosService().listarMeusAvisos();
});
