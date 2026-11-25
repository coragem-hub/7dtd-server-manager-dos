// lib/apps/zorkut_app.dart
import 'package:flutter/material.dart';
import 'package:sd_dos_dart/services/lang_service.dart';

import '../models/log_token.dart';
import '../models/jogador_status.dart';

class ZorkutApp extends StatefulWidget {
  final List<LogToken> todosOsLogs;
  final List<JogadorStatus> jogadoresZorkut;
  final List<JogadorStatus> historicoJogadores;
  final String nomeBot;
  final Function(String) onAlterarNomeBot;
  final Function(String) onEnviarMensagem;
  final Function(JogadorStatus)? onPlayerClicado;

  const ZorkutApp({
    super.key,
    required this.todosOsLogs,
    required this.jogadoresZorkut,
    required this.historicoJogadores,
    required this.nomeBot,
    required this.onAlterarNomeBot,
    required this.onEnviarMensagem,
    this.onPlayerClicado,
  });

  @override
  State<ZorkutApp> createState() => _ZorkutAppState();
}

class _ZorkutAppState extends State<ZorkutApp> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _botNameController = TextEditingController();

  bool _autoScroll = true;
  bool _rolandoAutomaticamente = false;
  int _novasMensagensNaoLidas = 0;
  int _totalMensagensAnterior = 0;
  bool _modoVanilla = false;

  // Estados novos da v1.2.1
  bool _exibirInativos = false;
  bool _perfilAberto = false;
  bool _ehPerfilBot = false;
  bool _editandoNomeBot = false;
  JogadorStatus? _jogadorSelecionado;

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

  // Filtra jogadores do histórico que não estão na lista online e ordena pelo último login
  List<JogadorStatus> get _jogadoresInativosOrdenados {
    final idsOnline = widget.jogadoresZorkut.map((j) => j.id).toSet();
    final inativos = widget.historicoJogadores
        .where((j) => !idsOnline.contains(j.id))
        .toList();
    inativos.sort((a, b) => b.ultimoLogin.compareTo(a.ultimoLogin));
    return inativos;
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
      setState(() => _autoScroll = false);
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
        setState(() => _novasMensagensNaoLidas += diferenca);
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
    _botNameController.dispose();
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

  void _abrirPerfilBot() {
    setState(() {
      _perfilAberto = true;
      _ehPerfilBot = true;
      _editandoNomeBot = false;
      _jogadorSelecionado = null;
      _botNameController.text = widget.nomeBot;
    });
  }

  void _abrirPerfilJogador(JogadorStatus player) {
    setState(() {
      _perfilAberto = true;
      _ehPerfilBot = false;
      _editandoNomeBot = false;
      _jogadorSelecionado = player;
    });
    if (widget.onPlayerClicado != null) {
      widget.onPlayerClicado!(player);
    }
  }

  String _formatarDataCurta(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$d/$m $h:$min";
  }

  @override
  Widget build(BuildContext context) {
    final mensagens = _mensagensFiltradas;
    final inativos = _exibirInativos
        ? _jogadoresInativosOrdenados
        : <JogadorStatus>[];

    return Container(
      color: _corFundo,
      child: Row(
        children: [
          // COLUNA ESQUERDA: Chat Global + Janela de Perfil Sobreposta
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final alturaPerfil = constraints.maxHeight * (2 / 3);

                      return Stack(
                        children: [
                          // 1. Lista de Mensagens (Fundo)
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                          // 2. Contador Flutuante de Novas Mensagens
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
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
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
                          // 3. Janela Superior de Perfil (2/3 da altura)
                          if (_perfilAberto)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: alturaPerfil,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A0C2E)
                                      .withValues(alpha: 0.97),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _corDestaque.withValues(
                                        alpha: 0.6,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Barra Superior da Janela de Perfil (Mesma altura da barra ONLINE)
                                    Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      color: _corInputFundo,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                _ehPerfilBot
                                                    ? Icons.smart_toy
                                                    : Icons.person,
                                                color: _corDestaque,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _ehPerfilBot
                                                    ? tr(
                                                        'zorkut.profile_bot_title',
                                                      )
                                                    : tr(
                                                        'zorkut.profile_player_title',
                                                      ),
                                                style: const TextStyle(
                                                  color: _corDestaque,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Botão Recolher
                                          InkWell(
                                            onTap: () => setState(
                                              () => _perfilAberto = false,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: _corDestaque
                                                      .withValues(alpha: 0.4),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.keyboard_arrow_up,
                                                    color: _corDestaque,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    tr('zorkut.btn_collapse'),
                                                    style: TextStyle(
                                                      color: _corDestaque,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Conteúdo da Janela de Perfil
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: _ehPerfilBot
                                            ? _construirConteudoPerfilBot()
                                            : _construirConteudoPerfilJogador(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                // Barra de Digitação Inferior
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
                      Tooltip(
                        message: _modoVanilla
                            ? tr('zorkut.tooltip_mode_vanilla')
                            : tr('zorkut.tooltip_mode_prisma'),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _modoVanilla = !_modoVanilla),
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
          // COLUNA DIREITA: Lista Lateral (BotAdm + Online + Inativos)
          Container(
            width: 165,
            decoration: BoxDecoration(
              color: _corLateral,
              border: Border(
                left: BorderSide(color: _corDestaque.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho ONLINE + Botão OFF
                Container(
                  height: 28,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: _corInputFundo,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
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
                      // Botão Toggle OFF (Exibir/Ocultar Inativos)
                      InkWell(
                        onTap: () =>
                            setState(() => _exibirInativos = !_exibirInativos),
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _exibirInativos
                                ? Colors.amberAccent.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: _exibirInativos
                                  ? Colors.amberAccent
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tr(
                              'zorkut.off_header',
                              args: {
                                'count':
                                    '${_jogadoresInativosOrdenados.length}',
                              },
                            ),
                            style: TextStyle(
                              color: _exibirInativos
                                  ? Colors.amberAccent
                                  : Colors.white54,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista Rolável: [0] BotAdm -> [1..N] Online -> [Inativos]
                Expanded(
                  child: ListView(
                    children: [
                      // ITEM 0: BOT ADM
                      InkWell(
                        onTap: _abrirPerfilBot,
                        hoverColor: _corDestaque.withValues(alpha: 0.1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _corDestaque.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.smart_toy,
                                    color: Color(0xFF39FF14),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      widget.nomeBot,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF39FF14),
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
                                  left: 16,
                                  top: 1,
                                ),
                                child: Text(
                                  tr('zorkut.bot_subtitle'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 9,
                                    fontFamily: 'CustomFontA',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // JOGADORES ONLINE
                      ...widget.jogadoresZorkut.map((player) {
                        return InkWell(
                          onTap: () => _abrirPerfilJogador(player),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 9,
                                      fontFamily: 'CustomFontA',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // JOGADORES INATIVOS (Quando botão OFF está ativo)
                      if (_exibirInativos && inativos.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: Colors.black26,
                          child: Text(
                            tr('zorkut.inactive_section'),
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...inativos.map((player) {
                          return InkWell(
                            onTap: () => _abrirPerfilJogador(player),
                            hoverColor: _corDestaque.withValues(alpha: 0.08),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
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
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          player.nome,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10.5,
                                            fontFamily: 'CustomFontA',
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
                                        'zorkut.last_seen',
                                        args: {
                                          'date': _formatarDataCurta(
                                            player.ultimoLogin,
                                          ),
                                        },
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 8.5,
                                        fontFamily: 'CustomFontA',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Conteúdo do Perfil do Bot (com lápis para editar nome)
  Widget _construirConteudoPerfilBot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('zorkut.bot_id_label'),
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        if (!_editandoNomeBot)
          Row(
            children: [
              Text(
                widget.nomeBot,
                style: const TextStyle(
                  color: Color(0xFF39FF14),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'CustomFontA',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _editandoNomeBot = true),
                icon: const Icon(Icons.edit, color: _corDestaque, size: 15),
                tooltip: tr('zorkut.tooltip_edit_bot'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _botNameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: _corFundo,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: _corDestaque),
                    ),
                  ),
                  onSubmitted: (val) {
                    widget.onAlterarNomeBot(val);
                    setState(() => _editandoNomeBot = false);
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () {
                  widget.onAlterarNomeBot(_botNameController.text);
                  setState(() => _editandoNomeBot = false);
                },
                icon: const Icon(
                  Icons.check,
                  color: Color(0xFF39FF14),
                  size: 18,
                ),
                tooltip: tr('zorkut.tooltip_save_bot'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          tr('zorkut.bot_profile_hint'),
          style: TextStyle(color: Colors.white60, fontSize: 10.5),
        ),
      ],
    );
  }

  // Conteúdo Base do Perfil do Jogador (Preparado para futuras infrações e logs)
  Widget _construirConteudoPerfilJogador() {
    final p = _jogadorSelecionado;
    if (p == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              p.nome,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: p.zonaAtual == "PVP"
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                border: Border.all(
                  color: p.zonaAtual == "PVP"
                      ? Colors.redAccent
                      : Colors.greenAccent,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tr('zorkut.zone_badge', args: {'zone': p.zonaAtual}),
                style: TextStyle(
                  color: p.zonaAtual == "PVP"
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'zorkut.player_profile_stats',
            args: {'id': p.id, 'level': '${p.level}', 'deaths': '${p.deaths}'},
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'zorkut.player_last_pos',
            args: {'x': p.x.toStringAsFixed(0), 'z': p.z.toStringAsFixed(0)},
          ),
          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _corFundo,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _corDestaque.withValues(alpha: 0.2)),
          ),
          child: Text(
            tr('zorkut.player_infractions_placeholder'),
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
