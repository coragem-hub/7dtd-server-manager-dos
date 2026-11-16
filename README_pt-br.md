# SD-DOS Server Manager (v1.0)

Gerenciador visual leve para servidores dedicados de **7 Days to Die**, inspirado em sistemas operacionais clássicos. Desenvolvido para oferecer controle automatizado de fronteiras PVP/PVE, monitoramento de logs e radar tático sem exigir configurações pesadas.

# Objetivo do projeto

Criar um ambiente visualmente amigavel pra gestão segura de servidores e editores de arquivos de jogo. Leve e com multiplas ferramentas. Que em sua versão final vai rodar em Computadores, navegadores e celulares android (sim, vai dar pra usar aquele processador ocioso do seu celular velho guardado na gaveta).

## Funcionalidades da v1.0
* **Maps:** Mapa interativo com zoom, visualização de zonas PVE configuráveis e rastreamento de jogadores em tempo real.
* **Automação PVP / PVE:** Envio automático de avisos privados quando um jogador cruza a fronteira entre biomas seguros e hostis.
* **Zorkut Chat:** Interface de chat global compatível tanto com comandos nativos (`say`) quanto com o mod Prisma Core (`sayadmin`).
* **Log Splitter & Monitor:** Filtragem inteligente de eventos do servidor (`[LP]`, `[CHAT]`, `[CMD]`, `[PC]`) com trava automática de rolagem.
* **Prompt (CMD):** Terminal integrado para execução rápida de comandos administrativos via Telnet.

## Funcionalidades planejadas para a próxima versão
* Gerador de scripts Websocket já configurado por meio de um novo aplicativo.
* Configuração de IP, porta e credenciais via interface, sem a necessidade de edição manual de arquivos.
* Primeiro executável (.exe) para Windows.

## Tecnologias Utilizadas
* **Frontend / Interface:** Flutter (Desktop)
* **Backend / Túnel Telnet:** Python (WebSockets)

## Instalação e Configuração (v1.0)

Antes de executar o gerenciador, preencha manualmente as credenciais do servidor e os parâmetros de rede nos arquivos do projeto. O gerenciador foi desenvolvido para usar um script Python que mantém a conexão com o servidor via telnet por meio de websockets. Use um arquivo .bat para execução com um clique no Windows.

## Lógica de execução

* O script pode rodar diretamente no servidor ou em outro computador. Com estabilidade e com custo minimo de processamento pois não não roda verificações e calculos complexos e com possibilidade de implementação de filtros de segurança.
* O gerenciador se conecta ao websocket apartir de qualquer computador sem precisar se conectar diretemente ao servidor, e permite multiplas conexões estaveis mesmo realizando verificalções, tratamentos e calculos complexos.
* Na prática você pode rodar tudo no mesmo computador, ou ter SERVIDOR, SCRIPT e multiplos GERENCIADORES em diferentes locais.
* Na versão atual, multiplas conexões ao telnet usando o gerenciador vão sobrecarregar o telnete devido a aplicação automatica de regras de tramento já configuradas. Mas vocês pode usar qualquer ferramenta de conexão websocket pra ler logins e enviar comandos usando o mesmo tipo de conexão e suas credenciais.

### 1. Ponte WebSocket em Python (`WebsocketsExample.py`)
Instale a biblioteca necessária:
```bash
pip install websockets
```

Abra o script Python e substitua os marcadores (`<...>`) pelos dados do seu servidor:
* **Configurações do Telnet do Jogo:**
  * `SDTD_HOST`: Endereço IP do servidor de 7 Days to Die (ex: `"127.0.0.1"`).
  * `SDTD_PORT`: Porta Telnet configurada no `serverconfig.xml` (padrão `8081`, número inteiro sem aspas).
  * `SDTD_PASSWORD`: Senha do Telnet do servidor.
* **Configurações do Servidor WebSocket (Interface):**
  * `WS_HOST`: Use `"0.0.0.0"` para aceitar conexões externas/celulares, ou `"127.0.0.1"` apenas para uso local.
  * `WS_PORT`: Porta que o painel Flutter usará para se conectar (ex: `8082`, número inteiro sem aspas).
  * `WS_TOKEN`: Crie uma senha/token secreto para autenticar suas interfaces.

### 2. Script de Inicialização Windows (`IniciarWebsocketsExample.bat`)
Edite o arquivo `.bat` para apontar para a pasta onde você salvou o script Python:
* Ajuste a letra da unidade de disco (ex: `I:` ou `C:`) e substitua `<CAMINHO_DO_SEU_SCRIPT>` pelo caminho da pasta.
* Substitua `<NOME_DO_SEU_SCRIPT>.py` pelo nome exato do seu arquivo Python.

### 3. Interface Flutter (`lib/main.dart`)
Abra o arquivo `lib/main.dart` e ajuste os parâmetros de conexão e mapa:
* **URL de Conexão WebSocket:** Atualize o IP, a porta e o token na string de conexão (`ws://<WS_HOST>:<WS_PORT>/?token=<WS_TOKEN>`).
* **Zonas PVE (`retangulosPve`):** Ajuste os retângulos de coordenadas `[minX, maxX, minZ, maxZ]` de acordo com as áreas seguras do seu servidor. Por padrão vem rastreada a Floresta Pinhais do Navezgane da v3.4.0(b10). Otimize os retangulos pra uma quantidade minima pra não sobrecarregar as verificações.
* **Mapa Customizado (Opcional):** Você pode carregar qualquer imagem quadrada de mapa (`.png` / `.webp`) direto pelo botão **Mapa** na barra superior do app Maps, informando o caminho do arquivo e o tamanho do mundo (ex: `6144`, `8192`, `10240`, `16384`). Por padrão é carregado o assets/maps/Navezgane/images/Navezgane.webp

### 4. Bot Admin
* Procure e substitua o termo BotAdmin pelo nome do seu bot administrador. Isso está sendo projetado para implementações futuras. Se você não alterar isso, o BotAdmin ainda aparecerá em mensagens e alertas.
* Envia mensagens privadas para jogadores quando eles alternam entre áreas PvP e PvE.
* Envia mensagens globais de administrador (permissão 99) no modo Prisma Core através do aplicativo Zorkut. Não aplique a permissão 99 aos jogadores sem revisar os arquivos de configuração do servidor. As permissões de administrador são aplicadas por padrão no arquivo para níveis iguais ou inferiores a 100. 0 (zero) é o nível máximo. Tentar usar este comando aplicando o nível de autorização necessário a todos dará permissões de comando de administrador a todos. NÃO FAÇA ISSO! Até que você configure um novo sistema de permissões, use o seletor Vanilla não personalizado (clicando no botão) para mensagens globais.

## Licença
Este projeto está sob **The Unlicense** (Domínio Público). Você é livre para copiar, modificar, publicar, usar ou distribuir este software para qualquer finalidade, sem necessidade de atribuição.

# Transparência no Desenvolvimento e IA

Projetado, arquitetado e testado em servidores reais. O Gemini e o GitHub Copilot (VS Code) auxiliaram o fluxo de trabalho estritamente como ferramentas de programação em pares, não como geradores de código independentes. Não houve geração automática de prompts nem desenvolvimento em massa — o desenvolvimento seguiu uma abordagem lenta, deliberada e modular, onde cada componente foi auditado, compreendido e testado manualmente sob condições extremas antes da integração.