from random import random

NORMAL_GIFTS = [
    {
        "id": "rose_bloom",
        "name": "Rose Bloom",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 9,
        "icon_key": "local_favorite",
        "chat_symbol": "🌹",
        "asset_path": "assets/gifts/normal/rose_bloom.webp",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 10,
    },
    {
        "id": "gold_coin",
        "name": "Gold Coin",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 29,
        "icon_key": "local_paid",
        "chat_symbol": "🪙",
        "asset_path": "assets/gifts/normal/gold_coin.webp",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 20,
    },
    {
        "id": "party_pop",
        "name": "Party Pop",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 99,
        "icon_key": "local_celebration",
        "chat_symbol": "🎉",
        "asset_path": "assets/gifts/normal/party_pop.webp",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 30,
    },
    {
        "id": "love_rocket",
        "name": "Love Rocket",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 999,
        "icon_key": "local_rocket",
        "chat_symbol": "🚀",
        "asset_path": "assets/gifts/love_rocket/icon/love_rocket_icon.webp",
        "video_asset_path": "assets/videos/gifts/love_rocket.mp4",
        "is_enabled": True,
        "sort_order": 100,
    },
]

LUCKY_GIFTS = [
    {
        "id": "arcane_crystal_wand",
        "name": "Arcane Crystal Wand",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 99,
        "icon_key": "local_auto_fix_high",
        "chat_symbol": "🪄",
        "asset_path": "assets/gifts/lucky/arcane_crystal_wand.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 210,
        "max_multiplier": 100,
    },
    {
        "id": "celestial_rose",
        "name": "Celestial Rose",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 199,
        "icon_key": "local_favorite_border",
        "chat_symbol": "🌹",
        "asset_path": "assets/gifts/lucky/celestial_rose.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 220,
        "max_multiplier": 100,
    },
    {
        "id": "eternal_bond_rings",
        "name": "Eternal Bond Rings",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 299,
        "icon_key": "local_diamond",
        "chat_symbol": "💍",
        "asset_path": "assets/gifts/lucky/eternal_bond_rings.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 230,
        "max_multiplier": 500,
    },
    {
        "id": "bubble_elephant",
        "name": "Bubble Elephant",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 99,
        "icon_key": "local_pets",
        "chat_symbol": "🐘",
        "asset_path": "assets/gifts/lucky/bubble_elephant.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 240,
        "max_multiplier": 100,
    },
    {
        "id": "sun_fortune_coin",
        "name": "Sun Fortune Coin",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 499,
        "icon_key": "local_wb_sunny",
        "chat_symbol": "☀️",
        "asset_path": "assets/gifts/lucky/sun_fortune_coin.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 250,
        "max_multiplier": 500,
    },
    {
        "id": "moonlit_koi",
        "name": "Moonlit Koi",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 299,
        "icon_key": "local_waves",
        "chat_symbol": "🐟",
        "asset_path": "assets/gifts/lucky/moonlit_koi.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 260,
        "max_multiplier": 500,
    },
    {
        "id": "spellbound_tome",
        "name": "Spellbound Tome",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 999,
        "icon_key": "local_auto_stories",
        "chat_symbol": "📖",
        "asset_path": "assets/gifts/lucky/spellbound_tome.png",
        "video_asset_path": None,
        "is_enabled": True,
        "sort_order": 270,
        "max_multiplier": 1000,
    },
]

MULTIPLIER_TABLE = [
    {"multiplier": 1, "weight": 810000, "label": "safe"},
    {"multiplier": 2, "weight": 112000, "label": "small_win"},
    {"multiplier": 5, "weight": 44000, "label": "nice_win"},
    {"multiplier": 10, "weight": 20000, "label": "big_win"},
    {"multiplier": 50, "weight": 8500, "label": "rare_win"},
    {"multiplier": 100, "weight": 4200, "label": "super_win"},
    {"multiplier": 500, "weight": 1100, "label": "mega_win"},
    {"multiplier": 1000, "weight": 200, "label": "legend_win"},
]


def list_gifts() -> dict:
    return {"normal": NORMAL_GIFTS, "lucky": LUCKY_GIFTS, "all": sorted([*NORMAL_GIFTS, *LUCKY_GIFTS], key=lambda item: item["sort_order"])}


def find_gift(gift_id: str) -> dict | None:
    return next((gift for gift in [*NORMAL_GIFTS, *LUCKY_GIFTS] if gift["id"] == gift_id), None)


def roll_lucky_multiplier(gift_id: str, total_coin_value: int, house_risk_score: int = 0) -> dict:
    gift = find_gift(gift_id)
    if gift is None or gift.get("gift_type") != "lucky":
        raise ValueError("Lucky gift not found")

    max_multiplier = int(gift.get("max_multiplier") or 1)
    risk_penalty = max(min(house_risk_score, 90), 0) / 100
    filtered = []
    for item in MULTIPLIER_TABLE:
        multiplier = int(item["multiplier"])
        if multiplier > max_multiplier:
            continue
        weight = int(item["weight"])
        if multiplier >= 100:
            weight = max(1, int(weight * (1 - risk_penalty)))
        filtered.append({**item, "weight": weight})

    total_weight = sum(int(item["weight"]) for item in filtered)
    pick = random() * total_weight
    cursor = 0.0
    selected = filtered[0]
    for item in filtered:
        cursor += int(item["weight"])
        if pick <= cursor:
            selected = item
            break

    multiplier = int(selected["multiplier"])
    reward = total_coin_value * multiplier
    return {
        "gift_id": gift_id,
        "gift_name": gift["name"],
        "base_coin_value": int(gift["coin_value"]),
        "total_coin_value": total_coin_value,
        "multiplier": multiplier,
        "reward_coin_amount": reward,
        "risk_label": selected["label"],
        "is_global_broadcast_worthy": multiplier >= 500,
        "logic": "Backend-authoritative weighted multiplier roll. 100x/500x are boosted for testing and can be reduced by house risk score.",
    }
