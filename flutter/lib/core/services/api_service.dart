import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  void init() {}

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final r = await _dio.get(path, queryParameters: params);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final r = await _dio.post(path, data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final r = await _dio.put(path, data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final r = await _dio.delete(path);
    return r.data as Map<String, dynamic>;
  }
}
