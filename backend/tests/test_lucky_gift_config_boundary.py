from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class LuckyGiftConfigBoundaryTests(unittest.TestCase):
    def test_settlement_config_reads_are_side_effect_free(self):
        source=(ROOT/"backend/app/services/lucky_gift_props_service.py").read_text(encoding="utf-8")
        for name in ("load_rules","load_risk"):
            start=source.index(f"def {name}")
            end=source.find("\ndef ",start+5)
            block=source[start:] if end<0 else source[start:end]
            self.assertNotIn("get_or_create_definition(",block)
            self.assertIn("GameDefinition",block)

if __name__=="__main__":
    unittest.main()
