# backend/logistics_constants.py
"""Vehicle constraints and logistics calculation helpers.

Container specs from run.md (industry standard ISO containers).
Lorry specs from run.md (Malaysian market lorry types).
"""

import math
from typing import Dict, Any, List, Optional

# ---------------------------------------------------------------------------
# Container specifications (from run.md)
# ---------------------------------------------------------------------------
CONTAINERS = [
    {
        "name": "10' Container",
        "internal_l": 2.66, "internal_w": 2.35, "internal_h": 2.38,
        "capacity_m3": 15.19, "max_load_kg": 11299, "empty_weight_kg": 1302,
    },
    {
        "name": "20' Container",
        "internal_l": 5.71, "internal_w": 2.35, "internal_h": 2.38,
        "capacity_m3": 33.10, "max_load_kg": 27800, "empty_weight_kg": 2199,
    },
    {
        "name": "40' Container",
        "internal_l": 12.03, "internal_w": 2.35, "internal_h": 2.38,
        "capacity_m3": 67.54, "max_load_kg": 26199, "empty_weight_kg": 3801,
    },
    {
        "name": "40' High Cube",
        "internal_l": 12.07, "internal_w": 2.31, "internal_h": 2.67,
        "capacity_m3": 75.32, "max_load_kg": 26580, "empty_weight_kg": 3900,
    },
    {
        "name": "45' High Cube",
        "internal_l": 13.59, "internal_w": 2.31, "internal_h": 2.67,
        "capacity_m3": 86.08, "max_load_kg": 25201, "empty_weight_kg": 4799,
    },
]

# ---------------------------------------------------------------------------
# Lorry specifications (from run.md)
# ---------------------------------------------------------------------------
LORRIES = [
    {
        "name": "1 Ton Lorry",
        "length": 3.20, "width": 1.65, "inner_height": 1.90, "outer_height": 2.80,
        "capacity_m3": 3.20 * 1.65 * 1.90,  # ~10.03
        "max_load_kg": 1000,
        "description": "Light duty truck, small capacity, low fuel consumption",
        "tailgate": "Optional",
    },
    {
        "name": "2 Ton Lorry",
        "length": 4.30, "width": 2.00, "inner_height": 2.40, "outer_height": 3.40,
        "capacity_m3": 4.30 * 2.00 * 2.40,  # ~20.64
        "max_load_kg": 2000,
        "description": "Medium duty truck, suitable for home appliances",
        "tailgate": "Optional",
    },
    {
        "name": "4 Ton Lorry",
        "length": 7.40, "width": 2.00, "inner_height": 2.20, "outer_height": 3.00,
        "capacity_m3": 7.40 * 2.00 * 2.20,  # ~32.56
        "max_load_kg": 4000,
        "description": "Medium-heavy duty truck with tailgate",
        "tailgate": "Yes",
    },
    {
        "name": "5 Ton Lorry",
        "length": 7.50, "width": 2.35, "inner_height": 2.36, "outer_height": 3.63,
        "capacity_m3": 7.50 * 2.35 * 2.36,  # ~41.59
        "max_load_kg": 5000,
        "description": "Heavy duty truck, container box or canvas type",
        "tailgate": "Yes",
    },
    {
        "name": "10 Ton Lorry",
        "length": 7.60, "width": 2.40, "inner_height": 2.30, "outer_height": 3.50,
        "capacity_m3": 7.60 * 2.40 * 2.30,  # ~41.95
        "max_load_kg": 10000,
        "description": "Heavy duty truck for huge volume or bulky cargo",
        "tailgate": "Yes",
    },
]

# Quick-lookup sets
CONTAINER_NAMES = {c["name"] for c in CONTAINERS}
LORRY_NAMES = {l["name"] for l in LORRIES}


# ---------------------------------------------------------------------------
# Core selection logic
# ---------------------------------------------------------------------------

def select_best_container(total_cbm: float, total_weight_kg: float) -> Dict[str, Any]:
    """Pick the best container size and how many are needed.

    Strategy:
    - Try each container size from smallest to largest.
    - Pick the size that gives the best utilization (closest to 100%) with
      the fewest number of containers.
    - Returns container_size, container_count, utilization, spare_cbm.
    """
    if total_cbm <= 0 and total_weight_kg <= 0:
        return {
            "container_size": "None",
            "container_count": 0,
            "volume_utilization_pct": 0,
            "weight_utilization_pct": 0,
            "spare_cbm": 0,
            "spare_kg": 0,
        }

    best: Optional[Dict[str, Any]] = None

    for ctr in CONTAINERS:
        cap = ctr["capacity_m3"]
        max_kg = ctr["max_load_kg"]

        # How many containers needed? Constrained by both volume and weight.
        count_by_vol = math.ceil(total_cbm / cap) if cap > 0 else 999
        count_by_wt = math.ceil(total_weight_kg / max_kg) if max_kg > 0 else 999
        count = max(count_by_vol, count_by_wt, 1)

        total_cap = cap * count
        total_max_kg = max_kg * count
        vol_util = (total_cbm / total_cap) * 100
        wt_util = (total_weight_kg / total_max_kg) * 100
        spare_cbm = round(total_cap - total_cbm, 2)
        spare_kg = round(total_max_kg - total_weight_kg, 2)

        candidate = {
            "container_size": ctr["name"],
            "container_count": count,
            "volume_utilization_pct": round(vol_util, 1),
            "weight_utilization_pct": round(wt_util, 1),
            "spare_cbm": spare_cbm,
            "spare_kg": spare_kg,
            "capacity_m3": cap,
            "max_load_kg": max_kg,
        }

        # Prefer: fewest containers, then highest utilization
        if best is None:
            best = candidate
        elif count < best["container_count"]:
            best = candidate
        elif count == best["container_count"] and vol_util > best["volume_utilization_pct"]:
            best = candidate

    return best  # type: ignore


def select_best_lorry(total_cbm: float, total_weight_kg: float) -> Dict[str, Any]:
    """Pick the best lorry for local delivery.

    Returns the smallest lorry that fits. If it doesn't fit in one lorry,
    returns how many trips or multiple lorries needed.
    """
    if total_cbm <= 0 and total_weight_kg <= 0:
        return {
            "lorry_type": "None",
            "lorry_count": 0,
            "volume_utilization_pct": 0,
            "weight_utilization_pct": 0,
            "description": "",
        }

    # Try single lorry first (smallest that fits)
    for lorry in LORRIES:
        cap = lorry["capacity_m3"]
        max_kg = lorry["max_load_kg"]
        if total_cbm <= cap and total_weight_kg <= max_kg:
            vol_util = (total_cbm / cap) * 100
            wt_util = (total_weight_kg / max_kg) * 100
            return {
                "lorry_type": lorry["name"],
                "lorry_count": 1,
                "volume_utilization_pct": round(vol_util, 1),
                "weight_utilization_pct": round(wt_util, 1),
                "description": lorry["description"],
                "tailgate": lorry["tailgate"],
            }

    # Doesn't fit in one lorry — use the largest and calculate how many
    largest = LORRIES[-1]
    cap = largest["capacity_m3"]
    max_kg = largest["max_load_kg"]
    count_vol = math.ceil(total_cbm / cap)
    count_wt = math.ceil(total_weight_kg / max_kg)
    count = max(count_vol, count_wt)
    vol_util = (total_cbm / (cap * count)) * 100
    wt_util = (total_weight_kg / (max_kg * count)) * 100

    return {
        "lorry_type": largest["name"],
        "lorry_count": count,
        "volume_utilization_pct": round(vol_util, 1),
        "weight_utilization_pct": round(wt_util, 1),
        "description": largest["description"],
        "tailgate": largest["tailgate"],
    }


def compute_fill_up_suggestion(total_cbm: float, total_weight_kg: float,
                                container_size: str) -> str:
    """Suggest how much more cargo can be added to fill the container."""
    ctr = next((c for c in CONTAINERS if c["name"] == container_size), None)
    if not ctr:
        return ""

    spare_cbm = ctr["capacity_m3"] - total_cbm
    spare_kg = ctr["max_load_kg"] - total_weight_kg

    if spare_cbm <= 0.5 and spare_kg <= 50:
        return "Container is nearly full. Optimal utilization achieved."

    parts = []
    if spare_cbm > 0.5:
        parts.append(f"{spare_cbm:.1f} CBM")
    if spare_kg > 50:
        parts.append(f"{spare_kg:.0f} kg")

    return f"Spare capacity: {' / '.join(parts)}. Consider adding items to maximize container utilization."


def select_vehicle(total_cbm: float, total_weight_kg: float):
    """Legacy API — returns (vehicle_name, strategy, utilization_pct).

    Now delegates to the richer select_best_container / select_best_lorry.
    """
    if total_cbm <= 0 and total_weight_kg <= 0:
        return "Local Bulk", "Local Bulk", 0.0

    # Try lorries first for small shipments
    for lorry in LORRIES:
        if total_cbm <= lorry["capacity_m3"] and total_weight_kg <= lorry["max_load_kg"]:
            vol_util = (total_cbm / lorry["capacity_m3"]) * 100
            wt_util = (total_weight_kg / lorry["max_load_kg"]) * 100
            return lorry["name"], "Local Bulk", max(vol_util, wt_util)

    # Then containers
    for ctr in CONTAINERS:
        if total_cbm <= ctr["capacity_m3"] and total_weight_kg <= ctr["max_load_kg"]:
            vol_util = (total_cbm / ctr["capacity_m3"]) * 100
            wt_util = (total_weight_kg / ctr["max_load_kg"]) * 100
            util = max(vol_util, wt_util)
            strategy = "FCL" if util >= 60 else "LCL"
            return ctr["name"], strategy, util

    # Multiple containers — compute exact count
    largest = CONTAINERS[-1]
    count_by_vol = math.ceil(total_cbm / largest["capacity_m3"]) if largest["capacity_m3"] > 0 else 1
    count_by_wt = math.ceil(total_weight_kg / largest["max_load_kg"]) if largest["max_load_kg"] > 0 else 1
    count = max(count_by_vol, count_by_wt, 2)
    per_container_util = (total_cbm / (largest["capacity_m3"] * count)) * 100 if count > 0 else 0
    return f"{count}x {largest['name']}", "FCL", per_container_util


def calculate_full_logistics(total_cbm: float, total_weight_kg: float) -> Dict[str, Any]:
    """Calculate complete logistics recommendation: container + lorry + fill-up."""
    container = select_best_container(total_cbm, total_weight_kg)
    lorry = select_best_lorry(total_cbm, total_weight_kg)

    # Determine strategy
    if total_cbm <= 0 and total_weight_kg <= 0:
        strategy = "Local Bulk"
    elif container["container_count"] == 0:
        strategy = "Local Bulk"
    elif container["volume_utilization_pct"] >= 60:
        strategy = "FCL"
    else:
        strategy = "LCL"

    fill_suggestion = compute_fill_up_suggestion(
        total_cbm, total_weight_kg, container["container_size"]
    ) if container["container_count"] == 1 else ""

    if container["container_count"] > 1:
        fill_suggestion = (
            f"{container['container_count']}x {container['container_size']} needed. "
            f"Total capacity: {container['capacity_m3'] * container['container_count']:.1f} CBM / "
            f"{container['max_load_kg'] * container['container_count']:,.0f} kg."
        )

    return {
        "strategy": strategy,
        "container_size": container["container_size"],
        "container_count": container["container_count"],
        "container_utilization_pct": container["volume_utilization_pct"],
        "weight_utilization_pct": container["weight_utilization_pct"],
        "spare_cbm": container["spare_cbm"],
        "spare_kg": container["spare_kg"],
        "recommended_lorry": lorry["lorry_type"],
        "lorry_count": lorry["lorry_count"],
        "lorry_utilization_pct": lorry["volume_utilization_pct"],
        "lorry_description": lorry.get("description", ""),
        "fill_up_suggestion": fill_suggestion,
    }


def calculate_logistics(items: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Calculate total CBM, weight, cartons, and recommend a vehicle.

    Each item dict must have: forecasted_qty, units_per_ctn, cbm_per_ctn, weight_per_ctn.
    Returns logistics summary dict.
    """
    total_cartons = 0
    total_cbm = 0.0
    total_weight_kg = 0.0
    total_items = 0

    for item in items:
        qty = item.get('forecasted_qty', 0) or 0
        units_per_ctn = item.get('units_per_ctn', 1) or 1
        cbm_per_ctn = item.get('cbm_per_ctn', 0.05) or 0.05
        weight_per_ctn = item.get('weight_per_ctn', 10.0) or 10.0

        cartons = math.ceil(qty / units_per_ctn)
        total_cartons += cartons
        total_cbm += cartons * cbm_per_ctn
        total_weight_kg += cartons * weight_per_ctn
        total_items += qty

    full = calculate_full_logistics(round(total_cbm, 2), round(total_weight_kg, 2))

    return {
        "total_items": total_items,
        "total_cartons": total_cartons,
        "total_cbm": round(total_cbm, 2),
        "total_weight_kg": round(total_weight_kg, 2),
        "recommended_vehicle": full["recommended_lorry"] if full["strategy"] == "Local Bulk" else full["container_size"],
        "strategy": full["strategy"],
        "utilization_percentage": full["container_utilization_pct"] if full["strategy"] != "Local Bulk" else full["lorry_utilization_pct"],
        **full,
    }
