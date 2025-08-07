// lib/services/deductions_service.dart
import 'dart:math' as math;
import '../models/deductions.dart';

/// Stateless calculators to mirror your spreadsheet exactly once configured.
class DeductionsService {
  const DeductionsService();

  /// Convert gross for a period to an annualized amount for tax/NI calc, then prorate back.
  Map<String, double> computeNetForPeriod({
    required double periodGross,
    required int periodsPerYear, // e.g. 13 for 4-weekly
    required DeductionsSettings s,
  }) {
    final annualGross = periodGross * periodsPerYear;

    // Pension (employee) on gross
    double annualPension = annualGross * s.pensionRate;
    if (s.pensionCap > 0) annualPension = math.min(annualPension, s.pensionCap * 12);

    // Taxable after pension and allowance
    final taxableAnnual = math.max(0, annualGross - annualPension - s.taxFreeAllowance);
    final basicBand = math.max(0, math.min(taxableAnnual, s.taxHigherThreshold - s.taxFreeAllowance));
    final higherBand = math.max(0, taxableAnnual - basicBand);
    final annualTax = basicBand * s.taxBasicRate + higherBand * s.taxHigherRate;

    // NI (simplified main rate + upper rate)
    double niBase = math.max(0, annualGross - s.niLowerThreshold);
    double niBasicPart = math.max(0, math.min(niBase, s.niUpperThreshold - s.niLowerThreshold));
    double niUpperPart = math.max(0, niBase - niBasicPart);
    final annualNi = niBasicPart * s.niEmployeeRate + niUpperPart * s.niUpperRate;

    // Union monthly flat -> annual
    final annualUnion = s.unionMonthly * 12;

    // Back to per period
    final pension = annualPension / periodsPerYear;
    final tax = annualTax / periodsPerYear;
    final ni = annualNi / periodsPerYear;
    final union = annualUnion / periodsPerYear;

    final net = periodGross - pension - tax - ni - union;
    return {
      'gross': periodGross,
      'pension': pension,
      'tax': tax,
      'ni': ni,
      'union': union,
      'net': net,
    };
  }
}
