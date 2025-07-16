import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import 'history_screen.dart';
import 'services/auth_service.dart';
import 'ticker_utils.dart';

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
              _report = jsonEncode(data['report']);
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
    return Wrap(
      spacing: 8,
      children: const [
        Chip(icon: Icon(Icons.trending_up), label: Text('Bullish Momentum')),
        Chip(icon: Icon(Icons.attach_money), label: Text('Inflow Up')),
        Chip(icon: Icon(Icons.flag), label: Text('Low Risk')),
      ],
    );
  }

  Widget _buildInsightSections() {
    return ExpansionPanelList.radio(
      children: [
        ExpansionPanelRadio(
          value: 'news',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Macro & Market News'),
          ),
          body: Column(
            children: const [
              ListTile(
                title: Text('Headline 1'),
                subtitle: Text('Economic news summary'),
              ),
              ListTile(
                title: Text('Headline 2'),
                subtitle: Text('More news'),
              ),
              ListTile(
                title: Text('Headline 3'),
                subtitle: Text('Third news item'),
              ),
            ],
          ),
        ),
        ExpansionPanelRadio(
          value: 'analysts',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Analyst Team Breakdown'),
          ),
          body: Column(
            children: const [
              ListTile(
                leading: CircleAvatar(child: Text('RA')),
                title: Text('Risky Analyst'),
                subtitle: Text('Sell -30%'),
              ),
              ListTile(
                leading: CircleAvatar(child: Text('BA')),
                title: Text('Bull Analyst'),
                subtitle: Text('Buy +20%'),
              ),
            ],
          ),
        ),
        ExpansionPanelRadio(
          value: 'risk',
          headerBuilder: (context, isExpanded) => const ListTile(
            title: Text('Risk Assessment'),
          ),
          body: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.bar_chart),
                title: Text('Technical Risk'),
                subtitle: Text('Overbought'),
              ),
              ListTile(
                leading: Icon(Icons.language),
                title: Text('Geopolitical Risk'),
                subtitle: Text('Low'),
              ),
              ListTile(
                leading: Icon(Icons.warning),
                title: Text('Earnings Triggers'),
                subtitle: Text('Next week'),
              ),
            ],
          ),
        ),
      ],
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
