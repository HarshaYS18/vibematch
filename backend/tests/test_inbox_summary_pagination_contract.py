from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InboxSummaryPaginationContractTests(unittest.TestCase):
    def test_conversation_page_is_summary_only(self):
        route = (ROOT / "backend/app/api/routes/inbox.py").read_text(encoding="utf-8")
        start = route.index('def list_conversations(')
        end = route.index('\n\n@router.get("/conversations/{conversation_id}"', start)
        block = route[start:end]
        self.assertIn("list_conversations_page(", block)
        self.assertIn("limit=1", block)
        self.assertIn("include_messages=False", block)
        self.assertNotIn("limit=inbox_service.ACTIVE_MESSAGE_WINDOW", block)

    def test_chat_detail_keeps_bounded_message_window(self):
        service = (ROOT / "backend/app/services/inbox_service.py").read_text(encoding="utf-8")
        self.assertIn("ACTIVE_MESSAGE_WINDOW = 50", service)
        self.assertIn("def list_messages_page(", service)
        self.assertIn("page_size + 1", service)
        self.assertIn("if include_messages else []", service)


if __name__ == "__main__":
    unittest.main()
