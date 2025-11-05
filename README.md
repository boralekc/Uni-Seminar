# 🧠 Uni-Seminar — WebMall Agents Lab

Dieses Repository stellt eine komplette lokale Testumgebung für das **Uni-Seminar-Projekt** bereit.  
Es enthält sowohl die **WebMall-Shops** (WordPress + MariaDB) als auch die **KI-Agenten-Stacks** (BrowserAgent, Occam, BrowserUse).  
Ziel ist die Durchführung und Analyse von automatisierten Benchmark-Tests in einer kontrollierten Umgebung.

---

## 🔧 1. Repository klonen

```bash
git clone --recurse-submodules <dein-repo-url>
cd webmall-agents-lab
cp .env.example .env
```

> ⚠️ Das Flag `--recurse-submodules` ist **erforderlich**, da dieses Projekt Untermodule wie **WebMall** und **BrowserGym** enthält.

---

## ⚙️ 2. Umgebung vorbereiten

Erstelle und überprüfe die `.env`-Dateien:

```bash
# Lokale .env aus Vorlage erzeugen
make env-init

# Wichtige Variablen prüfen
make env-check

# Separate Umgebungen für Root und Runner
make env-init-root
make env-init-runner

# oder beides gleichzeitig
make env-init-both
```

---

## 🏗️ 3. WebMall installieren

Lade die offiziellen Backups und stelle sie lokal wieder her:

```bash
make webmall-restore-all
make webmall-init-admins
```

Dadurch werden vier Shops (Shop 1–4) mit WordPress + WooCommerce lokal bereitgestellt.

---

## 🧹 4. WebMall löschen (optional)

```bash
# Container + Volumes entfernen
make webmall-reset-all

# Zusätzlich Docker-Images löschen
make webmall-nuke NUKE_IMAGES=1

# Komplett alles löschen (WebMall + Agents + Netzwerk + Ergebnisse)
make nuke-all NUKE_RESULTS=1
```

---

## 🧪 5. BrowserAgent-Tests ausführen

```bash
make up-browser      # Startet den BrowserAgent-Stack
make logs-browser    # Zeigt die Logs live an
```

Ergebnisse werden automatisch unter:

```
./results/browser
```

gespeichert.

---

## ⚛️ 6. Occam-Stack starten

```bash
make up-occam
make logs-occam
```

Beide Stacks (BrowserAgent + Occam) gleichzeitig starten:

```bash
make up-both
```

---

## 🤖 7. BrowserUse-Benchmark starten

Führt das Python-Skript `run_browseruse_webmall_study.py` im Container aus:

```bash
make up-browseruse
make logs-browseruse
```

---

## 🛑 8. Container stoppen

```bash
make down-browser     # Nur BrowserAgent
make down-occam       # Nur Occam
make down-both        # Beide gleichzeitig
```

---

## 📁 9. Ergebnisse

Alle Resultate (Logs, JSON-Ausgaben, Screenshots) werden im lokalen Ordner gespeichert:

```
/results
```

---

## 🧼 10. Alte Container bereinigen (falls Reste vorhanden)

Falls noch alte WebMall-Container aus früheren Tests laufen:

```bash
# Alte WebMall-Container entfernen
docker compose -p docker_all -f external/WebMall/docker_all/docker-compose.yml down -v || true

# Hängenden Frontend-Container beenden
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
webmall-agents-lab/
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
