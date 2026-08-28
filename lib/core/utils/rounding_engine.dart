enum RoundingMethod {
  none,
  roundDown,
  roundUp,
  standard;

  static RoundingMethod fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'round down':
      case 'rounddown':
        return RoundingMethod.roundDown;
      case 'round up':
      case 'roundup':
        return RoundingMethod.roundUp;
      case 'standard':
        return RoundingMethod.standard;
      case 'none':
      default:
        return RoundingMethod.none;
    }
  }

  String toDisplayString() {
    switch (this) {
      case RoundingMethod.roundDown:
        return 'Round Down';
      case RoundingMethod.roundUp:
        return 'Round Up';
      case RoundingMethod.standard:
        return 'Standard';
      case RoundingMethod.none:
        return 'None';
    }
  }
}

class RoundingResult {
  final double roundedTotal;
  final double roundingAdjustment;

  RoundingResult({
    required this.roundedTotal,
    required this.roundingAdjustment,
  });
}

class RoundingEngine {
  RoundingEngine._();

  static RoundingResult calculate(double amount, RoundingMethod method) {
    if (amount <= 0) {
      return RoundingResult(roundedTotal: 0.0, roundingAdjustment: 0.0);
    }

    double rounded = amount;
    switch (method) {
      case RoundingMethod.roundDown:
        rounded = amount.floorToDouble();
        break;
      case RoundingMethod.roundUp:
        rounded = amount.ceilToDouble();
        break;
      case RoundingMethod.standard:
        rounded = amount.roundToDouble();
        break;
      case RoundingMethod.none:
        rounded = double.parse(amount.toStringAsFixed(2));
        break;
    }

    final adjustment = double.parse((rounded - amount).toStringAsFixed(2));
    return RoundingResult(
      roundedTotal: rounded,
      roundingAdjustment: adjustment,
    );
  }
}
