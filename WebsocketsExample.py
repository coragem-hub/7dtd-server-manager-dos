import asyncio
import websockets
from urllib.parse import urlparse, parse_qs

# --- CONFIGURAÇÕES DO JOGO (TELNET) ---
SDTD_HOST = "<IP_DO_SEU_SERVIDOR>" # Endereço IP local ou externo
SDTD_PORT = <PORTA_DO_TELNET>  # Porta padrão do Telnet do 7 Days to Die é 8081 
SDTD_PASSWORD = "<SUA_SENHA_DO_TELNET>"  # Senha do Telnet do seu servidor 7DTD

# --- CONFIGURAÇÕES DO SEU SERVIDOR WEBSOCKET (INTERFACE) ---
WS_HOST = "<IP_DO_SEU_SERVIDOR_WEBSOCKET>"  # 0.0.0.0 pra aceitar conexões de qualquer IP, ou use o IP local/externo do seu servidor
WS_PORT = <PORTA_DO_WEBSOCKET>  # Porta que o seu script vai ouvir para conexões de interfaces (ex: 8082)
# Defina aqui a senha que as suas interfaces precisarão usar para conectar
WS_TOKEN = "<SUA_SENHA_DE_ACESSO_AO_WEBSOCKET>"  # Senha que as interfaces precisam fornecer para se conectar

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
            jogo_writer.write((SDTD_PASSWORD + "\r\n").encode('utf-8'))
            await jogo_writer.drain()
            await asyncio.sleep(0.6)
            
            # Limpa o buffer de boas-vindas inicial do Telnet
            if not jogo_reader.at_eof():
                await jogo_reader.read(4096)
                
            # Ativa o streaming de logs em tempo real
            jogo_writer.write("logson\r\n".encode('utf-8'))
            await jogo_writer.drain()
            print("[7DTD] Conectado com sucesso e streaming de logs ativado!")
            
            buffer_residual = ""
            
            # Loop de leitura robusto para capturar linhas completas
            while True:
                dados = await jogo_reader.read(4096)
                if not dados:
                    break # Conexão caiu
                
                buffer_residual += dados.decode('utf-8', errors='ignore')
                linhas = buffer_residual.split("\n")
                
                # CORREÇÃO AQUI: Removemos o operador := e separamos as ações de forma limpa
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
            # CORREÇÃO AQUI: Separado de forma simples e tradicional sem o operador :=
            comando = mensagem.strip()
            
            if jogo_writer and not jogo_writer.is_closing():
                print(f"[WS -> JOGO] Comando injetado por ADM autenticado: {comando}")
                jogo_writer.write((comando + "\r\n").encode('utf-8'))
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
    server = await websockets.serve(gerenciar_interface, WS_HOST, WS_PORT)
    print(f"[WS Server] Ouvindo conexões de interfaces na porta {WS_PORT} com segurança ativa...")
    
    asyncio.create_task(conectar_ao_jogo())
    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[Proxy] Finalizado pelo administrador.")
