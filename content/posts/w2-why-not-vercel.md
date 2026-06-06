---
title: "Why I built my own stack instead of using Vercel"
description: "A practical comparison: Architect self-hosted vs Vercel — costs, control, and trade-offs"
pubDate: 2026-06-13
tags: ["vercel", "selfhosted", "architecture", "comparison", "indiemaker"]
channel: twitter
lang: en
type: thread
status: draft
---

1/ Everyone told me to "just use Vercel." $20/mo, auto-deploy, edge functions, analytics.

But over 6 months, that $20 turned into $140 across 7 tools. And I still didn't own my data.

Here's why I built Architect instead.

2/ The real cost of Vercel isn't $20/mo.

• Vercel Pro: $20
• Analytics (if >10k visits): $15–50
• Image optimization (if >1k images): add-on
• Edge config: limited without Enterprise

"Free tier" is marketing. The moment you grow, you pay.

3/ But cost isn't the main reason.

The main reason is CONTROL.

With Vercel:
- Your builds run on their infra
- Your edge config is abstracted
- Want to add a custom service? Hope they support it
- Migrating off? Rewrite your deployment

4/ With Architect (self-hosted):

✅ Astro.js SSG — same DX as Next.js, no Vercel lock-in
✅ Own VPS — full root access, no rate limits
✅ Cloudflare for CDN — free tier handles most traffic
✅ ComfyUI on local GPU — generate graphics without SaaS
✅ Paperclip agents — PM, marketing, monitoring all in one

Cost: $0–10/mo for the VPS. That's it.

5/ What you lose:

🔄 No "instant deploy" — you manage CI/CD yourself
🔄 No edge functions — use Cloudflare Workers or nginx
🔄 No built-in analytics — Plausible/Umami instead (self-hosted)

These are solvable problems. Vendor lock-in is not.

6/ The result?

For a project getting 5k–50k visits/mo:
• Vercel stack: $40–140/mo
• Architect stack: $5–15/mo

Same speed (Cloudflare CDN). More control. No surprise bills.

And everything is documented and open-source.

7/ This isn't a "Vercel bad" post. Vercel is great for teams that need to ship fast and don't mind paying.

But for indie makers, side projects, and builders who value ownership — self-hosting is viable.

I built the full comparison with numbers in my blog. Link in bio.

#buildinpublic #indiemaker #selfhosted #opensource
