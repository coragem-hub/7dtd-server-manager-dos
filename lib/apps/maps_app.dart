// lib/apps/maps_app.dart

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/jogador_status.dart';

class MapsApp extends StatefulWidget {
  final List<JogadorStatus> playersOnline;
  final List<List<double>> retangulosPve;
  final double tamanhoMundoInicial;
  final Function(JogadorStatus)? onPlayerClicado;

  const MapsApp({
    super.key,
    required this.playersOnline,
    this.retangulosPve = const [],
    this.tamanhoMundoInicial = 6144.0, // Padrão Navezgane (6144x6144)
    this.onPlayerClicado,
  });

  @override
  State<MapsApp> createState() => _MapsAppState();
}

class _MapsAppState extends State<MapsApp> {
  static const Color _corFundo = Color(0xFF050B0A);
  static const Color _corDestaque = Color(0xFF00FFCC);
  static const Color _corLateral = Color(0xFF0A1412);
  static const Color _corInputFundo = Color(0xFF10201D);

  // Controle de Camadas e Escala
  bool _mostrarCamadaPve = true;
  bool _mostrarCamadaPlayers = true;
  late double _tamanhoMundoAtual;
  String? _caminhoMapaCustomizado;

  @override
  void initState() {
    super.initState();
    _tamanhoMundoAtual = widget.tamanhoMundoInicial;
  }

  // Converte coordenada X do 7D2D (-metade até +metade) para pixel na tela (0 até tamanhoBox)
  double _converterXParaPixel(double xJogo, double tamanhoBox) {
    final metade = _tamanhoMundoAtual / 2.0;
    return ((xJogo + metade) / _tamanhoMundoAtual) * tamanhoBox;
  }

  // Converte coordenada Z do 7D2D (+metade no topo até -metade embaixo) para pixel Y na tela
  double _converterZParaPixel(double zJogo, double tamanhoBox) {
    final metade = _tamanhoMundoAtual / 2.0;
    return ((metade - zJogo) / _tamanhoMundoAtual) * tamanhoBox;
  }

  void _abrirDialogoCarregarMapa() {
    final pathController = TextEditingController(
      text: _caminhoMapaCustomizado ?? '',
    );
    final tamanhoController = TextEditingController(
      text: _tamanhoMundoAtual.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _corLateral,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _corDestaque, width: 1),
        ),
        title: const Text(
          "CARREGAR MAPA CUSTOMIZADO",
          style: TextStyle(
            color: _corDestaque,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Caminho do arquivo (.png / .webp)",
                labelStyle: TextStyle(
                  color: _corDestaque.withValues(alpha: 0.7),
                ),
                hintText: r"C:\7D2D\Worlds\MeuMapa\map.png",
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _corDestaque),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tamanhoController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Tamanho do Mapa (Ex: 6144, 8192, 10240, 16384)",
                labelStyle: TextStyle(
                  color: _corDestaque.withValues(alpha: 0.7),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _corDestaque),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _caminhoMapaCustomizado = null;
                _tamanhoMundoAtual = widget.tamanhoMundoInicial;
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              "Restaurar Padrão",
              style: TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _corDestaque),
            onPressed: () {
              final novoTamanho =
                  double.tryParse(tamanhoController.text.trim()) ??
                  _tamanhoMundoAtual;
              final novoCaminho = pathController.text.trim();

              setState(() {
                _tamanhoMundoAtual = novoTamanho;
                _caminhoMapaCustomizado = novoCaminho.isNotEmpty
                    ? novoCaminho
                    : null;
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              "Aplicar",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _corFundo,
      child: Row(
        children: [
          // COLUNA ESQUERDA: Barra de Ferramentas + Mapa Quadrado
          Expanded(
            child: Column(
              children: [
                // BARRA DE CAMADAS E CONTROLES DO MAPA (Extensível para botões futuros)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _corInputFundo,
                    border: Border(
                      bottom: BorderSide(
                        color: _corDestaque.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botão Camada PVE
                      _buildBotaoCamada(
                        icone: Icons.shield_outlined,
                        label: "PVE",
                        ativo: _mostrarCamadaPve,
                        corAtiva: Colors.greenAccent,
                        onTap: () => setState(
                          () => _mostrarCamadaPve = !_mostrarCamadaPve,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botão Camada Players
                      _buildBotaoCamada(
                        icone: Icons.person_pin_circle_outlined,
                        label: "Players",
                        ativo: _mostrarCamadaPlayers,
                        corAtiva: _corDestaque,
                        onTap: () => setState(
                          () => _mostrarCamadaPlayers = !_mostrarCamadaPlayers,
                        ),
                      ),
                      const Spacer(),

                      // Indicador / Atalho de Tamanho do Mundo
                      Text(
                        "${(_tamanhoMundoAtual / 1024).toStringAsFixed(0)}K (${_tamanhoMundoAtual.toInt()})",
                        style: TextStyle(
                          color: _corDestaque.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontFamily: 'CustomFontA',
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão Carregar Mapa Customizado
                      InkWell(
                        onTap: _abrirDialogoCarregarMapa,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _corDestaque.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _corDestaque.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.folder_open,
                                color: _corDestaque,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Mapa",
                                style: TextStyle(
                                  color: _corDestaque,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ÁREA INTERATIVA DO MAPA QUADRADO (Sem sobra de bordas laterais)
                Expanded(
                  child: ClipRect(
                    child: InteractiveViewer(
                      maxScale: 8.0,
                      minScale: 0.8,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Tamanho exato em pixels do quadrado visível na tela
                              final double tamanhoBox = constraints.maxWidth;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // CAMADA 0: Imagem Base do Mapa preenchendo 100% do quadrado
                                  Positioned.fill(
                                    child: _caminhoMapaCustomizado != null
                                        ? Image.file(
                                            File(_caminhoMapaCustomizado!),
                                            fit: BoxFit.fill,
                                            errorBuilder: (_, _, _) =>
                                                _buildErroMapa(),
                                          )
                                        : Image.asset(
                                            'assets/maps/Navezgane/images/Navezgane.webp',
                                            fit: BoxFit.fill,
                                            errorBuilder: (_, _, _) =>
                                                _buildErroMapa(),
                                          ),
                                  ),

                                  // CAMADA 1: Retângulos de Zona PVE
                                  if (_mostrarCamadaPve)
                                    ...widget.retangulosPve.map((limites) {
                                      // limites = [minX, maxX, minZ, maxZ]
                                      final left = _converterXParaPixel(
                                        limites[0],
                                        tamanhoBox,
                                      );
                                      final right = _converterXParaPixel(
                                        limites[1],
                                        tamanhoBox,
                                      );
                                      // No jogo maxZ (limites[3]) fica mais ao norte (menor pixel Y)
                                      final top = _converterZParaPixel(
                                        limites[3],
                                        tamanhoBox,
                                      );
                                      final bottom = _converterZParaPixel(
                                        limites[2],
                                        tamanhoBox,
                                      );

                                      return Positioned(
                                        left: left,
                                        top: top,
                                        width: (right - left).clamp(
                                          0.0,
                                          tamanhoBox,
                                        ),
                                        height: (bottom - top).clamp(
                                          0.0,
                                          tamanhoBox,
                                        ),
                                        child: IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent
                                                  .withValues(alpha: 0.14),
                                              border: Border.all(
                                                color: Colors.greenAccent
                                                    .withValues(alpha: 0.7),
                                                width: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                  // CAMADA 2: Pinos dos Jogadores Online
                                  if (_mostrarCamadaPlayers)
                                    ...widget.playersOnline.map((player) {
                                      final px = _converterXParaPixel(
                                        player.x,
                                        tamanhoBox,
                                      );
                                      final py = _converterZParaPixel(
                                        player.z,
                                        tamanhoBox,
                                      );
                                      final isPvp =
                                          player.zonaAtual
                                              .toUpperCase()
                                              .trim() ==
                                          "PVP";
                                      final corPino = isPvp
                                          ? Colors.redAccent
                                          : Colors.greenAccent;

                                      return Positioned(
                                        // Centraliza o ponto de 10px exatamente na coordenada
                                        left: px - 5,
                                        top: py - 5,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (widget.onPlayerClicado !=
                                                null) {
                                              widget.onPlayerClicado!(player);
                                            }
                                          },
                                          child: Tooltip(
                                            message:
                                                "${player.nome} (Nv.${player.level})\nX: ${player.x.toInt()} Z: ${player.z.toInt()} [${player.zonaAtual}]",
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: corPino,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.black,
                                                      width: 1.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: corPino
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 3,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          2,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    player.nome,
                                                    style: TextStyle(
                                                      color: corPino,
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'CustomFontA',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // COLUNA DIREITA: Lista Lateral com Coordenadas e Zona (PVP/PVE)
          Container(
            width: 170,
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
                    "RASTREADORES ATIVOS (${widget.playersOnline.length})",
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
                    itemCount: widget.playersOnline.length,
                    itemBuilder: (context, index) {
                      final player = widget.playersOnline[index];
                      final isPvp =
                          player.zonaAtual.toUpperCase().trim() == "PVP";
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
                                      color: _corDestaque,
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
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPvp
                                          ? Colors.redAccent.withValues(
                                              alpha: 0.2,
                                            )
                                          : Colors.greenAccent.withValues(
                                              alpha: 0.2,
                                            ),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: isPvp
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      player.zonaAtual,
                                      style: TextStyle(
                                        color: isPvp
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'CustomFontA',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  "X: ${player.x.toStringAsFixed(0)}  Y: ${player.y.toStringAsFixed(0)}  Z: ${player.z.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
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

  Widget _buildBotaoCamada({
    required IconData icone,
    required String label,
    required bool ativo,
    required Color corAtiva,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: ativo ? corAtiva.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: ativo ? corAtiva : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icone, color: ativo ? corAtiva : Colors.white38, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: ativo ? corAtiva : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErroMapa() {
    return Container(
      color: const Color(0xFF0F1A18),
      child: const Center(
        child: Icon(Icons.map_outlined, color: Colors.white24, size: 48),
      ),
    );
  }
}
