import os
import sqlite3
import pytest
from unittest.mock import patch, MagicMock
from verify_rag_ingestion import query_local_sqlite_rag

def test_query_local_sqlite_rag_db_not_exists():
    """Test that query_local_sqlite_rag returns [] if the database file does not exist."""
    with patch("os.path.exists", return_value=False):
        results = query_local_sqlite_rag("any query")
        assert results == []

def test_query_local_sqlite_rag_sqlite_error():
    """Test that query_local_sqlite_rag handles sqlite3.Error correctly."""
    with patch("os.path.exists", return_value=True):
        with patch("sqlite3.connect", side_effect=sqlite3.Error("Mocked connection failure")):
            results = query_local_sqlite_rag("any query")
            assert len(results) == 1
            assert "Local RAG error: Mocked connection failure" in results[0]

def test_query_local_sqlite_rag_happy_path():
    """Test the happy path of query_local_sqlite_rag where it returns matched commands."""
    mock_rows = [
        ("virt", "vm-deploy", "Deploy the virtual machine stack", "virt-deploy-cmd"),
        ("net", "port-forward", "Forward firewall ports", "net-pf-cmd"),
        ("sys", "kernel-args", "Apply real-time kernel arguments", "sys-kernel-cmd"),
    ]

    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = mock_rows
    mock_conn.cursor.return_value = mock_cursor

    with patch("os.path.exists", return_value=True):
        with patch("sqlite3.connect", return_value=mock_conn):
            # Query matching "virtual" should match the first command
            results = query_local_sqlite_rag("virtual")
            assert len(results) == 1
            assert results[0] == "[virt] virt-deploy-cmd - Deploy the virtual machine stack"

            # Query matching multiple keywords or case insensitive
            results_multi = query_local_sqlite_rag("FIREWALL deploy")
            assert len(results_multi) == 2
            assert results_multi[0] == "[virt] virt-deploy-cmd - Deploy the virtual machine stack"
            assert results_multi[1] == "[net] net-pf-cmd - Forward firewall ports"
