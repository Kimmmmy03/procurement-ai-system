# backend/ml_forecasting_service.py
"""
Hybrid ML Forecasting Service.

Provides a quantitative baseline 3-month demand projection using
historical monthly sales data. The baseline is fed to the Azure AI
Forecaster Agent so the LLM focuses on qualitative adjustments
(seasonality, supplier risk) rather than raw math.

Uses sklearn for trend regression + seasonal decomposition.
Falls back to simple moving average when data is too sparse.
"""

import logging
import numpy as np
from typing import Dict, Any, List, Optional
from sklearn.linear_model import LinearRegression

logger = logging.getLogger(__name__)

# Minimum months of history needed for regression-based forecast
MIN_HISTORY_FOR_REGRESSION = 6
# Months to forecast
FORECAST_HORIZON = 3


class MLForecastingService:
    """Baseline time-series forecasting using available sales history."""

    def __init__(self, db_service):
        self.db = db_service

    def get_sku_history(self, sku: str) -> List[Dict[str, Any]]:
        """Fetch monthly sales history for a SKU, ordered chronologically."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT year, month, sales_qty
                FROM monthly_sales_history
                WHERE sku = ?
                ORDER BY year, month
            ''', (sku,))
            return [dict(row) for row in cursor.fetchall()]

    def forecast_sku(self, sku: str) -> Dict[str, Any]:
        """Generate a 3-month baseline forecast for a single SKU.

        Returns:
            {
                "sku": str,
                "method": "regression" | "moving_average" | "insufficient_data",
                "history_months": int,
                "monthly_forecast": [float, float, float],
                "total_3month": float,
                "trend_direction": "increasing" | "decreasing" | "stable",
                "confidence": "high" | "medium" | "low",
                "seasonal_indices": {month: float},
            }
        """
        history = self.get_sku_history(sku)

        # Filter out zero-only trailing months (item may not exist yet)
        non_zero = [h for h in history if h['sales_qty'] > 0]

        if len(non_zero) < 3:
            return {
                "sku": sku,
                "method": "insufficient_data",
                "history_months": len(history),
                "monthly_forecast": [0.0, 0.0, 0.0],
                "total_3month": 0.0,
                "trend_direction": "stable",
                "confidence": "low",
                "seasonal_indices": {},
            }

        sales = np.array([h['sales_qty'] for h in history], dtype=float)
        n = len(sales)

        if n >= MIN_HISTORY_FOR_REGRESSION:
            return self._regression_forecast(sku, history, sales)
        else:
            return self._moving_average_forecast(sku, history, sales)

    def _regression_forecast(self, sku: str, history: list, sales: np.ndarray) -> Dict[str, Any]:
        """Trend regression + seasonal indices for SKUs with 6+ months of data."""
        n = len(sales)
        X = np.arange(n).reshape(-1, 1)

        # Fit linear trend
        model = LinearRegression()
        model.fit(X, sales)
        slope = model.coef_[0]
        trend_values = model.predict(X)

        # Calculate seasonal indices (ratio of actual to trend)
        seasonal_indices = {}
        if n >= 12:
            # Full year: compute month-level seasonality
            ratios_by_month = {}
            for i, h in enumerate(history):
                m = h['month']
                trend_val = max(trend_values[i], 0.1)  # avoid div by zero
                ratio = sales[i] / trend_val
                ratios_by_month.setdefault(m, []).append(ratio)
            for m, ratios in ratios_by_month.items():
                seasonal_indices[m] = float(np.mean(ratios))

        # Project next 3 months
        monthly_forecast = []
        for i in range(FORECAST_HORIZON):
            t = n + i
            base = max(model.predict([[t]])[0], 0)

            # Apply seasonal index if available
            future_month = (history[-1]['month'] + i) % 12 + 1
            si = seasonal_indices.get(future_month, 1.0)
            forecast = max(base * si, 0)
            monthly_forecast.append(round(forecast, 1))

        total_3m = sum(monthly_forecast)

        # Determine trend direction
        if slope > 1.0:
            trend = "increasing"
        elif slope < -1.0:
            trend = "decreasing"
        else:
            trend = "stable"

        # Confidence based on R² and data volume
        r2 = model.score(X, sales)
        if r2 > 0.5 and n >= 12:
            confidence = "high"
        elif r2 > 0.2 or n >= 8:
            confidence = "medium"
        else:
            confidence = "low"

        return {
            "sku": sku,
            "method": "regression",
            "history_months": n,
            "monthly_forecast": monthly_forecast,
            "total_3month": round(total_3m, 1),
            "trend_direction": trend,
            "confidence": confidence,
            "seasonal_indices": {str(k): round(v, 2) for k, v in seasonal_indices.items()},
            "r_squared": round(r2, 3),
            "slope_per_month": round(slope, 2),
        }

    def _moving_average_forecast(self, sku: str, history: list, sales: np.ndarray) -> Dict[str, Any]:
        """Simple weighted moving average for SKUs with 3-5 months of data."""
        # Use last 3 months with more weight on recent
        recent = sales[-3:]
        weights = np.array([0.2, 0.3, 0.5])
        weighted_avg = np.average(recent, weights=weights)
        forecast_val = max(round(weighted_avg, 1), 0)

        monthly_forecast = [forecast_val] * FORECAST_HORIZON
        total_3m = forecast_val * FORECAST_HORIZON

        # Simple trend from last 3 points
        if len(recent) >= 2:
            diff = recent[-1] - recent[0]
            trend = "increasing" if diff > 2 else ("decreasing" if diff < -2 else "stable")
        else:
            trend = "stable"

        return {
            "sku": sku,
            "method": "moving_average",
            "history_months": len(sales),
            "monthly_forecast": monthly_forecast,
            "total_3month": round(total_3m, 1),
            "trend_direction": trend,
            "confidence": "low",
            "seasonal_indices": {},
        }

    def forecast_all_skus(self) -> Dict[str, Any]:
        """Generate baseline forecasts for all SKUs with sales history."""
        with self.db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT DISTINCT sku FROM monthly_sales_history')
            skus = [row['sku'] for row in cursor.fetchall()]

        forecasts = {}
        methods_used = {"regression": 0, "moving_average": 0, "insufficient_data": 0}

        for sku in skus:
            result = self.forecast_sku(sku)
            forecasts[sku] = result
            methods_used[result["method"]] += 1

        return {
            "total_skus": len(skus),
            "methods_breakdown": methods_used,
            "forecasts": forecasts,
        }

    def get_forecast_summary_for_agent(self, skus: Optional[List[str]] = None) -> str:
        """Generate a formatted summary string for the Azure AI Forecaster Agent.

        This gives the LLM a mathematical baseline so it can focus on
        qualitative adjustments (market conditions, supplier risk, etc.)
        """
        if skus:
            forecasts = {sku: self.forecast_sku(sku) for sku in skus}
        else:
            result = self.forecast_all_skus()
            forecasts = result['forecasts']

        if not forecasts:
            return "No historical sales data available for ML baseline."

        lines = ["=== ML BASELINE FORECAST (3-MONTH PROJECTION) ==="]
        lines.append(f"Generated using {len(forecasts)} SKUs with historical data.\n")
        lines.append(f"{'SKU':<20} {'Method':<15} {'Trend':<12} {'Month1':>8} {'Month2':>8} {'Month3':>8} {'Total':>8} {'Conf':<6}")
        lines.append("-" * 95)

        for sku, f in sorted(forecasts.items()):
            m = f['monthly_forecast']
            lines.append(
                f"{sku:<20} {f['method']:<15} {f['trend_direction']:<12} "
                f"{m[0]:>8.0f} {m[1]:>8.0f} {m[2]:>8.0f} {f['total_3month']:>8.0f} {f['confidence']:<6}"
            )

        lines.append("\nIMPORTANT: These are MATHEMATICAL projections only. Please adjust based on:")
        lines.append("- Seasonal events (festivals, holidays, weather)")
        lines.append("- Supplier risk factors (lead time changes, shortages)")
        lines.append("- Market conditions (new product launches, competitor moves)")
        lines.append("- Known upcoming orders or projects")

        return "\n".join(lines)
