import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'login_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'about_screen.dart';
import 'services/auth_service.dart';
import 'ticker_utils.dart';
import 'data_availability.dart';
import 'config.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _tickerController = TextEditingController();
  final _dateController = TextEditingController();

  // Advanced settings
  double _researchDepth = 1;
  final Map<String, String> _providerUrls = const {
    'OpenAI': 'https://api.openai.com/v1',
    'Anthropic': 'https://api.anthropic.com/',
    'Google': 'https://generativelanguage.googleapis.com/v1',
    'Openrouter': 'https://openrouter.ai/api/v1',
    'Ollama': 'http://localhost:11434/v1',
  };
  final Map<String, List<String>> _quickModels = const {
    'OpenAI': ['gpt-4o-mini', 'gpt-4.1-nano', 'gpt-4.1-mini', 'gpt-4o'],
    'Anthropic': [
      'claude-3-5-haiku-latest',
      'claude-3-5-sonnet-latest',
      'claude-3-7-sonnet-latest',
      'claude-sonnet-4-0'
    ],
    'Google': [
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
      'gemini-2.5-flash-preview-05-20'
    ],
    'Openrouter': [
      'meta-llama/llama-4-scout:free',
      'meta-llama/llama-3.3-8b-instruct:free',
      'google/gemini-2.0-flash-exp:free'
    ],
    'Ollama': ['llama3.1', 'llama3.2'],
  };
  final Map<String, List<String>> _deepModels = const {
    'OpenAI': [
      'gpt-4.1-nano',
      'gpt-4.1-mini',
      'gpt-4o',
      'o4-mini',
      'o3-mini',
      'o3',
      'o1'
    ],
    'Anthropic': [
      'claude-3-5-haiku-latest',
      'claude-3-5-sonnet-latest',
      'claude-3-7-sonnet-latest',
      'claude-sonnet-4-0',
      'claude-opus-4-0'
    ],
    'Google': [
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
      'gemini-2.5-flash-preview-05-20',
      'gemini-2.5-pro-preview-06-05'
    ],
    'Openrouter': [
      'deepseek/deepseek-chat-v3-0324:free',
      'deepseek/deepseek-chat-v3-0324:free'
    ],
    'Ollama': ['llama3.1', 'qwen3'],
  };
  String _selectedProvider = 'OpenAI';
  late String _backendUrl;
  late String _quickModel;
  late String _deepModel;
  final Map<String, bool> _analysts = {
    'market': true,
    'social': true,
    'news': true,
    'fundamentals': true,
  };

  final Map<String, String> _agentStatus = {
    'Market Analyst': 'pending',
    'Social Analyst': 'pending',
    'News Analyst': 'pending',
    'Fundamentals Analyst': 'pending',
    'Bull Researcher': 'pending',
    'Bear Researcher': 'pending',
    'Research Manager': 'pending',
    'Trader': 'pending',
    'Risky Analyst': 'pending',
    'Neutral Analyst': 'pending',
    'Safe Analyst': 'pending',
    'Portfolio Manager': 'pending',
  };

  final Map<String, String> _reportStatus = {
    'Market Analysis': 'pending',
    'Sentiment Report': 'pending',
    'News Report': 'pending',
    'Fundamentals Report': 'pending',
    'Investment Plan': 'pending',
    'Trader Plan': 'pending',
    'Risk Assessment': 'pending',
    'Final Decision': 'pending',
  };

  static const Map<String, String> _agentToReport = {
    'Market Analyst': 'Market Analysis',
    'Social Analyst': 'Sentiment Report',
    'News Analyst': 'News Report',
    'Fundamentals Analyst': 'Fundamentals Report',
    'Bull Researcher': 'Investment Plan',
    'Bear Researcher': 'Investment Plan',
    'Research Manager': 'Investment Plan',
    'Trader': 'Trader Plan',
    'Risky Analyst': 'Risk Assessment',
    'Neutral Analyst': 'Risk Assessment',
    'Safe Analyst': 'Risk Assessment',
    'Portfolio Manager': 'Final Decision',
  };

  void _updateReportFromAgent(String agent, String status) {
    final report = _agentToReport[agent];
    if (report != null && _reportStatus.containsKey(report)) {
      if (status == 'in_progress' && _reportStatus[report] == 'pending') {
        _reportStatus[report] = 'in_progress';
      } else if (status == 'completed') {
        _reportStatus[report] = 'completed';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _backendUrl = _providerUrls[_selectedProvider]!;
    _quickModel = _quickModels[_selectedProvider]!.first;
    _deepModel = _deepModels[_selectedProvider]!.first;
    _checkKeys();
  }

  bool _loading = false;
  double _progress = 0;
  String? _error;
  String? _decision;
  String? _report;
  Map<String, dynamic>? _parsedReport;
  DataAvailability _availability = const DataAvailability.empty();
  Future<void>? _analysisFuture;
  final List<String> _messages = [];
  int _toolCalls = 0;
  int _llmCalls = 0;
  int _reportsGenerated = 0;
  http.Client? _activeClient;
  bool _stopRequested = false;
  bool _keysSet = false;
  List<String> _activeAnalysts = const [];

  Future<void> _checkKeys() async {
    try {
      final resp = await http.get(
        Uri.parse('$backendUrl/me'),
        headers: {'Authorization': 'Bearer ${AuthService.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _keysSet = (data['openai_api_key'] ?? '').toString().isNotEmpty &&
            (data['finnhub_api_key'] ?? '').toString().isNotEmpty;
        if (!_keysSet && mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('API keys required'),
              content: const Text('Please set your API keys before analyzing.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: const Text('Set Keys'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

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

  void _stopAnalysis() {
    setState(() {
      _stopRequested = true;
      _loading = false;
    });
    _activeClient?.close();
  }

  Future<void> _runAnalysis() async {
    final ticker = _tickerController.text.trim().toUpperCase();
    final date = _dateController.text.trim();
    _activeAnalysts =
        _analysts.entries.where((e) => e.value).map((e) => e.key).toList();

    if (!_keysSet) {
      await _checkKeys();
      if (!_keysSet) return;
    }

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
      _toolCalls = 0;
      _llmCalls = 0;
      _reportsGenerated = 0;
      _error = null;
      _decision = null;
      _report = null;
      _parsedReport = null;
      _availability = const DataAvailability.empty();
      _stopRequested = false;
      _agentStatus.updateAll((key, value) => 'pending');
      _reportStatus.updateAll((key, value) => 'pending');
    });

    final client = http.Client();
    _activeClient = client;
    try {
      await WakelockPlus.enable();
      final request = http.Request('POST', Uri.parse('$backendUrl/analyze/stream'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        })
        ..body = jsonEncode({
          'ticker': ticker,
          'date': date,
          'research_depth': _researchDepth.round(),
          'analysts': _activeAnalysts,
          'llm_provider': _selectedProvider.toLowerCase(),
          'backend_url': _backendUrl,
          'quick_model': _quickModel,
          'deep_model': _deepModel,
        });

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
        if (_stopRequested) {
          break;
        }
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
              _toolCalls = data['tool_calls'] ?? _toolCalls;
              _llmCalls = data['llm_calls'] ?? _llmCalls;
              _reportsGenerated = data['reports'] ?? _reportsGenerated;
            } else if (event == 'status') {
              final agent = data['agent']?.toString();
              final status = data['status']?.toString();
              if (agent != null && status != null && _agentStatus.containsKey(agent)) {
                _agentStatus[agent] = status;
                _updateReportFromAgent(agent, status);
              }
            } else if (event == 'complete') {
              _progress = 1.0;
              _decision = data['decision']?.toString();
              _parsedReport = data['report'] as Map<String, dynamic>?;
              _report = jsonEncode(data['report']);
              _availability = data.containsKey('availability')
                  ? DataAvailability.fromJson(
                      data['availability'] as Map<String, dynamic>)
                  : const DataAvailability.empty();
              if (data.containsKey('metrics')) {
                final m = data['metrics'] as Map<String, dynamic>;
                _toolCalls = m['tool_calls'] ?? _toolCalls;
                _llmCalls = m['llm_calls'] ?? _llmCalls;
                _reportsGenerated = m['reports'] ?? _reportsGenerated;
              }
              _agentStatus.updateAll((key, value) => 'completed');
              _reportStatus.updateAll((key, value) => 'completed');
              _loading = false;
            } else if (event == 'error') {
              _error = data['detail']?.toString();
              _loading = false;
            }
          });
        }
      }
      if (_stopRequested) {
        return;
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      WakelockPlus.disable();
      client.close();
      _activeClient = null;
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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.cyan),
              child: Text('Menu'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
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
            ExpansionTile(
              title: const Text('Advanced Settings'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Row(
                  children: [
                    Text('Debate Rounds: ${_researchDepth.round()}'),
                    Expanded(
                      child: Slider(
                        value: _researchDepth,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _researchDepth.round().toString(),
                        onChanged: (v) => setState(() => _researchDepth = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _selectedProvider,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedProvider = value;
                      _backendUrl = _providerUrls[value]!;
                      _quickModel = _quickModels[value]!.first;
                      _deepModel = _deepModels[value]!.first;
                    });
                  },
                  items: _providerUrls.keys
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _quickModel,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _quickModel = value);
                    }
                  },
                  items: _quickModels[_selectedProvider]!
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _deepModel,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _deepModel = value);
                    }
                  },
                  items: _deepModels[_selectedProvider]!
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _analysts.keys.map((a) {
                    return FilterChip(
                      label: Text(a[0].toUpperCase() + a.substring(1)),
                      selected: _analysts[a]!,
                      onSelected: (v) => setState(() => _analysts[a] = v),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            if (_loading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _stopAnalysis,
                  child: const Text('Stop'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _analyze,
                  child: const Text('Analyze'),
                ),
              ),
            if (_messages.isNotEmpty || _loading) ...[
              const SizedBox(height: 16),
              _buildAgentStatusBox(),
              if (_messages.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildStreamingBox(),
              ],
            ],
          ],
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
    if (_parsedReport?['market_report'] != null &&
        _activeAnalysts.contains('market')) {
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
    if (_parsedReport?['fundamentals_report'] != null &&
        _activeAnalysts.contains('fundamentals')) {
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
    if (_parsedReport?['sentiment_report'] != null &&
        _activeAnalysts.contains('social')) {
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
    if (_availability.macroNews &&
        _parsedReport?['news_report'] != null &&
        _activeAnalysts.contains('news')) {
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
            child: MarkdownBody(
                data: _parsedReport!['investment_debate_state']['history'] as String),
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
            child: MarkdownBody(
                data: _parsedReport!['risk_debate_state']['history'] as String),
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

  Widget _buildAgentStatusBox() {
    Icon _iconForStatus(String status) {
      switch (status) {
        case 'completed':
          return const Icon(Icons.check_circle, color: Colors.green);
        case 'in_progress':
          return const Icon(Icons.autorenew, color: Colors.orange);
        default:
          return const Icon(Icons.hourglass_empty, color: Colors.grey);
      }
    }

    final agentTiles = _agentStatus.entries.map((e) {
      return ListTile(
        dense: true,
        leading: _iconForStatus(e.value),
        title: Text(e.key),
        trailing: Text(e.value),
      );
    }).toList();

    final reportTiles = _reportStatus.entries.map((e) {
      return ListTile(
        dense: true,
        leading: _iconForStatus(e.value),
        title: Text(e.key),
        trailing: Text(e.value),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.tune),
        title: const Text('Process Status'),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Agents', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...agentTiles,
          const Padding(
            padding: EdgeInsets.all(8),
            child:
                Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...reportTiles,
        ],
      ),
    );
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
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
          const SizedBox(height: 8),
          Text(
            "Tool Calls: $_toolCalls  |  LLM Calls: $_llmCalls  |  Reports: $_reportsGenerated",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationBanner() {
    final trigger = _parsedReport?['trigger']?.toString();
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
          if (trigger != null) ...[
            const Divider(color: Colors.white54),
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Trigger: $trigger',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
