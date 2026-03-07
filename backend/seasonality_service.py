# backend/seasonality_service.py

"""
Pure seasonality detection algorithm.
No database imports — receives raw rows and returns analysis results.

SEASON_CALENDAR is kept as the seed data source. On startup, these entries
are inserted into the [dbo].[seasonality_events] table (is_system=1).
At runtime, detect_seasonal_patterns() receives all events from the DB
via the `db_events` parameter — it no longer reads SEASON_CALENDAR directly.
"""

from typing import Dict, Any, List
from collections import defaultdict
from datetime import datetime

# Named seasonal events mapped to months and expected multipliers
# Covers the full Malaysian / SE-Asian calendar relevant to procurement
# This dict is used ONLY for seeding the DB. Detection reads from DB.
SEASON_CALENDAR = {
    # ── Q1: Jan / Feb / Mar ──────────────────────────────────────────
    "Chinese New Year": {
        "months": [1, 2],
        "multipliers": {1: 1.45, 2: 1.60},
        "icon": "celebration",
        "description": "Pre-CNY stocking surge. Factories close 2-4 weeks; buyers order early.",
        "category": "festive",
        "severity": "high",
    },
    "Thaipusam": {
        "months": [1],
        "multipliers": {1: 1.08},
        "icon": "temple_hindu",
        "description": "Hindu festival with moderate uplift in food and supplies procurement.",
        "category": "festive",
        "severity": "low",
    },
    "Ramadan": {
        "months": [2, 3],
        "multipliers": {2: 1.20, 3: 1.30},
        "icon": "nights_stay",
        "description": "Fasting month drives demand for food, beverages, and bazaar supplies.",
        "category": "festive",
        "severity": "high",
    },
    "Post-CNY Trough": {
        "months": [3],
        "multipliers": {3: 0.85},
        "icon": "trending_down",
        "description": "Demand dips as inventories built up before CNY are consumed.",
        "category": "cycle",
        "severity": "medium",
    },
    # ── Q2: Apr / May / Jun ──────────────────────────────────────────
    "Hari Raya Aidilfitri": {
        "months": [3, 4],
        "multipliers": {3: 1.25, 4: 1.35},
        "icon": "mosque",
        "description": "End-of-Ramadan celebration drives strong festive procurement demand.",
        "category": "festive",
        "severity": "high",
    },
    "Wesak Day": {
        "months": [5],
        "multipliers": {5: 1.05},
        "icon": "self_improvement",
        "description": "Buddhist festival with minor uplift in community and temple supplies.",
        "category": "festive",
        "severity": "low",
    },
    "School Holiday Surge": {
        "months": [5, 6],
        "multipliers": {5: 1.08, 6: 1.12},
        "icon": "backpack",
        "description": "Mid-year school holidays increase family spending and retail restocking.",
        "category": "cycle",
        "severity": "low",
    },
    "Hari Raya Haji": {
        "months": [6],
        "multipliers": {6: 1.10},
        "icon": "mosque",
        "description": "Festival of Sacrifice with moderate demand increase in food and supplies.",
        "category": "festive",
        "severity": "low",
    },
    # ── Q3: Jul / Aug / Sep ──────────────────────────────────────────
    "Mid-Year Budget Push": {
        "months": [6, 7],
        "multipliers": {6: 1.15, 7: 1.25},
        "icon": "assessment",
        "description": "Mid-year budget utilisation and restocking cycle across organisations.",
        "category": "cycle",
        "severity": "medium",
    },
    "Merdeka / Malaysia Day": {
        "months": [8, 9],
        "multipliers": {8: 1.10, 9: 1.15},
        "icon": "flag",
        "description": "National Day (31 Aug) and Malaysia Day (16 Sep) drive patriotic promotions and government spending.",
        "category": "national",
        "severity": "medium",
    },
    # ── Q4: Oct / Nov / Dec ──────────────────────────────────────────
    "Deepavali": {
        "months": [10, 11],
        "multipliers": {10: 1.12, 11: 1.18},
        "icon": "light_mode",
        "description": "Festival of Lights increases demand for gifts, sweets, and home renovation supplies.",
        "category": "festive",
        "severity": "medium",
    },
    "Year-End Budget Rush": {
        "months": [11, 12],
        "multipliers": {11: 1.30, 12: 1.40},
        "icon": "shopping_cart",
        "description": "Year-end budget clearing and holiday season demand surge across all categories.",
        "category": "cycle",
        "severity": "high",
    },
    "Christmas & New Year": {
        "months": [12],
        "multipliers": {12: 1.20},
        "icon": "card_giftcard",
        "description": "Christmas and New Year festivities boost retail and hospitality procurement.",
        "category": "festive",
        "severity": "medium",
    },
    # ── Cross-quarter events ─────────────────────────────────────────
    "Q1 Construction Season": {
        "months": [1, 2, 3],
        "multipliers": {1: 1.10, 2: 1.15, 3: 1.10},
        "icon": "construction",
        "description": "Dry-season construction activity increases demand for building materials and hardware.",
        "category": "industry",
        "severity": "medium",
    },
    "Monsoon Slowdown (NE)": {
        "months": [11, 12, 1],
        "multipliers": {11: 0.92, 12: 0.88, 1: 0.90},
        "icon": "thunderstorm",
        "description": "Northeast monsoon disrupts logistics on the east coast; outdoor projects slow down.",
        "category": "weather",
        "severity": "medium",
    },
    "Back-to-School": {
        "months": [12, 1],
        "multipliers": {12: 1.08, 1: 1.10},
        "icon": "school",
        "description": "New school-year preparation drives stationery, uniform, and supply purchases.",
        "category": "cycle",
        "severity": "low",
    },
}

# Threshold: monthly index must exceed this to count as a seasonal peak
PEAK_THRESHOLD = 1.25


def detect_seasonal_patterns(
    rows: List[Dict[str, Any]],
    plan_start: str,
    plan_end: str,
    db_events: List[Dict[str, Any]] = None,
    custom_events: List[Dict[str, Any]] = None,  # backward compat
) -> Dict[str, Any]:
    """
    Analyse monthly sales history and detect seasonal patterns.

    Parameters
    ----------
    rows : list of dict
        Each row has keys: sku, year, month, sales_qty
    plan_start, plan_end : str  (ISO date, e.g. "2026-01-01")
    db_events : list of dict
        All seasonality events from the DB (system + custom).
        Each has: name, months (list of int), multiplier, category, severity, description
    custom_events : list of dict  (deprecated, kept for backward compat)

    Returns
    -------
    dict with detected_events, sku_multipliers, summary_text
    """
    if not rows:
        return _empty_result()

    # Parse plan date range into set of (year, month) tuples
    try:
        ps = datetime.fromisoformat(plan_start)
        pe = datetime.fromisoformat(plan_end)
    except (ValueError, TypeError):
        return _empty_result()

    plan_months: List[int] = []
    cur = ps
    while cur <= pe:
        plan_months.append(cur.month)
        if cur.month == 12:
            cur = cur.replace(year=cur.year + 1, month=1)
        else:
            cur = cur.replace(month=cur.month + 1)

    plan_months = list(dict.fromkeys(plan_months))  # deduplicate, preserve order

    # ---- Build per-SKU monthly index ----
    sku_month_sales: Dict[str, Dict[int, List[int]]] = defaultdict(lambda: defaultdict(list))
    for r in rows:
        sku_month_sales[r["sku"]][r["month"]].append(r["sales_qty"])

    sku_seasonal_index: Dict[str, Dict[int, float]] = {}
    for sku, month_data in sku_month_sales.items():
        avg_per_month: Dict[int, float] = {}
        for m, values in month_data.items():
            avg_per_month[m] = sum(values) / len(values)
        overall_avg = sum(avg_per_month.values()) / len(avg_per_month) if avg_per_month else 1
        if overall_avg == 0:
            overall_avg = 1
        sku_seasonal_index[sku] = {m: v / overall_avg for m, v in avg_per_month.items()}

    # ---- Build event calendar from DB events ----
    # Use db_events if provided; fall back to custom_events (legacy) merged with SEASON_CALENDAR
    event_calendar: Dict[str, Dict[str, Any]] = {}

    if db_events is not None:
        # All events come from DB (system events already seeded from SEASON_CALENDAR)
        for evt in db_events:
            evt_name = evt.get('name', 'Unknown')
            evt_months = evt.get('months', [])
            if isinstance(evt_months, str):
                import json
                try:
                    evt_months = json.loads(evt_months)
                except Exception:
                    evt_months = []
            evt_mult = float(evt.get('multiplier', 1.2))
            event_calendar[evt_name] = {
                "months": evt_months,
                "multipliers": {m: evt_mult for m in evt_months},
                "icon": "event",
                "description": evt.get('description', ''),
                "category": evt.get('category', 'general'),
                "severity": evt.get('severity', 'medium'),
            }
    else:
        # Legacy path: use hardcoded calendar + custom_events overlay
        event_calendar = dict(SEASON_CALENDAR)
        for ce in (custom_events or []):
            ce_name = ce.get('name', 'Custom Event')
            ce_months = ce.get('months', [])
            ce_mult = ce.get('multiplier', 1.2)
            event_calendar[ce_name] = {
                "months": ce_months,
                "multipliers": {m: ce_mult for m in ce_months},
                "icon": "event",
                "description": ce.get('description', ''),
                "category": ce.get('category', 'other'),
                "severity": ce.get('severity', 'medium'),
            }

    # ---- Match plan months to named events ----
    detected_events: List[Dict[str, Any]] = []
    sku_multipliers: Dict[str, float] = {}

    for event_name, event_info in event_calendar.items():
        overlap = [m for m in plan_months if m in event_info["months"]]
        if not overlap:
            continue

        affected_skus: List[str] = []
        for sku, idx_map in sku_seasonal_index.items():
            for m in overlap:
                if idx_map.get(m, 1.0) >= PEAK_THRESHOLD:
                    affected_skus.append(sku)
                    break

        max_mult = max(event_info["multipliers"].get(m, 1.0) for m in overlap)

        detected_events.append({
            "event": event_name,
            "months": overlap,
            "multiplier": round(max_mult, 2),
            "affected_sku_count": len(affected_skus),
            "total_sku_count": len(sku_seasonal_index),
            "affected_skus": affected_skus[:10],
            "icon": event_info["icon"],
            "description": event_info["description"],
            "category": event_info.get("category", "general"),
            "severity": event_info.get("severity", "medium"),
        })

    # ---- Compute per-SKU multiplier for the plan window ----
    for sku in sku_seasonal_index:
        mult = 1.0
        for event_name, event_info in event_calendar.items():
            for m in plan_months:
                if m in event_info["multipliers"]:
                    m_mult = event_info["multipliers"][m]
                    if m_mult > mult:
                        mult = m_mult
        sku_multipliers[sku] = round(mult, 2)

    # ---- Summary text ----
    if detected_events:
        names = ", ".join(e["event"] for e in detected_events)
        summary = f"Detected {len(detected_events)} seasonal event(s) in plan period: {names}."
    else:
        summary = "No significant seasonal events detected for the selected plan period."

    return {
        "detected_events": detected_events,
        "sku_multipliers": sku_multipliers,
        "summary_text": summary,
        "plan_months": plan_months,
    }


def _empty_result() -> Dict[str, Any]:
    return {
        "detected_events": [],
        "sku_multipliers": {},
        "summary_text": "No monthly sales history available for seasonality analysis.",
        "plan_months": [],
    }
