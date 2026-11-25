// lib/services/player_storage_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/jogador_status.dart';

class PlayerStorageService {
  static final PlayerStorageService instance = PlayerStorageService._();
  PlayerStorageService._();

  final Map<String, JogadorStatus> _cacheJogadores = {};
  Timer? _debounceTimer;

  // Salva na pasta local de dados do executável/app
  File get _arquivoDb => File('sd_dos_players_db.json');

  List<JogadorStatus> get todosJogadores => _cacheJogadores.values.toList();

  Future<void> carregarDoDisco() async {
    try {
      if (await _arquivoDb.exists()) {
        final conteudo = await _arquivoDb.readAsString();
        final Map<String, dynamic> dados = jsonDecode(conteudo);
        final Map<String, dynamic> playersMap = dados['players'] ?? {};

        _cacheJogadores.clear();
        playersMap.forEach((id, jsonPlayer) {
          _cacheJogadores[id] = JogadorStatus.fromJson(jsonPlayer);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar banco de jogadores: $e');
    }
  }

  void registrarOuAtualizar(JogadorStatus jogador) {
    _cacheJogadores[jogador.id] = jogador;
    _agendarGravacao();
  }

  void _agendarGravacao() {
    if (_debounceTimer != null && _debounceTimer!.isActive) return;

    _debounceTimer = Timer(const Duration(seconds: 60), () async {
      try {
        // Estrutura otimizada para futura sincronização Web / API
        final payload = {
          'updated_at': DateTime.now().toIso8601String(),
          'total_registered': _cacheJogadores.length,
          'players': _cacheJogadores.map((k, v) => MapEntry(k, v.toJson())),
        };
        await _arquivoDb.writeAsString(jsonEncode(payload));
      } catch (e) {
        debugPrint('Erro ao salvar banco de jogadores: $e');
      }
    });
  }

  // Adicione dentro de PlayerStorageService (lib/services/player_storage_service.dart):
  Future<void> salvarImediatamente() async {
    _debounceTimer?.cancel();
    try {
      final payload = {
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'total_registered': _cacheJogadores.length,
        'players': _cacheJogadores.map((k, v) => MapEntry(k, v.toJson())),
      };
      await _arquivoDb.writeAsString(jsonEncode(payload));
    } catch (e) {
      debugPrint('Erro ao salvar banco de jogadores: $e');
    }
  }
}
