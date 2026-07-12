import 'package:supabase_flutter/supabase_flutter.dart';

// Fase FLT-1 — inicialização do client Supabase, mesmo projeto usado pela
// aplicação web Next.js (nedthbeekvwzcjrhsghp). A chave abaixo é a chave
// pública "anon"/"publishable" (não é secreta — é a mesma que qualquer
// client-side JS da web já embute; toda a proteção de dados vem das
// políticas de RLS no banco, não do sigilo desta chave).
//
// TODO(Daniel): se você já tem essas credenciais só como env var em algum
// outro lugar (ex.: pra apontar pra outro ambiente/projeto no futuro), pode
// mover pra --dart-define e ler via String.fromEnvironment em vez de deixar
// fixo aqui — deixei direto por simplicidade nesta primeira fase.
class SupabaseService {
  static const String supabaseUrl = 'https://nedthbeekvwzcjrhsghp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5lZHRoYmVla3Z3emNqcmhzZ2hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTUyMzUsImV4cCI6MjA5NDczMTIzNX0.VBgDNFAXysqX9HDiJYYjFxgtsP1zaj3LH1EbZQXH00E';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
