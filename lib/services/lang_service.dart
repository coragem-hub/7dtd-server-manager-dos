import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangService extends ChangeNotifier {
  static final LangService instance = LangService._internal();
  LangService._internal();

  static const String _prefKey = 'app_language';
  static const String _fallbackLang = 'pt-BR';

  static const Map<String, String> idiomasDisponiveis = {
    'pt-BR': 'Português (BR)',
    'en-US': 'English (US)',
    'es-ES': 'Español',
  };

  String get siglaTopo {
    final meta = _dadosAtuais['_meta'];
    if (meta is Map && meta['tray_top'] != null) {
      return meta['tray_top'].toString().toUpperCase();
    }
    return _idiomaAtual.split('-').first.toUpperCase();
  }

  String get siglaBase {
    final meta = _dadosAtuais['_meta'];
    if (meta is Map && meta['tray_bottom'] != null) {
      return meta['tray_bottom'].toString().toUpperCase();
    }
    final partes = _idiomaAtual.split('-');
    return partes.length > 1 ? partes[1].toUpperCase() : 'SYS';
  }

  String _idiomaAtual = _fallbackLang;
  Map<String, dynamic> _dadosAtuais = {};
  Map<String, dynamic> _dadosFallback = {};

  String get idiomaAtual => _idiomaAtual;

  /// Inicializa detectando o idioma salvo ou o idioma do Sistema Operacional
  Future<void> inicializar() async {
    _dadosFallback = await _carregarJsonAsset(_fallbackLang);

    final prefs = await SharedPreferences.getInstance();
    final idiomaSalvo = prefs.getString(_prefKey);

    if (idiomaSalvo != null && idiomasDisponiveis.containsKey(idiomaSalvo)) {
      await mudarIdioma(idiomaSalvo, salvarPreferencia: false);
    } else {
      final idiomaSistema = _detectarIdiomaSistema();
      await mudarIdioma(idiomaSistema, salvarPreferencia: false);
    }
  }

  /// Lê o Locale do SO/Navegador e encontra a melhor correspondência
  String _detectarIdiomaSistema() {
    final localeSistema = PlatformDispatcher.instance.locale;
    final codigoCompleto =
        '${localeSistema.languageCode}-${localeSistema.countryCode}';

    // 1. Tenta correspondência exata (ex: en-US, pt-BR)
    for (final chave in idiomasDisponiveis.keys) {
      if (chave.toLowerCase() == codigoCompleto.toLowerCase()) {
        return chave;
      }
    }

    // 2. Tenta correspondência apenas pelo idioma base (ex: en-GB -> en-US, pt-PT -> pt-BR)
    final codigoBase = localeSistema.languageCode.toLowerCase();
    for (final chave in idiomasDisponiveis.keys) {
      if (chave.toLowerCase().startsWith('$codigoBase-')) {
        return chave;
      }
    }

    // 3. Fallback caso o idioma do SO ainda não tenha tradução
    return 'en-US';
  }

  Future<void> mudarIdioma(
    String codigoIdioma, {
    bool salvarPreferencia = true,
  }) async {
    if (!idiomasDisponiveis.containsKey(codigoIdioma)) {
      codigoIdioma = _fallbackLang;
    }

    if (codigoIdioma == _fallbackLang) {
      _dadosAtuais = _dadosFallback;
    } else {
      _dadosAtuais = await _carregarJsonAsset(codigoIdioma);
    }

    _idiomaAtual = codigoIdioma;

    if (salvarPreferencia) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, codigoIdioma);
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> _carregarJsonAsset(String codigo) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/lang/$codigo.json',
      );
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LangService] Erro ao carregar $codigo.json: $e');
      return {};
    }
  }

  String tr(String caminho, {Map<String, String>? args}) {
    String? texto =
        _buscarNoMapa(_dadosAtuais, caminho) ??
        _buscarNoMapa(_dadosFallback, caminho);

    if (texto == null) {
      return '[$caminho]';
    }

    if (args != null) {
      args.forEach((chave, valor) {
        texto = texto!.replaceAll('{$chave}', valor);
      });
    }

    return texto!;
  }

  String? _buscarNoMapa(Map<String, dynamic> mapa, String caminho) {
    final partes = caminho.split('.');
    dynamic atual = mapa;

    for (final parte in partes) {
      if (atual is Map<String, dynamic> && atual.containsKey(parte)) {
        atual = atual[parte];
      } else {
        return null;
      }
    }

    if (atual is Map<String, dynamic> && atual.containsKey('text')) {
      return atual['text']?.toString();
    }

    return null;
  }
}

String tr(String caminho, {Map<String, String>? args}) {
  return LangService.instance.tr(caminho, args: args);
}
