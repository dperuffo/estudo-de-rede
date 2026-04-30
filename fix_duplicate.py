#!/usr/bin/env python3
"""
Fix: remove pasta duplicada gestao-abastecimentos.html (NFD vs NFC).
Usa -z para obter paths em bytes brutos, sem aspas nem escapes octal.
"""
import subprocess, os, sys

cwd = '/Users/daniel/Documents/Claude/Projects/How to use Claude'
os.chdir(cwd)

# -z retorna paths null-terminated SEM quoting, bytes brutos
result = subprocess.run(['git', 'ls-files', '-z', '--cached'],
                       capture_output=True, cwd=cwd)
all_files = [f for f in result.stdout.split(b'\x00') if f]

# Filtrar gestao-abastecimentos.html
roto = [f for f in all_files if b'gestao-abastecimentos' in f]

print(f"=== Entradas encontradas: {len(roto)} ===")
for i, r in enumerate(roto):
    folder = os.path.dirname(r)
    siblings = [f for f in all_files if f.startswith(folder + b'/')]
    print(f"  [{i}] path bytes: {r.hex()}")
    print(f"       pasta:  {folder!r}")
    print(f"       arquivos na pasta: {len(siblings)}")

if len(roto) < 2:
    print("\nNenhuma duplicata. Nada a fazer.")
    sys.exit(0)

# Ordenar: pasta com MENOS arquivos = duplicata
roto_info = []
for r in roto:
    folder = os.path.dirname(r)
    siblings = [f for f in all_files if f.startswith(folder + b'/')]
    roto_info.append((len(siblings), r))
roto_info.sort()

to_remove = roto_info[0][1]   # 1 arquivo na pasta = duplicata (NFD)
to_keep   = roto_info[-1][1]  # 21 arquivos = pasta correta (NFC)

print(f"\n=== Ação ===")
print(f"Remover: {to_remove!r}")
print(f"Manter : {to_keep!r}")

# git rm --cached passando bytes brutos via stdin com -z
r2 = subprocess.run(
    ['git', 'rm', '--cached', '-z', '--stdin'],
    input=to_remove + b'\x00',
    capture_output=True, cwd=cwd
)
print(f"\ngit rm: código {r2.returncode}")
if r2.stdout: print("  stdout:", r2.stdout.decode(errors='replace'))
if r2.stderr: print("  stderr:", r2.stderr.decode(errors='replace'))

if r2.returncode != 0:
    # Fallback: tentar com --ignore-unmatch e path direto
    r2b = subprocess.run(
        ['git', 'rm', '--cached', '--ignore-unmatch', to_remove],
        capture_output=True, cwd=cwd
    )
    print(f"  fallback git rm: código {r2b.returncode}")
    if r2b.stdout: print("  stdout:", r2b.stdout.decode(errors='replace'))
    if r2b.stderr: print("  stderr:", r2b.stderr.decode(errors='replace'))

# git add na pasta correta para garantir conteúdo mais recente
r3 = subprocess.run(['git', 'add', to_keep],
                   capture_output=True, cwd=cwd)
print(f"\ngit add: código {r3.returncode}")
if r3.stderr: print("  stderr:", r3.stderr.decode(errors='replace'))

# Configurar para evitar futuros problemas
subprocess.run(['git', 'config', 'core.precomposeunicode', 'true'], cwd=cwd)

# Verificar resultado
r4 = subprocess.run(['git', 'ls-files', '-z', '--cached'],
                   capture_output=True, cwd=cwd)
remaining = [f for f in r4.stdout.split(b'\x00') if b'gestao-abastecimentos' in f]
print(f"\n=== Resultado: {len(remaining)} entrada(s) restante(s) ===")
for r in remaining:
    print(f"  {r!r}")

if len(remaining) == 1:
    print("\n✅ Duplicata removida com sucesso!")
    print("\nAgora rode:")
    print('  git commit -m "fix: remove pasta duplicada gestao-abastecimentos (NFD/NFC)"')
    print("  git push github master")
else:
    print("\n⚠️  Ainda há duplicatas. Status do git:")
    subprocess.run(['git', 'status', '--short'], cwd=cwd)
