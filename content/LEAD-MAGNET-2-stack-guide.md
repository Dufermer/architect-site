# Гайд: Open-source стек веб-присутствия за $0

**Проект:** Architect
**Автор:** PM (ecdaa85f)
**Связано:** DUN-134 / Лид-магнит #2
**Формат:** Гайд / PDF (скачивание по email)
**Дата:** 2026-06-06

---

## Вступление

Ты платишь $20–200/мес за Vercel, Netlify, WordPress, Notion — и всё равно не контролируешь свой стек.

Что если собрать production-ready экосистему, которая стоит **$1/мес** (только домен), работает быстрее, и вся — open-source?

Вот точный список: что, зачем и как настроить за один вечер.

---

## 1. Сайт — Astro.js

**Стоимость:** $0 (бесплатный open-source)
**Что даёт:** статический сайт с производительностью 95+ Lighthouse из коробки

Почему Astro:
- Нулевой JS по умолчанию — страницы грузятся мгновенно
- .astro + .mdx — пиши контент в Markdown, оборачивай в компоненты
- Островная архитектура — интерактив только там, где нужен
- Билд в статику — можно хостить где угодно

```
# quick-start.sh
npm create astro@latest ./mysite -- --template blog
cd mysite
npm run dev
```

---

## 2. Хостинг — Cloudflare Pages

**Стоимость:** $0 (бесплатный тариф)
**Что даёт:** CDN по всему миру, SSL, автоматический деплой

Cloudflare Pages:
- Неограниченная полоса пропускания (free tier)
- Автоматический HTTPS
- Деплой из GitHub: push → build → live
- 500 сборок/месяц, 1 билдер, 500 MB хранилища

```
# wrangler.toml
name = "mysite"
compatibility_date = "2024-12-01"
```

---

## 3. CI/CD — GitHub Actions

**Стоимость:** $0 (2000 минут/мес для публичных репозиториев)
**Что даёт:** автоматическая сборка и деплой при каждом push

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install && npm run build
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CF_API_TOKEN }}
```

---

## 4. Домен — .dev за $12/год

**Стоимость:** $1/мес ($12/год)
**Где купить:** namecheap, reg.ru, porkbun

Подключение к Cloudflare:
1. Добавить домен в Cloudflare
2. Сменить NS-записи на cloudflare
3. CNAME на pages.dev
4. SSL — автоматически

---

## 5. Аналитика — Cloudflare Web Analytics

**Стоимость:** $0
**Что даёт:** базовая аналитика без cookie-баннеров и GDPR-головной боли

Альтернативы:
- **Plausible** — $0 self-hosted (1 строка кода), или $9/мес cloud
- **Umami** — $0 self-hosted
- **GoatCounter** — $0 для некоммерческих

---

## 6. Мониторинг — Healthchecks.io / UptimeRobot

**Стоимость:** $0
**Что даёт:** уведомления, если сайт упал

- Healthchecks.io — 20 мониторов бесплатно (cron-based)
- UptimeRobot — 50 мониторов, 5-мин интервал
- Better Uptime — статус-страница + алерты

---

## 7. AI-превью — ComfyUI (локально)

**Стоимость:** $0 (на твоём GPU, с RTX 3060+)
**Что даёт:** генерация превью для статей, Open Graph картинок, баннеров

Стек:
- Stable Diffusion SDXL — генерация изображений
- AnimateDiff — короткие видео-превью
- IP-Adapter — генерация в едином стиле

---

## Итоговая смета

| Компонент | Сервис | Цена/мес |
|-----------|--------|---------|
| Сайт | Astro.js | $0 |
| Хостинг | Cloudflare Pages | $0 |
| CI/CD | GitHub Actions | $0 |
| Домен | .dev через namecheap | **$1** |
| Аналитика | Cloudflare WA | $0 |
| Мониторинг | Healthchecks.io | $0 |
| AI-превью | ComfyUI (self-hosted) | $0 |
| **Итого** | | **$1/мес** |

Сравни с:
- Vercel Pro — $20/мес
- Netlify Pro — $19/мес
- WordPress Business — $25/мес
- Webflow — $23/мес

## Что дальше?

[Скачать чеклист "10 шагов к self-hosted" →](./LEAD-MAGNET-1-checklist.md)
[Посмотреть архитектуру Architect →](../ARCHITECTURE.md)
