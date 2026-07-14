import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/sessao_usuario.dart';
import '../providers/permissoes_provider.dart';
import '../services/permissoes_service.dart';

// Fase FLT-3 — Permissões por Perfil (cliente): matriz funcionalidade x
// perfil com toggles, porta de permissoes/page.tsx. Ver escopo em
// permissoes_provider.dart. Layout em cards (1 por funcionalidade, com um
// switch por perfil visível) em vez da tabela larga da web, mais natural
// pra tela de celular — `Wrap` em vez de `Row`/`Expanded` porque o admin
// (Fase FLT-4) vê 4 perfis, não cabem bem numa linha só.
class PermissoesScreen extends ConsumerStatefulWidget {
  const PermissoesScreen({super.key});

  @override
  ConsumerState<PermissoesScreen> createState() => _PermissoesScreenState();
}

class _PermissoesScreenState extends ConsumerState<PermissoesScreen> {
  final _salvando = <String>{};

  Future<void> _alternar(String funcionalidade, String perfil, bool novoValor, String empresaEdicao) async {
    final sessao = await ref.read(sessaoProvider.future);
    final chave = '$funcionalidade|$perfil';
    setState(() => _salvando.add(chave));
    try {
      await PermissoesService().alternar(
        funcionalidade: funcionalidade,
        perfil: perfil,
        permitido: novoValor,
        empresaId: empresaEdicao,
        atualizadoPor: sessao.email,
      );
      ref.invalidate(permissoesMatrizProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando.remove(chave));
    }
  }

  @override
  Widget build(BuildContext context) {
    final matrizAsync = ref.watch(permissoesMatrizProvider);
    final sessao = ref.watch(sessaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Permissões por Perfil')),
      body: matrizAsync.when(
        data: (matriz) => _conteudo(matriz, sessao.valueOrNull),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(MatrizPermissoes matriz, SessaoUsuario? sessao) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Controla o que cada perfil de usuário pode ver e fazer no sistema. Toque no interruptor '
          'para permitir ou negar o acesso de um perfil a uma funcionalidade.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          matriz.modoGlobal
              ? 'Você está editando o padrão GLOBAL do sistema — vale pra todo cliente que não tiver uma '
                  'customização própria. Inclui os perfis Administrador e Posto.'
              : 'Você está vendo apenas os perfis do seu nível de gestão ou abaixo, para '
                  '${sessao?.nomeEmpresa ?? 'sua empresa'}. Permissões do Administrador e de outros clientes '
                  'não ficam visíveis nem editáveis por aqui.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
        ),
        const SizedBox(height: 16),

        if (matriz.funcionalidades.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhuma permissão cadastrada ainda.', style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          ...matriz.funcionalidades.map((f) => _cardFuncionalidade(f, matriz)),
      ],
    );
  }

  Widget _cardFuncionalidade(String funcionalidade, MatrizPermissoes matriz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatarFuncionalidade(funcionalidade), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final perfil in matriz.perfisVisiveis)
                  SizedBox(
                    width: 68,
                    child: _celulaPerfil(funcionalidade, perfil, matriz.celula(funcionalidade, perfil), matriz.empresaEdicao),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _celulaPerfil(String funcionalidade, String perfil, PermissaoCelula? celula, String empresaEdicao) {
    final permitido = celula?.permitido ?? false;
    final chave = '$funcionalidade|$perfil';
    final ocupado = _salvando.contains(chave);

    return Column(
      children: [
        // Achado real (Daniel, print do PWA): rótulos com tamanhos
        // diferentes ("Administrador"/"Gestor de Frota" quebram em 2
        // linhas num box de 68px, "Analista"/"Posto" cabem numa só) faziam
        // cada switch da linha começar numa altura diferente, porque cada
        // Column dentro do Wrap só tem a altura do próprio conteúdo. Altura
        // fixa (2 linhas) + alinhamento embaixo resolve: todo rótulo ocupa
        // o mesmo espaço, então todo switch nasce na mesma posição.
        SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              perfilLabel[perfil] ?? perfil,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 32,
          width: 32,
          child: ocupado
              ? const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: permitido,
                  onChanged: (v) => _alternar(funcionalidade, perfil, v, empresaEdicao),
                ),
        ),
        if (celula?.customizado == true)
          const Text('Personalizado', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF0369A1))),
      ],
    );
  }
}
