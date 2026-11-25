// lib/apps/netconfig_app.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sd_dos_dart/services/lang_service.dart';
import 'package:sd_dos_dart/services/web_sync_service.dart';

class NetConfigApp extends StatefulWidget {
  final String ipInicial;
  final String portaInicial;
  final String tokenInicial;
  final bool conectado;
  final int totalJogadoresOnline;
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
    this.totalJogadoresOnline = 0,
    required this.onSalvarEConectar,
  });

  @override
  State<NetConfigApp> createState() => _NetConfigAppState();
}

class _NetConfigAppState extends State<NetConfigApp> {
  static const Color _corFundo = Color(0xFF060D14);
  static const Color _corDestaque = Color(0xFF38BDF8); // Azul Ciano Rede
  static const Color _corInputFundo = Color(0xFF0D1B2A);

  int _abaAtual = 0; // 0 = Painel | 1 = Scripts (.py/.bat) | 2 = Web Sync
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

  // Controladores da Aba 3 (Web Sync / Contador Site)
  late TextEditingController _webSyncUrlController;
  late TextEditingController _webSyncTokenController;
  bool _webSyncAtivo = false;
  bool _ocultarWebSyncToken = true;
  bool _testandoWebSync = false;

  @override
  void initState() {
    super.initState();
    _ipProxyController = TextEditingController(text: widget.ipInicial);
    _portaProxyController = TextEditingController(text: widget.portaInicial);
    _tokenProxyController = TextEditingController(text: widget.tokenInicial);

    _wsPortController.text = widget.portaInicial.isNotEmpty
        ? widget.portaInicial
        : "8082";
    _wsTokenController.text = widget.tokenInicial;

    // Carrega dados atuais do WebSyncService
    _webSyncAtivo = WebSyncService.instance.syncAtivo;
    _webSyncUrlController = TextEditingController(
      text: WebSyncService.instance.endpointUrl,
    );
    _webSyncTokenController = TextEditingController(
      text: WebSyncService.instance.apiKeyOuSecret,
    );
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
    _webSyncUrlController.dispose();
    _webSyncTokenController.dispose();
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
    if (_salvando) return;

    final ip = _ipProxyController.text.trim();
    final porta = _portaProxyController.text.trim();
    final token = _tokenProxyController.text.trim();

    if (ip.isEmpty || porta.isEmpty || token.isEmpty) {
      _exibirFeedback(tr('netconfig.feedback_fill_panel'), erro: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      await widget.onSalvarEConectar(
        novoIp: ip,
        novaPorta: porta,
        novoToken: token,
      );
      _exibirFeedback(tr('netconfig.feedback_connecting'));
    } finally {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  // Salva configurações do Web Sync
  Future<void> _salvarWebSync({bool testarAgora = false}) async {
    final url = _webSyncUrlController.text.trim();
    final token = _webSyncTokenController.text.trim();

    if ((_webSyncAtivo || testarAgora) && url.isEmpty) {
      _exibirFeedback(tr('netconfig.feedback_websync_url_missing'), erro: true);
      return;
    }

    await WebSyncService.instance.salvarConfiguracoes(
      ativo: _webSyncAtivo,
      url: url,
      token: token,
    );

    if (!testarAgora) {
      _exibirFeedback(
        _webSyncAtivo
            ? tr('netconfig.feedback_websync_saved_on')
            : tr('netconfig.feedback_websync_saved_off'),
      );
      return;
    }

    // Executa envio imediato para teste
    setState(() => _testandoWebSync = true);
    try {
      final bool estadoAnterior = WebSyncService.instance.syncAtivo;
      WebSyncService.instance.syncAtivo = true;

      final sucesso = await WebSyncService.instance.enviarDadosAgora(
        jogadoresOnlineAgora: widget.totalJogadoresOnline,
      );

      WebSyncService.instance.syncAtivo = estadoAnterior;

      if (sucesso) {
        _exibirFeedback(tr('netconfig.feedback_websync_test_ok'));
      } else {
        _exibirFeedback(tr('netconfig.feedback_websync_test_err'), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _testandoWebSync = false);
      }
    }
  }

  // Gera e salva o arquivo Python (.py)
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
      _exibirFeedback(tr('netconfig.feedback_fill_script'), erro: true);
      return;
    }

    final conteudoPy =
        '''import asyncio
import websockets
from urllib.parse import urlparse, parse_qs

# --- 7 DAYS TO DIE (TELNET) ---
SDTD_HOST = "$sdtdHost"
SDTD_PORT = $sdtdPort
SDTD_PASSWORD = "$sdtdPass"

# --- WEBSOCKET SERVER (UI BRIDGE) ---
WS_HOST = "$wsHost"
WS_PORT = $wsPort
WS_TOKEN = "$wsToken"

jogo_reader = None
jogo_writer = None
interfaces_conectadas = set()

async def conectar_ao_jogo():
    global jogo_reader, jogo_writer
    
    while True:
        try:
            print(f"${tr('proxy_script.py_connecting')}")
            jogo_reader, jogo_writer = await asyncio.open_connection(SDTD_HOST, SDTD_PORT)
            
            jogo_writer.write((SDTD_PASSWORD + "\\r\\n").encode('utf-8'))
            await jogo_writer.drain()
            await asyncio.sleep(0.6)
            
            if not jogo_reader.at_eof():
                await jogo_reader.read(4096)
                
            jogo_writer.write("logson\\r\\n".encode('utf-8'))
            await jogo_writer.drain()
            print("${tr('proxy_script.py_connected')}")
            
            buffer_residual = ""
            
            while True:
                dados = await jogo_reader.read(4096)
                if not dados:
                    break
                
                buffer_residual += dados.decode('utf-8', errors='ignore')
                linhas = buffer_residual.split("\\n")
                buffer_residual = linhas.pop()
                
                for linha_completa in linhas:
                    linha_limpa = linha_completa.strip()
                    if linha_limpa and interfaces_conectadas:
                        await asyncio.gather(
                            *[asyncio.create_task(cliente.send(linha_limpa)) for cliente in interfaces_conectadas],
                            return_exceptions=True
                        )
                    
        except Exception as e:
            print(f"${tr('proxy_script.py_conn_error')}")
            
        if jogo_writer:
            jogo_writer.close()
            try:
                await jogo_writer.wait_closed()
            except Exception:
                pass
        await asyncio.sleep(5)

async def gerenciar_interface(websocket):
    global jogo_writer
    
    url_info = urlparse(websocket.request.path)
    parametros = parse_qs(url_info.query)
    
    lista_token = parametros.get("token", [None])
    token_recebido = lista_token[0]
    
    if token_recebido != WS_TOKEN:
        print("${tr('proxy_script.py_blocked')}")
        await websocket.close(code=4001, reason="Authentication failed: Invalid Token")
return
interfaces_conectadas.add(websocket)
print(f"${tr('proxy_script.py_client_connected')}")
try:
async for mensagem in websocket:
comando = mensagem.strip()
if jogo_writer and not jogo_writer.is_closing():
print(f"${tr('proxy_script.py_cmd_injected')}")
jogo_writer.write((comando + "\r\n").encode('utf-8'))
await jogo_writer.drain()
else:
await websocket.send("${tr('proxy_script.py_err_not_connected')}")
except websockets.exceptions.ConnectionClosed:
pass
finally:
if websocket in interfaces_conectadas:
interfaces_conectadas.remove(websocket)
print(f"${tr('proxy_script.py_client_disconnected')}")
async def main():
server = await websockets.serve(
gerenciar_interface,
WS_HOST,
WS_PORT,
ping_interval=10,
ping_timeout=5,
)
print(f"${tr('proxy_script.py_listening')}")
asyncio.create_task(conectar_ao_jogo())
await server.wait_closed()
if name == "main":
try:
asyncio.run(main())
except KeyboardInterrupt:
print("\n${tr('proxy_script.py_stopped')}")
''';
    final uriDestino = await FilePicker.saveFile(
      dialogTitle: tr('netconfig.dialog_save_py'),
      fileName: nomeArquivo.endsWith('.py') ? nomeArquivo : '$nomeArquivo.py',
      bytes: utf8.encode(conteudoPy),
    );
    if (uriDestino != null) {
      _exibirFeedback(tr('netconfig.feedback_py_saved'));
    }
  }

  // Gera e salva o inicializador Windows (.bat)
  Future _gerarArquivoBat() async {
    final nomePy = _nomeArquivoPyController.text.trim().isEmpty
        ? "WebsocketsExample.py"
        : _nomeArquivoPyController.text.trim();
    final nomePyFinal = nomePy.endsWith('.py') ? nomePy : '$nomePy.py';
    String blocoDiretorio = "";
    if (_usarCaminhoManualBat) {
      final pasta = _caminhoPastaBatController.text.trim();
      if (pasta.isEmpty) {
        _exibirFeedback(
          tr('netconfig.feedback_bat_folder_missing'),
          erro: true,
        );
        return;
      }
      String comandoDrive = "";
      if (pasta.length >= 2 && pasta[1] == ':') {
        comandoDrive = "${pasta.substring(0, 2)}\n";
      }
      blocoDiretorio = '${comandoDrive}cd /d "$pasta"';
    } else {
      blocoDiretorio = 'cd /d "%~dp0"';
    }
    final conteudoBat =
        '''@echo off
title SD-DOS WebSocket Proxy Bridge
color 0A
$blocoDiretorio
echo ${tr('proxy_script.bat_starting')}
python "$nomePyFinal"
pause
''';
    final uriDestino = await FilePicker.saveFile(
      dialogTitle: tr('netconfig.dialog_save_bat'),
      fileName: 'IniciarProxy_SDDOS.bat',
      bytes: utf8.encode(conteudoBat),
    );
    if (uriDestino != null) {
      _exibirFeedback(tr('netconfig.feedback_bat_saved'));
    }
  }

  Widget _buildIconeAjuda({required String titulo, required String mensagem}) {
    return Tooltip(
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
                      style: const TextStyle(
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
                    tr('netconfig.btn_understood'),
                    style: const TextStyle(
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
                  titulo: tr('netconfig.tab_connection'),
                ),
                const SizedBox(width: 6),
                _buildBotaoAba(
                  indice: 1,
                  icone: Icons.build_circle_outlined,
                  titulo: tr('netconfig.tab_generator'),
                ),
                const SizedBox(width: 6),
                _buildBotaoAba(
                  indice: 2,
                  icone: Icons.cloud_upload_outlined,
                  titulo: tr('netconfig.tab_websync'),
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
                    widget.conectado
                        ? tr('netconfig.status_online')
                        : tr('netconfig.status_offline'),
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
                  : _abaAtual == 1
                  ? _buildAbaGeradorScripts()
                  : _buildAbaWebSync(),
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
            Text(
              tr('netconfig.sec_panel_title'),
              style: const TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            _buildIconeAjuda(
              titulo: tr('netconfig.help_panel_title'),
              mensagem: tr('netconfig.help_panel_body'),
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
                label: tr('netconfig.label_proxy_ip'),
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
                label: tr('netconfig.label_ws_port'),
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCampoTexto(
          controller: _tokenProxyController,
          label: tr('netconfig.label_ws_token'),
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
              _salvando
                  ? tr('netconfig.btn_connecting')
                  : tr('netconfig.btn_save_connect'),
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
            Text(
              tr('netconfig.sec_telnet_title'),
              style: const TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: tr('netconfig.help_telnet_title'),
              mensagem: tr('netconfig.help_telnet_body'),
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
                label: tr('netconfig.label_sdtd_ip'),
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
                label: tr('netconfig.label_telnet_port'),
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _sdtdPassController,
          label: tr('netconfig.label_telnet_pass'),
          oculto: _ocultarSdtdPass,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarSdtdPass = !_ocultarSdtdPass),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              tr('netconfig.sec_ws_title'),
              style: const TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: tr('netconfig.help_ws_title'),
              mensagem: tr('netconfig.help_ws_body'),
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
                label: tr('netconfig.label_ws_listen'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildCampoTexto(
                controller: _wsPortController,
                label: tr('netconfig.label_ws_port'),
                tecladoNumerico: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _wsTokenController,
          label: tr('netconfig.label_create_token'),
          oculto: _ocultarWsToken,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarWsToken = !_ocultarWsToken),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              tr('netconfig.sec_bat_title'),
              style: const TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _buildIconeAjuda(
              titulo: tr('netconfig.help_bat_title'),
              mensagem: tr('netconfig.help_bat_body'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCampoTexto(
          controller: _nomeArquivoPyController,
          label: tr('netconfig.label_py_filename'),
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
                        ? tr('netconfig.checkbox_manual_folder_on')
                        : tr('netconfig.checkbox_manual_folder_off'),
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
        if (_usarCaminhoManualBat) ...[
          const SizedBox(height: 8),
          _buildCampoTexto(
            controller: _caminhoPastaBatController,
            label: tr('netconfig.label_py_folder'),
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
                label: Text(
                  tr('netconfig.btn_download_py'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
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
                label: Text(
                  tr('netconfig.btn_download_bat'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ABA 3: Sincronização HTTP (Nuvem / Contadores do Site)
  Widget _buildAbaWebSync() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('netconfig.sec_websync_title'),
              style: TextStyle(
                color: _corDestaque,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            _buildIconeAjuda(
              titulo: tr('netconfig.help_websync_title'),
              mensagem: tr('netconfig.help_websync_body'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _corInputFundo,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _webSyncAtivo
                  ? const Color(0xFF39FF14).withValues(alpha: 0.5)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _webSyncAtivo
                    ? tr('netconfig.websync_active')
                    : tr('netconfig.websync_inactive'),
                style: TextStyle(
                  color: _webSyncAtivo
                      ? const Color(0xFF39FF14)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _webSyncAtivo,
                activeThumbColor: const Color(0xFF39FF14),
                onChanged: (valor) {
                  setState(() => _webSyncAtivo = valor);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCampoTexto(
          controller: _webSyncUrlController,
          label: tr('netconfig.label_websync_url'),
        ),
        const SizedBox(height: 12),
        _buildCampoTexto(
          controller: _webSyncTokenController,
          label: tr('netconfig.label_websync_token'),
          oculto: _ocultarWebSyncToken,
          onAlternarVisibilidade: () =>
              setState(() => _ocultarWebSyncToken = !_ocultarWebSyncToken),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corDestaque,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: () => _salvarWebSync(testarAgora: false),
                icon: const Icon(Icons.save_alt, size: 16),
                label: Text(
                  tr('netconfig.btn_save_websync'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF39FF14),
                  side: const BorderSide(color: Color(0xFF39FF14)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: _testandoWebSync
                    ? null
                    : () => _salvarWebSync(testarAgora: true),
                icon: _testandoWebSync
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF39FF14),
                        ),
                      )
                    : const Icon(Icons.cloud_upload, size: 16),
                label: Text(
                  _testandoWebSync
                      ? tr('netconfig.btn_testing_websync')
                      : tr('netconfig.btn_test_websync'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
            const SizedBox(width: 4),
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
                tooltip: oculto
                    ? tr('netconfig.tooltip_show')
                    : tr('netconfig.tooltip_hide'),
                onPressed: onAlternarVisibilidade,
              )
            : null,
      ),
    );
  }
}
