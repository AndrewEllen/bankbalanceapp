// lib/models/deductions.dart
class DeductionsSettings {
  final double unionMonthly;     // USDAW membership flat amount per month
  final double pensionRate;      // e.g. 0.05 = 5% employee contribution
  final double pensionCap;       // optional monthly cap (0 = none)
  final double taxFreeAllowance; // per year personal allowance
  final double taxBasicRate;     // e.g. 0.20
  final double taxHigherRate;    // e.g. 0.40
  final double taxHigherThreshold; // per year threshold for higher
  final double niLowerThreshold; // per year
  final double niEmployeeRate;   // main NI rate (Scotland uses UK NI)
  final double niUpperRate;      // rate above upper threshold
  final double niUpperThreshold; // per year

  const DeductionsSettings({
    this.unionMonthly = 0.0,
    this.pensionRate = 0.0,
    this.pensionCap = 0.0,
    this.taxFreeAllowance = 12570, // default UK
    this.taxBasicRate = 0.20,
    this.taxHigherRate = 0.40,
    this.taxHigherThreshold = 50270,
    this.niLowerThreshold = 12000,
    this.niEmployeeRate = 0.08,
    this.niUpperRate = 0.02,
    this.niUpperThreshold = 50270,
  });

  DeductionsSettings copyWith({
    double? unionMonthly,
    double? pensionRate,
    double? pensionCap,
    double? taxFreeAllowance,
    double? taxBasicRate,
    double? taxHigherRate,
    double? taxHigherThreshold,
    double? niLowerThreshold,
    double? niEmployeeRate,
    double? niUpperRate,
    double? niUpperThreshold,
  }) => DeductionsSettings(
    unionMonthly: unionMonthly ?? this.unionMonthly,
    pensionRate: pensionRate ?? this.pensionRate,
    pensionCap: pensionCap ?? this.pensionCap,
    taxFreeAllowance: taxFreeAllowance ?? this.taxFreeAllowance,
    taxBasicRate: taxBasicRate ?? this.taxBasicRate,
    taxHigherRate: taxHigherRate ?? this.taxHigherRate,
    taxHigherThreshold: taxHigherThreshold ?? this.taxHigherThreshold,
    niLowerThreshold: niLowerThreshold ?? this.niLowerThreshold,
    niEmployeeRate: niEmployeeRate ?? this.niEmployeeRate,
    niUpperRate: niUpperRate ?? this.niUpperRate,
    niUpperThreshold: niUpperThreshold ?? this.niUpperThreshold,
  );

  Map<String, dynamic> toJson() => {
    'unionMonthly': unionMonthly,
    'pensionRate': pensionRate,
    'pensionCap': pensionCap,
    'taxFreeAllowance': taxFreeAllowance,
    'taxBasicRate': taxBasicRate,
    'taxHigherRate': taxHigherRate,
    'taxHigherThreshold': taxHigherThreshold,
    'niLowerThreshold': niLowerThreshold,
    'niEmployeeRate': niEmployeeRate,
    'niUpperRate': niUpperRate,
    'niUpperThreshold': niUpperThreshold,
  };

  static DeductionsSettings fromJson(Map<String, dynamic> j) => DeductionsSettings(
    unionMonthly: (j['unionMonthly'] as num?)?.toDouble() ?? 0.0,
    pensionRate: (j['pensionRate'] as num?)?.toDouble() ?? 0.0,
    pensionCap: (j['pensionCap'] as num?)?.toDouble() ?? 0.0,
    taxFreeAllowance: (j['taxFreeAllowance'] as num?)?.toDouble() ?? 12570,
    taxBasicRate: (j['taxBasicRate'] as num?)?.toDouble() ?? 0.20,
    taxHigherRate: (j['taxHigherRate'] as num?)?.toDouble() ?? 0.40,
    taxHigherThreshold: (j['taxHigherThreshold'] as num?)?.toDouble() ?? 50270,
    niLowerThreshold: (j['niLowerThreshold'] as num?)?.toDouble() ?? 12000,
    niEmployeeRate: (j['niEmployeeRate'] as num?)?.toDouble() ?? 0.08,
    niUpperRate: (j['niUpperRate'] as num?)?.toDouble() ?? 0.02,
    niUpperThreshold: (j['niUpperThreshold'] as num?)?.toDouble() ?? 50270,
  );
}
