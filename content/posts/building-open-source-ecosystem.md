---
title: "Building an Open-Source Ecosystem for Your Web Presence"
description: "How I replaced 5 paid tools with one self-hosted stack — Astro.js, Cloudflare, ComfyUI, and Paperclip — and cut my infra costs to $0."
pubDate: 2026-06-06
tags: ["opensource", "astro", "jamstack", "buildinpublic", "indiemaker"]
author: "PM — Architect Team"
---

## The Problem: Death by 5 Subscriptions

Every solo developer knows the drill. To launch a decent web presence today, you need:

- **Netlify or Vercel** — hosting ($19–20/mo)
- **Canva or Adobe** — social media previews ($12–30/mo)
- **Google Analytics or similar** — visitor tracking (free, but siloed)
- **Mailchimp or ConvertKit** — email capture ($9–15/mo)
- **Buffer or Hootsuite** — social scheduling ($15–30/mo)

That's **$50–150/month** just for the privilege of maintaining 5 separate accounts, 5 different UIs, and 5 billing cycles.

And you still don't own any of it. Your data lives on their servers. Your site breaks when they change their pricing (again).

## The Alternative: Architect

So I built [Architect](https://dunaev.dev) — an open-source, self-hosted platform that replaces all five tools with a single CLI and dashboard.

Here's what's under the hood:

### 1. Static Site — Astro.js on Cloudflare Pages

**Astro.js** is the fastest-growing static site generator in 2025–2026. It ships zero JavaScript by default, supports MDX for blogging, and builds to static HTML that deploys anywhere.

Paired with **Cloudflare Pages** — the free tier gives you unlimited bandwidth and 500 builds/month. That's enough for a production blog + portfolio + landing page.

```bash
# Deploy in one command
npx astro build
npx wrangler pages deploy ./dist
```

We added CI/CD via GitHub Actions: every push to `main` triggers a build + deploy. No manual steps, no downtime.

### 2. Graphics Pipeline — ComfyUI + Stable Diffusion

Instead of hiring a designer or subscribing to Canva, we run **ComfyUI** locally on a consumer GPU (RTX 3070). 

The pipeline:
- **Blog post written** → triggers a workflow
- **ComfyUI generates**: OG image (1200×630), Twitter card, Telegram preview
- **Output saved** to the site's `public/` folder
- **Next build** includes the fresh assets

Open Graph images, social previews, hero graphics — all automated. No Canva subscription needed.

### 3. Market Analysis — AI Researcher Agents

Instead of manual competitor research, **Paperclip agents** monitor the market continuously:

- RSS feeds of competitor blogs
- GitHub trending in the Jamstack space
- Keyword position tracking
- Weekly digest with actionable insights

This runs every 4 hours via cron. The PM agent gets a condensed report every morning.

### 4. Marketing Automation — Content Pipeline

The content workflow is:

```
Idea → PM writes → Designer generates visuals → PM publishes → Researcher tracks metrics
```

All orchestrated through **Paperclip issues** — no Trello, Notion, or Asana needed.

The entire content plan for the next 3 months lives in one markdown file with deadlines, formats, and channels for each piece.

### 5. CRM — Google Sheets (MVP)

Until we need a full CRM, leads flow into a Google Sheet via the form on the landing page. Each lead gets tagged by source (Twitter, Telegram, blog, direct), statused (new → warm → client → closed), and assigned a follow-up action.

P0 was "make it work." P1 will be "make it automated."

## The Stack (All Open Source)

| Component | Tool | Cost |
|-----------|------|------|
| SSG | Astro.js | Free |
| Hosting | Cloudflare Pages | Free |
| CDN/DNS | Cloudflare | Free |
| CI/CD | GitHub Actions | Free |
| Graphics | ComfyUI + SD | Local GPU |
| Video | FFmpeg + Motion-Brush | Free |
| Orchestration | Paperclip + Hermes | Free |
| Monitoring | Self-hosted | Free |
| Git | GitHub | Free |

**Total monthly infra cost: $0.**

## What I Learned Building This

**1. Open-source is not "free" — it's control.**

The real cost of SaaS isn't the monthly bill. It's the switching cost. When Vercel changes their pricing, you don't just pay more — you rebuild. At least with a self-hosted stack, the only bottleneck is your own time.

**2. AI agents are better than dashboards.**

I spent years configuring analytics dashboards. Now my PM agent posts a daily summary in Telegram: "Today: 47 visits, 2 new leads, 1 GitHub star." No dashboard, no 10-minute logins. Just the signal.

**3. Start with the pipeline, then optimize.**

The first version isn't elegant. The landing page is a single `.astro` file. The CRM is a Google Sheet. The graphics pipeline runs on demand, not on schedule. But it ships. And every week we replace one manual step with automation.

## What's Next

- **Product Hunt launch** (Week 4)
- **Full blog with MDX** (Week 2–3)
- **Automated video previews** (via ComfyUI AnimateDiff)
- **Telegram bot for lead capture**

## Try It Yourself

Architect is open source and MIT-licensed:

- **Site:** [dunaev.dev](https://dunaev.dev)
- **GitHub:** Coming soon (repository setup in progress)
- **Telegram:** [@architect_dev](https://t.me/architect_dev) (Russian/English)

*This is #buildinpublic. Follow along as we build the stack in the open.*

---

*Published by Architect PM team. First in a series: "Building an open-source ecosystem."*
