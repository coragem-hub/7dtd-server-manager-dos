// lib/models/jogador_status.dart

class JogadorStatus {
  final String id;
  final String nome;
  final double x;
  final double y;
  final double z;
  final int health;
  final int deaths;
  final int level;
  final int ping;
  final String platformId;
  final String zonaAtual; // "PVE" ou "PVP"
  final DateTime ultimoLogin; // Novo campo para ordenar inativos

  JogadorStatus({
    required this.id,
    required this.nome,
    required this.x,
    required this.y,
    required this.z,
    required this.health,
    required this.deaths,
    required this.level,
    required this.ping,
    required this.platformId,
    required this.zonaAtual,
    DateTime? ultimoLogin,
  }) : ultimoLogin = ultimoLogin ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'x': x,
    'y': y,
    'z': z,
    'health': health,
    'deaths': deaths,
    'level': level,
    'ping': ping,
    'platformId': platformId,
    'zonaAtual': zonaAtual,
    'ultimoLogin': ultimoLogin.toIso8601String(),
  };

  factory JogadorStatus.fromJson(Map<String, dynamic> json) {
    return JogadorStatus(
      id: json['id'] ?? '',
      nome: json['nome'] ?? 'Desconhecido',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      health: json['health'] ?? 100,
      deaths: json['deaths'] ?? 0,
      level: json['level'] ?? 1,
      ping: json['ping'] ?? 0,
      platformId: json['platformId'] ?? '',
      zonaAtual: json['zonaAtual'] ?? 'PVE',
      ultimoLogin: json['ultimoLogin'] != null
          ? DateTime.tryParse(json['ultimoLogin']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
