import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'data_availability.dart';

class AnalysisResultPage extends StatelessWidget {
  final String? decision;
  final Map<String, dynamic>? report;
  final DataAvailability availability;
  final List<String>? messages;

  const AnalysisResultPage({
    super.key,
    this.decision,
    this.report,
    this.messages,
    this.availability = const DataAvailability.empty(),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Analysis Results'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final content = SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlights(),
                  const SizedBox(height: 16),
                  _buildInsightSections(),
                  if (messages != null && messages!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStreamingBox(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
          return Stack(
            children: [
              isWide
                  ? Row(
                      children: [
                        Expanded(child: content),
                        if (decision != null) _buildRecommendationBanner(),
                      ],
                    )
                  : content,
              if (!isWide && decision != null)
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
    if (!availability.anyChip) return const SizedBox.shrink();
    final chips = <Widget>[];
    if (availability.bullishMomentum) {
      chips.add(const Chip(
          avatar: Icon(Icons.trending_up), label: Text('Bullish Momentum')));
    }
    if (availability.inflowUp) {
      chips.add(const Chip(
          avatar: Icon(Icons.attach_money), label: Text('Inflow Up')));
    }
    if (availability.riskAssessment) {
      chips.add(
          const Chip(avatar: Icon(Icons.flag), label: Text('Low Risk')));
    }
    return Wrap(spacing: 8, children: chips);
  }

  Widget _buildInsightSections() {
    if (report == null) return const SizedBox.shrink();
    final panels = <ExpansionPanelRadio>[];
    if (report?['market_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'market',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Market Analysis'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: report!['market_report'] as String),
          ),
        ),
      );
    }
    if (report?['fundamentals_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'fundamentals',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Fundamentals Overview'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: report!['fundamentals_report'] as String),
          ),
        ),
      );
    }
    if (report?['sentiment_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'sentiment',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Sentiment Summary'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: report!['sentiment_report'] as String),
          ),
        ),
      );
    }
    if (availability.macroNews && report?['news_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'news',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Macro & Market News'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: report!['news_report'] as String),
          ),
        ),
      );
    }
    if (availability.analystBreakdown &&
        report?['investment_debate_state'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'analysts',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Analyst Team Breakdown'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
                data: report!['investment_debate_state']['history'] as String),
          ),
        ),
      );
    }
    if (availability.riskAssessment && report?['risk_debate_state'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'risk',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Risk Assessment'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
                data: report!['risk_debate_state']['history'] as String),
          ),
        ),
      );
    }
    if (report?['final_trade_decision'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'final',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Final Trade Decision'),
          ),
          body: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.lightGreen.shade50,
            child: MarkdownBody(
              data:
                  '**FINAL TRANSACTION PROPOSAL**\n\n${report!['final_trade_decision']}',
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
                  data: messages!.join('\n'),
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
            'Suggested Action: ${decision ?? ''}',
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
