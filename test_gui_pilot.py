import unittest
from unittest.mock import patch, MagicMock
import subprocess
import xml.etree.ElementTree as ET
import logging

from gui_pilot import get_vm_vnc_port, logger

class TestGuiPilotVncPort(unittest.TestCase):

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_success_xml(self, mock_check_output):
        # XML contains a valid vnc port
        xml_content = b"""
        <domain>
          <devices>
            <graphics type='vnc' port='5902'/>
          </devices>
        </domain>
        """
        mock_check_output.return_value = xml_content

        port = get_vm_vnc_port('my-test-vm')

        self.assertEqual(port, 5902)
        # Verify first subprocess call
        mock_check_output.assert_called_once_with(['virsh', 'dumpxml', 'my-test-vm'], stderr=subprocess.DEVNULL)

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_no_devices_fallback_success(self, mock_check_output):
        # First call returns XML with no devices, second call succeeds with domdisplay
        xml_content = b"<domain></domain>"
        domdisplay_output = b"vnc://127.0.0.1:5903"

        mock_check_output.side_effect = [xml_content, domdisplay_output]

        port = get_vm_vnc_port('my-test-vm')
        self.assertEqual(port, 5903)
        self.assertEqual(mock_check_output.call_count, 2)

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_xml_failed_fallback_success(self, mock_check_output):
        # First call raises CalledProcessError, second call succeeds with domdisplay
        mock_check_output.side_effect = [
            subprocess.CalledProcessError(1, 'virsh dumpxml'),
            b"vnc://127.0.0.1:5904"
        ]

        with self.assertLogs(logger, level='DEBUG') as log_capture:
            port = get_vm_vnc_port('my-test-vm')

        self.assertEqual(port, 5904)
        self.assertEqual(mock_check_output.call_count, 2)
        # Check that debug message was logged
        self.assertTrue(any("Failed to get VM XML from virsh" in msg for msg in log_capture.output))

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_xml_malformed_fallback_success(self, mock_check_output):
        # First call returns malformed XML, second call succeeds with domdisplay
        xml_content = b"<domain><devices><graphics"  # Malformed
        domdisplay_output = b"vnc://127.0.0.1:5905"

        mock_check_output.side_effect = [xml_content, domdisplay_output]

        with self.assertLogs(logger, level='WARNING') as log_capture:
            port = get_vm_vnc_port('my-test-vm')

        self.assertEqual(port, 5905)
        self.assertEqual(mock_check_output.call_count, 2)
        # Check that warning message was logged
        self.assertTrue(any("Failed to parse VM XML" in msg for msg in log_capture.output))

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_unexpected_error_fallback_success(self, mock_check_output):
        # First call raises an unexpected exception (e.g. ValueError or RuntimeError), second succeeds
        mock_check_output.side_effect = [
            RuntimeError("Unexpected error"),
            b"vnc://127.0.0.1:5906"
        ]

        with self.assertLogs(logger, level='ERROR') as log_capture:
            port = get_vm_vnc_port('my-test-vm')

        self.assertEqual(port, 5906)
        self.assertEqual(mock_check_output.call_count, 2)
        self.assertTrue(any("Unexpected error getting VNC port" in msg for msg in log_capture.output))

    @patch('gui_pilot.subprocess.check_output')
    def test_get_vnc_port_all_failed(self, mock_check_output):
        # Both methods fail
        mock_check_output.side_effect = [
            subprocess.CalledProcessError(1, 'virsh dumpxml'),
            subprocess.CalledProcessError(1, 'virsh domdisplay')
        ]

        with self.assertLogs(logger, level='DEBUG') as log_capture:
            port = get_vm_vnc_port('my-test-vm')

        self.assertIsNone(port)
        self.assertEqual(mock_check_output.call_count, 2)
        self.assertTrue(any("Failed to get VM XML from virsh" in msg for msg in log_capture.output))
        self.assertTrue(any("Failed to get domdisplay from virsh" in msg for msg in log_capture.output))
