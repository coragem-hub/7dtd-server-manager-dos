import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sd_dos_dart/models/log_token.dart';
import 'package:sd_dos_dart/apps/monitor_app.dart';
import 'package:sd_dos_dart/apps/cmd_app.dart';
import 'package:sd_dos_dart/apps/logsplit_app.dart';
import 'package:sd_dos_dart/apps/zorkut_app.dart';
import 'package:sd_dos_dart/apps/maps_app.dart';
import 'package:sd_dos_dart/models/jogador_status.dart';

import 'dart:math';

void main() {
  runApp(const SdDOSManager());
}

class SdDOSManager extends StatelessWidget {
  const SdDOSManager({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SD-DOS Server Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'CustomFontA',
        scaffoldBackgroundColor: const Color.fromARGB(255, 30, 30, 30),
        primaryColor: const Color(0xFF39FF14),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// Estado do widget DashboardPage, que gerencia a conexão WebSocket e os logs
class _DashboardPageState extends State<DashboardPage> {
  //Substitua por <IP_DO_PROXY> antes de publicar.
  final String ipProxy = "<IP_DO_PROXY>"; // "localhost" ou IP do servidor
  //Substitua por <PORTA_DO_PROXY> antes de publicar.
  final String portaProxy = "<PORTA_DO_PROXY>";
  //Substitua por <TOKEN_DO_PROXY> antes de publicar.
  final String token = "<TOKEN_DO_PROXY>";

  // Variáveis para gerenciar a conexão WebSocket
  WebSocketChannel? _channel;
  bool _conectado = false;
  bool _scriptConectado =
      false; // Fica true assim que receber a primeira linha do servidor

  //== INICIO MODULO 1: LISTAS, CONSTANTES, VARIÁVEIS E LOOPS ==//

  final List<String> _logs =
      []; // Lista mestre de texto bruto do console do servidor
  final List<LogToken> _logsTratadosLogSplit = [];
  final List<JogadorStatus> _jogadoresOnline = [];
  final List<JogadorStatus> _jogadoresHistorico = [];
  int _contadorCiclosLp = 0;

  // Listas de Zonas: [MinX, MaxX, MinZ, MaxZ]
  final List<List<double>> retangulosPve = [
    [-3000.0, -2480.0, -190.0, 1660.0],
    [-2480.0, -1790.0, -360.0, 1610.0],
    [-1790.0, -1340.0, -340.0, 1500.0],
    [-1340.0, -990.0, -330.0, 1380.0],
    [-990.0, -740.0, -710.0, 1270.0],
    [-740.0, -640.0, -390.0, 1190.0],
    [-640.0, -540.0, 50.0, 1160.0],
    [-540.0, -320.0, 70.0, 1120.0],
    [-320.0, -90.0, 250.0, 1080.0],
    [-90.0, 80.0, 270.0, 1220.0],
    [80.0, 480.0, 140.0, 1230.0],
    [480.0, 670.0, 220.0, 1130.0],
    [670.0, 1410.0, 290.0, 1070.0],
    [1410.0, 1660.0, 270.0, 950.0],
  ];

  final _random = Random();

  void _iniciarLoopRastreamentoAleatorio() {
    if (!_conectado || _channel == null) return;
    _channel!.sink.add('lp');
    // Gera um tempo aleatório em milissegundos
    int proximoIntervaloMilissegundos = (10000 + _random.nextInt(20000))
        .toInt();
    // Agenda o próximo disparo com o tempo sorteado
    Future.delayed(Duration(milliseconds: proximoIntervaloMilissegundos), () {
      if (mounted) _iniciarLoopRastreamentoAleatorio();
    });
  }

  final RegExp _lpRegex = RegExp(
    r'id=(\d+),\s+([^,]+),\s+pos=\(([-\d.]+),\s+([-\d.]+),\s+([-\d.]+)\).*health=(\d+).*deaths=(\d+).*level=(\d+).*pltfmid=([^,]+).*ping=(\d+)',
  );

  //== FINAL MODULO 1: LISTAS, CONSTANTES, VARIÁVEIS E LOOPS ==//

  //== INICIO MODULO 2.1: FUNÇÕES DE CONEXÃO COM O PROXY ==//

  @override
  void initState() {
    super.initState(); // Chama o método initState da classe pai
    _conectarAoProxy(); // Tenta conectar ao Proxy Python assim que o widget é criado
  }

  // Função auxiliar para centralizar a reconexão segura
  void _tratarDesconexao(String mensagemErro) {
    if (!_conectado && _logs.last.contains("Tentando reconectar")) {
      return; // Evita logs duplicados no loop
    }

    // Atualiza o estado para indicar que a conexão foi perdida e tenta reconectar após 5 segundos
    setState(() {
      _conectado = false;
      _logs.add(mensagemErro);
      _logs.add("[Sistema] Tentando reconectar em 5 segundos...");
    });

    // Limpa o canal antigo
    _channel = null;

    // Aumentamos para 5 segundos para dar fôlego ao app e ao sistema operacional
    Future.delayed(const Duration(seconds: 5), () {
      // Verifica se o widget ainda está na tela antes de rodar código assíncrono
      if (mounted) _conectarAoProxy();
    });
  }

  @override
  void dispose() {
    // Fecha o canal WebSocket e libera os recursos dos controladores
    _channel?.sink.close();
    _channel = null;
    _comandoController.dispose();

    // Libera os novos controladores de rolagem independentes
    _scrollFundoController.dispose();
    super.dispose();
  }

  //== FIM MODULO 2.1: FUNÇÕES DE CONEXÃO COM O PROXY ==//

  //== INICIO MODULO 2.2: CONEXÃO E TRATAMENTO DE LOGS BRUTOS==//

  void _conectarAoProxy() async {
    // Evita criar conexões duplicadas se já estiver tentando conectar
    if (_channel != null) {
      // Se já houver um canal existente, fecha-o antes de criar um novo
      try {
        // Tenta fechar o canal existente
        _channel!.sink.close(); // Fecha o canal existente
      } catch (_) {} // Ignora qualquer erro ao fechar o canal existente
    }

    // Atualiza o estado para indicar que está tentando conectar
    setState(() {
      _conectado = false; // Começa sempre como falso
      _logs.add(
        "[Sistema] Tentando conectar ao Proxy Python...",
      ); // Adiciona um log indicando que está tentando conectar
    });

    // Tenta criar uma nova conexão WebSocket com o Proxy Python
    try {
      // Tenta criar uma nova conexão WebSocket
      final url = 'ws://$ipProxy:$portaProxy/?token=$token'; // Cria a URL de conexão com o Proxy Python usando o IP, porta e token fornecidos
      final channel = WebSocketChannel.connect(
        Uri.parse(url),
      ); // Cria um novo canal de comunicação WebSocket

      // Aguarda o 'ready' garante que o handshake terminou com sucesso
      await channel.ready;

      // Atualiza o canal de comunicação WebSocket com o novo canal criado
      _channel = channel;

      // Atualiza o estado para indicar que a conexão foi estabelecida com sucesso
      setState(() {
        _conectado = true; // Atualiza o estado
        _logs.add("[Sistema] Conectado com sucesso!");
      });

      _iniciarLoopRastreamentoAleatorio();

      _channel!.stream.listen(
        (mensagem) {
          if (!_scriptConectado) setState(() => _scriptConectado = true);
          final linhaBruta = mensagem.toString();

          // 1. Tratamento: Identificando os tipos de Logs
          LogToken tokenTratado;

          // REGRA 1: Se for o início do comando 'lp', limpamos a lista temporária e incrementamos o ciclo
          if (linhaBruta.contains("Executing command 'lp'")) {
            _jogadoresOnline.clear();
            _contadorCiclosLp++;
          }

          if (linhaBruta.contains("INF Chat (") &&
              linhaBruta.contains("from '-non-player-'")) {
            setState(() {
              _logs.add(linhaBruta);
            });
            _scrollParaOFinal();
            return;
          }

          // REGRA 2: Se a linha bate com o padrão de dados de um jogador
          if (_lpRegex.hasMatch(linhaBruta)) {
            // Se a linha bate com o padrão de dados de um jogador
            final match = _lpRegex.firstMatch(linhaBruta)!; // Extrai os grupos de captura da regex para obter os dados do jogador

            final nomeJogador = match.group(
              2,
            )!; // Extrai o nome do jogador do grupo 2 da regex
            final double posX = double.parse(
              match.group(3)!,
            ); // Extrai a posição X do jogador do grupo 3 da regex
            final double posZ = double.parse(
              match.group(5)!,
            ); // Extrai a posição Z do jogador do grupo 5 da regex

            String zonaCalculada = "PVP";
            for (var limites in retangulosPve) {
              if (posX >= limites[0] &&
                  posX <= limites[1] &&
                  posZ >= limites[2] &&
                  posZ <= limites[3]) {
                zonaCalculada = "PVE";
                break;
              }
            }

            // 2. Instancia o objeto do jogador usando as variáveis extraídas
            final novoJogador = JogadorStatus(
              id: match.group(1)!,
              nome: nomeJogador,
              x: posX,
              y: double.parse(match.group(4)!),
              z: posZ,
              health: int.parse(match.group(6)!),
              deaths: int.parse(match.group(7)!),
              level: int.parse(match.group(8)!),
              platformId: match.group(9)!,
              ping: int.parse(match.group(10)!),
              zonaAtual: zonaCalculada,
            );

            final jogadorAntigo =
                _jogadoresHistorico.any((j) => j.id == novoJogador.id)
                ? _jogadoresHistorico.firstWhere((j) => j.id == novoJogador.id)
                : null;

            if (jogadorAntigo == null ||
                jogadorAntigo.zonaAtual != zonaCalculada) {
              if (zonaCalculada == "PVP") {
                enviarMensagemHub(
                  comandoBruto:
                      'pm "${novoJogador.nome}" "[39FF14]BotAdm (MP):[-] [FF7979]Bioma Hostil[-] [eb3f24]PVP ATIVO![-]          Anarquia: Matar, Roubar, Raid, Griefing, Trap, etc.          [F9CA24]Não abuse! Respeite Fronteiras e TODOS os Traders![-]"',
                  tagExibicao: "[PM]",
                  textoLimpo:
                      "BotAdm enviou aviso de PVP para ${novoJogador.nome}",
                  corLabel: Colors.purpleAccent,
                );
              } else if (jogadorAntigo != null &&
                  jogadorAntigo.zonaAtual == "PVP" &&
                  zonaCalculada == "PVE") {
                enviarMensagemHub(
                  comandoBruto:
                      'pm "${novoJogador.nome}" "[39FF14]BotAdm (MP):[-] [78E08F]Floresta Pinhal[-] [00ff00]PVE ATIVO![-]          Proibido: Matar jogadores, Raid, Griefing, Trap, etc.          [F9CA24]Respeite PVE! Floresta Pinhal e TODOS os Traders![-]"',
                  tagExibicao: "[PM]",
                  textoLimpo:
                      "BotAdm enviou aviso de PVE para ${novoJogador.nome}",
                  corLabel: Colors.greenAccent,
                );
              }
            }

            setState(() {
              // Atualiza a lista de quem está ativamente online neste exato ciclo
              _jogadoresOnline.removeWhere((j) => j.id == novoJogador.id);
              _jogadoresOnline.add(novoJogador);

              // Atualiza TAMBÉM o histórico para guardar o último estado/zona conhecido do jogador para o próximo ciclo
              _jogadoresHistorico.removeWhere((j) => j.id == novoJogador.id);
              _jogadoresHistorico.add(novoJogador);
            });

            // Alimenta o logsplit de forma elegante com uma TAG especial [LP]
            final tokenLP = LogToken(
              linhaPura: linhaBruta,
              tag: "[LP]",
              mensagemLimpa:
                  "📍 ${novoJogador.nome} (Nv.${novoJogador.level}) pos: (${novoJogador.x.toStringAsFixed(1)}, ${novoJogador.z.toStringAsFixed(1)}) Ping: ${novoJogador.ping}ms",
              corTag: Colors.deepPurpleAccent,
              icone: Icons.location_searching,
            );

            setState(() {
              _logsTratadosLogSplit.add(tokenLP);
            });
            _scrollParaOFinal();
            return; // Interceptado com sucesso, não precisa passar pelos filtros de baixo!
          }

          // REGRA 3: Conexão e Desconexão de Jogadores
          if (linhaBruta.contains("joined the game") ||
              linhaBruta.contains("left the game")) {
            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[PC]",
              mensagemLimpa: linhaBruta.trim(),
              corTag: Colors.green,
              icone: Icons.person_add,
            );
          }
          // REGRA 4: Total de Players Online (Com contador de ciclo + hora local para mostrar atividade)
          else if (linhaBruta.contains("Total of ") &&
              linhaBruta.contains(" in the game")) {
            final idxInicio = linhaBruta.indexOf("Total of ");
            final resumoTotal = linhaBruta.substring(idxInicio).trim();

            // Pega a hora local formatada (HH:mm:ss) sem precisar de pacotes externos
            final agora = DateTime.now();
            final horaFormatada =
                "${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}:${agora.second.toString().padLeft(2, '0')}";

            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[LP]",
              mensagemLimpa:
                  "$resumoTotal  •  Ciclo #$_contadorCiclosLp ($horaFormatada)",
              corTag: Colors.deepPurpleAccent,
              icone: Icons.groups,
            );
          }
          // REGRA 5: Chat Nativo dos Jogadores
          else if (linhaBruta.contains("INF Chat (")) {
            final idxFechamento = linhaBruta.indexOf("): ");
            final mensagemExtraida = idxFechamento != -1
                ? linhaBruta.substring(idxFechamento + 3).trim()
                : linhaBruta;

            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[CHAT]",
              mensagemLimpa: mensagemExtraida,
              corTag: Colors.cyanAccent,
              icone: Icons.chat_bubble,
            );
          }
          // REGRA 6: Comando sayadmin externo (Antes do filtro genérico de comandos)
          else if (linhaBruta.contains("Executing command 'sayadmin ") &&
              !linhaBruta.contains("sayadmin [39FF14]BotAdm[-] 99")) {
            final inicioCmd =
                linhaBruta.indexOf("Executing command 'sayadmin ") + 27;
            final fimCmd = linhaBruta.lastIndexOf("' by ");
            final argsBrutos = (fimCmd > inicioCmd)
                ? linhaBruta.substring(inicioCmd, fimCmd)
                : "";

            String remetente = "Admin";
            String textoMensagem = argsBrutos;

            final primeiraAspa = argsBrutos.indexOf('"');
            final ultimaAspa = argsBrutos.lastIndexOf('"');

            if (primeiraAspa != -1 && ultimaAspa > primeiraAspa) {
              textoMensagem = argsBrutos.substring(
                primeiraAspa + 1,
                ultimaAspa,
              );
              final prefixo = argsBrutos.substring(0, primeiraAspa).trim();
              final partesPrefixo = prefixo.split(' ');
              if (partesPrefixo.length > 1) {
                partesPrefixo.removeLast();
              }
              remetente = partesPrefixo
                  .join(' ')
                  .replaceAll(RegExp(r'\[[0-9a-fA-F]{6}\]|\[-\]'), '')
                  .replaceAll('"', '')
                  .trim();
            }

            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[MSG]",
              mensagemLimpa: "$remetente: $textoMensagem",
              corTag: const Color(0xFFD580FF),
              icone: Icons.campaign,
            );
          }
          // REGRA 7: Comandos Executados via Telnet/Console (Extrai Comando puro + IP sem porta)
          else if (linhaBruta.contains("INF Executing command '")) {
            final inicioCmd =
                linhaBruta.indexOf("INF Executing command '") + 23;
            final fimCmd = linhaBruta.lastIndexOf("' by ");
            final comandoPuro = (fimCmd > inicioCmd)
                ? linhaBruta.substring(inicioCmd, fimCmd)
                : "Comando desconhecido";

            // Extrai o IP após " from " e remove a porta (ex: ":53476")
            String ipLimpo = "Console";
            final idxFrom = linhaBruta.lastIndexOf(" from ");
            if (idxFrom != -1) {
              final ipComPorta = linhaBruta.substring(idxFrom + 6).trim();
              ipLimpo = ipComPorta.contains(':')
                  ? ipComPorta.split(':').first
                  : ipComPorta;
            }

            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[CMD]",
              mensagemLimpa: "$comandoPuro  |  IP: $ipLimpo",
              corTag: Colors.amberAccent,
              icone: Icons.terminal,
            );
          }
          // REGRA FINAL: Tudo que não foi tratado acima
          else {
            tokenTratado = LogToken(
              linhaPura: linhaBruta,
              tag: "[NT]",
              mensagemLimpa: linhaBruta.trim(),
              corTag: Colors.red,
              icone: Icons.gpp_maybe,
            );
          }

          // 2. Atualiza o Estado de forma otimizada
          setState(() {
            _logs.add(linhaBruta);
            // Alimenta a torneira do logsplit.exe com o objeto já processado
            _logsTratadosLogSplit.add(tokenTratado);
          });
          _scrollParaOFinal();
        },

        onDone: () {
          _conectado = false;
          _scriptConectado = false;
          // Quando a conexão é encerrada, trata a desconexão e tenta reconectar
          _tratarDesconexao("[⚠️ Erro] Conexão encerrada pelo servidor.");
        },
        onError: (erro) {
          _conectado = false;
          _scriptConectado = false;
          _tratarDesconexao("[⚠️ Erro] Falha na conexão: $erro");
        },
      );
    } catch (e) {
      _tratarDesconexao("[⚠️ Erro] Não foi possível alcançar o servidor: $e");
    }
  }

  //== FIM MODULO 2.2: CONEXÃO ETRATAMENTO DE LOGS BRUTOS==//

  //== INICIO MODULO 2.3: FUNÇÕES DE ENVIO DE COMANDOS E MENSAGENS ==//

  // Função que envia o comando digitado no campo de entrada para o Proxy Python via WebSocket
  void _enviarComando(String comando) {
    // Obtém o comando digitado no campo de entrada e remove espaços em branco extras
    final comandoLimpo = comando.trim();
    // Verifica se o comando não está vazio e se a conexão WebSocket está ativa
    if (comandoLimpo.isNotEmpty && _channel != null && _conectado) {
      _logs.add(
        "[Comando] $comandoLimpo",
      ); // Adiciona o comando à lista de logs
      _channel!.sink.add(
        comandoLimpo,
      ); // Envia o comando para o Proxy Python via WebSocket
      _comandoController
          .clear(); // Limpa o campo de entrada de comando após enviar
    }
  }

  void _enviarComandoDoPrompt() {
    final comando = _comandoController.text.trim();
    if (comando.isNotEmpty) {
      _enviarComando(comando);
    }
  }

  // Função para enviar mensagens do chat global do Zorkut
  // Recebe o texto direto do ZorkutApp e aciona o Hub central
  void _enviarChatGlobalZorkut(String msg) {
    if (msg.isEmpty) return;

    // Se o Zorkut estiver no modo VANILLA, ele envia a string começando com 'say "'
    if (msg.startsWith('say "') && msg.endsWith('"')) {
      final textoPuro = msg.substring(5, msg.length - 1);
      enviarMensagemHub(
        comandoBruto: msg,
        tagExibicao: "[CHAT]",
        textoLimpo: "Server: $textoPuro",
        corLabel: const Color(0xFF39FF14),
      );
    } else {
      // Modo padrão PRISMA CORE
      enviarMensagemHub(
        comandoBruto: 'sayadmin [39FF14]BotAdm[-] 99 "$msg"',
        tagExibicao: "[MSG]",
        textoLimpo: "BotAdm: $msg",
        corLabel: Colors.cyanAccent,
      );
    }
  }

  // Função mestra pra enviar mensagens
  void enviarMensagemHub({
    required String comandoBruto, // Ex: 'say "[39FF14]BotAdm:[-] Teste"'
    required String tagExibicao, // Ex: '[BotAdm]' ou '[PM]'
    required String textoLimpo, // Ex: 'BotAdm: Teste'
    required Color corLabel,
  }) {
    if (_channel != null && _conectado) {
      // 1. Despacha o comando real via Telnet para o servidor Python
      _channel!.sink.add(comandoBruto);

      // 2. Cria um Token de Log interno para o Zorkut/LogSplit rastrearem
      final novoToken = LogToken(
        linhaPura: comandoBruto,
        tag: tagExibicao,
        mensagemLimpa: textoLimpo,
        corTag: corLabel,
        icone: tagExibicao == "[PM]"
            ? Icons.lock_outline
            : Icons.chat_bubble_outline,
      );

      setState(() {
        // Alimenta ambas as listas locais para que o operador veja o log no monitor
        _logsTratadosLogSplit.add(novoToken);
      });

      _scrollParaOFinal();
    }
  }

  //== FIM MODULO 2.3: FUNÇÕES DE ENVIO DE COMANDOS E MENSAGENS ==//

  //== INICIO MODULO 3.1: CONSTRUÇÃO BASE DE JANELAS FLUTUANTES ==//

  Widget _construirJanela({
    required String id,
    required String titulo,
    required Widget conteudo,
    Color corTema = const Color(0xFF39FF14),
    double larguraJanela = 500.0,
    double alturaJanela = 350.0,
  }) {
    if (_appsAbertos[id] != true || _appsMinimizados[id] == true) {
      return const SizedBox.shrink();
    }

    final larguraTela = MediaQuery.of(context).size.width;
    final ehCelular = larguraTela < 600;

    final larguraJanelaFinal = ehCelular ? larguraTela : larguraJanela;
    final alturaJanelaFinal = ehCelular
        ? (MediaQuery.of(context).size.height - 95)
        : alturaJanela;

    final notifierPosicao = _posicoesJanelas[id]!;

    // ValueListenableBuilder redesenha APENAS esta janela durante o arrasto
    return ValueListenableBuilder<Offset>(
      key: ValueKey('janela_$id'), // <-- CORREÇÃO 1: Identifica cada janela unicamente para o Flutter não misturar as posições
      valueListenable: notifierPosicao,
      builder: (context, posicaoAtual, child) {
        return Positioned(
          top: ehCelular ? 45 : posicaoAtual.dy,
          left: ehCelular ? 0 : posicaoAtual.dx,
          child: Container(
            width: larguraJanelaFinal,
            height: alturaJanelaFinal,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(ehCelular ? 0 : 8),
              border: Border.all(
                color: corTema.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Barra de título (Traz para frente E arrasta no mesmo gesto sem cancelar o clique)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: ehCelular
                      ? null
                      : (_) {
                          _trazerParaFrente(id); // Traz para frente quando o arrasto realmente inicia
                        },
                  onPanUpdate: ehCelular
                      ? null
                      : (detalhes) {
                          final tamanhoTela = MediaQuery.of(context).size;
                          final novaPosicao =
                              notifierPosicao.value + detalhes.delta;

                          // Limites horizontais: permite mover parcialmente para os lados, mas deixa 80px visíveis para puxar de volta
                          final double minX = -(larguraJanelaFinal - 80.0);
                          final double maxX = tamanhoTela.width - 80.0;

                          // Limites verticais: respeita a barra do topo (38px) e não deixa a barra de título sumir atrás da barra de tarefas (50px + 35px da barra)
                          const double minY = 38.0;
                          final double maxY = (tamanhoTela.height - 85.0).clamp(
                            minY,
                            double.infinity,
                          );

                          notifierPosicao.value = Offset(
                            novaPosicao.dx.clamp(minX, maxX),
                            novaPosicao.dy.clamp(minY, maxY),
                          );
                        },

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: corTema.withValues(alpha: 0.15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            color: corTema,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _appsMinimizados[id] = true),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appsAbertos[id] = false;
                                  _appsMinimizados[id] = false;
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // O Listener fica apenas no conteúdo interno para focar ao clicar dentro do app
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => _trazerParaFrente(id),
                    child: conteudo,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //== FIM MODULO 3.1: CONSTRUÇÃO BASE DE JANELAS FLUTUANTES ==//

  //== INICIO MODULO 3.1: DE GERENCIAMENTO DE JANELAS ==//

  // Controla quais aplicativos estão abertos
  final Map<String, bool> _appsAbertos = {
    'cmd': false,
    'monitor': false,
    'logsplit': false,
    'zorkut': false,
    'maps': false,
  };
  // Ordem de foco das janelas (Stack)
  final List<String> _ordemFoco = [
    'cmd',
    'monitor',
    'logsplit',
    'zorkut',
    'maps',
  ];
  // Controla quais aplicativos estão minimizados
  final Map<String, bool> _appsMinimizados = {
    'cmd': false,
    'monitor': false,
    'logsplit': false,
    'zorkut': false,
    'maps': false,
  };
  // Função para trazer uma janela para frente (foco)
  void _trazerParaFrente(String id) {
    if (_ordemFoco.last != id) {
      setState(() {
        _ordemFoco.remove(id);
        _ordemFoco.add(id);
      });
    }
  }

  // Controla a posição inicial das janelas de forma isolada (sem redesenhar o fundo ao arrastar)
  final Map<String, ValueNotifier<Offset>> _posicoesJanelas = {
    'cmd': ValueNotifier(const Offset(0, 50)),
    'monitor': ValueNotifier(const Offset(50, 100)),
    'logsplit': ValueNotifier(const Offset(100, 150)),
    'zorkut': ValueNotifier(const Offset(150, 200)),
    'maps': ValueNotifier(const Offset(200, 250)),
  };

  // Controlador para o campo de entrada de comando
  final TextEditingController _comandoController = TextEditingController();
  // Controlador para a rolagem da lista de logs
  final ScrollController _scrollFundoController =
      ScrollController(); // Para o fundo
  final ScrollController _scrollMapsController =
      ScrollController(); // Para o Maps

  // Faz a caixa de texto descer sozinha ao receber novos logs (Tail File)
  void _scrollParaOFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Rola o fundo se ele estiver ativo
      if (_scrollFundoController.hasClients) {
        _scrollFundoController.animateTo(
          _scrollFundoController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      // Rola o Maps se a janela estiver aberta e ativa
      if (_appsAbertos['maps'] == true && _scrollMapsController.hasClients) {
        _scrollMapsController.animateTo(
          _scrollMapsController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  //== FIM MODULO 3.1: DE GERENCIAMENTO DE JANELAS ==//

  //== INICIO MODULO 3.2: CONSTRUÇÃO DA INTERFACE PRINCIPAL ==//

  @override
  Widget build(BuildContext context) {
    // Constrói a interface do widget DashboardPage
    return Scaffold(
      // Cria um Scaffold que fornece a estrutura básica da interface do aplicativo
      body: Stack(
        children: [
          //== CAMADA 1 (FUNDO): O console de logs ocupando a tela inteira ==//

          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              controller: _scrollFundoController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Color(
                      0x808cffb2,
                    ), // Cinza escuro para ficar sutil ao fundo
                    fontFamily: 'CustomFontA',
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),

          //== CAMADA 2: Área de Trabalho (Wallpaper / Grid de Ícones) ==//
          Positioned(
            top: 45, // Começa logo abaixo da CAMADA 2 (Barra de Topo)
            bottom: 50, // Termina logo acima da CAMADA 3 (Barra de Tarefas)
            left: 0,
            right: 0,
            child: Container(
              // Vidro opaco escuro sobre o terminal de logs
              color: Colors.black.withValues(alpha: 0.60),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 20, // Espaço horizontal entre os ícones
                  runSpacing: 20, // Espaço vertical quando quebrar linha
                  children: [
                    // APP 1: Prompt (CMD) que permite enviar comandos brutos para o servidor //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['cmd'] = true;
                          _appsMinimizados['cmd'] = false;
                        });
                        _trazerParaFrente('cmd');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.terminal,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Prompt (CMD)',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // APP 2: Monitor de Logs Brutos //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['monitor'] = true;
                          _appsMinimizados['monitor'] = false;
                        });
                        _trazerParaFrente('monitor');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: const Color(0xFF39FF14)
                                    .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.monitor,
                              color: Color(0xFF39FF14),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Monitor de Logs',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // APP 3: Log Splitter que organiza visualmente os logs em categorias //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['logsplit'] = true;
                          _appsMinimizados['logsplit'] = false;
                        });
                        _trazerParaFrente('logsplit');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.filter_alt_outlined,
                              color: Colors.amberAccent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Log Splitter',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // APP 4: Zorkut envia mensagens globais e futuramente individuais em campos //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['zorkut'] = true;
                          _appsMinimizados['zorkut'] = false;
                        });
                        _trazerParaFrente('zorkut');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: const Color(0xFFD580FF)
                                    .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chat_bubble,
                              color: Color(0xFFD580FF),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Zorkut Chat',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // APP 5: Maps que mostra a posição dos jogadores e futuramente claims //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['maps'] = true;
                          _appsMinimizados['maps'] = false;
                        });
                        _trazerParaFrente('maps');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: const Color(0xFF00FFCC)
                                    .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.map,
                              color: Color(0xFF00FFCC),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sistema de Monitoramento por Satélite (Maps)',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          //== CAMADA 3: JANELAS FLUTUANTES DINÂMICAS (POR FOCO) ==//
          ..._ordemFoco.map((id) {
            if (id == 'cmd') {
              return _construirJanela(
                id: 'cmd',
                titulo: r'Z:\Dukes\System16\cmd.exe',
                corTema: Colors.grey,
                larguraJanela: 520,
                alturaJanela: 180,
                conteudo: CmdApp(
                  comandoController: _comandoController,
                  onEnviarComando: _enviarComandoDoPrompt,
                ),
              );
            } else if (id == 'monitor') {
              return _construirJanela(
                id: 'monitor',
                titulo: 'Monitor de Tráfego do Núcleo (Kernel)',
                conteudo: MonitorApp(
                  logs: _logs,
                  onLimparTela: () {
                    setState(() {
                      _logs.clear(); // <-- Apaga tudo da memória instantaneamente!
                    });
                  },
                ),
              );
            } else if (id == 'logsplit') {
              return _construirJanela(
                id: 'logsplit',
                titulo: 'LogSplit - Eventos Filtrados',
                corTema: Colors.amberAccent,
                larguraJanela: 550,
                alturaJanela: 350,
                conteudo: LogSplitApp(
                  logsSplit: _logsTratadosLogSplit, // <-- Sua lista de logs filtrados no main.dart
                  onLimparTela: () {
                    setState(() {
                      _logsTratadosLogSplit.clear(); // <-- Apaga tudo da memória instantaneamente!
                    });
                  },
                ),
              );
            } else if (id == 'zorkut') {
              return _construirJanela(
                id: 'zorkut',
                titulo: 'ZORKUT - Chat Global',
                corTema: const Color(0xFFD580FF),
                larguraJanela:
                    595, // Ajustado para dar folga para o painel de level/ping
                alturaJanela: 360,
                conteudo: ZorkutApp(
                  todosOsLogs: _logsTratadosLogSplit,
                  jogadoresZorkut: _jogadoresOnline, // <-- Passando a lista pura diretamente!
                  onEnviarMensagem: _enviarChatGlobalZorkut,

                  onPlayerClicado: (jogador) {
                    // Chamada de log segura em ambiente de desenvolvimento ou futura lógica de teletransporte/foco do mapa
                    debugPrint("Jogador clicado: ${jogador.nome}");
                  },
                ),
              );
            } else if (id == 'maps') {
              return _construirJanela(
                id: 'maps',
                titulo: 'Sistema de Monitoramento por Satélite (Maps)',
                corTema: const Color(0xFF00FFCC),
                larguraJanela: 640,
                alturaJanela: 440,
                conteudo: MapsApp(
                  playersOnline: _jogadoresOnline,
                  retangulosPve: retangulosPve, // <-- Passa os mesmos retângulos do seu main.dart!
                  tamanhoMundoInicial:
                      6144.0, // <-- Navezgane padrão (6144x6144)
                  onPlayerClicado: (jogador) {
                    debugPrint("Focar no jogador: ${jogador.nome}");
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          }),

          //== CAMADA 4: Seus menus e painéis flutuantes transparentes ==//
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                border: Border.all(
                  color: const Color(0xFF39FF14).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SD-DOS Server Manager (7 Days to Die)',
                    style: TextStyle(
                      color: Color(0xFF39FF14),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _conectado ? "PROXY ONLINE" : "PROXY OFFLINE",
                    style: TextStyle(
                      color: _conectado ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          //== CAMADA 5 (RODAPÉ): Nova Barra de Tarefas (Estilo SO) ==//
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF39FF14).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  // PROMPT (CMD)
                  Tooltip(
                    message: 'Prompt (CMD)',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['cmd'] == true &&
                              _appsMinimizados['cmd'] == false) {
                            _appsMinimizados['cmd'] = true;
                          } else {
                            _appsAbertos['cmd'] = true;
                            _appsMinimizados['cmd'] = false;
                            _trazerParaFrente('cmd');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['cmd'] == true
                              ? Colors.grey.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['cmd'] == true
                                ? Colors.grey
                                : Colors.white24,
                            width: _appsAbertos['cmd'] == true ? 1.2 : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.terminal_outlined,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // MONITOR DE LOGS BRUTOS
                  Tooltip(
                    message: 'Monitor',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['monitor'] == true &&
                              _appsMinimizados['monitor'] == false) {
                            _appsMinimizados['monitor'] = true;
                          } else {
                            _appsAbertos['monitor'] = true;
                            _appsMinimizados['monitor'] = false;
                            _trazerParaFrente('monitor');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['monitor'] == true
                              ? const Color(0xFF39FF14).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['monitor'] == true
                                ? const Color(0xFF39FF14)
                                : Colors.white24,
                            width: _appsAbertos['monitor'] == true ? 1.2 : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.monitor,
                          color: Color(0xFF39FF14),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // LOG SPLITTER
                  Tooltip(
                    message: 'Log Splitter',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['logsplit'] == true &&
                              _appsMinimizados['logsplit'] == false) {
                            _appsMinimizados['logsplit'] = true;
                          } else {
                            _appsAbertos['logsplit'] = true;
                            _appsMinimizados['logsplit'] = false;
                            _trazerParaFrente('logsplit');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['logsplit'] == true
                              ? Colors.amberAccent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['logsplit'] == true
                                ? Colors.amberAccent
                                : Colors.white24,
                            width: _appsAbertos['logsplit'] == true ? 1.2 : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.filter_alt_outlined,
                          color: Colors.amberAccent,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  // ZORKUT CHAT
                  Tooltip(
                    message: 'Zorkut Chat',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['zorkut'] == true &&
                              _appsMinimizados['zorkut'] == false) {
                            _appsMinimizados['zorkut'] = true;
                          } else {
                            _appsAbertos['zorkut'] = true;
                            _appsMinimizados['zorkut'] = false;
                            _trazerParaFrente('zorkut');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['zorkut'] == true
                              ? const Color(0xFFD580FF).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['zorkut'] == true
                                ? const Color(0xFFD580FF)
                                : Colors.white24,
                            width: _appsAbertos['zorkut'] == true ? 1.2 : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFFD580FF),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  // MAPS
                  Tooltip(
                    message: 'Maps',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['maps'] == true &&
                              _appsMinimizados['maps'] == false) {
                            _appsMinimizados['maps'] = true;
                          } else {
                            _appsAbertos['maps'] = true;
                            _appsMinimizados['maps'] = false;
                            _trazerParaFrente('maps');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['maps'] == true
                              ? const Color(0xFF00FFCC).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['maps'] == true
                                ? const Color(0xFF00FFCC)
                                : Colors.white24,
                            width: _appsAbertos['maps'] == true ? 1.2 : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          color: Color(0xFF00FFCC),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Spacer(),

                  // ÁREA DE STATUS DO SISTEMA (Canto Direito do Rodapé)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Ícone Status do Script / Telnet 7D2D
                      Tooltip(
                        message: _scriptConectado
                            ? 'Script 7D2D: Recebendo logs'
                            : 'Script 7D2D: Sem resposta do Telnet',
                        child: Icon(
                          Icons.article_outlined,
                          size: 16,
                          color: _scriptConectado
                              ? const Color(0xFF39FF14)
                              : Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // 2. Ícone Status do Proxy (WebSocket)
                      Tooltip(
                        message: _conectado ? 'Proxy WebSocket: Conectado' : 'Proxy WebSocket: Desconectado (Verifique o Python)',
                        child: Icon(
                          Icons.account_tree_outlined,
                          size: 16,
                          color: _conectado
                              ? const Color(0xFF39FF14)
                              : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 3. Relógio Isolado (Atualiza a cada 15s sem redesenhar a tela toda)
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 15)),
                        builder: (context, _) {
                          final agora = DateTime.now();
                          final hora =
                              "${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
                          final data =
                              "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}";

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                hora,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'CustomFontA',
                                ),
                              ),
                              Text(
                                data,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                  fontFamily: 'CustomFontA',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  // Espaço reservado para novos aplicativos fixados futuramente...
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  //== FIM MODULO 3.2: CONSTRUÇÃO DA INTERFACE PRINCIPAL ==//
}
