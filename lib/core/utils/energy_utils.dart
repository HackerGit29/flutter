class EnergyAggregator {
  double calculateTotal(List<double> readings) {
    return readings.fold(0.0, (sum, r) => sum + r);
  }

  double calculateAverage(List<double> readings) {
    if (readings.isEmpty) return 0.0;
    return calculateTotal(readings) / readings.length;
  }
}
