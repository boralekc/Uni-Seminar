# Uni-Seminar

## Clone
```bash
git clone --recurse-submodules <your-repo-url>
cd webmall-agents-lab
cp .env.example .env

# запустить только браузерный стек
make up-browser
make ps-browser
make run-browser

# запустить только occam стек
make up-occam
make ps-occam
make run-occam

# запустить оба
make up-both

# погасить
make down-browser
make down-occam
# или
make down-both


