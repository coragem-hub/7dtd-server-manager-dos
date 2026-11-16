# Engenharia de Software: Troubleshooting & Debug Log

# Validação de Infraestrutura de Rede (Camadas)

Antes das correções de código, a conectividade entre o Windows precisa ser validada com sucesso através dos seguintes testes nativos no terminal:
• Camada de Rede (ICMP): O comando *"ping <IP_SERVIDOR>"* no CMD retornou com sucesso (Máquina Linux ativa na rede local).
• Camada de Transporte (TCP): O comando do PowerShell *"Test-NetConnection -ComputerName <IP_SERVIDOR> -Port <PORTA_TELNET>"* retornou TcpTestSucceeded : True (Porta aberta no firewall do Linux e serviço do jogo escutando).


## 1. Erros de Código Identificados e Soluções

### Erro 1: Incompatibilidade de Tipos (TypeError)
* **Sintoma:** O script quebrava exibindo a mensagem:
  ```text
  TypeError: argument should be integer or bytes-like object, not 'str'
  ```
* **Causa:** Bibliotecas de comunicação assíncrona exigem tráfego de dados binários brutos. O script tentava enviar e buscar strings normais (`str`).
* **Solução:** Implementação do método `.encode('utf-8')` antes do envio de strings à rede, e tratamento com `.decode('utf-8')` no recebimento dos dados.

### Erro 2: Travamento Infinito (Congelamento do Script)
* **Sintoma:** O código ficava paralisado indefinidamente em *"Conectando ao servidor..."* ou *"Aguardando prompt do servidor..."*.
* **Causa 1 (Handshake):** A biblioteca `telnetlib3` tentava forçar uma negociação de recursos de terminal que o servidor simplificado do 7DTD não suporta.
* **Causa 2 (Lógica Invertida):** O código esperava receber a string `"Password:"` para agir. No entanto, o servidor do 7DTD abre uma conexão do tipo RAW Socket e fica em silêncio absoluto aguardando que o cliente envie a senha proativamente.
* **🎯 Solução Definitiva:** A biblioteca externa foi descartada em prol do módulo nativo `asyncio`. A lógica foi invertida para enviar a senha imediatamente após a abertura do canal TCP.

### Erro 3: Travamento (Não aplica o comando)
* **Sintoma:** O código ficava paralisado até o log imprimir uma próxima linha de registro de atividade não relacionada ao comando. E o comando não surte efeito.
* **Causa:** Comandos que pedem nivel de permissão só podem receber duas casas decimais (0-99). Usar 3 casas, número 100 em diante travam o comando.
* **Solução:** Implementação de nivel de permissões baseado em duas casas decimais (0-99).