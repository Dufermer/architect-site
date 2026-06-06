# W2: Architecture Deep Dive — How Architect Is Built

**Date:** 2026-06-06
**Author:** PM (ecdaa85f)
**Project:** Architect
**Series:** Open-Source Ecosystem (Week 2)
**Format:** Technical deep-dive (5-7 min read)
**Target:** Dev.to, Twitter/X, Telegram

---

## The Architecture Behind Architect

Last week I introduced the concept: one self-hosted stack to replace 7+ SaaS tools. Now let's open the hood and show you how Architect is actually built — every component, every connection, and why we chose what we chose.

What started as "let's save $140/month" turned into a surprisingly elegant system architecture. Here's the full breakdown.

---

## TL;DR — The Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | Astro.js + Tailwind CSS | Static site + blog (SSG/SSR hybrid) |
| **Backend** | Go (Chi + PostgreSQL) | API server, analytics, data |
| **Graphics** | ComfyUI + Stable Diffusion | AI-generated images, video |
| **Infrastructure** | Docker + Nginx + VPS | Hosting, reverse proxy, SSL |
| **DNS/WAF** | Cloudflare (gateway.pro) | DNS, DDoS protection, CDN |
| **CI/CD** | GitHub Actions | Auto-deploy on push |
| **Orchestration** | Paperclip + Hermes Agents | AI-driven task management |
| **Monitoring** | Uptime Kuma + custom scripts | Health checks, alerts |
| **Content** | MDX (Markdown + JSX) | Blog posts with interactive elements |
| **Security** | UFW firewall + fail2ban | Server hardening |

All running on a single VPS ($13.50/month) with 30GB of active open-source tooling and about 2GB actual usage for the core services.

---

## Why This Architecture?

### The Problem We Started With

The typical indie-developer stack looks like this:

- **Vercel** — $20/month for static hosting
- **Vercel Analytics** — $30/month
- **Netlify** — $19/month for forms + functions
- **Canva Pro** — $13/month for graphics
- **Notion** — $10/month for docs
- **Figma** — $12/month for design
- **Render** — $7/month for backend
- **Sentry** — $26/month for error tracking
- **Upstash** — $10/month for Redis

**Total: ~$147/month.**

And that's the *indie* tier. Scale up and you're at $500+.

### Our Alternative

We replaced all of that with:

1. A **VPS** ($13.50/month at Masterhost)
2. **Open-source software** (free)
3. **AI agents** (Paperclip + Hermes running on our own LLM — $0 inference via DeepSeek)

---

## Module 1: Site + Hosting (DevOps)

### Infrastructure Layout

```
Internet → Cloudflare (proxy) → VPS :443 → Nginx → Docker containers
                                                          │
                                              ┌───────────┼───────────┐
                                              ▼           ▼           ▼
                                          Astro.js     Go API     ComfyUI
                                          (static)     (backend)   (AI)
```

### Why VPS Over Serverless?

Serverless is convenient but expensive at scale. A $13 VPS gives us:
- Full control over the stack
- No cold starts
- Predictable pricing
- Room to grow (we can bump to $50/month and get 4x the resources)

### Nginx as Reverse Proxy

Every service runs in its own Docker container with port mapping. Nginx handles:
- SSL termination (via Cloudflare Origin CA)
- Routing: `/ → Astro`, `/api → Go`, `/comfy → ComfyUI`
- Rate limiting
- Static file caching

---

## Module 2: Site Development (Lead Engineer)

### Astro.js — Why Not Next.js?

We chose Astro over Next.js for three reasons:

1. **Zero JS by default** — Most pages are static content. Why ship React to read a blog post?
2. **Partial hydration** — Interactive components only where needed. Islands architecture.
3. **MDX-native** — Full blog support, interactive code samples, embedded diagrams.

### The Go API Server

For dynamic content (forms, analytics, lead tracking) we use a lightweight Go server:
- **Chi router** — idiomatic, composable
- **PostgreSQL** — one database for everything
- **Clean REST** — no GraphQL overhead for MVP

### The Vision Service

One unique feature: an AI-powered image analysis service that runs locally via our ComfyUI pipeline. This lets us:
- Auto-generate OG images for blog posts
- Analyze and tag uploaded images
- Generate social media cards programmatically

---

## Module 3: Graphics + Video (Designer)

### ComfyUI Pipeline

```
Text Prompt → ComfyUI (SDXL) → Post-processing → 1200×630 OG Image
                                                     │
                                                     ▼
                                           Twitter card / Telegram preview
```

We use ComfyUI because:
- **Visual node editor** — non-destructive, easy to iterate
- **Modular** — swap models, add LoRAs, chain workflows
- **API-first** — integrates with our automation pipeline

### Why Local Generation?

Cloud image generation APIs (DALL-E, Midjourney) cost $10-60/month and have usage limits. Running Stable Diffusion locally:
- **Free** after hardware cost
- **Unlimited** generation
- **Private** — no prompt sent to third parties
- **Fast** — ~2-5 seconds per image on RTX 3070

---

## Module 4: Orchestration (Paperclip + Hermes)

This is the secret sauce. Instead of a human project manager, Architect runs on **AI agents** coordinated through Paperclip:

### The Agent Team

| Agent | Role | Responsibilities |
|-------|------|-----------------|
| **SEO.SYS** | CEO / Systems Engineer | Sets goals, delegates, audits |
| **DevOps** | Infrastructure | Docker, Nginx, CI/CD, security |
| **Lead Engineer** | Development | Site, API, features |
| **Designer** | Graphics | ComfyUI, brand kit, visuals |
| **Researcher** | Market Analysis | Competitors, trends, data |
| **PM** | Marketing | Content calendar, SMM, CRM |
| **Critics (QA/CTO/Researcher)** | Review Board | Quality check on decisions |

### How It Works

1. **SEO.SYS** runs a routine every 4 hours: scans system health, creates/assigns issues
2. **Agents** wake, pick up their tasks, execute, and report back
3. **Critics** review decisions and give feedback
4. **Everything** is tracked in Paperclip as issues, comments, and statuses

### Real Numbers

As of today:
- **86 issues** created
- **~60 completed**
- **9 active agents**
- **20+ in progress**
- Zero human intervention for task management

---

## Module 5: Marketing & Content (PM)

Content production runs on a 30-day calendar:

| Week | Theme | Format |
|------|-------|--------|
| W1 | Launch & Ecosystem | Manifesto article |
| W2 | Architecture Deep Dive | Technical breakdown |
| W3 | AI Graphics Guide | Tutorial + demo |
| W4 | MVP Release | Launch post |

Each article is produced in EN (Dev.to/Twitter) and RU (Habr/Telegram).

---

## The Cost Breakdown

| Service | Monthly Cost | SaaS Alternative Cost |
|---------|-------------|----------------------|
| VPS (Masterhost) | $13.50 | — |
| Domain (dunaev.dev) | $1.00/mo amortized | — |
| Cloudflare (free tier) | $0 | $20-200 (CDN/WAF) |
| AI Image Generation | $0 (local GPU) | $10-60 (DALL-E/Midjourney) |
| CI/CD | $0 (GitHub free) | $20-50 (CircleCI/Netlify) |
| Monitoring | $0 (Uptime Kuma) | $10-30 (Better Stack/Sentry) |
| Task Management | $0 (Paperclip) | $10-25 (Linear/Jira) |
| **Total** | **~$14.50/mo** | **$70-365/mo** |

---

## What We Learned

1. **Start with the bottleneck.** Our DevOps agent has 9 high-priority tasks — that's where we should have focused first.
2. **AI agents work at this scale.** Paperclip + Hermes handles ~20 concurrent tasks without human oversight.
3. **Self-hosting doesn't mean DIY.** The infrastructure is real — Docker, Nginx, CI/CD — but the management is automated.
4. **Content needs visuals.** The biggest blocker for our Week 1 article wasn't the text — it was the designer graphics.

---

## What's Next

- **ComfyUI pipeline** — going from manual to automated image generation
- **Blog launch** — MDX-powered blog on the main site
- **Product Hunt launch** — Week 4 target
- **Backup automation** — redundant database snapshots

### Try It Yourself

Architect is open-source. Everything we build goes to GitHub:

- [GitHub Repository] (coming soon — blocked on CI/CD)
- [Architect Docs](https://dunaev.dev) (coming soon — blocked on deployment)
- [Follow on Twitter](https://twitter.com/dunaev) for daily updates

---

*Want weekly updates? We're building in public — every issue, every decision, every mistake. Follow along.*
