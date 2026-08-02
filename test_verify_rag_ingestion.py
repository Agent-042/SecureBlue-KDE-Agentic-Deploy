import unittest
from unittest.mock import patch
from verify_rag_ingestion import query_local_sqlite_rag

class TestVerifyRagIngestion(unittest.TestCase):
    @patch("verify_rag_ingestion.os.path.exists")
    def test_query_local_sqlite_rag_db_not_found(self, mock_exists):
        # Configure mock to return False
        mock_exists.return_value = False

        # Call the function
        result = query_local_sqlite_rag("test query")

        # Assert the result is an empty list
        self.assertEqual(result, [])
        # Assert mock was called with the correct database path
        mock_exists.assert_called_once_with("/var/lib/agy/knowledge.db")

if __name__ == "__main__":
    unittest.main()
