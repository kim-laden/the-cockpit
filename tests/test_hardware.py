"""Unit tests for tools/cockpit-hardware.py (privacy filters and safe degradation)."""
import importlib.util
import pathlib
import subprocess
import unittest
from unittest.mock import patch

PATH = pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'cockpit-hardware.py'
spec = importlib.util.spec_from_file_location('cockpit_hardware', PATH)
hw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hw)


class Tests(unittest.TestCase):
    def test_renderer_filters_identifiers(self):
        text = 'OpenGL renderer string: llvmpipe\nDevice UUID: secret\nOpenGL vendor string: Mesa'
        out = hw.renderer_summary(text)
        self.assertEqual(len(out), 2)
        self.assertNotIn('secret', str(out))

    def test_pci_filters_unrelated(self):
        text = ('01:00.0 VGA compatible controller: Example GPU\n\tSubsystem: private\n'
                '\tKernel driver in use: amdgpu\n\n02:00.0 Audio device: skip')
        self.assertEqual(hw.pci_summary(text), ['VGA compatible controller: Example GPU', 'Kernel driver in use: amdgpu'])

    def test_wifi_modes_only(self):
        text = 'Supported interface modes:\n\t * managed\n\t * monitor\nBand 1:\n\t* secret extra'
        self.assertEqual(hw.wifi_summary(text), ['managed', 'monitor'])

    def test_mac_display_filter(self):
        text = 'Chipset Model: Apple M2\nSerial Number: SECRET\nMetal Support: Metal 3'
        out = hw.mac_display_summary(text)
        self.assertEqual(out, ['Chipset Model: Apple M2', 'Metal Support: Metal 3'])

    def test_missing_tool(self):
        with patch.object(hw.shutil, 'which', return_value=None), patch.object(hw.subprocess, 'run') as run:
            self.assertEqual(hw.run(['missing']), '')
            run.assert_not_called()

    def test_timed_out_tool(self):
        with patch.object(hw.shutil, 'which', return_value='/tool'), \
                patch.object(hw.subprocess, 'run', side_effect=subprocess.TimeoutExpired('tool', 8)):
            self.assertEqual(hw.run(['tool']), '')

    def test_advisory_only(self):
        out = hw.advice({'ram_gib': 4, 'opengl_current_session': ['OpenGL renderer string: llvmpipe']})
        self.assertTrue(any('Limited RAM' in x for x in out))
        self.assertTrue(any('Software OpenGL' in x for x in out))

    def test_collect_runs_here(self):
        data = hw.collect()
        self.assertIn('architecture', data)
        self.assertIn('tools', data)


if __name__ == '__main__':
    unittest.main()
