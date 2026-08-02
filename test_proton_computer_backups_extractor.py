import os
import sys
import pytest
import requests
from unittest.mock import patch, MagicMock, mock_open

# Import the modules we want to test
import proton_computer_backups_extractor as pbe

def test_generate_totp():
    """Verify that TOTP generation runs and returns a 6-digit string."""
    totp = pbe.generate_totp(pbe.SECRET)
    assert len(totp) == 6
    assert totp.isdigit()

@patch('os.path.exists')
def test_load_credentials_missing_file(mock_exists):
    """Test load_credentials returns None, None if rclone.conf is missing."""
    mock_exists.return_value = False
    token, uid = pbe.load_credentials()
    assert token is None
    assert uid is None

@patch('os.path.exists')
@patch('builtins.open', new_callable=mock_open, read_data="""
[protondrive]
type = protondrive
client_access_token = mocktoken123
client_uid = mockuid456
""")
def test_load_credentials_valid(mock_file, mock_exists):
    """Test load_credentials correctly extracts token and uid from rclone.conf."""
    mock_exists.return_value = True
    token, uid = pbe.load_credentials()
    assert token == "mocktoken123"
    assert uid == "mockuid456"

@patch('proton_computer_backups_extractor.load_credentials')
@patch('requests.get')
@patch('proton_computer_backups_extractor.refresh_rclone_session')
def test_fetch_shares_with_retry_cache_success(mock_refresh, mock_get, mock_load):
    """Test fetch_shares_with_retry returns the response directly if cache is valid (status 200)."""
    # Setup mocks
    mock_load.return_value = ("valid_token", "valid_uid")

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_get.return_value = mock_response

    # Run target function
    res = pbe.fetch_shares_with_retry()

    # Assertions
    assert res == mock_response
    mock_load.assert_called_once()
    mock_get.assert_called_once_with(
        "https://drive-api.proton.me/drive/shares",
        headers={
            "Authorization": "Bearer valid_token",
            "x-pm-uid": "valid_uid",
            "x-pm-appversion": "Other",
            "x-pm-apiversion": "3",
            "Accept": "application/vnd.protonmail.v1+json"
        },
        timeout=15
    )
    # refresh should not be called at all! (this is the performance gain!)
    mock_refresh.assert_not_called()

@patch('proton_computer_backups_extractor.load_credentials')
@patch('requests.get')
@patch('proton_computer_backups_extractor.refresh_rclone_session')
def test_fetch_shares_with_retry_cache_expired_then_refresh(mock_refresh, mock_get, mock_load):
    """Test fetch_shares_with_retry falls back to refresh and retry if cache is expired (e.g. status 401)."""
    # First load_credentials call returns cached values. Second load_credentials call returns refreshed values.
    mock_load.side_effect = [
        ("expired_token", "expired_uid"),
        ("refreshed_token", "refreshed_uid")
    ]

    # First requests.get call returns 401. Second requests.get call returns 200.
    mock_resp_401 = MagicMock()
    mock_resp_401.status_code = 401
    mock_resp_200 = MagicMock()
    mock_resp_200.status_code = 200
    mock_get.side_effect = [mock_resp_401, mock_resp_200]

    # Run target function
    res = pbe.fetch_shares_with_retry()

    # Assertions
    assert res == mock_resp_200
    assert mock_load.call_count == 2
    mock_refresh.assert_called_once()
    assert mock_get.call_count == 2

@patch('proton_computer_backups_extractor.load_credentials')
@patch('requests.get')
@patch('proton_computer_backups_extractor.refresh_rclone_session')
def test_fetch_shares_with_retry_cache_throws_then_refresh(mock_refresh, mock_get, mock_load):
    """Test fetch_shares_with_retry falls back to refresh and retry if cached request throws an exception."""
    mock_load.side_effect = [
        ("faulty_token", "faulty_uid"),
        ("refreshed_token", "refreshed_uid")
    ]

    # First requests.get call throws an exception. Second requests.get call returns 200.
    mock_resp_200 = MagicMock()
    mock_resp_200.status_code = 200
    mock_get.side_effect = [requests.exceptions.RequestException("Timeout"), mock_resp_200]

    # Run target function
    res = pbe.fetch_shares_with_retry()

    # Assertions
    assert res == mock_resp_200
    assert mock_load.call_count == 2
    mock_refresh.assert_called_once()
    assert mock_get.call_count == 2
