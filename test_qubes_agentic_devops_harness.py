import subprocess
from unittest.mock import patch
from qubes_agentic_devops_harness import run_cmd

def test_run_cmd_success():
    # Test a command that runs successfully
    code, stdout, stderr = run_cmd("echo 'hello'")
    assert code == 0
    assert stdout == "hello"
    assert stderr == ""

def test_run_cmd_failure():
    # Test a command that runs but exits with non-zero code
    code, stdout, stderr = run_cmd("false")
    assert code != 0

@patch("subprocess.run")
def test_run_cmd_subprocess_error(mock_run):
    # Test when subprocess.run raises a SubprocessError
    mock_run.side_effect = subprocess.SubprocessError("Subprocess failed")
    code, stdout, stderr = run_cmd("mock_command")
    assert code == -1
    assert stdout == ""
    assert "Subprocess failed" in stderr

@patch("subprocess.run")
def test_run_cmd_os_error(mock_run):
    # Test when subprocess.run raises an OSError
    mock_run.side_effect = OSError("No such file or directory")
    code, stdout, stderr = run_cmd("mock_command")
    assert code == -1
    assert stdout == ""
    assert "No such file or directory" in stderr
