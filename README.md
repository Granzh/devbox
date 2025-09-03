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
