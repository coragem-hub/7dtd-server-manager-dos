// lib/services/web_sync_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'player_storage_service.dart';

class WebSyncService {
  static final WebSyncService instance = WebSyncService._();
  WebSyncService._();

  Timer? _timerEnvio;

  // Configurações futuras (poderão ir para o NetConfig depois)
  bool syncAtivo = false;
  String endpointUrl = ""; // Ex: https://firebaseio.com
  String apiKeyOuSecret = ""; // Token de segurança para evitar envios falsos

  void iniciarSincronizacaoPeriodica({
    Duration intervalo = const Duration(minutes: 5),
  }) {
    _timerEnvio?.cancel();
    _timerEnvio = Timer.periodic(intervalo, (_) => enviarDadosAgora());
  }

  void pararSincronizacao() {
    _timerEnvio?.cancel();
    _timerEnvio = null;
  }

  Future<bool> enviarDadosAgora({int jogadoresOnlineAgora = 0}) async {
    if (!syncAtivo || endpointUrl.isEmpty) return false;

    try {
      final jogadores = PlayerStorageService.instance.todosJogadores;

      // Estrutura padronizada para somar múltiplos jogos no site
      final payload = {
        'game_id': '7dtd',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'online_count': jogadoresOnlineAgora,
        'total_registered': jogadores.length,
        'players': jogadores
            .map(
              (j) => {
                'id': j.id,
                'nome': j.nome,
                'level': j.level,
                'deaths': j.deaths,
                'ultimo_login': j.ultimoLogin.toUtc().toIso8601String(),
              },
            )
            .toList(),
      };

      // Se usar Firebase Realtime Database, o segredo vai na URL (?auth=TOKEN)
      final uri = apiKeyOuSecret.isNotEmpty
          ? Uri.parse('$endpointUrl?auth=$apiKeyOuSecret')
          : Uri.parse(endpointUrl);

      // PUT substitui sempre pela versão mais recente sem duplicar registros
      final resposta = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        debugPrint('[WebSync] Dados sincronizados com sucesso!');
        return true;
      } else {
        debugPrint(
          '[WebSync] Falha HTTP ${resposta.statusCode}: ${resposta.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[WebSync] Erro de conexão ao enviar dados: $e');
      return false;
    }
  }

  // Adicione dentro de WebSyncService (lib/services/web_sync_service.dart):
  Future<void> carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    syncAtivo = prefs.getBool('websync_ativo') ?? false;
    endpointUrl = prefs.getString('websync_url') ?? "";
    apiKeyOuSecret = prefs.getString('websync_token') ?? "";

    if (syncAtivo && endpointUrl.isNotEmpty) {
      iniciarSincronizacaoPeriodica();
    }
  }

  Future<void> salvarConfiguracoes({
    required bool ativo,
    required String url,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('websync_ativo', ativo);
    await prefs.setString('websync_url', url.trim());
    await prefs.setString('websync_token', token.trim());

    syncAtivo = ativo;
    endpointUrl = url.trim();
    apiKeyOuSecret = token.trim();

    if (syncAtivo && endpointUrl.isNotEmpty) {
      iniciarSincronizacaoPeriodica();
    } else {
      pararSincronizacao();
    }
  }
}
