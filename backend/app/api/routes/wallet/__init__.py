from __future__ import annotations

import importlib.util
from pathlib import Path

_wallet_file = Path(__file__).resolve().parent.parent / "wallet.py"
_spec = importlib.util.spec_from_file_location("app.api.routes._legacy_wallet_route_file", _wallet_file)
if _spec is None or _spec.loader is None:
    raise ImportError("Unable to load wallet route file")

_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_module)
router = _module.router
