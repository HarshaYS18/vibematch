from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class WorkerLocalOverlayTests(unittest.TestCase):
    def test_local_overlay_targets_pool_scaled_objects(self):
        source=(ROOT/"deploy/kubernetes/overlays/local/local-scale.yaml").read_text(encoding="utf-8")
        self.assertNotIn("metadata: {name: funkey-worker}\nspec: {minReplicaCount",source)
        for name in ("funkey-worker-notification","funkey-worker-media","funkey-worker-fanout","funkey-worker-maintenance"):
            self.assertIn(f"metadata: {{name: {name}}}",source)

if __name__=="__main__": unittest.main()
