# MVP Release Checklist — 06.06.2026

**Цель:** Первый публичный релиз Architect
**Текущий статус:** 🟢 SITE LIVE (GitHub Pages) / 🟡 INFRA IN PROGRESS
**Ответственный за координацию:** CTO (0b699d1b)

---

## ✅ Stage 1: LIVE (Всё работает сейчас)

| # | Пункт | Статус | Подробности |
|---|-------|--------|-------------|
| 1 | Публичный сайт | 🟢 LIVE | https://dufermer.github.io/architect-site/ — HTTP 200 |
| 2 | Astro.js frontend | ✅ Собирается | 7 страниц (landing, portfolio, products, blog) |
| 3 | MDX Blog | ✅ Работает | 5 постов, RSS, sitemap |
| 4 | CI/CD GitHub Pages | ✅ Auto-deploy | Push в main → деплой на GitHub Pages |
| 5 | GitHub аутентификация | ✅ Работает | gh CLI, PAT с workflow scope |
| 6 | SEO | ✅ Настроено | JSON-LD, OG, Twitter Cards, sitemap, robots.txt |
| 7 | Форма обратной связи | ✅ Форма есть | Formspree (ждёт ID из .env) |
| 8 | Go Backend API | ✅ Скомпилирован | Health endpoint, контактная форма, Docker-ready |

## 🟡 Stage 2: VPS Production Deploy (В работе, DUN-94)

| # | Пункт | Статус | Исполнитель | Задача | Примечание |
|---|-------|--------|-------------|--------|------------|
| 1 | Docker Compose | 🟢 Код готов | DevOps | DUN-144 | infra/docker-compose.yml с backend/frontend/nginx/postgres |
| 2 | CI/CD на VPS | 🟡 in_progress | DevOps | DUN-100 | GitHub Actions workflow готов |
| 3 | nginx + SSL | 🟡 in_progress | DevOps | DUN-146 | Конфиг готов, ждёт домена |
| 4 | Firewall | 🟡 in_progress | DevOps | DUN-108 | Critical — ufw/nftables |
| 5 | Мониторинг | 🟡 in_progress | DevOps/SRE | DUN-105 | uptime-monitor.sh готов |

## 🔴 Stage 3: Domain + Cloudflare (Блокер — DUN-67)

| # | Пункт | Статус | Исполнитель | Задача |
|---|-------|--------|-------------|--------|
| 1 | Домен dunaev.dev | 🟡 in_progress | DevOps | DUN-67 |
| 2 | Cloudflare DNS | 🟡 in_progress | DevOps | DUN-67 |
| 3 | Cloudflare Pages | 🟡 in_progress | DevOps | wrangler.toml готов, ждёт DNS |

## ⏳ Stage 4: Графика (Не влияет на MVP)

| # | Пункт | Статус | Исполнитель | Задача |
|---|-------|--------|-------------|--------|
| 1 | ComfyUI установка | 🟡 in_progress | Lead Engineer | DUN-63 |
| 2 | Brand kit | ✅ Готов | Designer | DUN-55 |
| 3 | Видео/графика | 🟡 in_progress | Designer | DUN-92 |

---

## 📋 Deadline: 07.06.2026 (Завтра)

### Что можно сделать прямо сейчас без зависимостей:
1. Добавить SSH-ключ (vps_masterhost.pub) в ~/.ssh/authorized_keys на VPS
2. Установить Docker на VPS (apt install docker.io docker-compose-v2)
3. Скопировать infra/ на VPS и запустить `make up`
4. Настроить Cloudflare DNS после регистрации домена

### Критический путь к деплою:
```
VPS SSH доступ → Docker на VPS → docker-compose up → Cloudflare DNS
       ↑                               ↑
  DUN-108 (firewall)             DUN-67 (domain)
```

### Уже НЕ блокирует:
- GitHub токены — ✅ (DUN-72/74)
- Архитектура — ✅ (DUN-52)
- Контент — ✅ (DUN-96/99)
- Анализ рынка — ✅ (DUN-93)
