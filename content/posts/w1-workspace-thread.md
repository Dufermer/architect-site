---
title: "Our dev workspace: RTX 3070, Ryzen 7700, and zero cloud bills"
description: "buildinpublic thread about the hardware running Architect — all local, all owned"
pubDate: 2026-06-11
tags: ["buildinpublic", "indiemaker", "hardware", "selfhosted", "devsetup"]
channel: twitter
lang: en
type: thread
status: draft
---

1/ People keep asking what hardware runs the Architect stack. 

The answer: one PC. 

Ryzen 7700 (8C/16T) + RTX 3070 (8GB) + 30GB RAM. 

Here's how far you can push a single consumer machine 🧵

2/ **What runs on it:**

• Astro.js builds (SSG, 50+ pages) — ~8 seconds  
• CI/CD pipeline via GitHub Actions (not local)  
• ComfyUI + Stable Diffusion — 7 it/s for SDXL, ~3s per 1024×1024 image  
• PostgreSQL + Go API server (Chi router)  
• Paperclip + Hermes agents orchestrating 9 AI agents  
• FFmpeg video processing  

All simultaneously. No cloud instances.

3/ **The GPU setup (RTX 3070)**

Most people think you need an A100 or at least a 4090 for local AI. You don't.

For ComfyUI workflows:
- SDXL: 7 it/s (1024×1024, 20 steps, Euler a)  
- SD 1.5: 18 it/s  
- AnimateDiff (16 frames, 512×512): ~90s per GIF  

VRAM is the real bottleneck at 8GB — SDXL fills it completely. But for production pre-renders and batch jobs, it works.

Workaround: queue jobs overnight. Wake up to 200+ rendered images.

4/ **CPU + RAM (Ryzen 7700, 30GB)**

30GB is *just* enough for:
- PostgreSQL (index-heavy analytic queries + JSONB)  
- Go API server with hot reload  
- Node.js build process  
- 3-4 Tmux panes with agents running  

Swap kicks in during ComfyUI + Go builds simultaneously. Next upgrade: 64GB.

5/ **Storage**

2TB NVMe partitioned:
- 49GB root (Arch Linux, CachyOS)  
- 408GB /home (all projects, Docker images, ComfyUI models)  
- 61GB zram swap  

ComfyUI models alone = ~40GB (SDXL, SD 1.5, AnimateDiff, ControlNets). 

Tip: symlink `ComfyUI/models` to a dedicated SSD if you can.

6/ **The cloud bill**

$0/month.

No Vercel Pro ($20). No Canva Pro ($15). No Midjourney ($30). No Uptime Robot ($10). 

Just one machine, one electricity bill (~$15/month), and open-source software.

The only exception: Cloudflare (free tier, DNS + CDN) and GitHub (free, public repos).

7/ **Why this matters**

If you're an indie maker or small team, you don't need enterprise cloud infrastructure.

A mid-range gaming PC from 2023 can:
- Host your production website  
- Generate AI graphics for your content  
- Run CI/CD  
- Analyze your market  
- Manage your marketing  

All local. All owned. No surprises when a SaaS doubles its price.

8/ **The full stack**

```
Frontend:       Astro.js + Tailwind + TypeScript
Backend:        Go (Chi) + PostgreSQL
Graphics:       ComfyUI + SDXL/AnimateDiff on RTX 3070
Orchestration:  Paperclip + Hermes Agents (9 agents)
Hosting:        Cloudflare Pages (free) + VPS for API
CI/CD:          GitHub Actions → Docker → VPS
Domain:         dunaev.dev via Cloudflare
```

9/ I'm documenting everything at @dunaev_dev.

Architect is open source, and we're building it in public. No hype, no VC, no growth hacks. Just solid engineering and a $0 infrastructure bill.

⭐ Coming soon on GitHub
💬 @architect_dev (Telegram)

#buildinpublic #selfhosted #indiemaker #opensource #devsetup
