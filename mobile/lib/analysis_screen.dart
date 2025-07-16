import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import 'history_screen.dart';
import 'services/auth_service.dart';

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
    final ticker = _tickerController.text.trim();
    final date = _dateController.text.trim();

    if (ticker.isEmpty || date.isEmpty) {
      setState(() {
        _error = 'Ticker and date are required';
      });
      return;
    }

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
      await for (final line in lines) {
        if (line.startsWith('data:')) {
          final data = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
          final event = data['event'] as String?;
          if (event == 'update') {
            setState(() {
              _progress = (_progress + 0.05).clamp(0.0, 0.9);
              _messages.add(data['message']?.toString() ?? '');
            });
          } else if (event == 'complete') {
            setState(() {
              _progress = 1.0;
              _decision = data['decision']?.toString();
              _report = jsonEncode(data['report']);
              _loading = false;
            });
          } else if (event == 'error') {
            setState(() {
              _error = data['detail']?.toString();
              _loading = false;
            });
          }
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
        title: const Text('Analysis'),
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
      body: Padding(
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
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
            const SizedBox(height: 16),
            if (_messages.isNotEmpty)
              Expanded(
                child: ListView(
                  children:
                      _messages.map((m) => Text(m)).toList(growable: false),
                ),
              ),
            if (_decision != null) ...[
              Text(
                'Decision: $_decision',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_report ?? ''),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
