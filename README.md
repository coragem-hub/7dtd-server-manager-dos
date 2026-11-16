# sd_dos_dart
Lightweight retro-OS visual server manager for 7 Days to Die with automated PVP/PVE zone control, live player radar, and integrated chat (Flutter + Python).

![Interface](./sd-dos_v1_0.png)

[🇧🇷 Leia em Português](README_pt-BR.md)

# SD-DOS Server Manager (v1.0)

Lightweight visual manager for **7 Days to Die** dedicated servers, inspired by classic operating systems. Built to provide automated PVP/PVE border control, log monitoring, and a tactical player radar without heavy configurations.

# Project Objective

To create a visually user-friendly environment for the secure management of game servers and file editors. Lightweight and with multiple tools. In its final version, it will run on computers, browsers, and Android phones (yes, you'll be able to use that idle processor from your old phone stored in a drawer).

> **Note (v1.0):** The current user interface and internal variables are in Portuguese. Multi-language localization support is planned for upcoming releases.

## v1.0 Features
* **Maps:** Interactive map with zoom, configurable PVE zone overlays, and live player tracking.
* **PVP / PVE Automation:** Automatic private warnings sent to players crossing borders between safe and hostile biomes.
* **Zorkut Chat:** Global chat interface compatible with both vanilla console commands (`say`) and Prisma Core (`sayadmin`).
* **Log Splitter & Monitor:** Smart server event filtering (`[LP]`, `[CHAT]`, `[CMD]`, `[PC]`) with automatic scroll lock.
* **Prompt (CMD):** Built-in terminal for quick Telnet administrative commands.

## Features planned for the next version
* Websocket script generator already configured through a new app.
* IP, port, and credential configuration via interface, without the need for manual file editing.
* First executable (.exe) for Windows.

## Tech Stack
* **Frontend / UI:** Flutter (Desktop)
* **Backend / Telnet Bridge:** Python (WebSockets)

## Setup & Configuration (v1.0)

Before running the manager, manually fill in your server credentials and network parameters in the project files. The manager was developed to currently use a Python script that maintains the connection to the server's telnet via websockets. Use a .bat file for one-click execution on Windows.

## Execution Logic

* The script can run directly on the server or on another computer. It offers stability and minimal processing cost because it doesn't perform complex checks and calculations, and allows for the implementation of security filters.
* The manager connects to the websocket from any computer without needing to connect directly to the server, and allows multiple stable connections even when performing complex checks, processing, and calculations.
* In practice, you can run everything on the same computer, or have a SERVER, SCRIPT, and multiple MANAGERS in different locations.
* In the current version, multiple connections to telnet using the manager will overload telnet due to the automatic application of pre-configured handling rules. However, you can use any websocket connection tool to read logins and send commands using the same connection type and credentials.

### 1. Python WebSocket Bridge (`WebsocketsExample.py`)
Install the required dependency:
```bash
pip install websockets
```

Open the Python script and replace the placeholders (`<...>`) with your server details:
* **Game Telnet Settings:**
  * `SDTD_HOST`: Your 7 Days to Die server IP address (e.g., `"127.0.0.1"`).
  * `SDTD_PORT`: Your server Telnet port (default is `8081`, integer without quotes).
  * `SDTD_PASSWORD`: Your `serverconfig.xml` Telnet password.
* **WebSocket Bridge Settings:**
  * `WS_HOST`: Use `"0.0.0.0"` to accept external connections, or `"127.0.0.1"` for local access only.
  * `WS_PORT`: Port used by the Flutter interface to connect (e.g., `8082`, integer without quotes).
  * `WS_TOKEN`: A custom secret token/password to authenticate your client interfaces.

### 2. Windows Startup Script (`IniciarWebsocketsExample.bat`)
Edit the `.bat` launcher to point to your Python script directory:
* Change the drive letter (e.g., `I:` or `C:`) and replace `<CAMINHO_DO_SEU_SCRIPT>` with the folder path.
* Replace `<NOME_DO_SEU_SCRIPT>.py` with the exact name of your Python file.

### 3. Flutter Interface (`lib/main.dart`)
Open `lib/main.dart` and update the connection and zone parameters to match your Python bridge:
* **WebSocket Connection URL:** Update the IP, port, and token in the connection string (`ws://<WS_HOST>:<WS_PORT>/?token=<WS_TOKEN>`).
* **PVE Zones (`retangulosPve`):** Adjust the `[minX, maxX, minZ, maxZ]` coordinate rectangles to match the safe zones of your map. By default, the Navezgane Pine Forest from v3.4.0(b10) is tracked. Optimize the rectangles to a minimum quantity to avoid overloading the checks.
* **Custom Map (Optional):** Load any square map image (`.png` / `.webp`) directly from the **Maps** top toolbar by entering its file path and world size (e.g., `6144`, `8192`, `10240`, `16384`). By default, the assets/maps/Navezgane/images/Navezgane.webp file is loaded.

### 4. Bot Admin
* Search and replace the term BotAdmin with the name of your admin bot. This is being designed for future implementations. If you don't change this, BotAdmin will still appear in messages and alerts.
* Sends private messages to players when they switch between PvP and PvE areas.
* Sends global admin messages (permission 99) in Prisma Core mode via the Zorkut application. Do not apply permission 99 to players without reviewing the server configuration files. Admin permissions are applied by default in the file for levels equal to or less than 100. 0 (zero) is the maximum level. Attempting to use this command applying the required authorization level to everyone will give admin command permissions to everyone. DO NOT DO THIS! Until you set up a new permissions system, use the non-custom Vanilla selector (by clicking the button) for global messages.

## License
This project is released under **The Unlicense** (Public Domain). You are free to copy, modify, publish, use, or distribute this software for any purpose without attribution.

# Transparency in Development and AI

Designed, architected, and tested on real servers. Gemini and GitHub Copilot (VS Code) aided the workflow strictly as pair programming tools, not as standalone code generators. There was no automatic prompt generation or mass development—development followed a slow, deliberate, and modular approach, where each component was audited, understood, and manually tested under extreme conditions before integration.
