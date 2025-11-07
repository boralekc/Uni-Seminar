# 🧠 Uni-Seminar — WebMall Agents Lab

Dieses Repository stellt eine komplette lokale Testumgebung für das **Uni-Seminar-Projekt** bereit.  
Es enthält sowohl die **WebMall-Shops** (WordPress + MariaDB) als auch die **KI-Agenten-Stacks** (BrowserAgent, Occam, BrowserUse).  
Ziel ist die Durchführung und Analyse von automatisierten Benchmark-Tests in einer kontrollierten Umgebung.

---

## ⚙️ Alles basiert auf GNU Make

Das gesamte Projekt wird über **GNU Make** gesteuert.  
Alle wichtigen Befehle (Erstellen, Starten, Stoppen, Löschen, Logs ansehen usw.) sind in **Makefiles** definiert.

Das bedeutet:
- Kein manuelles Eintippen langer Docker-Befehle.  
- Eine einzige Schnittstelle (`make`) reicht für alle Aufgaben.  
- Konsistente und reproduzierbare Umgebung auf jedem System.

Beispiele:

```bash
make env-init
make webmall-restore-all
make up-browser
make logs-browser
make down-both
```

---

## 💻 1. Installation unter Windows (mit WSL2)

Da Windows kein nativer Linux-Shell-Interpreter ist, muss **WSL2 (Windows Subsystem for Linux)** installiert werden.  
Dies ermöglicht die Verwendung von `make`, `bash`, `docker` und anderen Linux-Tools direkt unter Windows.

### 🔹 Schritt 1 – WSL2 aktivieren

Öffne PowerShell **als Administrator** und führe aus:

```powershell
wsl --install
```

Nach der Installation starte den Computer neu.

### 🔹 Schritt 2 – Ubuntu als Standarddistribution setzen

```powershell
wsl --set-default Ubuntu
```

### 🔹 Schritt 3 – In Ubuntu wechseln und Make installieren

Öffne anschließend Ubuntu (z. B. über das Startmenü) und führe aus:

```bash
sudo apt update
sudo apt install -y make git docker.io docker-compose
```

> ⚠️ Achte darauf, dass Docker Desktop für Windows **aktiviert ist** und **WSL2-Integration** in den Einstellungen (Resources → WSL Integration) eingeschaltet ist.

Danach kannst du alle Befehle wie gewohnt verwenden, z. B.:

```bash
make env-init
make webmall-restore-all
make up-both
```

---

## 🐧 2. Installation unter Linux

Auf nativen Linux-Systemen (Ubuntu, Debian, Fedora usw.) genügt es, folgende Pakete zu installieren:

```bash
sudo apt update
sudo apt install -y make git docker.io docker-compose
```

Anschließend:

```bash
git clone --recurse-submodules <dein-repo-url>
cd webmall-agents-lab
cp .env.example .env
make env-init-both
make webmall-restore-all
make up-both
```

---

## 🌐 3. Zugriff auf externe WebMall-Shops (lokaler Browserzugriff)

Wenn du über deinen lokalen Browser auf die WebMall-Frontends zugreifen möchtest, überschreibe in deiner `.env`-Datei folgende Variablen:

```bash
FRONTEND_URL=http://localhost:${FRONTEND_PORT}
SHOP1_URL=http://localhost:${SHOP1_PORT}
SHOP2_URL=http://localhost:${SHOP2_PORT}
SHOP3_URL=http://localhost:${SHOP3_PORT}
SHOP4_URL=http://localhost:${SHOP4_PORT}
```

> Danach kannst du die Shops unter `http://localhost:8081`, `http://localhost:8082` usw. aufrufen (je nach Port-Konfiguration).

---

## 🧩 4. Repository klonen

```bash
git clone --recurse-submodules <dein-repo-url>
cd webmall-agents-lab
cp .env.example .env
```

> ⚠️ Das Flag `--recurse-submodules` ist **erforderlich**, da dieses Projekt Untermodule wie **WebMall** und **BrowserGym** enthält.

---

## 🔧 5. Umgebung vorbereiten

Erstelle und überprüfe die `.env`-Dateien:

```bash
make env-init
make env-check
make env-init-root
make env-init-runner
make env-init-both
```

---

## 🏗️ 6. WebMall installieren

```bash
make webmall-restore-all
make webmall-init-admins
```

Dadurch werden vier Shops (Shop 1–4) mit WordPress + WooCommerce lokal bereitgestellt.

---

## 🧹 7. WebMall löschen (optional)

```bash
make webmall-reset-all
make webmall-nuke NUKE_IMAGES=1
make nuke-all NUKE_RESULTS=1
```

---

## 🧪 8. BrowserAgent-Tests ausführen

```bash
make up-browser
make logs-browser
```

Ergebnisse werden automatisch unter:

```
./results/browser
```

gespeichert.

---

## ⚛️ 9. Occam-Stack starten

```bash
make up-occam
make logs-occam
make up-both
```

---

## 🤖 10. BrowserUse-Benchmark starten

```bash
make up-browseruse
make logs-browseruse
```

---

## 🛑 11. Container stoppen

```bash
make down-browser
make down-occam
make down-both
```

---

## 📁 12. Ergebnisse

Alle Resultate (Logs, JSON-Ausgaben, Screenshots) werden im lokalen Ordner gespeichert:

```
/results
```

---

## 🧼 13. Alte Container bereinigen (falls Reste vorhanden)

```bash
docker compose -p docker_all -f external/WebMall/docker_all/docker-compose.yml down -v || true
docker rm -f WebMall_frontend || true
```

---

## ✅ Systemanforderungen

| Komponente | Empfehlung |
|-------------|-------------|
| **Betriebssystem** | Linux oder WSL2 (Ubuntu 20.04+) |
| **RAM** | mindestens 16 GB |
| **Docker / Compose** | v24+ |
| **Make** | GNU Make 4.3+ |
| **Python** | wird automatisch im Container installiert |

> 💡 Bei Problemen mit Chromium/Playwright im BrowserAgent kann die Shared-Memory-Größe in `docker-compose-browser*.yaml` angepasst werden:
> ```yaml
> shm_size: "2gb"
> ```

---

## 👥 Projektstruktur

```
Uni-Seminar/
├── agents/                  # Agenten-Skripte (Browser, Occam, etc.)
├── external/                # Submodule (WebMall, BrowserGym)
├── make/                    # Makefile-Module
├── results/                 # Ergebnisse und Logs
├── runner/                  # Runner-Umgebung (.env, Skripte)
├── docker-compose-*.yaml    # Compose-Dateien für Agenten
└── Makefile                 # Hauptsteuerung
```

---

## 🧩 Häufige Befehle

| Zweck | Befehl |
|-------|--------|
| Umgebung prüfen | `make env-check` |
| WebMall starten | `make webmall-restore-all` |
| BrowserAgent starten | `make up-browser` |
| Logs live sehen | `make logs-browser` |
| Alles stoppen | `make down-both` |
| Alles bereinigen | `make nuke-all NUKE_RESULTS=1` |

---

© 2025 Uni-Seminar AI Systems Lab  
Dieses Projekt dient ausschließlich zu Forschungs- und Bildungszwecken.
