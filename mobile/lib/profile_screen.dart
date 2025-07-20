import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/auth_service.dart';
import 'config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _openaiController = TextEditingController();
  final _finnhubController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final resp = await http.get(
        Uri.parse('$backendUrl/me'),
        headers: {'Authorization': 'Bearer ${AuthService.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _openaiController.text = data['openai_api_key'] ?? '';
          _finnhubController.text = data['finnhub_api_key'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final resp = await http.put(
        Uri.parse('$backendUrl/keys'),
        headers: {
          'Authorization': 'Bearer ${AuthService.token}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'openai_api_key': _openaiController.text,
          'finnhub_api_key': _finnhubController.text,
        }),
      );
      if (resp.statusCode == 200) {
        setState(() => _success = 'Saved');
      } else {
        setState(() => _error = 'Failed to save');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _openaiController,
              decoration: const InputDecoration(labelText: 'OpenAI API Key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _finnhubController,
              decoration: const InputDecoration(labelText: 'Finnhub API Key'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_success != null)
              Text(_success!, style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
