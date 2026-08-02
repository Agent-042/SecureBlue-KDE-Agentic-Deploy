import unittest
from unittest.mock import patch, MagicMock
import xml.etree.ElementTree as ET

# Import the functions to test
import deploy_qubes_nested

class TestDeployQubesNested(unittest.TestCase):

    def test_calculate_gui_videoram_defaults(self):
        # Default: 1920, 1080, 1
        # (1920 * 1080 * 4 / 1024) * 1 + 16384 = 8100 * 1 + 16384 = 24484
        expected = int((1920 * 1080 * 4 / 1024) * 1) + 16384
        vram = deploy_qubes_nested.calculate_gui_videoram()
        self.assertEqual(vram, expected)
        self.assertEqual(vram, 24484)

    def test_calculate_gui_videoram_custom(self):
        # Test custom parameters (e.g., dual monitor 1080p)
        # (1920 * 1080 * 4 / 1024) * 2 + 16384 = 8100 * 2 + 16384 = 32584
        vram_dual = deploy_qubes_nested.calculate_gui_videoram(1920, 1080, 2)
        self.assertEqual(vram_dual, 32584)

        # Test 4K single display
        # (3840 * 2160 * 4 / 1024) * 1 + 16384 = 32400 + 16384 = 48784
        vram_4k = deploy_qubes_nested.calculate_gui_videoram(3840, 2160, 1)
        self.assertEqual(vram_4k, 48784)

    @patch('deploy_qubes_nested.calculate_gui_videoram')
    def test_generate_domain_xml_calls_calculate_vram(self, mock_calc):
        mock_calc.return_value = 24484
        deploy_qubes_nested.generate_domain_xml()
        mock_calc.assert_called_once_with(1920, 1080, 1)

    def test_generate_domain_xml_content(self):
        xml_str = deploy_qubes_nested.generate_domain_xml()

        # Verify XML is well-formed
        try:
            root = ET.fromstring(xml_str)
        except ET.ParseError as e:
            self.fail(f"generate_domain_xml output is not well-formed XML: {e}")

        # Assert basic domain metadata
        self.assertEqual(root.tag, 'domain')
        self.assertEqual(root.attrib.get('type'), 'kvm')

        name_elem = root.find('name')
        self.assertIsNotNone(name_elem)
        self.assertEqual(name_elem.text, deploy_qubes_nested.VM_NAME)

        # Assert memory settings
        memory_elem = root.find('memory')
        self.assertIsNotNone(memory_elem)
        self.assertEqual(memory_elem.text, '16777216')
        self.assertEqual(memory_elem.attrib.get('unit'), 'KiB')

        # Assert CPU nested virtualization configurations
        cpu_elem = root.find('cpu')
        self.assertIsNotNone(cpu_elem)
        self.assertEqual(cpu_elem.attrib.get('mode'), 'host-passthrough')

        features = [f.attrib.get('name') for f in cpu_elem.findall('feature')]
        self.assertIn('vmx', features)
        self.assertIn('svm', features)

        # Assert specific hardware elements
        devices_elem = root.find('devices')
        self.assertIsNotNone(devices_elem)

        # Check for looking-glass IVSHMEM
        shmem_elem = devices_elem.find("shmem[@name='looking-glass-bazzite']")
        self.assertIsNotNone(shmem_elem)
        size_elem = shmem_elem.find('size')
        self.assertIsNotNone(size_elem)
        self.assertEqual(size_elem.text, '128')
        self.assertEqual(size_elem.attrib.get('unit'), 'M')

        # Check for VGA video vram
        video_elem = devices_elem.find('video')
        self.assertIsNotNone(video_elem)
        model_elem = video_elem.find('model')
        self.assertIsNotNone(model_elem)
        self.assertEqual(model_elem.attrib.get('type'), 'vga')
        self.assertEqual(model_elem.attrib.get('vram'), '65536')

if __name__ == '__main__':
    unittest.main()
