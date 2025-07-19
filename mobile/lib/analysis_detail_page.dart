import 'package:flutter/material.dart';

class AnalysisDetailPage extends StatelessWidget {
  final Map<String, dynamic> analysisData;

  const AnalysisDetailPage({super.key, required this.analysisData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Details'),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Analysis Results Here'),
            const SizedBox(height: 8),
            Text(analysisData.toString()),
          ],
        ),
      ),
    );
  }
}
