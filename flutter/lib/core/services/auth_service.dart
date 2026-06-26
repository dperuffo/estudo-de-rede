import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _i = AuthService._();
  factory AuthService() => _i;
  AuthService._();
  final _g = GoogleSignIn(
    clientId: '629066078340-h9o6518gmnf5lsu6a8n606d4dsva65tn.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  final _s = const FlutterSecureStorage();

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    final account = await _g.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null) throw Exception('Access token nao encontrado');
    final r = await Dio().post(
      '${ApiConstants.baseUrl}${ApiConstants.authGoogle}',
      data: {'access_token': accessToken},
    );
    final data = r.data as Map<String, dynamic>;
    await _s.write(key: 'jwt_token',   value: data['access_token']);
    await _s.write(key: 'user_email',  value: data['email']);
    await _s.write(key: 'user_nome',   value: data['nome']);
    await _s.write(key: 'cnpj_frota',  value: data['cnpj_frota']);
    ApiService().init();
    return data;
  }

  Future<void> signOut() async {
    await _g.signOut();
    await _s.deleteAll();
  }

  Future<bool> isLoggedIn() async => (await _s.read(key: 'jwt_token')) != null;
}
