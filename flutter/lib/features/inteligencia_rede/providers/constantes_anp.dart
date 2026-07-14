// Constantes de referência geográfica/ANP usadas pelas 10 abas de
// Inteligência de Rede — porto 1:1 de src/lib/constants.ts (ESTADO_PARA_UF,
// ANP_PRECO_REFERENCIA_FALLBACK, PRODUTO_PARA_CATEGORIA_ANP) e das
// constantes fixas duplicadas em cada _components/*.tsx da web (REGIOES,
// TOTAL_MUNICIPIOS_REGIAO, TOTAL_MUNICIPIOS_UF, UF_CENTROIDES) — mantidas
// juntas aqui num arquivo só pra não duplicar 5x como a web faz.

// Macrorregiões brasileiras (agrupamento IBGE) — usado em Macrorregião &
// Expansão e no Modo Comparativo (toggle "Regiões").
const Map<String, List<String>> regioesBrasil = {
  'Norte': ['AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO'],
  'Nordeste': ['AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE'],
  'Centro-Oeste': ['DF', 'GO', 'MS', 'MT'],
  'Sudeste': ['ES', 'MG', 'RJ', 'SP'],
  'Sul': ['PR', 'RS', 'SC'],
};

// Total de municípios por macrorregião (fonte: IBGE) — usado só pra % de
// cobertura em Macrorregião & Expansão.
const Map<String, int> totalMunicipiosRegiao = {
  'Norte': 449,
  'Nordeste': 1794,
  'Centro-Oeste': 467,
  'Sudeste': 1668,
  'Sul': 1191,
};

// Total de municípios por UF (referência aproximada IBGE) — usado no Modo
// Comparativo pra % de cobertura por estado.
const Map<String, int> totalMunicipiosUf = {
  'AC': 22, 'AL': 102, 'AP': 16, 'AM': 62, 'BA': 417, 'CE': 184, 'DF': 1,
  'ES': 78, 'GO': 246, 'MA': 217, 'MT': 141, 'MS': 79, 'MG': 853, 'PA': 144,
  'PB': 223, 'PR': 399, 'PE': 184, 'PI': 224, 'RJ': 92, 'RN': 167, 'RS': 497,
  'RO': 52, 'RR': 15, 'SC': 295, 'SP': 645, 'SE': 75, 'TO': 139,
};

// Centroide aproximado de cada UF (lat, lon) — usado só pra plotar bolhas no
// Mapa de Gaps (Cobertura x Demanda), já que o gap é por UF, não por posto.
const Map<String, List<double>> ufCentroides = {
  'AC': [-9.0, -70.0], 'AL': [-9.6, -36.6], 'AP': [1.4, -51.8], 'AM': [-4.0, -63.0],
  'BA': [-12.5, -41.7], 'CE': [-5.2, -39.3], 'DF': [-15.8, -47.9], 'ES': [-19.8, -40.5],
  'GO': [-15.9, -49.6], 'MA': [-5.0, -45.3], 'MT': [-12.9, -55.8], 'MS': [-20.5, -54.6],
  'MG': [-18.6, -44.5], 'PA': [-3.9, -52.5], 'PB': [-7.2, -36.5], 'PR': [-24.9, -51.5],
  'PE': [-8.3, -37.9], 'PI': [-7.7, -42.7], 'RJ': [-22.3, -42.7], 'RN': [-5.8, -36.6],
  'RS': [-30.0, -53.4], 'RO': [-10.9, -62.8], 'RR': [2.0, -61.4], 'SC': [-27.5, -50.5],
  'SP': [-22.2, -48.6], 'SE': [-10.6, -37.4], 'TO': [-10.2, -48.3],
};

// Nome do estado (como a ANP grava, maiúsculo sem acento) por UF — e o
// caminho inverso, usado pra casar a coluna "estado" de
// anp_precos_referencia com a sigla UF.
const Map<String, String> ufParaEstadoAnp = {
  'AC': 'ACRE', 'AL': 'ALAGOAS', 'AP': 'AMAPA', 'AM': 'AMAZONAS', 'BA': 'BAHIA',
  'CE': 'CEARA', 'DF': 'DISTRITO FEDERAL', 'ES': 'ESPIRITO SANTO', 'GO': 'GOIAS',
  'MA': 'MARANHAO', 'MT': 'MATO GROSSO', 'MS': 'MATO GROSSO DO SUL', 'MG': 'MINAS GERAIS',
  'PA': 'PARA', 'PB': 'PARAIBA', 'PR': 'PARANA', 'PE': 'PERNAMBUCO', 'PI': 'PIAUI',
  'RJ': 'RIO DE JANEIRO', 'RN': 'RIO GRANDE DO NORTE', 'RS': 'RIO GRANDE DO SUL',
  'RO': 'RONDONIA', 'RR': 'RORAIMA', 'SC': 'SANTA CATARINA', 'SP': 'SAO PAULO',
  'SE': 'SERGIPE', 'TO': 'TOCANTINS',
};

final Map<String, String> estadoParaUf = {
  for (final entry in ufParaEstadoAnp.entries) entry.value: entry.key,
};

// Referência nacional de preço médio de combustível (ESTIMATIVA — só usada
// quando anp_precos_referencia ainda não tem dados importados pra semana).
const Map<String, double> anpPrecoReferenciaFallback = {
  'Gasolina Comum': 6.3,
  'Gasolina Aditivada': 6.45,
  'Diesel S10': 6.05,
  'Diesel S500': 5.95,
  'Etanol': 4.1,
  'GNV': 4.25,
};

// Nome do "Produto" como aparece no preço por posto -> categoria oficial da
// ANP (a ANP agrupa comum/aditivado numa única categoria por combustível).
const Map<String, String> produtoParaCategoriaAnp = {
  'Diesel S-500 Comum': 'OLEO DIESEL',
  'Diesel S-500 Aditivado': 'OLEO DIESEL',
  'Diesel S-10 Comum': 'OLEO DIESEL S10',
  'Diesel S-10 Aditivado': 'OLEO DIESEL S10',
  'Etanol Comum': 'ETANOL HIDRATADO',
  'Etanol Aditivado': 'ETANOL HIDRATADO',
  'Gasolina Comum': 'GASOLINA COMUM',
  'Gasolina Aditivada': 'GASOLINA ADITIVADA',
  'Gasolina Alta Octanagem': 'GASOLINA ADITIVADA',
  'GNV': 'GNV',
  'GLP': 'GLP',
};

String nomeUf(String uf) => '$uf — ${ufParaEstadoAnp[uf] ?? uf}';
