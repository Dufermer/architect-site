#!/usr/bin/env python3
"""
Competitor Monitor — система автоматического мониторинга конкурентов
для проекта Architect.

Возможности:
- RSS/Atom-мониторинг новостей конкурентов
- Веб-скрапинг ключевых страниц (блоги, changelog, цены)
- Обнаружение изменений (diff-детекция)
- Экспорт в Markdown-отчёт
- Хранение снапшотов по дням

Использование:
  python3 competitor-monitor.py --update    # полный цикл сбора
  python3 competitor-monitor.py --report    # сформировать отчёт
  python3 competitor-monitor.py --watch     # фоновый режим (1 раз в час)
"""

import json
import os
import re
import sys
import time
import hashlib
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# Paperclip-уведомления
# ═══════════════════════════════════════════════════════════════════════════════

PAPERCLIP_BASE = os.environ.get(
    "PAPERCLIP_API_BASE", "http://127.0.0.1:3100/api"
)
PAPERCLIP_COMPANY = os.environ.get(
    "PAPERCLIP_COMPANY_ID", "7c1f2d87-dfe6-41f6-b48d-03e616548709"
)
PAPERCLIP_ISSUE = os.environ.get(
    "PAPERCLIP_NOTIFY_ISSUE", "DUN-124"
)
PAPERCLIP_AGENT_ID = os.environ.get(
    "PAPERCLIP_AGENT_ID", "27fc8019-add3-478f-9e89-b80bfa38ada7"
)


def notify_new_entries(rss_data: dict, page_changes: dict) -> str | None:
    # Отправляет уведомление о найденных изменениях в Paperclip issue как комментарий
    new_rss = rss_data.get("new_entries", [])
    page_diffs = page_changes.get("pages", [])
    total_changes = len(new_rss) + len(page_diffs)

    if total_changes == 0:
        log("Нет изменений — пропускаем уведомление")
        return None

    # Формируем Markdown-тело комментария
    lines = [
        f"**🔔 Мониторинг конкурентов — обнаружено изменений: {total_changes}**",
        "",
    ]
    if new_rss:
        lines.append(f"### Новые RSS-записи ({len(new_rss)})")
        for e in new_rss[:5]:
            title = e.get("title", "—")[:120]
            source = e.get("source", "?")
            lines.append(f"- [{title}]({e.get('url', '#')}) — _{source}_")
        if len(new_rss) > 5:
            lines.append(f"  *...и ещё {len(new_rss) - 5} записей*")
        lines.append("")

    if page_diffs:
        lines.append(f"### Изменения на страницах ({len(page_diffs)})")
        for ch in page_diffs:
            lines.append(
                f"- **{ch['competitor']}** — {ch['page_type']}: [ссылка]({ch['url']})"
            )
        lines.append("")

    lines.append(f"*Полный отчёт: research/COMPETITOR_MONITOR_REPORT.md*")

    body = "\n".join(lines)

    # POST-запрос к Paperclip API
    import urllib.parse

    url = f"{PAPERCLIP_BASE}/issues/{PAPERCLIP_ISSUE}/comments"
    payload = json.dumps({
        "body": body,
        "authorAgentId": PAPERCLIP_AGENT_ID,
    }).encode("utf-8")

    try:
        req = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Architect-CompetitorMonitor/1.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = resp.read().decode("utf-8")
            log(f"Уведомление отправлено в Issue {PAPERCLIP_ISSUE} (HTTP {resp.status})")
            return result
    except Exception as e:
        log(f"[WARN] Не удалось отправить уведомление в Paperclip: {e}")
        # Пробуем альтернативный путь: issues без company prefix
        try:
            url2 = f"{PAPERCLIP_BASE}/companies/{PAPERCLIP_COMPANY}/issues/{PAPERCLIP_ISSUE}/comments"
            req2 = urllib.request.Request(
                url2,
                data=payload,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Architect-CompetitorMonitor/1.0",
                },
                method="POST",
            )
            with urllib.request.urlopen(req2, timeout=10) as resp2:
                result = resp2.read().decode("utf-8")
                log(f"Уведомление отправлено (альтернативный путь, HTTP {resp2.status})")
                return result
        except Exception as e2:
            log(f"[WARN] Альтернативный путь тоже не сработал: {e2}")
            return None


def notify_digest(rss_data: dict, page_changes: dict):
    # Краткий дайджест для консоли/лога
    new_rss = rss_data.get("new_entries", [])
    page_diffs = page_changes.get("pages", [])
    total = len(new_rss) + len(page_diffs)
    log(f"📊 Дайджест: {len(new_rss)} новых RSS, {len(page_diffs)} изменений на страницах")
    for e in new_rss[:3]:
        log(f"  📰 {e['source']}: {e['title'][:80]}")
    for ch in page_diffs[:3]:
        log(f"  🔄 {ch['competitor']} — {ch['page_type']} изменился")


# ═══════════════════════════════════════════════════════════════════════════════

# ─── Конфигурация ───────────────────────────────────────────────────────────

BASE_DIR = Path(__file__).parent.resolve()
DATA_DIR = BASE_DIR / "competitor_data"
SNAPSHOTS_DIR = DATA_DIR / "snapshots"
REPORTS_DIR = DATA_DIR / "reports"

COMPETITORS = {
    "netlify": {
        "name": "Netlify",
        "url": "https://www.netlify.com",
        "blog_rss": "https://www.netlify.com/changelog/feed.xml",
        "changelog": "https://www.netlify.com/changelog/",
        "pricing": "https://www.netlify.com/pricing/",
        "rss_timeout": 10,
    },
    "vercel": {
        "name": "Vercel",
        "url": "https://vercel.com",
        "blog_rss": "https://vercel.com/atom",
        "changelog": "https://vercel.com/changelog",
        "pricing": "https://vercel.com/pricing",
        "rss_timeout": 10,
    },
    "cloudflare": {
        "name": "Cloudflare",
        "url": "https://www.cloudflare.com",
        "blog_rss": "https://blog.cloudflare.com/rss/",
        "changelog": None,
        "pricing": None,
        "rss_timeout": 15,
    },
    "astro": {
        "name": "Astro",
        "url": "https://astro.build",
        "blog_rss": "https://astro.build/rss.xml",
        "changelog": None,
        "pricing": None,
        "rss_timeout": 15,
    },
    "webflow": {
        "name": "Webflow",
        "url": "https://webflow.com",
        "blog_rss": "https://webflow.com/blog/rss.xml",
        "changelog": "https://webflow.com/changelog",
        "pricing": "https://webflow.com/pricing",
        "rss_timeout": 15,
    },
}

# Прочие источники трендов
TREND_SOURCES = [
    {"name": "Product Hunt — Trending", "rss": "https://www.producthunt.com/feed", "timeout": 8},
    {"name": "Hacker News — Front Page", "rss": "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=10", "timeout": 8},
    {"name": "Hacker News — Show", "rss": "https://hn.algolia.com/api/v1/search?tags=show&hitsPerPage=10", "timeout": 8},
    {"name": "ArXiv — AI/CS", "rss": "https://rss.arxiv.org/rss/cs.AI", "timeout": 20},
    {"name": "ArXiv — Distributed Systems", "rss": "https://rss.arxiv.org/rss/cs.DC", "timeout": 20},
]


# ─── Вспомогательные функции ────────────────────────────────────────────────

def ensure_dirs():
    """Создаёт структуру директорий для данных."""
    for d in [DATA_DIR, SNAPSHOTS_DIR, REPORTS_DIR]:
        d.mkdir(parents=True, exist_ok=True)


def fetch_url(url: str, timeout: int = 10) -> str | None:
    """Загружает содержимое URL с обработкой ошибок."""
    if not url:
        return None
    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "Architect-CompetitorMonitor/1.0 (+https://github.com/architect-research)"
            },
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  [WARN] Не удалось загрузить {url}: {e}")
        return None


def hash_content(content: str) -> str:
    """SHA256 хеш содержимого для детекции изменений."""
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def now_iso() -> str:
    """ISO-формат времени с часовым поясом."""
    return datetime.now(timezone.utc).isoformat()


def log(msg: str):
    """Форматированный лог."""
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}")


# ─── RSS-парсинг ────────────────────────────────────────────────────────────

def parse_rss(content: str, source_name: str) -> list[dict]:
    """Парсит RSS/Atom ленту и возвращает список записей."""
    entries = []

    try:
        root = ET.fromstring(content)
    except ET.ParseError as e:
        log(f"  Ошибка парсинга RSS {source_name}: {e}")
        return entries

    # Пробуем стандартный RSS 2.0
    for item in root.iter("item"):
        title = item.findtext("title", "")
        link = item.findtext("link", "")
        pub_date = item.findtext("pubDate", "")
        description = item.findtext("description", "")[:500]
        entries.append({
            "source": source_name,
            "title": title,
            "url": link,
            "published": pub_date,
            "snippet": description,
            "detected_at": now_iso(),
        })

    # Пробуем Atom
    if not entries:
        ns = {"atom": "http://www.w3.org/2005/Atom"}
        for entry in root.iter("atom:entry"):
            title = entry.findtext("atom:title", "", ns)
            link_el = entry.find("atom:link", ns)
            link = link_el.get("href", "") if link_el is not None else ""
            published = entry.findtext("atom:published", "", ns)
            updated = entry.findtext("atom:updated", "", ns)
            summary = entry.findtext("atom:summary", "", ns)[:500]
            entries.append({
                "source": source_name,
                "title": title,
                "url": link,
                "published": published or updated,
                "snippet": summary,
                "detected_at": now_iso(),
            })

    # Пробуем Atom без namespace (некоторые фиды)
    if not entries:
        for entry in root.iter("entry"):
            title = entry.findtext("title", "")
            link_el = entry.find("link")
            link = link_el.get("href", "") if link_el is not None else ""
            published = entry.findtext("published", "")
            updated = entry.findtext("updated", "")
            summary = entry.findtext("summary", "")[:500]
            entries.append({
                "source": source_name,
                "title": title,
                "url": link,
                "published": published or updated,
                "snippet": summary,
                "detected_at": now_iso(),
            })

    return entries


# ─── Загрузка/сохранение состояния ──────────────────────────────────────────

def load_seen_entries() -> set[str]:
    """Загружает хеши уже виденных записей."""
    seen_file = DATA_DIR / "seen_entries.json"
    if seen_file.exists():
        with open(seen_file) as f:
            return set(json.load(f))
    return set()


def save_seen_entries(entries: set[str]):
    """Сохраняет хеши виденных записей."""
    seen_file = DATA_DIR / "seen_entries.json"
    with open(seen_file, "w") as f:
        json.dump(list(entries), f, indent=2)


def load_snapshots() -> dict:
    """Загружает историю снапшотов."""
    snap_file = DATA_DIR / "snapshot_history.json"
    if snap_file.exists():
        with open(snap_file) as f:
            return json.load(f)
    return {}


def save_snapshots(snapshots: dict):
    snap_file = DATA_DIR / "snapshot_history.json"
    with open(snap_file, "w") as f:
        json.dump(snapshots, f, indent=2, ensure_ascii=False)


LAST_DATA_FILE = DATA_DIR / "last_data.json"


def save_last_data(rss_data: dict):
    """Сохраняет последние собранные RSS-данные для быстрого отчёта."""
    with open(LAST_DATA_FILE, "w") as f:
        json.dump(rss_data, f, indent=2, ensure_ascii=False)


def load_cached_data() -> dict:
    """Загружает последние собранные RSS-данные (без повторного сбора)."""
    if LAST_DATA_FILE.exists():
        with open(LAST_DATA_FILE) as f:
            return json.load(f)
    return {"competitors": [], "trends": [], "new_entries": [], "collected_at": None}


# ─── Основные модули ────────────────────────────────────────────────────────

def collect_rss() -> dict:
    """Собирает RSS-ленты со всех конкурентов и трендовых источников."""
    log("=== Сбор RSS-лент ===")

    results = {
        "competitors": [],
        "trends": [],
        "new_entries": [],
        "collected_at": now_iso(),
    }

    seen = load_seen_entries()

    # Сбор с конкурентов
    for key, comp in COMPETITORS.items():
        rss_url = comp.get("blog_rss")
        if not rss_url:
            continue
        log(f"Читаю {comp['name']} RSS: {rss_url}")
        timeout = comp.get("rss_timeout", 10)
        content = fetch_url(rss_url, timeout=timeout)
        if content:
            entries = parse_rss(content, comp["name"])
            new_count = 0
            for entry in entries:
                entry_hash = hash_content(entry["title"] + entry["url"])
                if entry_hash not in seen:
                    seen.add(entry_hash)
                    results["new_entries"].append(entry)
                    new_count += 1
            results["competitors"].extend(entries)
            log(f"  → {len(entries)} записей, {new_count} новых")
        time.sleep(0.5)  # вежливая пауза

    # Сбор трендовых источников
    for src in TREND_SOURCES:
        url = src["rss"]
        log(f"Читаю тренды: {src['name']}")
        timeout = src.get("timeout", 8)
        content = fetch_url(url, timeout=timeout)
        if content:
            # Determine if this is JSON API (HN Algolia) or XML (RSS/Atom)
            if url.startswith("https://hn.algolia.com/"):
                entries = parse_hn_algolia(content, src["name"])
            else:
                entries = parse_rss(content, src["name"])
            new_count = 0
            for entry in entries:
                entry_hash = hash_content(entry["title"] + entry["url"])
                if entry_hash not in seen:
                    seen.add(entry_hash)
                    results["new_entries"].append(entry)
                    new_count += 1
            results["trends"].extend(entries)
            log(f"  → {len(entries)} записей, {new_count} новых")

    save_seen_entries(seen)
    log(f"Всего новых записей: {len(results['new_entries'])}")
    return results


def check_pages_changes() -> dict:
    """Проверяет изменения на ключевых страницах (цены, changelog)."""
    log("=== Проверка изменений на страницах ===")

    snapshots = load_snapshots()
    changes = {
        "pages": [],
        "changed_at": now_iso(),
    }

    for key, comp in COMPETITORS.items():
        for page_type in ["pricing", "changelog"]:
            url = comp.get(page_type)
            if not url:
                continue
            log(f"Проверяю {comp['name']} — {page_type}: {url}")
            content = fetch_url(url)
            if content is None:
                continue

            content_hash = hash_content(content)
            snap_key = f"{key}_{page_type}"
            old_hash = snapshots.get(snap_key, {}).get("hash")

            if old_hash and old_hash != content_hash:
                changes["pages"].append({
                    "competitor": comp["name"],
                    "page_type": page_type,
                    "url": url,
                    "previous_hash": old_hash[:12],
                    "new_hash": content_hash[:12],
                    "detected_at": now_iso(),
                })
                log(f"  → ИЗМЕНЕНИЕ ОБНАРУЖЕНО!")
            elif not old_hash:
                log(f"  → Первичный снапшот сохранён")
            else:
                log(f"  → Без изменений")

            snapshots[snap_key] = {
                "hash": content_hash,
                "checked_at": now_iso(),
                "url": url,
            }
            time.sleep(0.3)

    save_snapshots(snapshots)
    return changes


def parse_hn_algolia(content: str, source_name: str) -> list[dict]:
    """Парсит JSON-ответ HN Algolia API и возвращает список записей."""
    import json
    entries = []
    try:
        data = json.loads(content)
        hits = data.get("hits", [])
        for hit in hits:
            title = hit.get("title", "")
            url = hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID', '')}"
            points = hit.get("points", 0)
            author = hit.get("author", "")
            entries.append({
                "source": source_name,
                "title": title,
                "url": url,
                "published": hit.get("created_at", ""),
                "snippet": f"{points} points by {author}",
                "detected_at": now_iso(),
            })
    except json.JSONDecodeError as e:
        log(f"  Ошибка парсинга JSON HN Algolia: {e}")
    return entries


def generate_report(rss_data: dict, page_changes: dict) -> str:
    """Генерирует Markdown-отчёт о мониторинге."""
    now = datetime.now()
    report = f"""# Отчёт мониторинга конкурентов

**Дата:** {now.strftime('%d %B %Y, %H:%M')}  
**Автор:** Competitor Monitor (Researcher)  
**Статус:** Автоматический сбор

---

## 1. Новые записи из RSS ({len(rss_data.get('new_entries', []))})

"""

    new_entries = rss_data.get("new_entries", [])
    if new_entries:
        for entry in new_entries[:20]:
            report += f"""### {entry['title']}
- **Источник:** {entry['source']}
- **Дата:** {entry.get('published', 'не указана')}
- **URL:** [{entry['url'][:80]}...]({entry['url']})
- **Фрагмент:** {entry.get('snippet', '')[:300]}

"""
        if len(new_entries) > 20:
            report += f"*...и ещё {len(new_entries) - 20} записей*\n\n"
    else:
        report += "*Новых записей нет.*\n\n"

    report += f"""## 2. Изменения на страницах ({len(page_changes.get('pages', []))})

"""
    changes = page_changes.get("pages", [])
    if changes:
        for ch in changes:
            report += f"""### {ch['competitor']} — {ch['page_type']}
- **URL:** [{ch['url'][:80]}...]({ch['url']})
- **Обнаружено:** {ch['detected_at']}

"""
    else:
        report += "*Изменений не обнаружено.*\n\n"

    # Статистика по RSS
    total_comp = len(rss_data.get("competitors", []))
    total_trends = len(rss_data.get("trends", []))

    report += f"""## 3. Статистика сбора

| Метрика | Значение |
|---------|---------:|
| Записей от конкурентов | {total_comp} |
| Записей из трендов | {total_trends} |
| Проверок страниц | {len(COMPETITORS) * 2} |
| Источников RSS | {len(COMPETITORS) + len(TREND_SOURCES)} |

## 4. Ключевые инсайты (автоматические)

"""

    # Простейший эвристический анализ
    all_titles = [e["title"].lower() for e in rss_data.get("competitors", [])]
    keywords_of_interest = {
        "pricing": "Изменения цен",
        "price": "Изменения цен",
        "new feature": "Новые функции",
        "launch": "Запуски продуктов",
        "acquisition": "Слияния/поглощения",
        "partnership": "Партнёрства",
        "security": "Безопасность",
        "deprecat": "Устаревание функций",
        "sunset": "Прекращение поддержки",
    }

    insights_found = []
    for kw, category in keywords_of_interest.items():
        matching = [t for t in all_titles if kw in t]
        if matching:
            insights_found.append(f"- **{category}**: {len(matching)} упоминаний")

    if insights_found:
        report += "\n".join(insights_found) + "\n\n"
    else:
        report += "*Автоматические инсайты не обнаружены.*\n\n"

    report += "---\n*Сгенерировано автоматически Competitor Monitor v1.0*\n"
    return report


def save_report(report: str) -> Path:
    """Сохраняет отчёт и возвращает путь к нему."""
    filename = f"competitor-report-{datetime.now().strftime('%Y%m%d-%H%M')}.md"
    filepath = REPORTS_DIR / filename
    with open(filepath, "w") as f:
        f.write(report)
    log(f"Отчёт сохранён: {filepath}")
    return filepath


def update_project_report(report: str):
    """Обновляет основной файл отчёта в корне проекта."""
    project_file = BASE_DIR / "COMPETITOR_MONITOR_REPORT.md"
    with open(project_file, "w") as f:
        f.write(report)
    log(f"Проектный отчёт обновлён: {project_file}")


def generate_dashboard(rss_data: dict, page_changes: dict) -> str:
    """Генерирует HTML-дашборд из данных мониторинга."""
    now = datetime.now()
    total_comp = len(rss_data.get("competitors", []))
    total_trends = len(rss_data.get("trends", []))
    new_entries = rss_data.get("new_entries", [])
    page_diffs = page_changes.get("pages", [])

    # Статус конкурентов
    competitor_rows = ""
    for key, comp in COMPETITORS.items():
        status = "🟢"
        status_cls = "status-ok"
        title = comp["name"]
        # check if any recent page change for this competitor
        has_change = any(ch["competitor"] == comp["name"] for ch in page_diffs)
        if has_change:
            status = "🟡"
            status_cls = "status-changed"

        competitor_rows += f"""        <tr>
            <td><strong>{comp['name']}</strong><br><small>{key}</small></td>
            <td><a href="{comp['url']}" target="_blank">{comp['url']}</a></td>
            <td class="{status_cls}">{status}</td>
            <td><small>RSS: {'✅' if comp.get('blog_rss') else '—'} Pages: {'✅' if comp.get('pricing') or comp.get('changelog') else '—'}</small></td>
        </tr>
"""

    # Свежие изменения
    alert_rows = ""
    for ch in page_diffs[-10:]:
        detected = ch.get("detected_at", "")[:19]
        alert_rows += f"""        <tr>
            <td><strong>{ch['competitor']}</strong></td>
            <td>{ch['page_type']}</td>
            <td><small>{ch.get('previous_hash', '—')[:8]}</small></td>
            <td><small>{ch.get('new_hash', '—')[:8]}</small></td>
            <td>{detected}</td>
        </tr>
"""
    if not alert_rows:
        alert_rows = "        <tr><td colspan='5' style='color: var(--muted);'>Нет изменений</td></tr>\n"

    # Новые RSS
    rss_rows = ""
    for entry in new_entries[:10]:
        published = entry.get("published", "")[:16] or "—"
        rss_rows += f"""        <tr>
            <td><a href="{entry['url']}" target="_blank">{entry['title'][:80]}</a></td>
            <td>{entry['source']}</td>
            <td><small>{published}</small></td>
        </tr>
"""
    if not rss_rows:
        rss_rows = "        <tr><td colspan='3' style='color: var(--muted);'>Новых записей нет</td></tr>\n"

    # Статистика инсайтов
    all_titles = [e["title"].lower() for e in rss_data.get("competitors", [])]
    keywords_of_interest = {
        "pricing": "Изменения цен", "price": "Изменения цен",
        "new feature": "Новые функции", "launch": "Запуски продуктов",
        "acquisition": "Слияния/поглощения", "partnership": "Партнёрства",
        "security": "Безопасность", "deprecat": "Устаревание функций",
        "sunset": "Прекращение поддержки",
    }
    insight_rows = ""
    for kw, category in keywords_of_interest.items():
        matching = [t for t in all_titles if kw in t]
        if matching:
            insight_rows += f"            <tr><td>{category}</td><td>{len(matching)}</td></tr>\n"
    if not insight_rows:
        insight_rows = "            <tr><td colspan='2' style='color: var(--muted);'>Нет инсайтов</td></tr>\n"

    # Детектированные изменения на страницах (сводка)
    page_status_rows = ""
    for key, comp in COMPETITORS.items():
        for page_type in ["pricing", "changelog"]:
            url = comp.get(page_type)
            if not url:
                continue
            snapshots = load_snapshots()
            snap_key = f"{key}_{page_type}"
            snap = snapshots.get(snap_key, {})
            checked = snap.get("checked_at", "—")[:19]
            has_change = any(ch["competitor"] == comp["name"] and ch["page_type"] == page_type for ch in page_diffs)
            status_icon = "🟡 изменён" if has_change else "🟢 ok"
            page_status_rows += f"""        <tr>
            <td><strong>{comp['name']}</strong></td>
            <td>{page_type}</td>
            <td><a href="{url}" target="_blank">{url}</a></td>
            <td>{status_icon}</td>
            <td><small>{checked}</small></td>
        </tr>
"""

    html = f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Architect — Market Monitor</title>
<style>
:root {{ --bg: #0e1829; --card: #1a2744; --accent: #22c55e; --warn: #eab308; --danger: #ef4444; --text: #e6e6e6; --muted: #8892b0; }}
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ font-family: -apple-system, 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 2rem; }}
h1 {{ color: var(--accent); margin-bottom: 0.25rem; }}
h2 {{ color: var(--accent); margin: 1.5rem 0 0.75rem; border-bottom: 1px solid var(--card); padding-bottom: 0.3rem; }}
h3 {{ color: #94a3b8; margin: 0.75rem 0 0.25rem; }}
.last-updated {{ color: var(--muted); font-size: 0.85rem; }}
table {{ width: 100%; border-collapse: collapse; margin: 0.75rem 0; }}
th, td {{ text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--card); }}
th {{ color: var(--muted); font-weight: 600; text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }}
tr:hover td {{ background: rgba(255,255,255,0.03); }}
a {{ color: #60a5fa; text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
.card {{ background: var(--card); border-radius: 8px; padding: 1rem; margin: 0.75rem 0; }}
ul {{ list-style: none; margin: 0.25rem 0; }}
li {{ padding: 0.3rem 0; border-bottom: 1px solid rgba(255,255,255,0.05); }}
.status-ok {{ color: var(--accent); }}
.status-changed {{ color: var(--warn); }}
.status-error {{ color: var(--danger); }}
footer {{ margin-top: 2rem; color: var(--muted); font-size: 0.75rem; text-align: center; }}
</style>
</head>
<body>
<h1>🏗️ Architect — Market Monitor</h1>
<p class="last-updated">Last scan: {now.strftime('%Y-%m-%d %H:%M:%S')} UTC | New RSS: {len(new_entries)} | Page changes: {len(page_diffs)} | Total entries: {total_comp + total_trends}</p>

<h2>🏢 Competitor Monitoring</h2>
<table>
<thead><tr><th>Competitor</th><th>URL</th><th>Status</th><th>Feeds</th></tr></thead>
<tbody>
{competitor_rows}</tbody>
</table>

<h2>📄 Page Change Detection</h2>
<table>
<thead><tr><th>Competitor</th><th>Page</th><th>URL</th><th>Status</th><th>Last Check</th></tr></thead>
<tbody>
{page_status_rows}</tbody>
</table>

<h2>🔔 Recent Alerts</h2>
<table>
<thead><tr><th>Competitor</th><th>Type</th><th>Old Hash</th><th>New Hash</th><th>Time</th></tr></thead>
<tbody>
{alert_rows}</tbody>
</table>

<h2>📰 New RSS Entries</h2>
<table>
<thead><tr><th>Title</th><th>Source</th><th>Published</th></tr></thead>
<tbody>
{rss_rows}</tbody>
</table>

<h2>📈 Key Insights</h2>
<table>
<thead><tr><th>Category</th><th>Mentions</th></tr></thead>
<tbody>
{insight_rows}</tbody>
</table>

<h2>ℹ️ About</h2>
<div class="card">
<p>Automated competitor monitoring for <strong>Architect</strong> project.<br>
Monitors {len(COMPETITORS)} competitor sites + {len(TREND_SOURCES)} trend sources.<br>
Changes trigger alerts in Paperclip issue DUN-124.</p>
</div>

<footer>Generated by Competitor Monitor v2.0 • {now.strftime('%Y-%m-%dT%H:%M:%S.%f')}+00:00</footer>
</body>
</html>"""
    return html


def update_dashboard(rss_data: dict, page_changes: dict):
    """Обновляет HTML-дашборд в корне проекта."""
    html = generate_dashboard(rss_data, page_changes)
    dashboard_file = BASE_DIR.parent / "MARKET_DASHBOARD.html"
    with open(dashboard_file, "w") as f:
        f.write(html)
    log(f"Дашборд обновлён: {dashboard_file}")


# ─── Точка входа ────────────────────────────────────────────────────────────

def run_full_update(notify: bool = True):
    # Полный цикл: RSS -> страницы -> отчёт -> уведомление
    log("=" * 50)
    log("ЗАПУСК ПОЛНОГО ЦИКЛА МОНИТОРИНГА")
    log("=" * 50)
    ensure_dirs()

    rss_data = collect_rss()
    save_last_data(rss_data)
    page_changes = check_pages_changes()
    report = generate_report(rss_data, page_changes)

    report_path = save_report(report)
    update_project_report(report)
    update_dashboard(rss_data, page_changes)

    notify_digest(rss_data, page_changes)

    if notify:
        notify_new_entries(rss_data, page_changes)

    changes_count = len(rss_data.get("new_entries", [])) + len(page_changes.get("pages", []))
    log(f"Цикл завершён. Изменений найдено: {changes_count}")
    log(f"Отчёт: {report_path}")

    return changes_count


if __name__ == "__main__":
    if "--update" in sys.argv:
        run_full_update(notify="--notify" in sys.argv or "--silent" not in sys.argv)
    elif "--notify" in sys.argv and "--report" not in sys.argv:
        # Быстрый запуск с уведомлением (для cron)
        run_full_update(notify=True)
    elif "--report" in sys.argv:
        ensure_dirs()
        # Сформировать отчёт из кешированных данных (без повторного сбора RSS)
        rss_data = load_cached_data()
        page_changes = {"pages": [], "changed_at": now_iso(), "from_cache": True}
        # Всё равно проверяем страницы — это быстро
        try:
            page_changes = check_pages_changes()
        except Exception as e:
            log(f"Ошибка при проверке страниц: {e}")
        report = generate_report(rss_data, page_changes)
        save_report(report)
        update_project_report(report)
        update_dashboard(rss_data, page_changes)
    elif "--watch" in sys.argv:
        log("Запуск в режиме наблюдения (каждый час)...")
        while True:
            try:
                run_full_update()
            except Exception as e:
                log(f"Ошибка в цикле: {e}")
            log("Ожидание 1 час...")
            time.sleep(3600)
    else:
        print(__doc__)
