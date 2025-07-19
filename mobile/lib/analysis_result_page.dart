import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'data_availability.dart';


/// Displays results from an analysis run.
class AnalysisResultPage extends StatelessWidget {
  /// Raw analysis data to display.
  final Map<String, dynamic> analysisData;

  const AnalysisResultPage({super.key, required this.analysisData});

  DataAvailability get _availability => analysisData.containsKey('availability')
      ? DataAvailability.fromJson(
          analysisData['availability'] as Map<String, dynamic>)
      : const DataAvailability.empty();

  String? get _decision => analysisData['decision'] as String?;

  Map<String, dynamic>? get _report =>
      analysisData['report'] as Map<String, dynamic>?;

  List<String> get _messages =>
      List<String>.from(analysisData['messages'] ?? const []);

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHighlights(),
            const SizedBox(height: 16),
            _buildInsightSections(),
            if (_messages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStreamingBox(),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );


    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Analysis Results'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return Stack(
            children: [
              isWide
                  ? Row(
                      children: [
                        Expanded(child: content),
                        if (_decision != null) _buildRecommendationBanner(),
                      ],
                    )
                  : content,
              if (!isWide && _decision != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildRecommendationBanner(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighlights() {
    if (!_availability.anyChip) return const SizedBox.shrink();
    final chips = <Widget>[];
    if (_availability.bullishMomentum) {
      chips.add(const Chip(
          avatar: Icon(Icons.trending_up), label: Text('Bullish Momentum')));
    }
    if (_availability.inflowUp) {
      chips.add(
          const Chip(avatar: Icon(Icons.attach_money), label: Text('Inflow Up')));
    }
    if (_availability.riskAssessment) {
      chips.add(
          const Chip(avatar: Icon(Icons.flag), label: Text('Low Risk')));
    }
    return Wrap(spacing: 8, children: chips);
  }

  Widget _buildInsightSections() {
    if (_report == null) return const SizedBox.shrink();
    final panels = <ExpansionPanelRadio>[];
    if (_report?['market_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'market',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Market Analysis')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _report!['market_report'] as String),
          ),
        ),
      );
    }
    if (_report?['fundamentals_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'fundamentals',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Fundamentals Overview')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _report!['fundamentals_report'] as String),
          ),
        ),
      );
    }
    if (_report?['sentiment_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'sentiment',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Sentiment Summary')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _report!['sentiment_report'] as String),
          ),
        ),
      );
    }
    if (_availability.macroNews && _report?['news_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'news',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Macro & Market News')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _report!['news_report'] as String),
          ),
        ),
      );
    }
    if (_availability.analystBreakdown &&
        _report?['investment_debate_state'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'analysts',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Analyst Team Breakdown')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
                data: _report!['investment_debate_state']['history'] as String),
          ),
        ),
      );
    }
    if (_availability.riskAssessment && _report?['risk_debate_state'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'risk',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Risk Assessment')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child:
                MarkdownBody(data: _report!['risk_debate_state']['history'] as String),
          ),
        ),
      );
    }
    if (_report?['final_trade_decision'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'final',
          headerBuilder: (context, isExpanded) =>
              const ListTile(title: Text('Final Trade Decision')),
          body: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.lightGreen.shade50,
            child: MarkdownBody(
              data:
                  '**FINAL TRANSACTION PROPOSAL**\n\n${_report!['final_trade_decision']}',
            ),
          ),
        ),
      );
    }
    if (panels.isEmpty) return const SizedBox.shrink();
    return ExpansionPanelList.radio(children: panels);
  }

  Widget _buildStreamingBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              '── Current Report ──',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: MarkdownBody(
                  data: _messages.join('\n'),
                  selectable: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested Action: ${_decision ?? ''}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Divider(color: Colors.white54),
          Row(
            children: const [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Trigger: RSI > 70',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
