from sqlalchemy.orm import Session

from app.models.help_article import HelpArticle


DEFAULT_HELP_ARTICLES = [
    ("recharge-help", "recharge_issue", "Recharge or coins not credited", "Share amount, date, payment reference, and screenshot. Support will verify ledger records."),
    ("ban-appeal", "ban_appeal", "Ban appeal", "Appeals are reviewed by support and monitors. AI can summarize, but cannot unban users."),
    ("room-locked", "room_issue", "Room access issue", "Locked and Secret Vibe rooms follow host/privacy rules. Include room ID and host name."),
    ("inbox-help", "inbox_issue", "Inbox privacy and lock", "Inbox lock, backups, message requests, and privacy controls live in Inbox settings."),
    ("vip-svip", "vip_svip_issue", "VIP/SVIP help", "VIP/SVIP levels are backend economy state. Include level, recharge details, and what changed."),
]


def seed_default_articles(db: Session) -> None:
    for slug, category, title, body in DEFAULT_HELP_ARTICLES:
        exists = db.query(HelpArticle).filter(HelpArticle.slug == slug).first()
        if exists:
            continue
        db.add(HelpArticle(slug=slug, category=category, title=title, body=body, tags_json=[category]))
    db.commit()


def search_articles(db: Session, query: str, category: str | None = None, limit: int = 5) -> list[HelpArticle]:
    seed_default_articles(db)
    cleaned = query.strip().lower()
    rows = db.query(HelpArticle).filter(HelpArticle.is_published.is_(True)).all()
    filtered = []
    for row in rows:
        if category and category != "other" and row.category != category:
            continue
        haystack = f"{row.title} {row.body} {row.category} {' '.join(row.tags_json or [])}".lower()
        if not cleaned or any(term in haystack for term in cleaned.split()):
            filtered.append(row)
    return filtered[:limit]
