// lib/apps/logsplit_app.dart

import 'package:flutter/material.dart';

import '../models/log_token.dart';

class LogSplitApp extends StatefulWidget {
  final List<LogToken> logsSplit;
  final VoidCallback onLimparTela;

  const LogSplitApp({
    super.key,
    required this.logsSplit,
    required this.onLimparTela,
  });

  @override
  State<LogSplitApp> createState() => _LogSplitAppState();
}

class _LogSplitAppState extends State<LogSplitApp> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _rolandoAutomaticamente = false;
  int _novosLogsNaoLidos = 0;
  int _totalLogsAnterior = 0;

  @override
  void initState() {
    super.initState();
    _totalLogsAnterior = widget.logsSplit.length;
    _scrollController.addListener(_verificarPosicaoRolagem);
  }

  void _verificarPosicaoRolagem() {
    if (_rolandoAutomaticamente || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final atual = _scrollController.position.pixels;
    final estaNoFundo = (maxScroll - atual) <= 15.0;

    if (estaNoFundo && !_autoScroll) {
      setState(() => _autoScroll = true);
    } else if (!estaNoFundo && _autoScroll) {
      setState(() => _autoScroll = false);
    }
  }

  @override
  void didUpdateWidget(covariant LogSplitApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final totalAtual = widget.logsSplit.length;

    // Se a lista foi limpa, reseta os contadores e destrava o scroll
    if (totalAtual == 0) {
      _totalLogsAnterior = 0;
      if (_novosLogsNaoLidos > 0 || !_autoScroll) {
        setState(() {
          _novosLogsNaoLidos = 0;
          _autoScroll = true;
        });
      }
      return;
    }

    if (totalAtual > _totalLogsAnterior) {
      final diferenca = totalAtual - _totalLogsAnterior;
      _totalLogsAnterior = totalAtual;

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
          _novosLogsNaoLidos += diferenca;
        });
      }
    } else {
      _totalLogsAnterior = totalAtual;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_verificarPosicaoRolagem);
    _scrollController.dispose();
    super.dispose();
  }

  void _alternarAutoScrollPeloBotao() {
    setState(() {
      _autoScroll = !_autoScroll;
    });

    if (_autoScroll && _scrollController.hasClients) {
      _rolandoAutomaticamente = true;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _rolandoAutomaticamente = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0500),
      child: Column(
        children: [
          // Barra superior interna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.08),
              border: const Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _alternarAutoScrollPeloBotao,
                  child: Row(
                    children: [
                      Icon(
                        _autoScroll
                            ? Icons.lock_clock
                            : Icons.pause_circle_filled,
                        color: _autoScroll
                            ? const Color(0xFF39FF14)
                            : Colors.amberAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _autoScroll ? "Auto-Scroll: ON" : "Rolagem Pausada",
                        style: TextStyle(
                          color: _autoScroll
                              ? const Color(0xFF39FF14)
                              : Colors.amberAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => widget.onLimparTela(),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.cleaning_services,
                        color: Colors.amberAccent,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Limpar Tela",
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista renderizando os atributos do LogToken
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.logsSplit.length,
                itemBuilder: (context, index) {
                  final log = widget.logsSplit[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ícone do token
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 6),
                          child: Icon(log.icone, color: log.corTag, size: 13),
                        ),
                        // Tag + Mensagem limpa selecionável
                        Expanded(
                          child: SelectableText.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: 'CustomFontA',
                                fontSize: 11,
                              ),
                              children: [
                                if (log.tag.isNotEmpty)
                                  TextSpan(
                                    text: "${log.tag} ",
                                    style: TextStyle(
                                      color: log.corTag,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                TextSpan(
                                  text: log.mensagemLimpa,
                                  style: const TextStyle(color: Colors.white70),
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
          ),
        ],
      ),
    );
  }
}
