# План рекламных кампаний — Architect

**Проект:** Architect
**Автор:** PM (ecdaa85f)
**Связано:** DUN-130, DUN-99
**Статус:** ✅ Готово (закрыт DUN-130)
**Зависит от:** DUN-101 (запуск сайта)

---

## 1. Цели кампаний (M1)

| Метрика | Цель | Срок |
|---------|------|------|
| Переходы на сайт | >500/мес | M1-W4 |
| Лиды (email/tg) | >20/мес | M1-W4 |
| Установки (git clone) | >10/мес | M1-W4 |
| CPI (cost per install) | <$5 | M1-W4 |

---

## 2. Каналы

### 2.1 Twitter/X Ads (Приоритет: высокий)

**Цель:** Привлечение технической аудитории (indie makers, devs)

| Параметр | Значение |
|----------|----------|
| Бюджет | $50/нед (тест), $200/мес (полный) |
| Формат | Промо-твиты + карусель |
| Таргетинг | Followers of: @levelsio, @shadcn, @marc_louvion, @rauchg |
| Интересы | Web development, JavaScript, Open source, Indie hacking |
| Гео | US, EU, UK |
| Креатив | Скриншот лендинга + CTA "Build your stack in 5 min" |

**Варианты CTA:**
1. "Ditch Vercel. Build your own stack for $0."
2. "Open-source ecosystem for your web presence. Try it."
3. "$140/mo → $0/mo. Here's how."

### 2.2 Telegram Ads (Приоритет: средний)

**Цель:** Привлечение русскоязычной технической аудитории

| Параметр | Значение |
|----------|----------|
| Бюджет | €2/CPM тест, ~$100/мес |
| Каналы | @pythonlom, @webdev, @startupology, @tproger_official |
| Формат | Нативное объявление (1250 символов) |
| Текст | История: как заменили 5 SaaS одним стеком |

**Пример объявления:**
```
Собрал open-source экосистему для сайта вместо Vercel + Canva + GA.
Стек: Astro.js, Cloudflare, ComfyUI.
Всё self-hosted, $0/мес (кроме домена).
Разбираю архитектуру в статье → [ссылка]
```

### 2.3 Google Ads (Приоритет: низкий / Phase 2)

**Цель:** Поисковый трафик по keywords

| Параметр | Значение |
|----------|----------|
| Бюджет | $100/мес (Phase 2) |
| Ключевые слова | astro.js hosting, open source website builder, self-hosted alternative to vercel, jamstack hosting free |
| Формат | Search ads + Performance Max |

---

## 3. Воронка (Ad → Conversion)

```
Реклама → Landing page → Lead Magnet (чеклист/гайд) → Email capture → Follow-up
```

### Этапы:

1. **Клик** — пользователь видит объявление → переходит на лендинг
2. **Лендинг** — hero с CTA "Get the free checklist" или "Try the demo"
3. **Захват** — форма email → получает лид-магнит
4. **Прогрев** — 3 письма (день 1, 3, 7):
   - День 1: "Вот твой чеклист + ссылка на GitHub"
   - День 3: "Как мы собрали стек — разбор" (ссылка на статью)
   - День 7: "Вопрос: пробовал уже? Нужна помощь?"

### UTM-разметка:

```
?utm_source={twitter|telegram|google}
&utm_medium={social|native|search}
&utm_campaign={launch-w1|stack-compare|free-checklist}
&utm_content={ad-v1|ad-v2}
```

---

## 4. Креативы (к Designer)

### Twitter промо-твиты:

1. **Скриншот дашборда** — "What if your stack cost $0?"
   - Размер: 1200×675px
   - Текст на изображении: "$140/mo → $0/mo"

2. **Архитектурная схема** — "Full-stack open source"
   - Размер: 1200×675px
   - Схема: Astro.js + Cloudflare + ComfyUI + Paperclip

3. **Сравнительная таблица** — "Architect vs Vercel vs Netlify"
   - Размер: 1200×900px
   - Колонки: Цена, Open-source, Self-hosted, AI превью

### Telegram нативные:

4. **Скриншот статьи** — "Why I left Vercel"
   - Размер: 512×512px

---

## 5. Бюджет M1

| Канал | Тест (нед) | Полный (мес) |
|-------|-----------|-------------|
| Twitter/X Ads | $50 | $200 |
| Telegram Ads | €30 | €100 |
| Google Ads | — | $100 (Phase 2) |
| **Итого** | **~$80** | **~$400** |

### KPI окупаемости:
- CPI (cost per install) < $5
- CPL (cost per lead) < $2
- ROAS > 2x (если есть монетизация)

---

## 6. A/B тесты (DUN-132)

| Тест | Вариант A | Вариант B | Метрика |
|------|-----------|-----------|---------|
| Заголовок объявления | "Open-source stack" | "Ditch Vercel" | CTR |
| CTA | "Try free" | "Get checklist" | Конверсия |
| Креатив | Скриншот | Схема | CTR |
| Лендинг | GitHub CTA | Form CTA | Конверсия |

---

**Следующий шаг:** Запуск после DUN-101 (MVP). Креативы — к Designer.
