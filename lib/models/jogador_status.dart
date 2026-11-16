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
    required this.zonaAtual, // Adicionado ao construtor
  });
}
