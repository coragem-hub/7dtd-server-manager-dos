import 'package:flutter/material.dart';

class LogToken {
  final String linhaPura;
  final String tag; // Ex: [PC], [CHAT], [NT]
  final String mensagemLimpa; // Apenas o texto sem a sujeira do sistema
  final Color corTag;
  final IconData icone;

  LogToken({
    required this.linhaPura,
    required this.tag,
    required this.mensagemLimpa,
    required this.corTag,
    required this.icone,
  });
}
