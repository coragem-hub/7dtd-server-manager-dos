# PrismaCore - Referência de Comandos para 7 Days to Die

## Objetivo do arquivo

Este arquivo documenta os comandos adicionados aos servidores de 7 Days to Die pela ferramenta PrismaCore.

Use este documento como referência para explicar comandos, montar exemplos e ajudar a executar comandos PrismaCore.

---

## 1. Comando sayadmin

Descrição:
Envia uma mensagem privada para todos os jogadores que atendem ao nível mínimo de permissão para recebimento.

Parâmetros e funcionamento:
O comando é dividido em 4 partes:

1. Comando.
2. Nome de exibição. Entre aspas se usar espaços ou tag de cores.
3. Nível de permissão alcançado (0-99). No jogo a permissão vai de 0 a 1000, mas somente duas casas decimais podem ser configuradas nesse comando. O servidor precisa implementar 99 como padrão pra novos jogadores ou eles não vão receber a mensagem. 0 é o nivel de admin.
4. Mensagem.

Sintaxe:
```text
sayadmin "<chatName>" <levelReceipients> "<message>"
```

Exemplo prático:
```text
sayadmin "[39FF14]Alita[-]" 0 "Siga as Regras! Monitorando..."