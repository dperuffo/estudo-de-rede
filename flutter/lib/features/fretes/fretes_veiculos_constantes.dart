// Fase Fretes-Dados-Completos-2 — pedido do Daniel (inspirado em telas de
// outras plataformas de frete): cliente informa que tipo de veículo e
// carroceria servem pro frete, motorista filtra a lista pelo que ele tem.
// Mesmas categorias do painel web (src/lib/fretesVeiculos.ts).

const Map<String, List<String>> gruposVeiculoFrete = {
  'Leves': ['3/4', 'Toco', 'VLC', 'Fiorino', 'Van', 'HR'],
  'Médios': ['Bitruck', 'Truck'],
  'Pesados': ['Carreta', 'Carreta LS', 'Bitrem', 'Rodotrem'],
};

List<String> get veiculosFrete => gruposVeiculoFrete.values.expand((v) => v).toList();

const List<String> carroceriasFrete = [
  'Baú',
  'Sider',
  'Grade Baixa',
  'Graneleiro',
  'Caçamba',
  'Prancha',
  'Tanque',
  'Frigorífico/Refrigerado',
  'Bug/Porta Container',
];
