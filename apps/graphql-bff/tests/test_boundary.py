import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class BoundaryTests(unittest.TestCase):
    def test_bff_has_no_database_or_mutation_authority(self):
        sources = "\n".join(
            path.read_text(encoding="utf-8")
            for path in ROOT.glob("*.py")
        )
        forbidden = (
            "sqlalchemy",
            "app.database",
            "Session(",
            "GraphQLMutation",
            "mutation_type=",
            ".post_json(",
            ".put(",
            ".patch(",
            ".delete(",
        )
        for marker in forbidden:
            self.assertNotIn(marker, sources)

    def test_only_get_is_exposed_to_upstreams(self):
        upstream = (ROOT / "upstream.py").read_text(encoding="utf-8")
        self.assertIn("async def get_json", upstream)
        self.assertNotIn("async def post_", upstream)


if __name__ == "__main__":
    unittest.main()
