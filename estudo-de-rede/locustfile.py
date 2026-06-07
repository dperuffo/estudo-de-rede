# ═══════════════════════════════════════════════════════════════════════════
#  FNI Gestão de Frotas — Teste de Carga (Locust)
#  Fase 5: simular 100 tenants com 10 usuários cada
#
#  Como rodar:
#      locust -f locustfile.py --host=https://fxgestaodefrotasonline.com
#      Acesse http://localhost:8089 para o dashboard
# ═══════════════════════════════════════════════════════════════════════════

from locust import HttpUser, task, between
import random

class UsuarioFrota(HttpUser):
    """Simula um usuário comum da plataforma."""
    wait_time = between(1, 3)  # espera 1-3s entre requests

    def on_start(self):
        """Setup inicial — simula abertura do app."""
        self.client.get("/")

    @task(5)
    def acessar_home(self):
        """Acesso à página principal — mais frequente."""
        self.client.get("/", name="Home")

    @task(3)
    def acessar_healthcheck(self):
        """Healthcheck do app."""
        self.client.get("/healthz", name="Healthcheck")

    @task(2)
    def acessar_static(self):
        """Recursos estáticos."""
        self.client.get("/static/", name="Static")


class UsuarioANP(HttpUser):
    """Simula usuário consultando preços ANP."""
    wait_time = between(2, 5)

    @task
    def consultar_anp(self):
        self.client.get("/?page=anp", name="Consulta ANP")


class AdminUsuario(HttpUser):
    """Simula admin da plataforma."""
    wait_time = between(3, 8)

    @task
    def acessar_admin(self):
        self.client.get("/?admin=true", name="Admin")
