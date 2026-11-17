# sd_dos_dart
Gerenciador visual leve em estilo sistema operacional retrô para **7 Days to Die**, com controle automatizado de zonas PVP/PVE, radar de jogadores em tempo real, gerador de proxy integrado e chat nativo (Flutter + Python).

![Interface](./sd-dos_v1_0.png)

[🇺🇸 Read in English](README.md)

# SD-DOS Server Manager (v1.1)

Gerenciador visual leve para servidores dedicados de **7 Days to Die**, inspirado em sistemas operacionais clássicos. Desenvolvido para oferecer controle automático de fronteiras PVP/PVE, monitoramento de logs, radar tático de jogadores e configuração de rede sem precisar editar código-fonte.

## Novidades da v1.1
* **Aplicativo NetConfig (Rede TCP/IP e Gerador de Scripts):** Configure o IP do Proxy, porta e token secreto diretamente pela interface com salvamento local (`shared_preferences`) e botões de ocultar/mostrar dados (`obscureText`) para proteger streamers durante transmissões ao vivo.
* **Gerador Integrado de `.py` e `.bat`:** Gere e baixe o script Python da ponte WebSocket e o atalho inicializador do Windows `.bat` (com suporte automático ao caminho relativo `%~dp0`) já configurados pela própria janela do programa.
* **Conexão WebSocket Blindada:** Implementação de IDs de geração de tentativa, bloqueio contra cliques repetidos (*debounce*) no botão de conectar e verificação automática `ping_interval` / `ping_timeout` para eliminar conexões fantasmas, sessões duplicadas e loops de reconexão.
* **Monitores de Log de Alta Performance:** Adição de buffer circular limitado a 1.000 linhas na memória e renderização otimizada com `SelectionArea` no **Monitor** e no **LogSplit**, evitando travamentos ao rolar listas longas após horas de servidor ativo.
* **Executável para Windows (`.exe`):** Primeira versão compilada disponível para Windows sem necessidade de editar arquivos manualmente.

## Funcionalidades Principais
* **NetConfig:** Configuração visual de rede, persistência local de credenciais e exportação rápida dos arquivos `.py` e `.bat` do proxy.
* **Maps:** Mapa interativo com zoom, camadas configuráveis de zonas PVE e rastreamento de jogadores em tempo real.
* **Automação PVP / PVE:** Envio automático de avisos privados para jogadores que cruzam fronteiras entre biomas seguros (PVE) e hostis (PVP).
* **Zorkut Chat:** Interface de chat global compatível tanto com comandos nativos do console (`say`) quanto com Prisma Core (`sayadmin`).
* **Log Splitter & Monitor:** Filtragem inteligente de eventos do servidor (`[LP]`, `[CHAT]`, `[CMD]`, `[PC]`) com trava automática de rolagem e proteção de memória.
* **Prompt (CMD):** Terminal embutido para envio rápido de comandos administrativos via Telnet.

## Objetivo do Projeto

Criar um ambiente visualmente amigável para o gerenciamento seguro de servidores de jogos e editores de arquivos. Leve e com múltiplas ferramentas. Em sua versão final, rodará em computadores, navegadores e celulares Android (sim, você poderá reaproveitar o processador parado daquele celular antigo guardado na gaveta).

> **Nota (v1.1):** A interface atual e as variáveis internas estão em Português. O suporte a múltiplos idiomas está planejado para as próximas versões.

## Tecnologias Utilizadas
* **Frontend / Interface:** Flutter (Windows Desktop / Web)
* **Backend / Ponte Telnet:** Python (`websockets`)

## Lógica de Execução

* O script proxy em Python pode rodar diretamente na máquina do servidor de jogo ou em outro computador. Ele mantém baixíssimo consumo de CPU e isola as credenciais do Telnet das interfaces clientes.
* Múltiplas interfaces do gerenciador podem se conectar simultaneamente ao mesmo proxy WebSocket sem sobrecarregar a porta Telnet do servidor.
* Na prática, você pode rodar tudo no mesmo computador ou hospedar o **Servidor do Jogo**, o **Proxy Python** e as **Interfaces do Gerenciador** em máquinas separadas.

## Instalação e Configuração Rápida (v1.1)

Você não precisa mais editar arquivos de código-fonte manualmente para configurar sua conexão.

### 1. Inicie o Gerenciador
* **Executável Windows:** Baixe o arquivo `.zip` da última release, extraia a pasta completa (mantenha o `.exe`, as `.dll` e a pasta `data/` juntos) e execute `sd_dos_dart.exe`.
* **Pelo Código-Fonte:** Execute `flutter pub get` e `flutter run -d windows` (ou `-d chrome`).
* No primeiro acesso, o aplicativo **NetConfig** será aberto automaticamente caso nenhuma configuração salva seja encontrada.

### 2. Gere o Script Proxy (`.py` e `.bat`)
Instale a dependência WebSocket do Python na máquina onde o script irá rodar:
```bash
pip install websockets
```

Dentro do **NetConfig**, acesse a aba **2. Gerar Script (.py / .bat)**:
1. **Configuração do Telnet (7D2D):** Informe o IP do servidor (`127.0.0.1` se estiver na mesma máquina), a `TelnetPort` (padrão `8081`) e a `TelnetPassword` configurada no `serverconfig.xml`.
2. **Configuração da Ponte WebSocket:** Defina `WS_HOST` (`0.0.0.0` para permitir conexões externas ou `127.0.0.1` apenas para acesso local), `WS_PORT` (padrão `8082`) e crie um `WS_TOKEN` forte.
3. **Exportar Arquivos:** Clique em **BAIXAR SCRIPT (.PY)** e **BAIXAR ATALHO (.BAT)** para salvar ambos na mesma pasta. Depois, dê um duplo clique no arquivo `.bat` para iniciar a ponte.

### 3. Conecte a Interface
Dentro do **NetConfig**, acesse a aba **1. Conexão do Painel**:
* Preencha o IP do Proxy, a Porta e o `WS_TOKEN` criado na etapa anterior, e clique em **SALVAR E CONECTAR AO PROXY**.
* Os dados ficam salvos localmente no seu dispositivo para reconexão automática nas próximas execuções.

## Personalização Avançada (Código-Fonte)

* **Zonas PVE (`retangulosPve` em `lib/main.dart`):** Ajuste os retângulos de coordenadas `[minX, maxX, minZ, maxZ]` para corresponder às áreas seguras do seu mapa (por padrão, a Floresta de Pinheiros de Navezgane está configurada).
* **Mapa Personalizado (Opcional):** Carregue qualquer imagem quadrada de mapa (`.png` / `.webp`) diretamente pela barra superior do aplicativo **Maps**, informando o caminho do arquivo e o tamanho do mundo (`6144`, `8192`, `10240`, `16384`).
* **Aviso sobre Permissões de Admin:** As mensagens globais no modo Prisma Core enviam atualmente o comando `sayadmin` com nível de permissão `99`. Não aplique nível de permissão `99` a jogadores comuns sem revisar os arquivos de configuração do seu servidor (`0` é o nível máximo de administrador, e níveis `<= 100` costumam liberar comandos administrativos por padrão). Em caso de dúvida, utilize o seletor **Vanilla** no Zorkut para enviar mensagens globais padrão via `say`.

## Licença
Este projeto é distribuído sob a licença **The Unlicense** (Domínio Público). Você é livre para copiar, modificar, publicar, usar ou distribuir este software para qualquer finalidade sem necessidade de atribuição.

# Transparência no Desenvolvimento e IA

Projetado, arquitetado e testado em servidores reais. O Gemini e o GitHub Copilot (VS Code) auxiliaram o fluxo de trabalho estritamente como ferramentas de *pair programming*, e não como geradores autônomos de código. Não houve geração automática de prompts ou desenvolvimento em massa — cada componente foi construído de forma modular, auditado, compreendido e testado manualmente em condições extremas antes da integração.
