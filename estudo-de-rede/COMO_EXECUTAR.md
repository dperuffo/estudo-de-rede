# ⛽ Estudo de Rede – Como Executar

## Pré-requisitos

- **Python 3.9 ou superior** instalado no computador  
  (verifique com: `python --version` ou `python3 --version`)

---

## Passo a Passo

### 1. Abra o Terminal (Prompt de Comando)

**No Windows:** Pressione `Win + R`, digite `cmd` e pressione Enter  
**No Mac:** Pressione `Cmd + Espaço`, digite `Terminal` e pressione Enter  
**No Linux:** Pressione `Ctrl + Alt + T`

---

### 2. Navegue até a pasta onde os arquivos estão salvos

```bash
cd CAMINHO/PARA/A/PASTA
```

Exemplo no Windows:
```bash
cd C:\Users\daniel\Downloads\estudo_de_rede
```

Exemplo no Mac/Linux:
```bash
cd /Users/daniel/Downloads/estudo_de_rede
```

---

### 3. Instale as dependências (só precisa fazer uma vez)

```bash
pip install -r requirements.txt
```

> ⚠️ Se der erro, tente: `pip3 install -r requirements.txt`

---

### 4. Execute a aplicação

```bash
streamlit run estudo_de_rede.py
```

> ✅ O navegador abrirá automaticamente em `http://localhost:8501`  
> Se não abrir sozinho, copie e cole esse endereço no navegador.

---

## Como usar

1. **Selecione um Estado (UF)** na barra lateral (esquerda)
2. Opcionalmente, informe o **Município**
3. Clique em **🗺️ Buscar e Plotar Mapa**
4. Aguarde o carregamento dos dados da API ANP
5. **Clique em qualquer marcador no mapa** para ver os detalhes do posto

---

## Dicas

- 🔍 Use o **multiselect de bandeiras** acima do mapa para filtrar quais redes exibir
- 📋 A aba **"Dados Tabulares"** mostra os dados em formato de tabela
- ⬇️ Você pode **baixar os dados em CSV** na aba de dados
- 📊 A aba **"Análise"** mostra gráficos de distribuição por bandeira e estado
- 🔄 Se quiser buscar novamente, clique em **"Limpar cache"** antes

---

## Estrutura dos arquivos

```
estudo_de_rede/
├── estudo_de_rede.py    ← Aplicação principal
├── requirements.txt     ← Dependências Python
└── COMO_EXECUTAR.md     ← Este arquivo
```

---

## Solução de Problemas

| Problema | Solução |
|---|---|
| `pip` não reconhecido | Use `pip3` ou `python -m pip` |
| Erro de conexão com a API | Verifique sua conexão com a internet |
| Mapa não aparece | Tente atualizar a página (F5) |
| Porta 8501 ocupada | Execute `streamlit run estudo_de_rede.py --server.port 8502` |

---

*Dados fornecidos pela **ANP – Agência Nacional do Petróleo, Gás Natural e Biocombustíveis***  
*API pública disponível em: https://revendedoresapi.anp.gov.br/swagger/index.html*
