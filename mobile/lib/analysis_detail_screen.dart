import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

import 'services/auth_service.dart';
import 'config.dart';
import 'data_availability.dart';

class AnalysisDetailScreen extends StatefulWidget {
  final int recordId;

  const AnalysisDetailScreen({super.key, required this.recordId});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  bool _loading = false;
  String? _error;
  String? _decision;
  String? _report;
  Map<String, dynamic>? _parsedReport;
  DataAvailability _availability = const DataAvailability.empty();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$backendUrl/history/${widget.recordId}'),
        headers: {'Authorization': 'Bearer ${AuthService.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final report = data['report'] as Map<String, dynamic>?;
        setState(() {
          _decision = data['decision']?.toString();
          _report = jsonEncode(report);
          _parsedReport = report;
          _availability = report != null
              ? DataAvailability.fromReport(report)
              : const DataAvailability.empty();
        });
      } else {
        setState(() {
          _error = 'Failed to load details';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _decision == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Decision: $_decision',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildHighlights(),
                            const SizedBox(height: 8),
                            _buildInsightSections(),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildHighlights() {
    if (!_availability.anyChip) {
      return const SizedBox.shrink();
    }
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
      chips.add(const Chip(avatar: Icon(Icons.flag), label: Text('Low Risk')));
    }
    return Wrap(spacing: 8, children: chips);
  }

  Widget _buildInsightSections() {
    if (_parsedReport == null) {
      return const SizedBox.shrink();
    }
    final panels = <ExpansionPanelRadio>[];
    if (_parsedReport?['market_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'market',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Market Analysis'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _parsedReport!['market_report'] as String),
          ),
        ),
      );
    }
    if (_parsedReport?['fundamentals_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'fundamentals',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Fundamentals Overview'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child:
                MarkdownBody(data: _parsedReport!['fundamentals_report'] as String),
          ),
        ),
      );
    }
    if (_parsedReport?['sentiment_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'sentiment',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Sentiment Summary'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child:
                MarkdownBody(data: _parsedReport!['sentiment_report'] as String),
          ),
        ),
      );
    }
    if (_parsedReport?['news_report'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'news',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Macro & Market News'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: _parsedReport!['news_report'] as String),
          ),
        ),
      );
    }
    final analyst = _parsedReport?['investment_debate_state'];
    if (analyst is Map && analyst['history'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'analysts',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Analyst Team Breakdown'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: analyst['history'] as String),
          ),
        ),
      );
    }
    final risk = _parsedReport?['risk_debate_state'];
    if (risk is Map && risk['history'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'risk',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Risk Assessment'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(data: risk['history'] as String),
          ),
        ),
      );
    }
    if (_parsedReport?['final_trade_decision'] != null) {
      panels.add(
        ExpansionPanelRadio(
          value: 'final',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Final Trade Decision'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
              data:
                  '**FINAL TRANSACTION PROPOSAL**\n\n${_parsedReport!['final_trade_decision']}',
            ),
          ),
        ),
      );
    }
    if (panels.isEmpty) return const SizedBox.shrink();
    return ExpansionPanelList.radio(children: panels);
  }
}
