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

  factory DataAvailability.fromReport(Map<String, dynamic> report) {
    final analyst = report['investment_debate_state'];
    final risk = report['risk_debate_state'];
    return DataAvailability(
      macroNews: report['news_report'] != null,
      analystBreakdown:
          analyst is Map && analyst['history'] != null,
      riskAssessment: risk is Map && risk['history'] != null,
      bullishMomentum: report['market_report'] != null,
      inflowUp: report['fundamentals_report'] != null,
    );
  }

  bool get anyChip => bullishMomentum || inflowUp || riskAssessment;

  bool get anyPanel => macroNews || analystBreakdown || riskAssessment;
}

