class DataAvailability {
  final bool macroNews;
  final bool analystBreakdown;
  final bool riskAssessment;
  final bool bullishMomentum;
  final bool inflowUp;

  const DataAvailability({
    required this.macroNews,
    required this.analystBreakdown,
    required this.riskAssessment,
    required this.bullishMomentum,
    required this.inflowUp,
  });

  factory DataAvailability.fromJson(Map<String, dynamic> json) {
    return DataAvailability(
      macroNews: json['macro_news'] ?? false,
      analystBreakdown: json['analyst_breakdown'] ?? false,
      riskAssessment: json['risk_assessment'] ?? false,
      bullishMomentum: json['bullish_momentum'] ?? false,
      inflowUp: json['inflow_up'] ?? false,
    );
  }

  const DataAvailability.empty()
      : macroNews = false,
        analystBreakdown = false,
        riskAssessment = false,
        bullishMomentum = false,
        inflowUp = false;

  bool get anyChip => bullishMomentum || inflowUp || riskAssessment;

  bool get anyPanel => macroNews || analystBreakdown || riskAssessment;
}

