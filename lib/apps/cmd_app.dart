import 'package:flutter/material.dart';
import 'package:sd_dos_dart/services/lang_service.dart';

class CmdApp extends StatelessWidget {
  final TextEditingController comandoController;
  final VoidCallback onEnviarComando;

  const CmdApp({
    super.key,
    required this.comandoController,
    required this.onEnviarComando,
  });

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final ehCelular = larguraTela < 600;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                tr('cmd.banner'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'CustomFontA',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        // Barra de digitação do CMD adaptada para celular e desktop
        Container(
          padding: const EdgeInsets.all(6),
          color: Colors.black,
          child: Row(
            children: [
              const Text(
                "> ",
                style: TextStyle(
                  color: Color(0xFF39FF14),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: comandoController,
                  onSubmitted: (_) => onEnviarComando(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'CustomFontA',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              if (ehCelular)
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color(0xFF39FF14),
                    size: 18,
                  ),
                  onPressed: onEnviarComando,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
