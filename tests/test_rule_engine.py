import unittest

from pydantic import ValidationError

from runcoach_ai.rule_engine import RunInput, analyze_run_metrics


class RunInputTests(unittest.TestCase):
    def test_rejects_rpe_outside_scale(self) -> None:
        with self.assertRaises(ValidationError):
            RunInput(distance_km=5, time_seconds=1800, avg_hr=140, rpe=11)

    def test_rejects_nonpositive_run_metrics(self) -> None:
        with self.assertRaises(ValidationError):
            RunInput(distance_km=0, time_seconds=1800, avg_hr=140, rpe=5)


class AnalyzeRunMetricsTests(unittest.TestCase):
    def test_calculates_pace_load_zone_and_base_recommendation(self) -> None:
        result = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1850, avg_hr=140, rpe=5),
            max_hr=195,
        )

        self.assertEqual(result.pace_formatted, "6:10")
        self.assertEqual(result.training_load, 154.17)
        self.assertEqual(result.intensity_zone, "Easy/Aerobic")
        self.assertEqual(result.base_recommendation, "Base Aerobic Run")

    def test_short_sleep_recommends_recovery(self) -> None:
        result = analyze_run_metrics(
            RunInput(
                distance_km=5,
                time_seconds=1800,
                avg_hr=140,
                rpe=5,
                sleep_hours=4.5,
            ),
        )

        self.assertEqual(result.base_recommendation, "Recovery Run or Rest Day")

    def test_high_resting_heart_rate_recommends_recovery(self) -> None:
        result = analyze_run_metrics(
            RunInput(
                distance_km=5,
                time_seconds=1800,
                avg_hr=140,
                rpe=5,
                resting_hr=100,
            ),
        )

        self.assertEqual(result.base_recommendation, "Recovery Run or Rest Day")

    def test_uses_zone_threshold_boundaries(self) -> None:
        at_75_percent = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1800, avg_hr=150, rpe=5),
            max_hr=200,
        )
        at_88_percent = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1800, avg_hr=176, rpe=5),
            max_hr=200,
        )
        above_88_percent = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1800, avg_hr=177, rpe=5),
            max_hr=200,
        )

        self.assertEqual(at_75_percent.intensity_zone, "Moderate/Threshold")
        self.assertEqual(at_88_percent.intensity_zone, "Moderate/Threshold")
        self.assertEqual(above_88_percent.intensity_zone, "Hard/Anaerobic")
        self.assertEqual(above_88_percent.base_recommendation, "Recovery Run or Rest Day")

    def test_high_rpe_takes_precedence_over_low_rpe_rule(self) -> None:
        result = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1800, avg_hr=140, rpe=8),
        )

        self.assertEqual(result.base_recommendation, "Recovery Run or Rest Day")

    def test_low_rpe_recommends_progression_or_intervals(self) -> None:
        result = analyze_run_metrics(
            RunInput(distance_km=5, time_seconds=1800, avg_hr=140, rpe=4),
        )

        self.assertEqual(result.base_recommendation, "Progression or Interval Run")

    def test_pace_rounding_carries_into_minutes(self) -> None:
        result = analyze_run_metrics(
            RunInput(distance_km=10, time_seconds=35996, avg_hr=140, rpe=5),
        )

        self.assertEqual(result.pace_formatted, "60:00")

    def test_rejects_nonpositive_max_heart_rate(self) -> None:
        data = RunInput(distance_km=5, time_seconds=1800, avg_hr=140, rpe=5)

        with self.assertRaises(ValueError):
            analyze_run_metrics(data, max_hr=0)


if __name__ == "__main__":
    unittest.main()
