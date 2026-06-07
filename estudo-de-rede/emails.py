from __future__ import annotations
import os

RESEND_API_KEY = os.environ.get("RESEND_API_KEY", "")
APP_URL        = os.environ.get("APP_URL", "https://fxgestaodefrotasonline.com")
FROM_EMAIL     = "FNI Pro-Frotas <noreply@fxgestaodefrotasonline.com>"
SUPORTE_EMAIL  = "d.peruffo@gmail.com"

def _enviar(to: str, subject: str, html: str) -> bool:
    if not RESEND_API_KEY:
        print(f"[emails] RESEND_API_KEY nao configurada")
        return False
    try:
        import resend
        resend.api_key = RESEND_API_KEY
        resend.Emails.send({"from": FROM_EMAIL, "to": [to], "subject": subject, "html": html})
        print(f"[emails] Enviado: {subject} para {to}")
        return True
    except Exception as e:
        print(f"[emails] Erro: {e}")
        return False

def _base(conteudo: str, titulo: str = "") -> str:
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>{titulo}</title></head>
<body style="margin:0;padding:0;background:#f4f6fb;font-family:Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:32px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">
<tr><td style="background:linear-gradient(135deg,#0a0e27 0%,#0d1b4b 100%);padding:28px 32px;text-align:center;">
<div style="font-size:22px;font-weight:800;color:#fff;">FNI Pro-Frotas</div>
<div style="font-size:12px;color:rgba(255,255,255,.6);margin-top:4px;">Plataforma de Inteligencia de Rede</div>
</td></tr>
<tr><td style="padding:32px;">{conteudo}</td></tr>
<tr><td style="background:#f8f9fc;padding:20px 32px;text-align:center;border-top:1px solid #eee;">
<p style="margin:0;font-size:12px;color:#999;">FNI Pro-Frotas &middot; <a href="{APP_URL}" style="color:#1040a0;">fxgestaodefrotasonline.com</a><br>
Duvidas? <a href="mailto:{SUPORTE_EMAIL}" style="color:#1040a0;">{SUPORTE_EMAIL}</a></p>
</td></tr>
</table></td></tr></table></body></html>"""

def enviar_boas_vindas(email: str, nome_empresa: str) -> bool:
    c = f"""<h2 style="color:#0d1b4b;margin-top:0;">Bem-vindo ao FNI Pro-Frotas!</h2>
    <p style="color:#444;line-height:1.6;">Sua empresa <strong>{nome_empresa}</strong> esta pronta.
    Voce tem acesso completo ao <strong>Plano Profissional por 14 dias</strong>.</p>
    <h3 style="color:#0d1b4b;">Por onde comecar?</h3>
    <ul style="color:#444;line-height:1.8;">
    <li>Cadastre seus veiculos</li>
    <li>Registre abastecimentos</li>
    <li>Explore os relatorios de consumo</li></ul>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#1040a0;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Acessar a plataforma</a>
    </div>"""
    return _enviar(email, "Bem-vindo ao FNI Pro-Frotas! Seu trial comecou", _base(c, "Boas-vindas"))

def enviar_engajamento_d3(email: str, nome_empresa: str) -> bool:
    c = f"""<h2 style="color:#0d1b4b;margin-top:0;">Voce ja cadastrou seus veiculos?</h2>
    <p style="color:#444;line-height:1.6;">Faz 3 dias que <strong>{nome_empresa}</strong> iniciou o trial.
    Cadastre sua frota para comecar a monitorar consumo e custos.</p>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#1040a0;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Cadastrar veiculos</a>
    </div>"""
    return _enviar(email, "Voce ja cadastrou sua frota?", _base(c, "Dica D+3"))

def enviar_engajamento_d7(email: str, nome_empresa: str) -> bool:
    c = f"""<h2 style="color:#0d1b4b;margin-top:0;">7 dias de FNI Pro-Frotas!</h2>
    <p style="color:#444;line-height:1.6;"><strong>{nome_empresa}</strong> esta ha uma semana na plataforma!
    Use o modulo Analise de Precos ANP para verificar se os postos praticam precos justos.</p>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#1040a0;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Ver analise de precos</a>
    </div>"""
    return _enviar(email, "Uma semana de FNI Pro-Frotas!", _base(c, "Engajamento D+7"))

def enviar_alerta_trial_d12(email: str, nome_empresa: str, dias_restantes: int = 2) -> bool:
    c = f"""<h2 style="color:#c0392b;margin-top:0;">Seu trial expira em {dias_restantes} dia(s)!</h2>
    <p style="color:#444;line-height:1.6;">O trial de <strong>{nome_empresa}</strong> esta chegando ao fim.
    Escolha seu plano para continuar sem interrupcao.</p>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#c0392b;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Escolher meu plano agora</a>
    </div>"""
    return _enviar(email, f"Seu trial expira em {dias_restantes} dia(s)!", _base(c, "Trial expirando"))

def enviar_pagamento_confirmado(email: str, nome_empresa: str, plano: str = "", valor: str = "") -> bool:
    c = f"""<h2 style="color:#27ae60;margin-top:0;">Pagamento confirmado!</h2>
    <p style="color:#444;line-height:1.6;">Recebemos o pagamento de <strong>{nome_empresa}</strong>. Sua assinatura esta ativa!</p>
    <div style="background:#f0fff4;border:1px solid #27ae60;border-radius:8px;padding:16px;margin:16px 0;">
    Plano: <strong>{plano}</strong> &middot; Valor: <strong>R$ {valor}/mes</strong>
    </div>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#1040a0;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Acessar a plataforma</a>
    </div>"""
    return _enviar(email, f"Pagamento confirmado - Plano {plano} ativo!", _base(c, "Pagamento confirmado"))

def enviar_pagamento_falhou(email: str, nome_empresa: str) -> bool:
    c = f"""<h2 style="color:#c0392b;margin-top:0;">Problema no pagamento</h2>
    <p style="color:#444;line-height:1.6;">Nao conseguimos processar o pagamento de <strong>{nome_empresa}</strong>.
    Atualize seus dados de pagamento para continuar usando a plataforma.</p>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#c0392b;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Atualizar dados de pagamento</a>
    </div>"""
    return _enviar(email, "Problema no pagamento - atualize seus dados", _base(c, "Pagamento falhou"))

def enviar_cancelamento(email: str, nome_empresa: str) -> bool:
    c = f"""<h2 style="color:#0d1b4b;margin-top:0;">Assinatura cancelada</h2>
    <p style="color:#444;line-height:1.6;">Confirmamos o cancelamento de <strong>{nome_empresa}</strong>.
    Seus dados ficam disponiveis por 30 dias para exportacao.</p>
    <div style="text-align:center;margin-top:24px;">
    <a href="{APP_URL}" style="background:#1040a0;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:700;">Reativar assinatura</a>
    </div>"""
    return _enviar(email, "Sua assinatura foi cancelada", _base(c, "Cancelamento"))

def disparar_email_evento(tipo_evento: str, email: str, nome_empresa: str, **kwargs) -> bool:
    mapa = {
        "boas_vindas":       lambda: enviar_boas_vindas(email, nome_empresa),
        "engajamento_d3":    lambda: enviar_engajamento_d3(email, nome_empresa),
        "engajamento_d7":    lambda: enviar_engajamento_d7(email, nome_empresa),
        "trial_expirando":   lambda: enviar_alerta_trial_d12(email, nome_empresa, kwargs.get("dias", 2)),
        "payment_succeeded": lambda: enviar_pagamento_confirmado(email, nome_empresa, kwargs.get("plano",""), kwargs.get("valor","")),
        "payment_failed":    lambda: enviar_pagamento_falhou(email, nome_empresa),
        "cancelamento":      lambda: enviar_cancelamento(email, nome_empresa),
    }
    fn = mapa.get(tipo_evento)
    if fn:
        return fn()
    print(f"[emails] Evento desconhecido: {tipo_evento}")
    return False
