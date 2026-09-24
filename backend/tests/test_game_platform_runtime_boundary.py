from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class GamePlatformRuntimeBoundaryTests(unittest.TestCase):
    def test_canonical_games_route_uses_game_platform_runtime(self):
        route=(ROOT/"backend/app/api/routes/games.py").read_text(encoding="utf-8")
        self.assertIn("game_platform_runtime_service as game_service",route)
        self.assertIn("payload.request_id",route)
        self.assertIn("open_game_session",route)
    def test_runtime_delegates_all_wallet_value_to_economy(self):
        source=(ROOT/"backend/app/services/game_platform_runtime_service.py").read_text(encoding="utf-8")
        self.assertIn("economy_service_client.game_wager",source)
        self.assertIn("economy_service_client.game_settle",source)
        self.assertIn("economy_service_client.wallet_snapshot",source)
        for forbidden in ("UserWallet","WalletLedger","game_pool_service","economy_service.get_or_create_wallet"):
            self.assertNotIn(forbidden,source)
    def test_bet_saga_is_durable_and_retry_identified(self):
        model=(ROOT/"backend/app/models/game.py").read_text(encoding="utf-8")
        source=(ROOT/"backend/app/services/game_platform_runtime_service.py").read_text(encoding="utf-8")
        self.assertIn("request_id: Mapped[str | None]",model)
        self.assertIn('"financial_status":"PENDING"',source)
        self.assertIn("game-bet:{round_id}:{user.id}:{rid}",source)
    def test_economy_records_wager_income_and_final_settlement(self):
        internal=(ROOT/"apps/economy-service/internal.py").read_text(encoding="utf-8")
        self.assertIn("COIN_GAME_WAGER_INCOME",internal)
        self.assertIn("house_pool_service.record_house_profit_or_loss",internal)
        self.assertIn('@router.get("/wallet/snapshot/{user_id}"',internal)
    def test_game_sessions_have_migration_and_authority_grant(self):
        migration=(ROOT/"backend/alembic/versions/20260924_0800_game_platform_runtime.py").read_text(encoding="utf-8")
        ownership=(ROOT/"deploy/postgres/game-platform-ownership.sql").read_text(encoding="utf-8")
        self.assertIn('"game_sessions"',migration); self.assertIn("game_sessions",ownership)
if __name__=="__main__": unittest.main()
