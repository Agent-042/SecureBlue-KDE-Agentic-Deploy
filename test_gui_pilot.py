import unittest
from unittest.mock import patch, MagicMock
import subprocess
import os

import gui_pilot

class TestGuiPilot(unittest.TestCase):

    @patch('subprocess.check_output')
    def test_get_vm_vnc_port_xml_success(self, mock_check_output):
        # Mock XML output from virsh dumpxml
        xml_content = """
        <domain type='kvm'>
          <devices>
            <graphics type='vnc' port='5901' autoport='yes' listen='127.0.0.1'/>
          </devices>
        </domain>
        """
        mock_check_output.return_value = xml_content.encode('utf-8')

        port = gui_pilot.get_vm_vnc_port('test_vm')
        self.assertEqual(port, 5901)
        mock_check_output.assert_called_once_with(['virsh', 'dumpxml', 'test_vm'], stderr=subprocess.DEVNULL)

    @patch('subprocess.check_output')
    def test_get_vm_vnc_port_domdisplay_fallback(self, mock_check_output):
        # Let's say dumpxml raises an Exception, and fallback to domdisplay succeeds
        def check_output_side_effect(args, **kwargs):
            if 'dumpxml' in args:
                raise subprocess.CalledProcessError(1, args)
            elif 'domdisplay' in args:
                return b'vnc://127.0.0.1:5902\n'
            raise ValueError(f"Unexpected args: {args}")

        mock_check_output.side_effect = check_output_side_effect

        port = gui_pilot.get_vm_vnc_port('test_vm')
        self.assertEqual(port, 5902)

    @patch('subprocess.check_output')
    def test_get_vm_vnc_port_all_fails(self, mock_check_output):
        # All virsh commands fail
        mock_check_output.side_effect = Exception("virsh command failed")

        port = gui_pilot.get_vm_vnc_port('test_vm')
        self.assertIsNone(port)

    @patch('gui_pilot.get_vm_vnc_port')
    @patch('subprocess.check_output')
    def test_get_all_vms(self, mock_check_output, mock_get_vnc_port):
        # Mock virsh list --all
        virsh_list_output = (
            " Id    Name                           State\n"
            "----------------------------------------------------\n"
            " 1     active_vm                      running\n"
            " -     shut_vm                        shut off\n"
        )
        mock_check_output.return_value = virsh_list_output.encode('utf-8')
        mock_get_vnc_port.side_effect = lambda name: 5901 if name == 'active_vm' else None

        vms = gui_pilot.get_all_vms()
        self.assertEqual(len(vms), 2)
        self.assertEqual(vms[0]['name'], 'active_vm')
        self.assertEqual(vms[0]['id'], '1')
        self.assertEqual(vms[0]['state'], 'running')
        self.assertEqual(vms[0]['vnc_port'], 5901)

        self.assertEqual(vms[1]['name'], '-')
        self.assertEqual(vms[1]['id'], '-')
        self.assertEqual(vms[1]['state'], 'shut_vm shut off')
        self.assertIsNone(vms[1]['vnc_port'])

    @patch('subprocess.check_output')
    @patch('os.remove')
    @patch('os.path.exists')
    def test_vm_screenshot(self, mock_exists, mock_remove, mock_check_output):
        mock_exists.return_value = True
        mock_check_output.side_effect = [
            b"", # virsh screenshot success
            b"", # convert success
            b"/tmp/test_vm_screenshot.png: PNG image data, 1024 x 768, 8-bit/color RGB, non-interlaced" # file output
        ]

        res = gui_pilot.vm_screenshot('test_vm', '/tmp/test_vm_screenshot.png')
        self.assertEqual(res['status'], 'success')
        self.assertEqual(res['filepath'], '/tmp/test_vm_screenshot.png')
        self.assertEqual(res['dimensions'], '1024')
