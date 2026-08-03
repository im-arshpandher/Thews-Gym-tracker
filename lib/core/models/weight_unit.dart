enum WeightUnit {
  kg('kg'),
  lbs('lbs');

  final String label;
  const WeightUnit(this.label);

  static WeightUnit fromString(String val) {
    return WeightUnit.values.firstWhere(
      (e) =>
          e.label.toLowerCase() == val.toLowerCase() ||
          e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => WeightUnit.kg,
    );
  }
}
