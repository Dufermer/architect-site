# Модуль M4: Анализ рынка — Свежий срез (06.06.2026)

**Автор:** Researcher (27fc8019)
**В рамках:** DUN-98 (Модуль: Анализ рынка)
**Дата:** 6 июня 2026

---

## 1. Astro.js — ключевые изменения (последние 6 месяцев)

### Присоединение к Cloudflare
- **Январь 2026:** The Astro Technology Company присоединилась к Cloudflare
- Astro остаётся MIT-licensed и platform-agnostic
- Cloudflare сфокусирован на развитии Astro как лучшего фреймворка для контентных сайтов
- Cloudflare пожертвовал $150K в Astro (сентябрь 2025)
- **Влияние на Architect:** стек Astro + Cloudflare Pages получает нативный приоритет развития

### Основные релизы
| Версия | Дата | Ключевые фичи |
|--------|------|---------------|
| **6.0** | 10.03.2026 | Rust-компилятор (эксп.), Live Content Collections, CSP, refactored dev server |
| **6.1** | 26.03.2026 | Sharp defaults, SmartyPants, i18n fallback routes |
| **6.2** | 30.04.2026 | JSON logger, SVG optimizer API, font helpers |
| **6.3** | 07.05.2026 | Advanced routing + Hono, image redirects, resilient islands |
| **6.4** | 28.05.2026 | Pluggable Markdown API, Rust-based Markdown processor, Cloudflare advanced routing |

### Партнёрства
- **TinaCMS** — стал шаблоном по умолчанию для Astro
- **CloudCannon** — официальный CMS-партнёр ($4K/мес спонсорства)
- **Webflow** — пожертвовал $150K, использует Astro для AI code gen
- **Mux** — официальный видео-партнёр

---

## 2. Состояние конкурентов

### Vercel
- Pricing-страница менялась (зафиксировано мониторингом 06.06)
- Changelog обновлялся
- **Гипотеза:** корректировка ценовой политики или новые фичи для Astro-сайтов
- Vercel ранее был официальным хостинг-партнёром Astro (2023), но после присоединения Astro к Cloudflare позиции ослабли

### Netlify
- Сайт жив (200 OK)
- Активно развивает Netlify Connect и Edge Functions
- Сохраняет позицию в Jamstack, но теряет долю на фоне Cloudflare Pages

### Cloudflare Pages
- Стратегически усилился через покупку Astro Company
- Cloudflare Workers + Astro — нативная связка с 6.4
- Бесплатный tier остаётся сильнейшим аргументом

### Webflow
- $150K в Astro, использует Astro для AI code generation
- Остаётся закрытым/дорогим — не прямой конкурент Architect

---

## 3. Тренды в нише

### Open-source экосистемы
- **Консолидация:** крупные игроки (Cloudflare) поглощают ключевые open-source проекты
- **Rust в вебе:** Astro 6.x внедряет Rust-компилятор — ускорение билдов в 3-5x
- **AI-генерация:** Webflow и Vercel внедряют AI code gen; Architect может использовать ComfyUI AI для графики как дифференциатор
- **Self-hosted возвращается:** рост интереса к самодеплою на VPS/Docker после ужесточения free-tier у Vercel/Netlify

### Content-driven web
- Astro лидирует в сегменте контентных сайтов (State of JS 2025)
- CMS-партнёрства (TinaCMS, CloudCannon, Storyblok) создают зрелый ecosystem
- MDX + Content Collections становятся стандартом

---

## 4. Рекомендации для стратегии Architect

1. **Приоритет Cloudflare-адаптера** — Astro 6.4 имеет нативные Cloudflare-хелперы. Наш стек Astro + Cloudflare Pages получает преимущество первого хода
2. **Rust-компилятор** — при переходе на Astro 6.x включить экспериментальный Rust-компилятор для ускорения билдов
3. **TinaCMS/CloudCannon** — оценить интеграцию любого из них как опционального CMS-слоя для не-разработчиков
4. **AI-графика как дифференциатор** — ни один конкурент не предоставляет встроенную ComfyUI-генерацию превью/графики. Это ключевое преимущество Architect
5. **Self-hosted narrative** — маркетинговое сообщение: "Один self-hosted набор вместо 5+ облачных подписок" попадает в тренд возвращения к самодеплою

---

## 5. Статус подзадач M4

| Задача | Статус | Что делать |
|--------|--------|------------|
| DUN-124 (мониторинг конкурентов) | in_progress | RSS + web-scraping работает, нужна донастройка триггеров |
| DUN-125 (тренды) | in_progress | Источники определены, нужна периодическая агрегация |
| DUN-126 (дайджесты) | in_progress | Шаблон готов, нужна автоматизация рассылки |
| DUN-127 (реклама конкурентов) | blocked | Ждёт DUN-124 (данные мониторинга) |
| DUN-132 (аналитика каналов) | in_progress | Сбор метрик, настройка пайплайна |
| DUN-93 (анализ рынка) | in_progress | Фундамент готов, нужен непрерывный апдейт |
| DUN-135 (передача в маркетинг) | in_progress | Шлюз Researcher → Marketing активен |
| DUN-148 (черновики контента W1/W2) | in_progress | Для PM, под контролем |
| DUN-98 (Модуль M4) | **active** | Настоящий отчёт |

---

*Следующий плановый срез: через 7 дней*
