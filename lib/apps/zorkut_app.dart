import 'package:flutter/material.dart';
import 'package:sd_dos_dart/services/lang_service.dart';

import '../models/log_token.dart';
import '../models/jogador_status.dart';

class ZorkutApp extends StatefulWidget {
  final List<LogToken> todosOsLogs;
  final List<JogadorStatus> jogadoresZorkut;
  final Function(String) onEnviarMensagem;
  final Function(JogadorStatus)? onPlayerClicado;

  const ZorkutApp({
    super.key,
    required this.todosOsLogs,
    required this.jogadoresZorkut,
    required this.onEnviarMensagem,
    this.onPlayerClicado,
  });

  @override
  State<ZorkutApp> createState() => _ZorkutAppState();
}

class _ZorkutAppState extends State<ZorkutApp> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  bool _autoScroll = true;
  bool _rolandoAutomaticamente = false;
  int _novasMensagensNaoLidas = 0;
  int _totalMensagensAnterior = 0;
  bool _modoVanilla = false;

  static const Color _corFundo = Color(0xFF12081F);
  static const Color _corDestaque = Color(0xFFD580FF);
  static const Color _corInputFundo = Color(0xFF1E0E33);
  static const Color _corLateral = Color(0xFF180B2B);

  @override
  void initState() {
    super.initState();
    _totalMensagensAnterior = _mensagensFiltradas.length;
    _scrollController.addListener(_verificarPosicaoRolagem);
  }

  List<LogToken> get _mensagensFiltradas {
    final tagsDeChat = ['[MSG]', '[CHAT]', '[PM]'];
    return widget.todosOsLogs
        .where((log) => tagsDeChat.contains(log.tag.toUpperCase().trim()))
        .toList();
  }

  void _verificarPosicaoRolagem() {
    if (_rolandoAutomaticamente || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final atual = _scrollController.position.pixels;
    final estaNoFundo = (maxScroll - atual) <= 15.0;

    if (estaNoFundo && !_autoScroll) {
      setState(() {
        _autoScroll = true;
        _novasMensagensNaoLidas = 0;
      });
    } else if (!estaNoFundo && _autoScroll) {
      setState(() {
        _autoScroll = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ZorkutApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final totalAtual = _mensagensFiltradas.length;

    if (totalAtual > _totalMensagensAnterior) {
      final diferenca = totalAtual - _totalMensagensAnterior;
      _totalMensagensAnterior = totalAtual;

      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _rolandoAutomaticamente = true;
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
            _rolandoAutomaticamente = false;
          }
        });
      } else if (!_autoScroll) {
        setState(() {
          _novasMensagensNaoLidas += diferenca;
        });
      }
    } else {
      _totalMensagensAnterior = totalAtual;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_verificarPosicaoRolagem);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _irParaOFinal() {
    setState(() {
      _autoScroll = true;
      _novasMensagensNaoLidas = 0;
    });

    if (_scrollController.hasClients) {
      _rolandoAutomaticamente = true;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _rolandoAutomaticamente = false;
    }
  }

  void _dispararMensagem() {
    final texto = _inputController.text.trim();
    if (texto.isEmpty) return;

    if (_modoVanilla) {
      widget.onEnviarMensagem('say "$texto"');
    } else {
      widget.onEnviarMensagem(texto);
    }

    _inputController.clear();
    _irParaOFinal();
  }

  @override
  Widget build(BuildContext context) {
    final mensagens = _mensagensFiltradas;

    return Container(
      color: _corFundo,
      child: Row(
        children: [
          // COLUNA ESQUERDA: Chat Global
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Lista de Mensagens
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: mensagens.length,
                          itemBuilder: (context, index) {
                            final msg = mensagens[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2,
                                      right: 6,
                                    ),
                                    child: Icon(
                                      msg.icone,
                                      color: _corDestaque,
                                      size: 13,
                                    ),
                                  ),
                                  Expanded(
                                    child: SelectableText.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontFamily: 'CustomFontA',
                                          fontSize: 12,
                                        ),
                                        children: [
                                          if (msg.tag.isNotEmpty)
                                            TextSpan(
                                              text: "${msg.tag} ",
                                              style: const TextStyle(
                                                color: _corDestaque,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          TextSpan(
                                            text: msg.mensagemLimpa,
                                            style: const TextStyle(
                                              color: Color(0xFFF3E5F5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // CONTADOR FLUTUANTE DE NOVAS MENSAGENS
                      if (!_autoScroll && _novasMensagensNaoLidas > 0)
                        Positioned(
                          bottom: 8,
                          right: 12,
                          child: GestureDetector(
                            onTap: _irParaOFinal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _corInputFundo,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _corDestaque,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_downward,
                                    color: _corDestaque,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _novasMensagensNaoLidas == 1
                                        ? tr('zorkut.new_msg_single')
                                        : tr(
                                            'zorkut.new_msg_plural',
                                            args: {
                                              'count':
                                                  '$_novasMensagensNaoLidas',
                                            },
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'CustomFontA',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Barra de Digitação Inferior com Seletor Prisma / Vanilla
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _corInputFundo,
                    border: Border(
                      top: BorderSide(
                        color: _corDestaque.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // BOTÃO ALTERNADOR: PRISMA CORE vs VANILLA (SAY)
                      Tooltip(
                        message: _modoVanilla
                            ? tr('zorkut.tooltip_mode_vanilla')
                            : tr('zorkut.tooltip_mode_prisma'),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _modoVanilla = !_modoVanilla;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _modoVanilla
                                  ? const Color(0xFF39FF14)
                                        .withValues(alpha: 0.15)
                                  : _corDestaque.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _modoVanilla
                                    ? const Color(0xFF39FF14)
                                    : _corDestaque,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _modoVanilla ? 'VANILLA' : 'PRISMA',
                              style: TextStyle(
                                color: _modoVanilla
                                    ? const Color(0xFF39FF14)
                                    : _corDestaque,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'CustomFontA',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Campo texto
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: (_) => _dispararMensagem(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'CustomFontA',
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: _modoVanilla
                                ? tr('zorkut.hint_vanilla')
                                : tr('zorkut.hint_prisma'),
                            hintStyle: TextStyle(
                              color: _corDestaque.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: _corFundo,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: _corDestaque.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: _corDestaque.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: _modoVanilla
                                    ? const Color(0xFF39FF14)
                                    : _corDestaque,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botão Enviar
                      IconButton(
                        onPressed: _dispararMensagem,
                        icon: Icon(
                          Icons.send,
                          color: _modoVanilla
                              ? const Color(0xFF39FF14)
                              : _corDestaque,
                          size: 18,
                        ),
                        tooltip: tr('zorkut.tooltip_send'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // COLUNA DIREITA: Lista Lateral Inteligente de Players Online
          Container(
            width: 155,
            decoration: BoxDecoration(
              color: _corLateral,
              border: Border(
                left: BorderSide(color: _corDestaque.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: _corInputFundo,
                  child: Text(
                    tr(
                      'zorkut.online_header',
                      args: {'count': '${widget.jogadoresZorkut.length}'},
                    ),
                    style: const TextStyle(
                      color: _corDestaque,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.jogadoresZorkut.length,
                    itemBuilder: (context, index) {
                      final player = widget.jogadoresZorkut[index];
                      return InkWell(
                        onTap: () {
                          if (widget.onPlayerClicado != null) {
                            widget.onPlayerClicado!(player);
                          }
                        },
                        hoverColor: _corDestaque.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF39FF14),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      player.nome,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'CustomFontA',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 1,
                                ),
                                child: Text(
                                  tr(
                                    'zorkut.player_stats',
                                    args: {
                                      'level': '${player.level}',
                                      'ping': '${player.ping}',
                                    },
                                  ),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 9,
                                    fontFamily: 'CustomFontA',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
