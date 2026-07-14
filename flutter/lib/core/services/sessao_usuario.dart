// Fase FLT-1 — mesmo conceito de "perfil + empresa atual" já usado na web
// (ver src/lib/empresaAtual.ts::resolverEmpresaAtual e o bloco de MFA em
// src/app/(dashboard)/layout.tsx). Resolve, depois do login:
//   - perfil: "admin" | "posto" | outro valor (cliente/frota — ver
//     PERFIL_LABEL em @/lib/constants na web pros rótulos exatos)
//   - segmento da empresa vinculada: "Revenda" (posto) | "Frota" (cliente)
//   - se a documentação/MFA já estão OK pra liberar o app
class SessaoUsuario {
  final String email;
  final String? perfil;
  final String? empresaId;
  final String? nomeEmpresa;
  final String? segmento;
  final List<String> empresasIds;

  const SessaoUsuario({
    required this.email,
    required this.perfil,
    required this.empresaId,
    required this.nomeEmpresa,
    required this.segmento,
    required this.empresasIds,
  });

  bool get ehAdmin => perfil == 'admin';
  bool get ehPosto => perfil == 'posto';
  // Fase FLT-1 — mesma regra da web (layout.tsx: !ehAdmin && !ehPosto):
  // qualquer perfil que não seja admin nem posto é tratado como cliente
  // (gestor_frota, analista etc. — ver PERFIL_LABEL na web).
  bool get ehCliente => !ehAdmin && !ehPosto;

  // Fase FLT-1 — empresa com mais de uma opção (grupo econômico) ainda
  // precisa de um seletor, igual a web faz em /dashboard, /documentos etc.
  // Por ora a sessão resolve a primeira automaticamente; o seletor fica
  // pra Fase FLT-2 quando isso bloquear algum caso real.
  //
  // Fase FLT-4 — admin SEMPRE precisa escolher (nunca tem 1 empresa óbvia:
  // `empresasIds`, pro admin, é a lista inteira de clientes Frota — ver
  // AuthService.carregarSessao). Sem este `ehAdmin ||`, o app ficava
  // travado/vazio pro admin (nunca caía nesta condição, nunca ia pro
  // seletor).
  bool get precisaEscolherEmpresa => empresaId == null && (ehAdmin || empresasIds.length > 1);
}
