// lib/apps/monitor_app.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MonitorApp extends StatefulWidget {
  final List<String> logs;
  final VoidCallback onLimparTela;

  const MonitorApp({super.key, required this.logs, required this.onLimparTela});

  @override
  State<MonitorApp> createState() => _MonitorAppState();
}

class _MonitorAppState extends State<MonitorApp> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _rolandoAutomaticamente = false;
  int _novosLogsNaoLidos = 0;
  int _totalLogsAnterior = 0;

  @override
  void initState() {
    super.initState();
    _totalLogsAnterior = widget.logs.length;
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
  void didUpdateWidget(covariant MonitorApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final totalAtual = widget.logs.length;

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
      color: const Color(0xFF050505),
      child: Column(
        children: [
          // Barra interna de controle do app (sem poluir o main.dart)
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
          // Lista de logs
          // Lista de logs otimizada com SelectionArea único
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(300),
                  addAutomaticKeepAlives: false,
                  itemCount: widget.logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        widget.logs[index],
                        style: const TextStyle(
                          color: Color(0xFF00FF66),
                          fontFamily: 'CustomFontA',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
