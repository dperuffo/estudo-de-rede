const GITHUB_RAW = "https://raw.githubusercontent.com/dperuffo/estudo-de-rede/master/landing";

const ROUTES = {
  "/":                    "index.html",
  "/index.html":          "index.html",
  "/sobre":               "sobre.html",
  "/sobre.html":          "sobre.html",
  "/sobre-en":            "sobre-en.html",
  "/sobre-en.html":       "sobre-en.html",
  "/termos":              "termos.html",
  "/termos.html":         "termos.html",
  "/termos-en":           "termos-en.html",
  "/termos-en.html":      "termos-en.html",
  "/privacidade":         "privacidade.html",
  "/privacidade.html":    "privacidade.html",
  "/privacidade-en":      "privacidade-en.html",
  "/privacidade-en.html": "privacidade-en.html",
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;
    const file = ROUTES[path] || "index.html";
    const raw = `${GITHUB_RAW}/${file}`;
    try {
      const res = await fetch(raw, { cf: { cacheTtl: 300 } });
      const html = await res.text();
      return new Response(html, {
        headers: {
          "Content-Type": "text/html; charset=utf-8",
          "Cache-Control": "public, max-age=300",
          "X-Served-By": "fni-landing-worker",
        },
      });
    } catch (e) {
      return new Response("Erro: " + e.message, { status: 500 });
    }
  },
};
