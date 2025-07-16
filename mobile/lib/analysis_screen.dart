import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import 'history_screen.dart';
import 'services/auth_service.dart';
import 'ticker_utils.dart';
import 'data_availability.dart';

const String backendUrl = 'http://localhost:8000';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _tickerController = TextEditingController();
  final _dateController = TextEditingController();

  bool _loading = false;
  double _progress = 0;
  String? _error;
  String? _decision;
  String? _report;
  Map<String, dynamic>? _parsedReport;
  DataAvailability _availability = const DataAvailability.empty();
  Future<void>? _analysisFuture;
  final List<String> _messages = [];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      _dateController.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _analyze() async {
    _analysisFuture = _runAnalysis();
    await _analysisFuture;
  }

  Future<void> _runAnalysis() async {
    final ticker = _tickerController.text.trim().toUpperCase();
    final date = _dateController.text.trim();

    if (ticker.isEmpty || date.isEmpty) {
      setState(() {
        _error = 'Ticker and date are required';
      });
      return;
    }

    if (!isValidTicker(ticker)) {
      setState(() {
        _error = 'Invalid ticker format';
      });
      return;
    }

    _tickerController.text = ticker;

    setState(() {
      _loading = true;
      _progress = 0;
      _messages.clear();
      _error = null;
      _decision = null;
      _report = null;
      _parsedReport = null;
      _availability = const DataAvailability.empty();
    });

    try {
      final client = http.Client();
      final request = http.Request('POST', Uri.parse('$backendUrl/analyze/stream'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        })
        ..body = jsonEncode({'ticker': ticker, 'date': date});

      final response = await client.send(request);
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Analysis failed: ${response.statusCode}';
          _loading = false;
        });
        return;
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? currentEvent;
      await for (final line in lines) {
        if (line.isEmpty) {
          currentEvent = null;
          continue;
        }

        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
          if (!mounted) return;

          final event = currentEvent ?? 'message';

          setState(() {
            if (event == 'update') {
              _progress = (_progress + 0.05).clamp(0.0, 0.9);
              _messages.add(data['message']?.toString() ?? '');
            } else if (event == 'complete') {
              _progress = 1.0;
              _decision = data['decision']?.toString();
              _parsedReport = data['report'] as Map<String, dynamic>?;
              _report = jsonEncode(data['report']);
              _availability = data.containsKey('availability')
                  ? DataAvailability.fromJson(
                      data['availability'] as Map<String, dynamic>)
                  : const DataAvailability.empty();
              _loading = false;
            } else if (event == 'error') {
              _error = data['detail']?.toString();
              _loading = false;
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trading Agents'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'History',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
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
                  _buildInputPanel(),
                  const SizedBox(height: 16),
                  _buildHighlights(),
                  const SizedBox(height: 16),
                  _buildInsightSections(),
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

  Widget _buildInputPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tickerController,
              decoration: const InputDecoration(labelText: 'Ticker (e.g., NVDA)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
              readOnly: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            _loading
                ? LinearProgressIndicator(value: _progress)
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _analyze,
                      child: const Text('Analyze'),
                    ),
                  ),
            if (_messages.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._messages.map((m) => Text(m)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlights() {
    return FutureBuilder<void>(
      future: _analysisFuture,
      builder: (context, snapshot) {
        if (!_availability.anyChip || snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final chips = <Widget>[];
        if (_availability.bullishMomentum) {
          chips.add(const Chip(
              avatar: Icon(Icons.trending_up), label: Text('Bullish Momentum')));
        }
        if (_availability.inflowUp) {
          chips.add(const Chip(
              avatar: Icon(Icons.attach_money), label: Text('Inflow Up')));
        }
        if (_availability.riskAssessment) {
          chips.add(const Chip(
              avatar: Icon(Icons.flag), label: Text('Low Risk')));
        }
        return Wrap(spacing: 8, children: chips);
      },
    );
  }

  Widget _buildInsightSections() {
    return FutureBuilder<void>(
      future: _analysisFuture,
      builder: (context, snapshot) {
        if (!_availability.anyPanel || snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final panels = <ExpansionPanelRadio>[];
        if (_availability.macroNews && _parsedReport?['news_report'] != null) {
          panels.add(
            ExpansionPanelRadio(
              value: 'news',
              headerBuilder: (context, isExpanded) => const ListTile(
                title: Text('Macro & Market News'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(_parsedReport!['news_report'] as String),
              ),
            ),
          );
        }
        if (_availability.analystBreakdown &&
            _parsedReport?['investment_debate_state'] != null) {
          panels.add(
            ExpansionPanelRadio(
              value: 'analysts',
              headerBuilder: (context, isExpanded) => const ListTile(
                title: Text('Analyst Team Breakdown'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                    _parsedReport!['investment_debate_state']['history'] as String),
              ),
            ),
          );
        }
        if (_availability.riskAssessment &&
            _parsedReport?['risk_debate_state'] != null) {
          panels.add(
            ExpansionPanelRadio(
              value: 'risk',
              headerBuilder: (context, isExpanded) => const ListTile(
                title: Text('Risk Assessment'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                    _parsedReport!['risk_debate_state']['history'] as String),
              ),
            ),
          );
        }
        if (panels.isEmpty) return const SizedBox.shrink();
        return ExpansionPanelList.radio(children: panels);
      },
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
