## 🌍 Traduções e Suporte a Novos Idiomas (i18n)

O **SD-DOS Server Manager** utiliza arquivos `.json` estruturados com contexto em `assets/lang/` para facilitar traduções rápidas feitas por humanos ou IAs (ChatGPT, Claude, Gemini, etc.).

### Como criar uma nova tradução com IA

1. Copie o arquivo `assets/lang/en-US.json` (ou `pt-BR.json`) e renomeie seguindo o padrão **IETF BCP 47** (ex: `es-ES.json`, `de-DE.json`, `ru-RU.json`, `ja-JP.json`).
2. Envie o conteúdo do arquivo para uma IA com o seguinte prompt:

> *"Traduza os valores do campo `"text"` deste arquivo JSON para [SEU IDIOMA]. Leia e siga estritamente as instruções em `"_meta.ai_instructions"` e respeite os limites de espaço descritos em cada campo `"context"`. Não altere as chaves do JSON, não traduza o campo `"context"`, nunca traduza variáveis entre chaves como `{player}` ou `{count}`, e preserve tags de cor como `[39FF14]` e `[-]`."*

3. Atualize o bloco `"_meta"` no topo do novo arquivo:
   - `"language_name"`: Nome nativo do idioma (ex: `"Español"`).
   - `"language_code"`: Código do arquivo (ex: `"es-ES"`).
   - `"tray_top"` e `"tray_bottom"`: Siglas de 3 letras para o relógio/bandeja do sistema (ex: `"ESP"` e `"ESP"`).
4. Registre o novo idioma no mapa `idiomasDisponiveis` em `lib/services/lang_service.dart`:
   ```dart
   static const Map<String, String> idiomasDisponiveis = {
     'pt-BR': 'Português (BR)',
     'en-US': 'English (US)',
     'es-ES': 'Español', // <-- Novo idioma
   };
   ```

### Regras de Ouro para Tradutores
- **Não altere chaves nem `"context"`:** O código Dart busca apenas as chaves e o campo `"text"`.
- **Respeite o tamanho dos rótulos:** Ícones da área de trabalho e abas têm largura limitada; siga as dicas de caracteres no campo `"context"`.
- **Variáveis e Tags:** Mantenha `{player}`, `{SDTD_HOST}`, `[39FF14]`, `[-]` e quebras de linha `\n` intactos.
