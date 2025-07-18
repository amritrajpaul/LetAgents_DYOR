import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/dashboard_models.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final List<Team> _teams = const [
    Team(name: 'Analyst', members: [
      TeamMember(agent: 'Alice', role: 'Lead', status: 'Completed'),
      TeamMember(agent: 'Bob', role: 'Analyst', status: 'In Progress'),
    ]),
    Team(name: 'Research', members: [
      TeamMember(agent: 'Eve', role: 'Lead', status: 'Pending'),
    ]),
    Team(name: 'Trading', members: [
      TeamMember(agent: 'Charlie', role: 'Trader', status: 'Completed'),
    ]),
    Team(name: 'Risk Management', members: [
      TeamMember(agent: 'Dave', role: 'Manager', status: 'In Progress'),
    ]),
    Team(name: 'Portfolio', members: [
      TeamMember(agent: 'Mallory', role: 'Advisor', status: 'Pending'),
    ]),
  ];

  final List<LogEntry> _logs = const [
    LogEntry(time: '09:00', type: 'Tool', content: 'Fetched market data'),
    LogEntry(time: '09:05', type: 'Reasoning', content: 'Analyzed momentum signals'),
    LogEntry(time: '09:10', type: 'Tool', content: 'Calculated RSI'),
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF5DFF8D);
      case 'In Progress':
        return const Color(0xFFF6C945);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.black, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final progress = _buildProgress();
    final messages = _buildMessages();
    final report = _buildReport();
    final decision = _buildDecision();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome to TradingAgents',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        backgroundColor:
            Theme.of(context).colorScheme.surface.withOpacity(0.3),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      children: [progress, const SizedBox(height: 16), report, const SizedBox(height:16), decision],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: messages),
                ],
              );
            } else {
              return ListView(
                children: [
                  progress,
                  const SizedBox(height: 16),
                  messages,
                  const SizedBox(height: 16),
                  report,
                  const SizedBox(height: 16),
                  decision,
                ],
              );
            }
          },
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress',
              style: GoogleFonts.sora(
                color: const Color(0xFF00FFC6),
                fontSize: 18,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 12),
            ..._teams.map(
              (team) => ExpansionTile(
                title: Text(team.name),
                children: team.members
                    .map(
                      (m) => ListTile(
                        title: Text(m.agent),
                        subtitle: Text(m.role),
                        trailing: _buildStatusChip(m.status),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages & Logs',
              style: GoogleFonts.sora(
                color: const Color(0xFF00FFC6),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ..._logs.map((log) {
              final typeColor = log.type == 'Tool'
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFA78BFA);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(log.time,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(log.type,
                          style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.content,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    return Card(
      child: ExpansionTile(
        title: const Text('Current Report: News Analysis'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _reportSection('🧠 Macro Environment', [
            'Interest rates remain steady',
            'Inflation expectations cooling'
          ]),
          const SizedBox(height: 8),
          _reportSection('🌍 Global Stock Performance', [
            'Asian markets mixed',
            'US futures trending up'
          ]),
          const SizedBox(height: 8),
          _reportSection('⚠️ Trade & Geopolitics', [
            'New tariffs announced',
            'Ongoing supply chain issues'
          ]),
          const SizedBox(height: 8),
          _reportSection('📈 Sector-Specific View', [
            'Tech showing resilience',
            'Energy pulling back'
          ]),
          const SizedBox(height: 8),
          _reportSection('🧩 Summary', [
            'Overall outlook cautious',
          ]),
        ],
      ),
    );
  }

  Widget _reportSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF00FFC6),
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((i) => Row(
              children: [
                const Text('• '),
                Expanded(child: Text(i)),
              ],
            )),
      ],
    );
  }

  Widget _buildDecision() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF00FFC6), width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Management Decision',
              style: GoogleFonts.sora(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                Text('Risky Analyst: ',
                    style: TextStyle(color: Color(0xFFA3E635))),
                Text('Buy more tech')
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                Text('Safe Analyst: ',
                    style: TextStyle(color: Color(0xFFF87171))),
                Text('Hold cash')
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                Text('Neutral Analyst: ',
                    style: TextStyle(color: Color(0xFFFBBF24))),
                Text('Wait and see')
              ],
            ),
            const SizedBox(height: 8),
            const Text('Rationale: momentum fading.'),
            const Text('Deployment: scale in slowly.'),
            const Text('Entry Triggers: break above resistance.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF1c1f26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Tool Calls: 14 | LLM Calls: 45 | Generated Reports: 7 ',
            style: TextStyle(letterSpacing: 1.2, color: Color(0xFF94A3B8), fontSize: 12),
          ),
          SizedBox(width: 4),
          Text('🟢'),
        ],
      ),
    );
  }
}
