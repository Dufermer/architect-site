#!/usr/bin/env python3
"""
Market Monitor — Module 4 (DUN-93)
Periodic competitor monitoring, trend tracking, and digest generation.

Usage:
    python3 market_monitor.py                # Full scan + digest
    python3 market_monitor.py --digest-only   # Generate digest from cached data
    python3 market_monitor.py --competitors   # Check competitor websites
    python3 market_monitor.py --trends        # Search for trends

Schedule suggestion: daily via cron or Paperclip heartbeat
"""

import json
import subprocess
import datetime
import os
import sys

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(PROJECT_DIR, "market-data")
DIGEST_FILE = os.path.join(PROJECT_DIR, "MARKET_DIGEST.md")

os.makedirs(DATA_DIR, exist_ok=True)

# Competitors to monitor (from MARKET_ANALYSIS.md)
COMPETITORS = [
    {"name": "Netlify", "url": "https://www.netlify.com", "blog": "https://www.netlify.com/blog", "rss": "https://www.netlify.com/blog/index.xml"},
    {"name": "Vercel", "url": "https://vercel.com", "blog": "https://vercel.com/blog", "rss": "https://vercel.com/blog/rss.xml"},
    {"name": "Cloudflare", "url": "https://pages.cloudflare.com", "blog": "https://blog.cloudflare.com", "rss": "https://blog.cloudflare.com/rss/"},
    {"name": "Astro", "url": "https://astro.build", "blog": "https://astro.build/blog", "rss": "https://astro.build/rss.xml"},
    {"name": "Webflow", "url": "https://webflow.com", "blog": "https://webflow.com/blog", "rss": "https://webflow.com/blog/rss.xml"},
]

CURL_BASE = ["curl", "-s", "-L", "--max-time", "10", "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"]

TREND_KEYWORDS = [
    "Jamstack 2026",
    "Astro.js trends",
    "static site generator market",
    "AI web development",
    "serverless hosting",
]


def check_url(url: str, timeout: int = 10) -> dict:
    """Check if a URL is accessible and get HTTP status."""
    try:
        cmd = CURL_BASE + ["-o", "/dev/null", "-w", "%{http_code}", url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        code = result.stdout.strip()
        return {"url": url, "status": int(code) if code else 0, "ok": code.startswith("2") or code.startswith("3")}
    except subprocess.TimeoutExpired:
        return {"url": url, "status": 0, "ok": False, "error": "timeout"}
    except Exception as e:
        return {"url": url, "status": 0, "ok": False, "error": str(e)}


def fetch_rss(url: str, max_items: int = 5) -> list:
    """Fetch an RSS/Atom feed and extract recent entries."""
    try:
        cmd = CURL_BASE + [url]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        text = result.stdout
        if not text or len(text) < 50:
            return []

        entries = []
        # Parse <item> (RSS 2.0) or <entry> (Atom) blocks
        # Simple XML split — works for standard feeds
        import re
        for item_tag in ["<item>", "<entry>"]:
            items = text.split(item_tag)
            for item in items[1:max_items+1]:
                title = ""
                link = ""
                m = re.search(rf'<title[^>]*>(.*?)</title>', item, re.DOTALL)
                if m:
                    title = m.group(1).strip()
                    # Strip CDATA and HTML entities
                    title = title.replace("<![CDATA[", "").replace("]]>", "")
                m = re.search(r'<link[^>]*>(.*?)</link>', item, re.DOTALL)
                if m:
                    link = m.group(1).strip()
                elif '<link href="' in item:
                    m = re.search(r'<link href="(.*?)"', item)
                    if m:
                        link = m.group(1)
                if title and len(title) > 5:
                    entries.append({"title": title[:120], "link": link[:200]})
            if entries:
                break  # prefer RSS 2.0 over Atom

        return entries[:max_items]
    except Exception as e:
        return []


def check_competitors() -> list:
    """Check all competitor websites."""
    results = []
    for comp in COMPETITORS:
        status = check_url(comp["url"])
        blog_ok = check_url(comp["blog"])
        posts = []
        if blog_ok["ok"] and comp.get("rss"):
            posts = fetch_rss(comp["rss"], max_items=3)
        
        results.append({
            "name": comp["name"],
            "url": comp["url"],
            "alive": status["ok"],
            "status_code": status["status"],
            "blog_posts": posts[:5],
            "checked_at": datetime.datetime.now().isoformat(),
        })
    return results


def search_trends() -> list:
    """Search for trend keywords (uses curl for simple web searches)."""
    results = []
    for kw in TREND_KEYWORDS:
        try:
            search_url = f"https://www.google.com/search?q={kw.replace(' ', '+')}"
            result = subprocess.run(
                ["curl", "-s", "-L", "-A", "Mozilla/5.0", search_url],
                capture_output=True, text=True, timeout=15
            )
            found = len(result.stdout) > 500  # got something back
            results.append({
                "keyword": kw,
                "found_data": found,
                "checked_at": datetime.datetime.now().isoformat(),
            })
        except Exception as e:
            results.append({
                "keyword": kw,
                "error": str(e),
                "checked_at": datetime.datetime.now().isoformat(),
            })
    return results


def generate_digest(competitor_data: list, trend_data: list = None):
    """Generate a markdown digest from collected data."""
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    
    digest = [
        f"# Еженедельный дайджест рынка — Architect",
        f"",
        f"**Дата:** {now}",
        f"**Источник:** DUN-93 Market Monitor",
        f"",
        f"---",
        f"",
        f"## 1. Статус конкурентов",
        f"",
        f"| Конкурент | Доступен | Статус | Последние посты в блоге |",
        f"|-----------|:--------:|--------|------------------------|",
    ]
    
    for comp in competitor_data:
        posts_str = "; ".join([p.get("title","") for p in comp.get("posts", [])][:2]) or "—"
        status_emoji = "✅" if comp["alive"] else "❌"
        digest.append(f"| **{comp['name']}** | {status_emoji} | {comp['status_code']} | {posts_str} |")
    
    digest.extend([
        "",
        "---",
        "",
        "## 2. Тренды (поисковые запросы)",
        "",
    ])
    
    if trend_data:
        for t in trend_data:
            status = "✅ найдено" if t.get("found_data") else f"⚠️ {t.get('error', 'нет данных')}"
            digest.append(f"- **{t['keyword']}** — {status}")
    else:
        digest.append("_(поиск трендов не выполнен)_")
    
    digest.extend([
        "",
        "---",
        "",
        "## 3. Рекомендации",
        "",
        "- *Заполняется Researcher при анализе дайджеста*",
        "",
        "---",
        f"*Дайджест сгенерирован автоматически {now}*",
    ])
    
    return "\n".join(digest)


def save_competitor_data(data: list):
    """Save competitor check results to JSON."""
    filename = f"competitors_{datetime.date.today().isoformat()}.json"
    filepath = os.path.join(DATA_DIR, filename)
    with open(filepath, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"  ✓ Данные сохранены: {filepath}")


def load_latest_competitor_data() -> list:
    """Load latest competitor data from cache."""
    files = sorted([f for f in os.listdir(DATA_DIR) if f.startswith("competitors_")], reverse=True)
    if files:
        with open(os.path.join(DATA_DIR, files[0])) as f:
            return json.load(f)
    return []


def main():
    print("=" * 60)
    print("  MARKET MONITOR — DUN-93")
    print(f"  {datetime.datetime.now().isoformat()}")
    print("=" * 60)
    
    args = set(sys.argv[1:])
    
    do_competitors = "--competitors" in args or not args or "--digest-only" not in args
    do_trends = "--trends" in args or not args or "--digest-only" not in args
    digest_only = "--digest-only" in args
    
    competitor_data = []
    trend_data = []
    
    if not digest_only:
        if do_competitors:
            print("\n📡 Checking competitors...")
            competitor_data = check_competitors()
            for c in competitor_data:
                emoji = "✅" if c["alive"] else "❌"
                print(f"  {emoji} {c['name']}: HTTP {c['status_code']}")
            save_competitor_data(competitor_data)
        
        if do_trends:
            print("\n🔍 Searching trends...")
            trend_data = search_trends()
            for t in trend_data:
                print(f"  {'✅' if t.get('found_data') else '❌'} {t['keyword']}")
    else:
        competitor_data = load_latest_competitor_data()
        if competitor_data:
            print(f"\n📂 Using cached data from {DATA_DIR}")
        else:
            print("\n⚠️ No cached data found. Run full scan first.")
            return
    
    print("\n📝 Generating digest...")
    digest = generate_digest(competitor_data, trend_data)
    
    with open(DIGEST_FILE, "w") as f:
        f.write(digest)
    print(f"  ✓ Digest saved: {DIGEST_FILE}")
    
    print("\n" + digest)
    print("\n" + "=" * 60)
    print("  Done.")


if __name__ == "__main__":
    main()
