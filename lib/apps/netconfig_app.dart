// lib/apps/netconfig_app.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class NetConfigApp extends StatefulWidget {
  final String ipInicial;
  final String portaInicial;
  final String tokenInicial;
  final bool conectado;
  final Future<void> Function({
    required String novoIp,
    required String novaPorta,
    required String novoToken,
  })
  onSalvarEConectar;

  const NetConfigApp({
    super.key,
    required this.ipInicial,
    required this.portaInicial,
    required this.tokenInicial,
    required this.conectado,
    required this.onSalvarEConectar,
  });

  @override
  State<NetConfigApp> createState() => _NetConfigAppState();
}

class _NetConfigAppState extends State<NetConfigApp> {
  static const Color _corFundo = Color(0xFF060D14);
  static const Color _corDestaque = Color(0xFF38BDF8); // Azul Ciano Rede
  static const Color _corInputFundo = Color(0xFF0D1B2A);

  int _abaAtual =
      0; // 0 = Conexão do Painel | 1 = Gerador de Scripts (.py/.bat)
  String _mensagemStatus = "";
  bool _erroStatus = false;
  bool _salvando = false;

  // Controladores da Aba 1 (Conexão do Painel)
  late TextEditingController _ipProxyController;
  late TextEditingController _portaProxyController;
  late TextEditingController _tokenProxyController;
  bool _ocultarIpProxy = true;
  bool _ocultarTokenProxy = true;

  // Controladores da Aba 2 (Gerador de Script Python e .BAT)
  final TextEditingController _sdtdHostController = TextEditingController(
    text: "127.0.0.1",
  );
  final TextEditingController _sdtdPortController = TextEditingController(
    text: "8081",
  );
  final TextEditingController _sdtdPassController = TextEditingController();
  final TextEditingController _wsHostController = TextEditingController(
    text: "0.0.0.0",
  );
  final TextEditingController _wsPortController = TextEditingController(
    text: "8082",
  );
  final TextEditingController _wsTokenController = TextEditingController();
  final TextEditingController _caminhoPastaBatController =
      TextEditingController(text: r"C:\SD-DOS-Proxy");
  final TextEditingController _nomeArquivoPyController = TextEditingController(
    text: "WebsocketsExample.py",
  );

  bool _usarCaminhoManualBat = false;
  bool _ocultarSdtdHost = true;
  bool _ocultarSdtdPass = true;
  bool _ocultarWsToken = true;

  @override
  void initState() {
    super.initState();
    _ipProxyController = TextEditingController(text: widget.ipInicial);
    _portaProxyController = TextEditingController(text: widget.portaInicial);
    _tokenProxyController = TextEditingController(text: widget.tokenInicial);

    // Espelha os dados iniciais na aba do gerador para facilitar
    _wsPortController.text = widget.portaInicial.isNotEmpty
        ? widget.portaInicial
        : "8082";
    _wsTokenController.text = widget.tokenInicial;
  }

  @override
  void dispose() {
    _ipProxyController.dispose();
    _portaProxyController.dispose();
    _tokenProxyController.dispose();
    _sdtdHostController.dispose();
    _sdtdPortController.dispose();
    _sdtdPassController.dispose();
    _wsHostController.dispose();
    _wsPortController.dispose();
    _wsTokenController.dispose();
    _caminhoPastaBatController.dispose();
    _nomeArquivoPyController.dispose();
    super.dispose();
  }

  void _exibirFeedback(String texto, {bool erro = false}) {
    setState(() {
      _mensagemStatus = texto;
      _erroStatus = erro;
    });
  }

  // Salva no SharedPreferences via main.dart e conecta
  Future<void> _salvarConfiguracaoPainel() async {
    if (_salvando) return; // Ignora cliques extras enquanto processa

    final ip = _ipProxyController.text.trim();
    final porta = _portaProxyController.text.trim();
    final token = _tokenProxyController.text.trim();

    if (ip.isEmpty || porta.isEmpty || token.isEmpty) {
      _exibirFeedback(
        "Preencha IP, Porta e Token antes de conectar.",
        erro: true,
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await widget.onSalvarEConectar(
        novoIp: ip,
        novaPorta: porta,
        novoToken: token,
      );
      _exibirFeedback("Configurações salvas! Tentando conectar ao Proxy...");
    } finally {
      // Libera o botão novamente após 800ms (debounce visual)
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  // Gera e salva o arquivo Python (.py)
  // Gera e salva o arquivo Python (.py) baseado no script oficial validado
  Future<void> _gerarArquivoPython() async {
    final sdtdHost = _sdtdHostController.text.trim();
    final sdtdPort = int.tryParse(_sdtdPortController.text.trim()) ?? 8081;
    final sdtdPass = _sdtdPassController.text.trim();
    final wsHost = _wsHostController.text.trim();
    final wsPort = int.tryParse(_wsPortController.text.trim()) ?? 8082;
    final wsToken = _wsTokenController.text.trim();
    final nomeArquivo = _nomeArquivoPyController.text.trim().isEmpty
        ? "WebsocketsExample.py"
        : _nomeArquivoPyController.text.trim();

    if (sdtdHost.isEmpty || sdtdPass.isEmpty || wsToken.isEmpty) {
      _exibirFeedback(
        "Preencha Host, Senha Telnet e Token WS para gerar o script.",
        erro: true,
      );
      return;
    }

    final conteudoPy =
        '''import asyncio
import websockets
from urllib.parse import urlparse, parse_qs

# --- CONFIGURAÇÕES DO JOGO (TELNET) ---
SDTD_HOST = "$sdtdHost"
SDTD_PORT = $sdtdPort
SDTD_PASSWORD = "$sdtdPass"

# --- CONFIGURAÇÕES DO SEU SERVIDOR WEBSOCKET (INTERFACE) ---
WS_HOST = "$wsHost"
WS_PORT = $wsPort
WS_TOKEN = "$wsToken"

# Variáveis globais para armazenar os fluxos da conexão com o jogo
jogo_reader = None
jogo_writer = None

# Lista de todas as interfaces (celulares, painéis) conectadas simultaneamente
interfaces_conectadas = set()

async def conectar_ao_jogo():
    """Tenta conectar ao Telnet do jogo e mantém a conexão viva, tratando o buffer de texto corretamente."""
    global jogo_reader, jogo_writer
    
    while True:
        try:
            print(f"[7DTD] Tentando conectar ao jogo em {SDTD_HOST}:{SDTD_PORT}...")
            jogo_reader, jogo_writer = await asyncio.open_connection(SDTD_HOST, SDTD_PORT)
            
            # Autenticação proativa
            jogo_writer.write((SDTD_PASSWORD + "\\r\\n").encode('utf-8'))
            await jogo_writer.drain()
            await asyncio.sleep(0.6)
            
            # Limpa o buffer de boas-vindas inicial do Telnet
            if not jogo_reader.at_eof():
                await jogo_reader.read(4096)
                
            # Ativa o streaming de logs em tempo real
            jogo_writer.write("logson\\r\\n".encode('utf-8'))
            await jogo_writer.drain()
            print("[7DTD] Conectado com sucesso e streaming de logs ativado!")
            
            buffer_residual = ""
            
            # Loop de leitura robusto para capturar linhas completas
            while True:
                dados = await jogo_reader.read(4096)
                if not dados:
                    break # Conexão caiu
                
                buffer_residual += dados.decode('utf-8', errors='ignore')
                linhas = buffer_residual.split("\\n")
                
                buffer_residual = linhas.pop()
                
                for linha_completa in linhas:
                    linha_limpa = linha_completa.strip()
                    if linha_limpa and interfaces_conectadas:
                        # Transmite em paralelo para todos os ADMs conectados do mundo
                        await asyncio.gather(
                            *[asyncio.create_task(cliente.send(linha_limpa)) for cliente in interfaces_conectadas],
                            return_exceptions=True
                        )
                    
        except Exception as e:
            print(f"[⚠️ ERRO 7DTD] Conexão falhou ou caiu: {e}. Tentando novamente em 5 segundos...")
            
        if jogo_writer:
            jogo_writer.close()
            try:
                await jogo_writer.wait_closed()
            except Exception:
                pass
        await asyncio.sleep(5)

async def gerenciar_interface(websocket):
    """Gerencia uma nova interface que passou na validação de segurança (Compatível com websockets v13+)."""
    global jogo_writer
    
    # Acessa os parâmetros da URL de forma segura na versão nova da biblioteca
    url_info = urlparse(websocket.request.path)
    parametros = parse_qs(url_info.query)
    
    # Extrai a lista do token e pega o primeiro item dela
    lista_token = parametros.get("token", [None])
    token_recebido = lista_token[0]
    
    # Se o token for incorreto ou ausente, rejeita a conexão na hora
    if token_recebido != WS_TOKEN:
        print(f"[🔒 BLOQUEADO] Tentativa de conexão recusada. Token inválido ou ausente.")
        await websocket.close(code=4001, reason="Authentication failed: Invalid Token")
        return

    # Adiciona na lista de administradores ativos
    interfaces_conectadas.add(websocket)
    print(f"[WS] Nova interface AUTENTICADA conectada! Total de dispositivos: {len(interfaces_conectadas)}")
    
    try:
        async for mensagem in websocket:
            comando = mensagem.strip()
            
            if jogo_writer and not jogo_writer.is_closing():
                print(f"[WS -> JOGO] Comando injetado por ADM autenticado: {comando}")
                jogo_writer.write((comando + "\\r\\n").encode('utf-8'))
                await jogo_writer.drain()
            else:
                await websocket.send("Erro: O script principal não está conectado ao servidor do jogo no momento.")
                
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        if websocket in interfaces_conectadas:
            interfaces_conectadas.remove(websocket)
        print(f"[WS] Interface desconectada. Total restante: {len(interfaces_conectadas)}")

async def main():
    server = await websockets.serve(
        gerenciar_interface,
        WS_HOST,
        WS_PORT,
        ping_interval=10,
        ping_timeout=5,
    )
    print(f"[WS Server] Ouvindo conexões de interfaces na porta {WS_PORT} com segurança ativa...")
    
    asyncio.create_task(conectar_ao_jogo())
    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\\n[Proxy] Finalizado pelo administrador.")
''';

    final uriDestino = await FilePicker.saveFile(
      dialogTitle: 'Salvar Script Python do Proxy',
      fileName: nomeArquivo.endsWith('.py') ? nomeArquivo : '$nomeArquivo.py',
      bytes: utf8.encode(conteudoPy),
    );

    if (uriDestino != null) {
      _exibirFeedback("Script Python salvo com sucesso!");
    }
  }

  // Gera e salva o inicializador Windows (.bat)
  // Gera e salva o inicializador Windows (.bat)
  Future<void> _gerarArquivoBat() async {
    final nomePy = _nomeArquivoPyController.text.trim().isEmpty
        ? "WebsocketsExample.py"
        : _nomeArquivoPyController.text.trim();
    final nomePyFinal = nomePy.endsWith('.py') ? nomePy : '$nomePy.py';

    String blocoDiretorio = "";

    if (_usarCaminhoManualBat) {
      final pasta = _caminhoPastaBatController.text.trim();
      if (pasta.isEmpty) {
        _exibirFeedback(
          "Informe o caminho da pasta ou desmarque o caminho manual.",
          erro: true,
        );
        return;
      }

      // Extrai a letra do drive (ex: "C:" ou "D:") se o caminho começar com ela
      String comandoDrive = "";
      if (pasta.length >= 2 && pasta[1] == ':') {
        comandoDrive = "${pasta.substring(0, 2)}\n";
      }
      blocoDiretorio = '${comandoDrive}cd /d "$pasta"';
    } else {
      // %~dp0 aponta automaticamente para a pasta onde o arquivo .bat está localizado
      blocoDiretorio = 'cd /d "%~dp0"';
    }

    final conteudoBat =
        '''@echo off
title SD-DOS WebSocket Proxy Bridge
color 0A
$blocoDiretorio
echo Iniciando ponte WebSocket para 7 Days to Die...
python "$nomePyFinal"
pause
''';

    final uriDestino = await FilePicker.saveFile(
      dialogTitle: 'Salvar Inicializador Windows (.bat)',
      fileName: 'IniciarProxy_SDDOS.bat',
      bytes: utf8.encode(conteudoBat),
    );

    if (uriDestino != null) {
      _exibirFeedback("Arquivo .BAT salvo com sucesso!");
    }
  }

  Widget _buildIconeAjuda({required String titulo, required String mensagem}) {
    return Tooltip(
      // No Desktop, mostra a dica rápida ao passar o mouse
      message: mensagem,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _corDestaque.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // No Mobile (ou ao clicar no PC), abre uma janela confortável para ler tudo
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _corDestaque.withValues(alpha: 0.5)),
              ),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: _corDestaque, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        color: _corDestaque,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                mensagem,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "ENTENDI",
                    style: TextStyle(
                      color: _corDestaque,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.help_outline,
            size: 15,
            color: _corDestaque.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _corFundo,
      child: Column(
        children: [
          // BARRA SUPERIOR DE ABAS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _corInputFundo,
              border: Border(
                bottom: BorderSide(color: _corDestaque.withValues(alpha: 0.25)),
              ),
            ),
            child: Row(
              children: [
                _buildBotaoAba(
                  indice: 0,
                  icone: Icons.settings_ethernet,
                  titulo: "1. Conexão do Painel",
                ),
                const SizedBox(width: 8),
                _buildBotaoAba(
                  indice: 1,
                  icone: Icons.build_circle_outlined,
                  titulo: "2. Gerar Script (.py / .bat)",
                ),
                const Spacer(),
                // Indicador de status da rede
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.conectado
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.conectado
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.conectado ? "ONLINE" : "OFFLINE",
                    style: TextStyle(
                      color: widget.conectado
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // CONTEÚDO DA ABA SELECIONADA
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: _abaAtual == 0
                  ? _buildAbaConexaoPainel()
                  : _buildAbaGeradorScripts(),
            ),
          ),
          // RODAPÉ DE FEEDBACK VISUAL
          if (_mensagemStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _erroStatus
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : Colors.greenAccent.withValues(alpha: 0.15),
              child: Text(
                _mensagemStatus,
                style: TextStyle(
                  color: _erroStatus ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 11,
                  fontFamily: 'CustomFontA',
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ABA 1: Configuração local de conexão com o Proxy
  Widget _buildAbaConexaoPainel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "PARÂMETROS DE REDE TCP/IP (PROXY WEBSOCKET)",
              style: TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            _buildIconeAjuda(
              titulo: "Conectar interface ao Proxy Websocket",
              mensagem:
                  "• Digite o IP onde esta o Script Proxy Websocket.\n"
                  "• Pode não ser o mesmo IP do servidor de jogo.\n"
                  "• 127.0.0.1 se estiver no mesmo computador,\n"
                  "• 192.168.(...) em rede local fixo no roteador,\n"
                  "• IP externo requer redirecionamento de porta.\n"
                  "• Digite o porta configurada no Script Websocket.\n"
                  "• Digite o token configurado no Script Websocket.",
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildCampoTexto(
                controller: _ipProxyController,
                label: "IP do Proxy (Ex: 127.0.0.1)",
                oculto: _ocultarIpProxy,
                onAlternarVisibilidade: () =>
                    setState(() => _ocultarIpProxy = !_ocultarIpProxy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: _buildCampoTexto(
                controller: _portaProxyController,
                label: "Porta WS",
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCampoTexto(
          controller: _tokenProxyController,
          label: "Token Secreto de Acesso (WS_TOKEN)",
          oculto: _ocultarTokenProxy,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarTokenProxy = !_ocultarTokenProxy),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _corDestaque,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: _salvando ? null : _salvarConfiguracaoPainel,
            icon: _salvando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_alt, size: 16),
            label: Text(
              _salvando ? "CONECTANDO..." : "SALVAR E CONECTAR AO PROXY",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  // ABA 2: Gerador de arquivos .py e .bat prontos para o servidor
  Widget _buildAbaGeradorScripts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "1. CONFIGURAÇÃO DO TELNET (7 DAYS TO DIE)",
              style: TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: "Conectar o script ao servidor de jogo",
              mensagem:
                  "• Digite o IP do servidor que o script deve se conectar.\n"
                  "• 127.0.0.1 (localhost) se estiver no mesmo computador,\n"
                  "• 192.168.(...) em rede local fixe pelo roteador,\n"
                  "• IP externo requer redirecionamento de porta.\n"
                  "• Verifique serverconfig.xml ou sdtdserver.xml no servidor.\n"
                  "• Certifique-se de que TelnetEnabled está como true.\n"
                  "• Configure TelnetPort(Porta) e TelnetPassword(Senha).\n"
                  "• Senha longa com letras, números e caracteres especiais.\n"
                  "• Não é a senha do painel web, é a senha do Telnet.",
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildCampoTexto(
                controller: _sdtdHostController,
                label: "IP do Servidor 7D2D",
                oculto: _ocultarSdtdHost,
                onAlternarVisibilidade: () =>
                    setState(() => _ocultarSdtdHost = !_ocultarSdtdHost),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildCampoTexto(
                controller: _sdtdPortController,
                label: "Porta Telnet",
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _sdtdPassController,
          label: "Senha Telnet (serverconfig.xml ou sdtdserver.xml)",
          oculto: _ocultarSdtdPass,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarSdtdPass = !_ocultarSdtdPass),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              "2. CONFIGURAÇÃO DA PONTE WEBSOCKET",
              style: TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: "Configuração da Ponte Websocket",
              mensagem:
                  "• IP que o SCRIPT deve autorizar (não é o servidor).\n"
                  "• 127.0.0.1 (localhost) se estiver no mesmo computador,\n"
                  "• IP fixo local ou externo se quiser acesso restrito,\n"
                  "• 0.0.0.0 pra acessar de qualquer IP, interno ou externo.\n"
                  "• IP externo requer redirecionamento de porta.\n"
                  "• Não é o mesmo IP que você digita na interface.\n"
                  "• Na interface vai apontar o IP do script.\n"
                  "• Porta WS (ex: 8082), pode requerer redirecionamento.\n"
                  "• Crie aqui um Token de autenticação para a conexão.\n"
                  "• Senha longa com letras, números e caracteres especiais.",
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildCampoTexto(
                controller: _wsHostController,
                label: "Escutas autorizadas WS (0.0.0.0 ou 127.0.0.1 ou fixo)",
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildCampoTexto(
                controller: _wsPortController,
                label: "Porta WS",
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _wsTokenController,
          label: "Crie um Token de Autenticação (WS_TOKEN)",
          oculto: _ocultarWsToken,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarWsToken = !_ocultarWsToken),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              "3. CONFIGURAÇÃO DO INICIALIZADOR (.BAT)",
              style: TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: "Gerar arquivo .BAT para iniciar o script",
              mensagem:
                  "• O arquivo .BAT é um atalho para iniciar o script Python.\n"
                  "• Por padrão, ele procura o script na mesma pasta do .BAT.\n"
                  "• Se o script estiver em outra pasta, marque a opção e informe o caminho.\n"
                  "• O nome do arquivo Python deve corresponder ao que você salvou.\n"
                  "• Exemplo de nome: WebsocketsExample.py\n"
                  "• O .BAT facilita a execução sem precisar abrir o terminal.",
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _nomeArquivoPyController,
          label: "Nome do arquivo Python (.py)",
        ),
        const SizedBox(height: 6),

        // Seletor: Mesma pasta do script (padrão) vs Caminho manual
        InkWell(
          onTap: () =>
              setState(() => _usarCaminhoManualBat = !_usarCaminhoManualBat),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _usarCaminhoManualBat,
                    activeColor: _corDestaque,
                    checkColor: Colors.black,
                    side: BorderSide(
                      color: _corDestaque.withValues(alpha: 0.6),
                    ),
                    onChanged: (valor) {
                      setState(() => _usarCaminhoManualBat = valor ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _usarCaminhoManualBat
                        ? "Só é necessário se o script python estiver em outra pasta"
                        : "Definir pasta manualmente (Por padrão reconhece na mesma pasta)",
                    style: TextStyle(
                      color: _usarCaminhoManualBat
                          ? Colors.amberAccent
                          : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Exibe o campo de pasta apenas se o usuário marcar o caminho manual
        if (_usarCaminhoManualBat) ...[
          const SizedBox(height: 8),
          _buildCampoTexto(
            controller: _caminhoPastaBatController,
            label: "Pasta onde o .py está salvo (Ex: C:\\SD-DOS-Proxy)",
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corDestaque,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: _gerarArquivoPython,
                icon: const Icon(Icons.code, size: 16),
                label: const Text(
                  "BAIXAR SCRIPT (.PY)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: _gerarArquivoBat,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text(
                  "BAIXAR ATALHO (.BAT)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotaoAba({
    required int indice,
    required IconData icone,
    required String titulo,
  }) {
    final ativo = _abaAtual == indice;
    return InkWell(
      onTap: () => setState(() {
        _abaAtual = indice;
        _mensagemStatus = "";
      }),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: ativo
              ? _corDestaque.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: ativo ? _corDestaque : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icone, size: 13, color: ativo ? _corDestaque : Colors.white54),
            const SizedBox(width: 5),
            Text(
              titulo,
              style: TextStyle(
                color: ativo ? _corDestaque : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    bool oculto = false,
    bool tecladoNumerico = false,
    VoidCallback? onAlternarVisibilidade,
  }) {
    return TextField(
      controller: controller,
      obscureText: oculto,
      keyboardType: tecladoNumerico ? TextInputType.number : TextInputType.text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'CustomFontA',
        fontSize: 12,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _corDestaque.withValues(alpha: 0.7),
          fontSize: 11,
        ),
        isDense: true,
        filled: true,
        fillColor: _corInputFundo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: _corDestaque.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: _corDestaque.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _corDestaque),
        ),
        suffixIcon: onAlternarVisibilidade != null
            ? IconButton(
                icon: Icon(
                  oculto ? Icons.visibility_off : Icons.visibility,
                  color: _corDestaque.withValues(alpha: 0.7),
                  size: 16,
                ),
                tooltip: oculto ? 'Mostrar valor' : 'Ocultar valor',
                onPressed: onAlternarVisibilidade,
              )
            : null,
      ),
    );
  }
}
