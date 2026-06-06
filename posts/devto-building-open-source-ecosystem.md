---
title: Building an Open-Source All-in-One Ecosystem for Your Web Presence
published: false
description: How we replaced 5+ paid services with one self-hosted stack — and you can too. Astro.js, ComfyUI, Cloudflare, and AI agents.
tags: opensource, indieweb, astro, jamstack, webdev
canonical_url: https://dunaev.dev/blog/building-open-source-ecosystem
# cover_image: design/article-og-launch.png
series: 
---

# Building an Open-Source All-in-One Ecosystem for Your Web Presence

> *How we replaced 5+ paid services with one self-hosted stack — and you can too*

---

## The Problem

If you're an indie maker, freelancer, or small team building a web presence, you know the drill:

| Service | Purpose | Monthly Cost |
|---------|---------|-------------|
| Vercel / Netlify | Hosting | $0–20 |
| Canva / Figma | Graphics | $0–15 |
| Google Analytics | Analytics | $0 |
| Mailchimp / Buttondown | Email | $0–15 |
| Buffer / Hootsuite | Social scheduling | $0–10 |
| Ahrefs / SEMrush | SEO research | $0–100 |
| **Total** | | **$0–160/mo** |

That's 5+ different logins, different UIs, different APIs, and a context switch every time you move between them. And the moment you outgrow a free tier, the price jumps 3-5x.

## The Alternative: Architect

**Architect** is an open-source platform that brings together:

1. **Static Site Generation** — Astro.js, the fastest-growing SSG with 95%+ developer satisfaction
2. **Hosting** — Cloudflare Pages / GitHub Pages / self-hosted VPS
3. **Graphics & Video Preview Generation** — ComfyUI + Stable Diffusion on local GPU
4. **Market Analysis** — competitor research, keyword analysis, trend tracking
5. **Marketing** — content planning, SMM pipeline, SEO audit, basic CRM

All in one CLI, one config, one dashboard.

### Why We Built It

We're a small team building our own products, and we got tired of:

- **Context switching** between 5+ tools
- **Surprise pricing** — every service raising prices 20-40% yearly
- **Vendor lock-in** — migrating from Netlify to anything is painful
- **No integration** — your analytics don't talk to your marketing, your hosting doesn't know about your graphics pipeline

So we spent the last month building **Architect** — not as a business, but as our own toolchain. Then we realized: *other developers have the same problems.*

### What's Inside the MVP

| Layer | Technology | Status |
|-------|-----------|--------|
| SSG | Astro.js (TypeScript) | ✅ Ready |
| Hosting | VPS + Docker / Cloudflare Pages | 🔄 Setting up CI/CD |
| Domain | dunaev.dev via Cloudflare | 🔄 DNS config |
| Graphics | ComfyUI + RTX 3070 | 🚧 Installing |
| Market Research | Paperclip agents (Researcher) | ✅ Complete |
| Marketing Strategy | Content plan, SMM, SEO, CRM | ✅ Documented |
| Analytics | Yandex Metrica / GA4 | 🚧 Integration |
| Monitoring | Uptime Kuma | 🚧 Setup |

### Architecture Overview

```
User → Astro.js SSG → Cloudflare/VPS
         ↓
    ComfyUI (GPU) → Preview Images
         ↓
    Paperclip Agents → Market Analysis + Marketing
         ↓
    GitHub Actions → CI/CD Pipeline
```

Each module runs independently, communicates via API, and can be swapped out.

### The Tech Stack

- **Frontend:** Astro.js + Tailwind CSS + TypeScript
- **Backend:** Go (Chi router) + PostgreSQL
- **Graphics:** ComfyUI + Stable Diffusion on RTX 3070
- **Video:** FFmpeg + Manim
- **Orchestration:** Paperclip + Hermes Agents
- **CI/CD:** GitHub Actions → Docker → VPS
- **DNS/CDN:** Cloudflare
- **Design System:** Dark theme, #7c3aed accent, Inter + JetBrains Mono

### What We've Learned So Far

1. **Open-source from day one** — we published the architecture and design system before writing production code. Community feedback shaped 30% of decisions.
2. **Agents are real teammates** — our Paperclip agents (Researcher, PM, QA, DevOps) work alongside humans. The Researcher wrote a 200-line market analysis that would take a human consultant 3 days.
3. **Local-first infrastructure** — everything runs on one machine (Ryzen 7700 + RTX 3070 + 30GB RAM). No cloud bills during development.
4. **Documentation is product** — every architectural decision gets an ADR, every process gets a template. Makes onboarding new agents trivial.

### Roadmap

- **Week 1-2:** MVP launch — live site + CI/CD + basic graphics
- **Week 3-4:** Content pipeline — blog, SMM, first articles
- **Month 2:** Community growth — open-source contributions, guest posts
- **Month 3:** Scale — 100 GitHub stars, 15 active installs

### Get Involved

We're building in public. Here's how you can join:

- ⭐ **Star us on GitHub** — it helps more than you think
- 🐛 **Open an issue** — bugs, feature requests, ideas
- 💬 **Join our Telegram** — Russian-speaking dev community
- 🐦 **Follow on X/Twitter** — daily #buildinpublic updates
- ✍️ **Write a guest post** — we'd love your perspective

### The Bottom Line

You don't need 5 subscriptions to have a professional web presence. With a bit of setup and the right open-source tools, you can run everything on a $0–10/mo infrastructure — and own every piece of it.

**Architect is the platform we wished existed. Now it does. And it's yours too.**

---

*Built by @dunaev. Open-source. Opinionated. Yours.*

#buildinpublic #opensource #indiemaker #astrojs #jamstack #webdev
