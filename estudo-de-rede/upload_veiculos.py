"""
Upload em lote de veículos com atributos FIPE.
Template Excel para download e upload pelo usuário.
"""
from __future__ import annotations
import os, re, io
import streamlit as st
import pandas as pd
from datetime import datetime, timezone

# Colunas do template
COLUNAS_TEMPLATE = [
    "placa",
    "marca",
    "modelo", 
    "ano_modelo",
    "cor",
    "tipo_veiculo",
    "municipio",
    "uf_veiculo",
    "codigo_fipe",
    "valor_fipe",
    "combustivel_fipe",
]

COLUNAS_OBRIGATORIAS = ["placa", "marca", "modelo"]

TIPO_VEICULO_OPCOES = ["Carro", "Moto", "Caminhão", "Van", "Ônibus", "Pickup"]
COMBUSTIVEL_OPCOES  = ["Gasolina", "Diesel", "Flex", "Etanol", "GNV", "Elétrico", "Híbrido"]
UF_OPCOES = ["AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS","MT",
             "PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC","SE","SP","TO"]

def _db():
    try:
        from supabase import create_client
        return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
    except Exception:
        return None

def _empresa_id():
    try:
        return (st.session_state.get("_empresa_ativa") or {}).get("id", "")
    except Exception:
        return ""

def _gerar_template() -> bytes:
    """Gera o template Excel com exemplos e instruções."""
    exemplos = [
        {
            "placa": "ABC1234",
            "marca": "CHEVROLET",
            "modelo": "ONIX SED. PLUS PREM. 1.0 12V TB FLEX AUT",
            "ano_modelo": "2024/2025",
            "cor": "Branca",
            "tipo_veiculo": "Carro",
            "municipio": "São Paulo",
            "uf_veiculo": "SP",
            "codigo_fipe": "004504-7",
            "valor_fipe": 99936.00,
            "combustivel_fipe": "Flex",
        },
        {
            "placa": "DEF5678",
            "marca": "VOLKSWAGEN",
            "modelo": "GOLS 1.0 FLEX 12V 5p",
            "ano_modelo": "2023/2023",
            "cor": "Prata",
            "tipo_veiculo": "Carro",
            "municipio": "Rio de Janeiro",
            "uf_veiculo": "RJ",
            "codigo_fipe": "005273-0",
            "valor_fipe": 62500.00,
            "combustivel_fipe": "Flex",
        },
    ]
    df = pd.DataFrame(exemplos, columns=COLUNAS_TEMPLATE)
    
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Veiculos", index=False)
        
        # Aba de instruções
        instrucoes = pd.DataFrame({
            "Campo": COLUNAS_TEMPLATE,
            "Obrigatorio": ["Sim" if c in COLUNAS_OBRIGATORIAS else "Não" for c in COLUNAS_TEMPLATE],
            "Descricao": [
                "Placa do veículo (formato ABC1234 ou ABC1D234)",
                "Marca do fabricante (ex: CHEVROLET, VOLKSWAGEN)",
                "Modelo completo conforme tabela FIPE",
                "Ano modelo (ex: 2024/2025)",
                "Cor do veículo",
                f"Tipo: {', '.join(TIPO_VEICULO_OPCOES)}",
                "Cidade de registro",
                f"UF: {', '.join(UF_OPCOES[:5])}... etc",
                "Código FIPE (ex: 004504-7)",
                "Valor de mercado FIPE em R$",
                f"Combustível: {', '.join(COMBUSTIVEL_OPCOES)}",
            ]
        })
        instrucoes.to_excel(writer, sheet_name="Instrucoes", index=False)
        
        # Formata planilha
        ws = writer.sheets["Veiculos"]
        for col in ws.columns:
            max_len = max(len(str(cell.value or "")) for cell in col)
            ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 50)
    
    return buf.getvalue()

def _normalizar_placa(placa: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", str(placa or "").upper())

def _processar_upload(df: pd.DataFrame, empresa_id: str) -> tuple[int, int, list]:
    """Processa o DataFrame e salva no Supabase. Retorna (ok, erros, lista_erros)."""
    db = _db()
    if not db:
        return 0, 0, ["Erro de conexão com o banco"]
    
    ok_count = 0
    err_count = 0
    erros = []
    
    for i, row in df.iterrows():
        placa = _normalizar_placa(str(row.get("placa", "")))
        if not placa:
            err_count += 1
            erros.append(f"Linha {i+2}: placa inválida")
            continue
        
        marca = str(row.get("marca", "")).strip()
        modelo = str(row.get("modelo", "")).strip()
        
        if not marca or not modelo:
            err_count += 1
            erros.append(f"Linha {i+2} ({placa}): marca e modelo obrigatórios")
            continue
        
        try:
            valor_fipe = float(str(row.get("valor_fipe", 0) or 0).replace(",", ".").replace("R$", "").strip() or 0)
        except Exception:
            valor_fipe = None
        
        registro = {
            "placa": placa,
            "marca": marca,
            "modelo": modelo,
            "ano_modelo": str(row.get("ano_modelo", "") or "").strip() or None,
            "cor": str(row.get("cor", "") or "").strip() or None,
            "tipo_veiculo": str(row.get("tipo_veiculo", "") or "").strip() or None,
            "municipio": str(row.get("municipio", "") or "").strip() or None,
            "uf_veiculo": str(row.get("uf_veiculo", "") or "").strip() or None,
            "codigo_fipe": str(row.get("codigo_fipe", "") or "").strip() or None,
            "valor_fipe": valor_fipe if valor_fipe else None,
            "combustivel_fipe": str(row.get("combustivel_fipe", "") or "").strip() or None,
            "empresa_id": empresa_id,
            "buscado_em": datetime.now(tz=timezone.utc).isoformat(),
        }
        
        try:
            db.table("frota_veiculos_fipe").upsert(registro, on_conflict="placa").execute()
            ok_count += 1
        except Exception as e:
            err_count += 1
            erros.append(f"Linha {i+2} ({placa}): {str(e)[:80]}")
    
    return ok_count, err_count, erros

def mostrar_upload_veiculos():
    """Tela de upload em lote de veículos."""
    st.markdown("### 📋 Cadastro em Lote de Veículos")
    st.caption("Baixe o template, preencha com os dados dos seus veículos e faça o upload.")
    
    # Download template
    col1, col2 = st.columns([2, 1])
    with col1:
        st.download_button(
            label="📥 Baixar Template Excel",
            data=_gerar_template(),
            file_name="template_veiculos_fipe.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            use_container_width=True,
        )
    with col2:
        st.info(f"📌 {len(COLUNAS_TEMPLATE)} campos disponíveis\n3 obrigatórios")
    
    st.markdown("---")
    
    # Upload
    st.markdown("**📤 Upload da planilha preenchida:**")
    arquivo = st.file_uploader(
        "Selecione o arquivo Excel (.xlsx) ou CSV",
        type=["xlsx", "xls", "csv"],
        key="upload_veiculos_lote",
    )
    
    if arquivo:
        try:
            if arquivo.name.lower().endswith(".csv"):
                df = pd.read_csv(arquivo, dtype=str)
            else:
                df = pd.read_excel(arquivo, dtype=str)
            
            # Normaliza colunas
            df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]
            
            # Verifica colunas obrigatórias
            cols_faltando = [c for c in COLUNAS_OBRIGATORIAS if c not in df.columns]
            if cols_faltando:
                st.error(f"❌ Colunas obrigatórias faltando: {', '.join(cols_faltando)}")
                return
            
            st.success(f"✅ {len(df)} veículos encontrados no arquivo")
            
            # Preview
            with st.expander("👁 Prévia dos dados", expanded=True):
                st.dataframe(df.head(5), use_container_width=True)
            
            # Botão de importar
            if st.button("🚀 Importar Veículos", type="primary", use_container_width=True):
                empresa_id = _empresa_id()
                with st.spinner(f"Importando {len(df)} veículos..."):
                    ok, erros_count, lista_erros = _processar_upload(df, empresa_id)
                
                if ok > 0:
                    st.success(f"✅ {ok} veículo(s) importado(s) com sucesso!")
                if erros_count > 0:
                    st.warning(f"⚠️ {erros_count} erro(s) encontrado(s)")
                    with st.expander("Ver erros"):
                        for e in lista_erros:
                            st.write(f"• {e}")
        
        except Exception as e:
            st.error(f"❌ Erro ao ler arquivo: {e}")
