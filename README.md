# Uni-Seminar

#1. Repo clone
```bash
git clone --recurse-submodules <your-repo-url>
cd webmall-agents-lab
cp .env.example .env

#2. Check enveronment
make env-init     # создать .env из шаблона
make env-check    # проверить ключевые значения
make env-init-root
make env-init-runner
# или сразу оба
make env-init-both

#4. Install WebMall
make webmall-restore-all
make webmall-init-admins

# Delete WebMall
make webmall-reset-all          # снести контейнеры+тома WebMall
make webmall-nuke NUKE_IMAGES=1 # дополнительно снести образы (опционально)
make nuke-all NUKE_RESULTS=1    # снести всё (WebMall+агенты+сеть) и очистить results

#5. Запуск тестов BrowserAgent
make up-browser
make logs-browser

#6. запустить только occam стек
make up-occam
make logs-occam

# запустить оба
make up-both

#7. Запуск run_browseruse_webmall_study.py
make up-browseruse
make logs-browseruse

# погасить
make down-browser
make down-occam
# или
make down-both

#Результаты в папке
/result

Удаление старых контейнеров
# Снести старые контейнеры от предыдущего проекта
docker compose -p docker_all -f external/WebMall/docker_all/docker-compose.yml down -v || true

# На всякий случай убрать висящий фронт (если остался)
docker rm -f WebMall_frontend || true


