# W3: Architect vs Vercel vs Netlify vs Self-hosted — comparison thread

**Канал:** X/Twitter (EN) + Telegram (RU)
**Формат:** Twitter thread / Telegram пост
**Дата:** W3 Day 18 (23.06.2026)

---

## Twitter Thread Draft (EN)

**Tweet 1/8:**
> We compared 4 hosting approaches for an indie dev site:
>
> • Vercel (💰 $20/mo Pro)
> • Netlify ($19/mo Pro)
> • Pure self-hosted ($5-10/mo VPS)
> • Architect (our open-source stack)
>
> Thread with real numbers 🧵

**Tweet 2/8:**
> Static site hosting — the baseline:
>
> | Platform | Free tier | Cold start | Custom domain |
> |---------|----------|------------|---------------|
> | Vercel  | 100GB BW | ~50ms | ✅ Free SSL |
> | Netlify | 100GB BW | ~100ms | ✅ Free SSL |
> | Self-host (Nginx) | Unlimited | ~5ms | ✅ |
> | Architect | Unlimited | ~5ms | ✅ Cloudflare |
>
> Winner for simple sites: Self-host (free after VPS)

**Tweet 3/8:**
> Git integration / CI/CD:
>
> Vercel/Netlify: push → deploy in 30s. Zero config.
> Self-host: need GitHub Actions + Docker. ~2 hrs to set up.
> Architect: GitHub Actions → Docker → VPS. Same as self-host, but documented as a playbook.
>
> Winner for DX: Vercel. Winner for control: Self-host/Architect.

**Tweet 4/8:**
> Dynamic features (API, auth, DB):
>
> Vercel: Edge Functions + KV/Postgres (💰 extra)
> Netlify: Functions + Fauna (💸)
> Self-host: Any stack you want (Go/Postgres/Nginx)
> Architect: Go API + PostgreSQL — running on same $5 VPS
>
> Winner for flexibility: Self-host/Architect

**Tweet 5/8:**
> Image generation & previews:
>
> Vercel: Vercel OG (💰 $20/mo or self-host img proxy)
> Netlify: ❌ No native OG tool
> Self-host: Any tool you install
> Architect: ComfyUI + RTX 3070 — $0 per generation
>
> Winner for media-heavy sites: Architect

**Tweet 6/8:**
> What you actually pay per month:
>
> Vercel Pro: ~$25/mo (Pro plan + overages)
> Netlify Pro: ~$25/mo
> Self-host VPS: $5-10/mo (Hetzner)
> Architect: ~$5-7/mo (VPS + domain)
>
> Annual savings: Architect saves ~$200-240/yr vs Vercel/Netlify Pro.

**Tweet 7/8:**
> The trade-offs:
>
> Vercel/Netlify ✅ Set up in 10 min, managed infrastructure
> Vercel/Netlify ❌ Vendor lock-in, paid features, BW limits
>
> Self-host/Architect ✅ Full control, $0 marginal cost, no lock-in
> Self-host/Architect ❌ You maintain it, 2-3 hr initial setup
>
> Pick your trade-off.

**Tweet 8/8:**
> Architect is our attempt at having both:
> • Control of self-hosting
> • DX of modern platforms
> • Integrated graphics pipeline
> • Paperclip agent orchestration
>
> Open source → github.com/dufermer/architect-site
>
> ⭐ and feedback welcome! #buildinpublic #opensource

---

## Telegram version (RU)

**Пост: Architect vs Vercel vs Netlify vs self-hosted — голые цифры**

Сравнили 4 подхода для хостинга сайта инди-разработчика. Вот что получилось.

**Ежемесячные расходы:**

- Vercel Pro: ~$25/мес (+ оверчарги при превышении BW)
- Netlify Pro: ~$25/мес (аналогично)
- Self-host на VPS: $5-10/мес (Hetzner)
- Architect: ~$5-7/мес (VPS 5$ + домен ~$2)

**Годовая экономия Architect vs Vercel:** ~$200-240.

**Когда Vercel/Netlify удобнее:**
- Запустить за 10 минут без настройки сервера
- Managed SSL, CDN, деплой из коробки
- Не нужно думать об uptime

**Когда self-host/Architect выигрывает:**
- Нет вендор-лока — полный контроль
- Бесплатная генерация превью через Stable Diffusion
- Безлимитный трафик в рамках VPS
- Весь стек на одной машине под вашим SSH

**Вывод:** Если у вас высоконагруженный проект с медиа (превью, графика, видео) — self-host с архитектурой как у нас окупается за 2-3 месяца. Для простого лендинга Vercel/Netlify проще.

Мы выбрали третий путь — Architect даёт контроль self-hostinga с DX, приближенным к Vercel. Открытый исходник, можете форкнуть.

#индиразработка #opensource #вебразработка
