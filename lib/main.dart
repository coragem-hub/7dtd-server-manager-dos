import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd_dos_dart/models/log_token.dart';
import 'package:sd_dos_dart/apps/monitor_app.dart';
import 'package:sd_dos_dart/apps/cmd_app.dart';
import 'package:sd_dos_dart/apps/logsplit_app.dart';
import 'package:sd_dos_dart/apps/zorkut_app.dart';
import 'package:sd_dos_dart/apps/maps_app.dart';
import 'package:sd_dos_dart/apps/netconfig_app.dart';
import 'package:sd_dos_dart/models/jogador_status.dart';
import 'package:sd_dos_dart/services/player_storage_service.dart';
import 'package:sd_dos_dart/services/lang_service.dart';
import 'package:sd_dos_dart/services/web_sync_service.dart';

import 'dart:math';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LangService.instance.inicializar();
  runApp(const SdDOSManager());
}

class SdDOSManager extends StatelessWidget {
  const SdDOSManager({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LangService.instance,
      builder: (context, _) {
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
      },
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
  String ipProxy = "";
  String portaProxy = "8082";
  String token = "";

  // Variáveis para gerenciar a conexão WebSocket
  WebSocketChannel? _channel;
  bool _conectado = false;
  bool _scriptConectado =
      false; // Fica true assim que receber a primeira linha do servidor
  Timer? _timerReconexao;

  Timer? _timerLp;
  int _idTentativaConexao = 0;

  // Se você já tiver um Timer para o loop de 'lp' (ex: Timer? _timerLp;), garanta que ele também seja cancelado abaixo.

  //== INICIO MODULO 1: LISTAS, CONSTANTES, VARIÁVEIS E LOOPS ==//

  String nomeBot = "BotAdm";
  final List<String> _logs =
      []; // Lista mestre de texto bruto do console do servidor
  final List<LogToken> _logsTratadosLogSplit = [];
  static const int _limiteMaximoLogs = 1000;
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
    // Evita iniciar dois ciclos simultâneos.
    _timerLp?.cancel();
    _timerLp = null;

    _executarCicloLp();
  }

  // Executa um ciclo e agenda o próximo.
  void _executarCicloLp() {
    final canal = _channel;

    // Não executa se não houver conexão ativa.
    if (!mounted || !_conectado || canal == null) return;

    // Envia o comando ao servidor.
    try {
      canal.sink.add('lp');
    } catch (_) {
      return;
    }

    // Sorteia o próximo intervalo: entre 10 e 30 segundos.
    final intervalo = Duration(milliseconds: 10000 + _random.nextInt(20000));

    // Agenda o próximo ciclo.
    _timerLp = Timer(intervalo, () {
      // Confere se ainda estamos usando a mesma conexão.
      if (!mounted || !_conectado || !identical(_channel, canal)) {
        return;
      }

      _executarCicloLp();
    });
  }

  final RegExp _lpRegex = RegExp(
    r'id=(\d+),\s+([^,]+),\s+pos=\(([-\d.]+),\s+([-\d.]+),\s+([-\d.]+)\).*health=(\d+).*deaths=(\d+).*level=(\d+).*pltfmid=([^,]+).*ping=(\d+)',
  );

  //== FINAL MODULO 1: LISTAS, CONSTANTES, VARIÁVEIS E LOOPS ==//

  //== INICIO MODULO 2.1: FUNÇÕES DE CONEXÃO COM O PROXY ==//

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoesEConectar();
  }

  // Lê as credenciais salvas antes de tentar abrir o WebSocket
  Future<void> _carregarConfiguracoesEConectar() async {
    await PlayerStorageService.instance.carregarDoDisco();
    await WebSyncService.instance.carregarConfiguracoes();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ipProxy = prefs.getString('proxy_ip') ?? "";
      portaProxy = prefs.getString('proxy_porta') ?? "8082";
      token = prefs.getString('proxy_token') ?? "";
      nomeBot = prefs.getString('bot_name') ?? "BotAdm";
      _jogadoresHistorico.clear();
      _jogadoresHistorico.addAll(PlayerStorageService.instance.todosJogadores);
    });

    if (ipProxy.isEmpty || token.isEmpty) {
      setState(() {
        _logs.add(tr('system_logs.no_network_config'));
        _logs.add(tr('system_logs.open_netconfig_hint'));
        // Já abre a janela de configurações de rede automaticamente no primeiro uso
        _appsAbertos['netconfig'] = true;
        _appsMinimizados['netconfig'] = false;
      });
      _trazerParaFrente('netconfig');
      return;
    }
    _conectarAoProxy();
  }

  Future<void> _alterarNomeBot(String novoNome) async {
    final limpo = novoNome.trim();
    if (limpo.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bot_name', limpo);
    setState(() {
      nomeBot = limpo;
    });
  }

  // Função chamada pelo app NetConfig ao clicar em "Salvar e Conectar"
  Future<void> _salvarEReconectarProxy({
    required String novoIp,
    required String novaPorta,
    required String novoToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('proxy_ip', novoIp.trim());
    await prefs.setString('proxy_porta', novaPorta.trim());
    await prefs.setString('proxy_token', novoToken.trim());

    setState(() {
      ipProxy = novoIp.trim();
      portaProxy = novaPorta.trim();
      token = novoToken.trim();
      _adicionarLogBruto(tr('system_logs.config_saved'));
    });

    _conectarAoProxy();
  }

  // Função auxiliar para centralizar a reconexão segura
  void _tratarDesconexao(String mensagemErro) {
    if (ipProxy.isEmpty || token.isEmpty) return;

    if (_timerReconexao != null && _timerReconexao!.isActive) {
      return;
    }

    _timerLp?.cancel();
    _timerLp = null;
    // Atualiza o estado para indicar que a conexão foi perdida e tenta reconectar após 5 segundos
    setState(() {
      _conectado = false;
      _scriptConectado = false;
      _adicionarLogBruto(
        tr('system_logs.disconnected', args: {'reason': mensagemErro}),
      );
    });

    _timerReconexao = Timer(const Duration(seconds: 5), () {
      _conectarAoProxy();
    });
  }

  @override
  void dispose() {
    _timerReconexao?.cancel(); // <-- Adicione apenas esta linha aqui
    _timerLp?.cancel(); // <-- Adicione apenas esta linha aqui

    // Fecha o canal WebSocket e libera os recursos dos controladores
    _channel?.sink.close();
    _channel = null;
    _comandoController.dispose();

    // Libera os novos controladores de rolagem independentes
    _scrollFundoController.dispose();
    super.dispose();

    PlayerStorageService.instance.salvarImediatamente();
    WebSyncService.instance.pararSincronizacao();
  }

  //== FIM MODULO 2.1: FUNÇÕES DE CONEXÃO COM O PROXY ==//

  //== INICIO MODULO 2.2: CONEXÃO E TRATAMENTO DE LOGS BRUTOS==//

  void _conectarAoProxy() async {
    // 1. Incrementa o ID desta tentativa. Qualquer tentativa anterior em 'await' será invalidada.
    final int tentativaAtual = ++_idTentativaConexao;

    // 2. Cancela timers ativos imediatamente
    _timerLp?.cancel();
    _timerLp = null;
    _timerReconexao?.cancel();
    _timerReconexao = null;

    // 3. Fecha o canal anterior de forma limpa (sem parâmetros para não travar)
    final canalAntigo = _channel;
    _channel = null;
    if (canalAntigo != null) {
      try {
        canalAntigo.sink.close();
      } catch (_) {}
    }

    if (ipProxy.isEmpty || token.isEmpty) return;

    setState(() {
      _conectado = false;
      _scriptConectado = false;
      _adicionarLogBruto(tr('system_logs.connecting'));
    });

    try {
      final url = 'ws://$ipProxy:$portaProxy/?token=$token';
      final channel = WebSocketChannel.connect(Uri.parse(url));

      // Aguarda o handshake terminar
      await channel.ready;

      // VERIFICAÇÃO CRÍTICA: Se o usuário clicou de novo enquanto este 'await' rodava,
      // aborta esta conexão obsoleta imediatamente!
      if (!mounted || tentativaAtual != _idTentativaConexao) {
        try {
          channel.sink.close();
        } catch (_) {}
        return;
      }

      _channel = channel;

      setState(() {
        _conectado = true;
        _adicionarLogBruto(tr('system_logs.connected'));
      });

      _iniciarLoopRastreamentoAleatorio();

      final canalAtual = channel;

      canalAtual.stream.listen(
        (mensagem) {
          if (_channel != canalAtual || tentativaAtual != _idTentativaConexao) {
            return;
          }

          if (!_scriptConectado) setState(() => _scriptConectado = true);
          final linhaBruta = mensagem.toString();

          // 1. Tratamento: Identificando os tipos de Logs
          LogToken tokenTratado;

          // REGRA 1: Se for o início do comando 'lp', limpamos a lista temporária e incrementamos o ciclo
          if (linhaBruta.contains("Executing command 'lp'")) {
            _jogadoresOnline.clear();
            _contadorCiclosLp++;
          }

          // DESCARTE SILENCIOSO: Eco do comando 'say' disparado pelo próprio servidor
          // Vai apenas para o Monitor bruto (_logs) e não polui o LogSplit como [NT]
          if (linhaBruta.contains("INF Chat (") &&
              linhaBruta.contains("from '-non-player-'")) {
            setState(() {
              _adicionarLogBruto(linhaBruta);
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
            PlayerStorageService.instance.registrarOuAtualizar(novoJogador);

            final jogadorAntigo =
                _jogadoresHistorico.any((j) => j.id == novoJogador.id)
                ? _jogadoresHistorico.firstWhere((j) => j.id == novoJogador.id)
                : null;

            if (jogadorAntigo == null ||
                jogadorAntigo.zonaAtual != zonaCalculada) {
              if (zonaCalculada == "PVP") {
                enviarMensagemHub(
                  comandoBruto:
                      'pm "${novoJogador.nome}" "${tr('automation.pvp_warning_pm', args: {'bot': nomeBot})}"',
                  tagExibicao: "[PM]",
                  textoLimpo: tr(
                    'automation.pvp_log_sent',
                    args: {'bot': nomeBot, 'player': novoJogador.nome},
                  ),
                  corLabel: Colors.purpleAccent,
                );
              } else if (jogadorAntigo != null &&
                  jogadorAntigo.zonaAtual == "PVP" &&
                  zonaCalculada == "PVE") {
                enviarMensagemHub(
                  comandoBruto:
                      'pm "${novoJogador.nome}" "${tr('automation.pve_warning_pm', args: {'bot': nomeBot})}"',
                  tagExibicao: "[PM]",
                  textoLimpo: tr(
                    'automation.pve_log_sent',
                    args: {'bot': nomeBot, 'player': novoJogador.nome},
                  ),
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
              _adicionarLogSplit(tokenLP);
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
              mensagemLimpa: tr(
                'tray_and_logs.lp_cycle_summary',
                args: {
                  'summary': resumoTotal,
                  'cycle': '$_contadorCiclosLp',
                  'time': horaFormatada,
                },
              ),
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
              !linhaBruta.contains("sayadmin [39FF14]$nomeBot[-] 99")) {
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
            _adicionarLogBruto(linhaBruta);
            // Alimenta a torneira do logsplit.exe com o objeto já processado
            _adicionarLogSplit(tokenTratado);
          });
          _scrollParaOFinal();
        },

        onDone: () {
          if (_channel != canalAtual) {
            return; // Ignora o fechamento de conexões antigas
          }
          _tratarDesconexao("Conexão encerrada pelo servidor");
        },
        onError: (erro) {
          if (_channel != canalAtual) {
            return; // Ignora erros de conexões antigas
          }
          _tratarDesconexao("Erro de rede: $erro");
        },
      );
    } catch (e) {
      if (tentativaAtual != _idTentativaConexao) return;
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
        tr('tray_and_logs.cmd_prefix', args: {'cmd': comandoLimpo}),
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
    if (msg.startsWith('say "') && msg.endsWith('"')) {
      final textoPuro = msg.substring(5, msg.length - 1);
      enviarMensagemHub(
        comandoBruto: msg,
        tagExibicao: "[CHAT]",
        textoLimpo: "Server: $textoPuro",
        corLabel: const Color(0xFF39FF14),
      );
    } else {
      enviarMensagemHub(
        comandoBruto: 'sayadmin [39FF14]$nomeBot[-] 99 "$msg"',
        tagExibicao: "[MSG]",
        textoLimpo: "$nomeBot: $msg",
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
        _adicionarLogSplit(novoToken);
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
                          _trazerParaFrente(id); // <-- CORREÇÃO 2: Traz para frente quando o arrasto realmente inicia
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
    'netconfig': false,
  };
  // Ordem de foco das janelas (Stack)
  final List<String> _ordemFoco = [
    'cmd',
    'monitor',
    'logsplit',
    'zorkut',
    'maps',
    'netconfig',
  ];
  // Controla quais aplicativos estão minimizados
  final Map<String, bool> _appsMinimizados = {
    'cmd': false,
    'monitor': false,
    'logsplit': false,
    'zorkut': false,
    'maps': false,
    'netconfig': false,
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
    'cmd': ValueNotifier(const Offset(0, 180)),
    'monitor': ValueNotifier(const Offset(50, 180)),
    'logsplit': ValueNotifier(const Offset(100, 180)),
    'zorkut': ValueNotifier(const Offset(150, 180)),
    'maps': ValueNotifier(const Offset(200, 180)),
    'netconfig': ValueNotifier(const Offset(250, 180)),
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

  void _adicionarLogBruto(String linha) {
    _logs.add(linha);
    if (_logs.length > _limiteMaximoLogs) {
      // Remove o excesso do início da lista de uma só vez (muito mais rápido que removeAt(0))
      _logs.removeRange(0, _logs.length - _limiteMaximoLogs);
    }
  }

  void _adicionarLogSplit(LogToken token) {
    _logsTratadosLogSplit.add(token);
    if (_logsTratadosLogSplit.length > _limiteMaximoLogs) {
      _logsTratadosLogSplit.removeRange(
        0,
        _logsTratadosLogSplit.length - _limiteMaximoLogs,
      );
    }
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
              scrollCacheExtent: const ScrollCacheExtent.pixels(200),
              addAutomaticKeepAlives: false,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x808cffb2),
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
                            padding: const EdgeInsets.all(20),
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
                          const SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              'Prompt (CMD)',
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
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
                            width: 72, // Fixa a largura exata (20 + 32 + 20)
                            height: 72,
                            alignment: Alignment.center,
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
                          SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              tr('desktop.monitor'),
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
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
                            padding: const EdgeInsets.all(20),
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
                          const SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              'Log Splitter',
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
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
                            padding: const EdgeInsets.all(20),
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
                          const SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              'Zorkut Chat',
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
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
                            padding: const EdgeInsets.all(20),
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
                          const SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              'Maps',
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // APP 6: NetConfig (Configurações de Rede e Gerador de Proxy) //
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _appsAbertos['netconfig'] = true;
                          _appsMinimizados['netconfig'] = false;
                        });
                        _trazerParaFrente('netconfig');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.settings_ethernet,
                              color: Color(0xFF38BDF8),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(
                            width:
                                72, // Trava a largura do texto igual à do ícone
                            child: Text(
                              'NetConfig',
                              textAlign: TextAlign.center, // Centraliza o texto
                              maxLines: 2, // Permite quebrar em até 2 linhas
                              overflow: TextOverflow.ellipsis, // Adiciona "..." se passar de 2 linhas
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
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
                titulo: tr('windows.monitor_title'),
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
                titulo: tr('windows.logsplit_title'),
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
                titulo: tr('windows.zorkut_title'),
                corTema: const Color(0xFFD580FF),
                larguraJanela:
                    595, // Ajustado para dar folga para o painel de level/ping
                alturaJanela: 360,
                conteudo: ZorkutApp(
                  todosOsLogs: _logsTratadosLogSplit,
                  jogadoresZorkut: _jogadoresOnline,
                  historicoJogadores: _jogadoresHistorico,
                  nomeBot: nomeBot,
                  onAlterarNomeBot: _alterarNomeBot,
                  onEnviarMensagem: _enviarChatGlobalZorkut,
                ),
              );
            } else if (id == 'maps') {
              return _construirJanela(
                id: 'maps',
                titulo: tr('windows.maps_title'),
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
            } else if (id == 'netconfig') {
              return _construirJanela(
                id: 'netconfig',
                titulo: tr('windows.netconfig_title'),
                corTema: const Color(0xFF38BDF8),
                larguraJanela: 520,
                alturaJanela: 520,
                conteudo: NetConfigApp(
                  totalJogadoresOnline: _jogadoresOnline.length,
                  ipInicial: ipProxy,
                  portaInicial: portaProxy,
                  tokenInicial: token,
                  conectado: _conectado,
                  onSalvarEConectar: _salvarEReconectarProxy,
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
              padding: const EdgeInsets.all(
                5,
              ), // Adiciona preenchimento interno ao container
              decoration: BoxDecoration(
                // Preto com 75% de opacidade (Efeito translúcido)
                color: Colors.black.withValues(alpha: 0.75),
                border: Border.all(
                  color: const Color(0xFF39FF14).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('topbar.title'),
                    style: const TextStyle(
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
                  // EXEMPLO: Botão da Barra de Tarefas (Monitor)
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
                          // Fundo acende levemente se o app estiver aberto (mesmo minimizado)
                          color: _appsAbertos['monitor'] == true
                              ? const Color(0xFF39FF14).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            // Borda brilhante se aberto, discreta se fechado
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
                  // NETCONFIG
                  Tooltip(
                    message: 'NetConfig',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_appsAbertos['netconfig'] == true &&
                              _appsMinimizados['netconfig'] == false) {
                            _appsMinimizados['netconfig'] = true;
                          } else {
                            _appsAbertos['netconfig'] = true;
                            _appsMinimizados['netconfig'] = false;
                            _trazerParaFrente('netconfig');
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 38,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _appsAbertos['netconfig'] == true
                              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _appsAbertos['netconfig'] == true
                                ? const Color(0xFF38BDF8)
                                : Colors.white24,
                            width: _appsAbertos['netconfig'] == true
                                ? 1.2
                                : 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_ethernet,
                          color: Color(0xFF38BDF8),
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
                      // 0. Seletor de Idioma estilo Bandeja do Windows (POR / BRA)
                      PopupMenuButton<String>(
                        tooltip: tr('tray_and_logs.tooltip_language'),
                        color: const Color(0xFF141414),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: const Color(0xFF39FF14)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        offset: const Offset(
                          0,
                          -95,
                        ), // Abre o menu para cima da barra de tarefas
                        onSelected: (novoCodigo) async {
                          await LangService.instance.mudarIdioma(novoCodigo);
                          setState(() {}); // <-- Força o DashboardPage e todas as janelas abertas a redesenharem na hora!
                        },
                        itemBuilder: (context) {
                          return LangService.idiomasDisponiveis.entries.map((
                            entry,
                          ) {
                            final selecionado =
                                entry.key == LangService.instance.idiomaAtual;
                            return PopupMenuItem<String>(
                              value: entry.key,
                              height: 34,
                              child: Row(
                                children: [
                                  Icon(
                                    selecionado
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 14,
                                    color: selecionado
                                        ? const Color(0xFF39FF14)
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: selecionado
                                          ? const Color(0xFF39FF14)
                                          : Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'CustomFontA',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                LangService.instance.siglaTopo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  fontFamily: 'CustomFontA',
                                ),
                              ),
                              Text(
                                LangService.instance.siglaBase,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  height: 1.1,
                                  fontFamily: 'CustomFontA',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 1. Ícone Status do Script / Telnet 7D2D
                      Tooltip(
                        message: _scriptConectado
                            ? tr('tray_and_logs.tooltip_script_on')
                            : tr('tray_and_logs.tooltip_script_off'),
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
                        message: _conectado
                            ? tr('tray_and_logs.tooltip_proxy_on')
                            : tr('tray_and_logs.tooltip_proxy_off'),
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
