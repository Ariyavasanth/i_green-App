class ProductRate {
  final String productName;
  final double operatorRate;
  final double trackerRate;
  final double supervisorRate;

  const ProductRate({
    required this.productName,
    required this.operatorRate,
    required this.trackerRate,
    required this.supervisorRate,
  });

  double getRateForDesignation(String designation) {
    final des = designation.trim().toLowerCase();
    if (des.contains('supervisor')) {
      return supervisorRate;
    } else if (des.contains('tracker')) {
      return trackerRate;
    } else {
      // Default to Operator rate if Operator or unrecognized
      return operatorRate;
    }
  }
}

const List<ProductRate> defaultProductRates = [
  ProductRate(
    productName: 'Duct',
    operatorRate: 4,
    trackerRate: 4,
    supervisorRate: 2,
  ),
  ProductRate(
    productName: 'Eb LT cable 240 sqmm',
    operatorRate: 0,
    trackerRate: 0,
    supervisorRate: 0,
  ),
  ProductRate(
    productName: 'EB Cable 11kv 120sqmm',
    operatorRate: 6,
    trackerRate: 6,
    supervisorRate: 3,
  ),
  ProductRate(
    productName: 'EB Cable 11kv 300sqmm',
    operatorRate: 8,
    trackerRate: 8,
    supervisorRate: 3,
  ),
  ProductRate(
    productName: 'EB Cable 11kv double',
    operatorRate: 12,
    trackerRate: 12,
    supervisorRate: 4,
  ),
  ProductRate(
    productName: 'EB Cable 33kv 3 cable',
    operatorRate: 12,
    trackerRate: 12,
    supervisorRate: 4,
  ),
  ProductRate(
    productName: 'EB Cable 33kv single cable',
    operatorRate: 8,
    trackerRate: 8,
    supervisorRate: 3,
  ),
  ProductRate(
    productName: 'MSPIPE EB /TWAD',
    operatorRate: 125,
    trackerRate: 125,
    supervisorRate: 50,
  ),
  ProductRate(
    productName: 'HDPE 110',
    operatorRate: 25,
    trackerRate: 25,
    supervisorRate: 10,
  ),
  ProductRate(
    productName: 'HDPE 160 to 250 dia',
    operatorRate: 50,
    trackerRate: 50,
    supervisorRate: 25,
  ),
  ProductRate(
    productName: 'HDPE 250 dia above 500mm',
    operatorRate: 75,
    trackerRate: 75,
    supervisorRate: 35,
  ),
  ProductRate(
    productName: 'HDPE above 500mm',
    operatorRate: 125,
    trackerRate: 125,
    supervisorRate: 50,
  ),
  ProductRate(
    productName: 'GAS Pipeline 100mm-250mm',
    operatorRate: 40,
    trackerRate: 40,
    supervisorRate: 20,
  ),
  ProductRate(
    productName: 'GAS Pipeline 250mm- 400mm',
    operatorRate: 60,
    trackerRate: 60,
    supervisorRate: 30,
  ),
  ProductRate(
    productName: 'GAS Pipeline 400mm-500mm',
    operatorRate: 80,
    trackerRate: 80,
    supervisorRate: 40,
  ),
  ProductRate(
    productName: 'GAS Pipeline above 500mm',
    operatorRate: 125,
    trackerRate: 125,
    supervisorRate: 50,
  ),
];

double calculateIncentiveRate(String productName, String designation) {
  final match = defaultProductRates.firstWhere(
    (p) => p.productName.trim().toLowerCase() == productName.trim().toLowerCase(),
    orElse: () => defaultProductRates.first,
  );
  return match.getRateForDesignation(designation);
}
