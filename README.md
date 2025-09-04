# Devbox — reproducible dev environment

Единый Docker-образ для разработки на **Python + TypeScript/React + Flutter** с (zsh + oh-my-zsh + Powerlevel10k).

---

## ✨ Что внутри
- **Python 3 + uv** 
- **Node.js 20 + pnpm**
- **Flutter (без Android SDK, для сборок/тестов)**
- **Java 17 (для Android-сборок)**
- **zsh + oh-my-zsh + Powerlevel10k + плагины**
- ssh-agent passthrough
- поддержка **docker-in-docker** и **docker-outside-of-docker**

---

## 🚀 Установка и сборка

Собрать образ локально:
```bash
docker build -t devbox:latest .
```
## Запуск
```bash
#Windows
.\dev.ps1 dev      # запустить контейнер в папке проекта
.\dev.ps1 dev-dood # то же самое, но с доступом к docker демону хоста
.\dev.ps1 dind     # поднять изолированный docker-daemon (DinD)

#linux и macos
make dev           # запустить контейнер в папке проекта
make dev-dood      # то же самое, но с доступом к docker демону хоста
make dind          # поднять изолированный docker-daemon (DinD)
```