import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(_aboutText),
      ),
    );
  }
}

const String _aboutText = '''
TradingAgents is a multi-agent trading framework that mirrors the dynamics of real-world trading firms. By deploying specialized LLM-powered agents—ranging from fundamentals analysts and sentiment experts to researchers, trader and risk management roles—the platform collaboratively evaluates market conditions and informs trading decisions.

The LetAgents_DYOR app orchestrates these agents behind the scenes. When you request an analysis for a particular stock and date, each agent gathers data or insights and debates with other agents to form the best strategy. A trader agent then composes the results into a report, which the risk management team reviews before finalizing a simulated trade decision.

The generated reports depend on the language models, data quality and other factors, so results may vary and are provided for research curiosity only—not as financial advice. For more details on the underlying framework visit https://github.com/TauricResearch/TradingAgents.
''';
