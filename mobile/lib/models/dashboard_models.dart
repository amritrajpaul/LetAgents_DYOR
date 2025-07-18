class TeamMember {
  final String agent;
  final String role;
  final String status;

  const TeamMember({
    required this.agent,
    required this.role,
    required this.status,
  });
}

class Team {
  final String name;
  final List<TeamMember> members;

  const Team({
    required this.name,
    required this.members,
  });
}

class LogEntry {
  final String time;
  final String type;
  final String content;

  const LogEntry({
    required this.time,
    required this.type,
    required this.content,
  });
}
