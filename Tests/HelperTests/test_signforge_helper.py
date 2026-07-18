import base64
import importlib.util
import json
import os
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HELPER = os.path.join(ROOT, 'Tools', 'signforge-helper', 'signforge_helper.py')
spec = importlib.util.spec_from_file_location('signforge_helper', HELPER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class HelperTests(unittest.TestCase):
    def test_run_reports_failure_text(self):
        with self.assertRaises(RuntimeError) as ctx:
            module.run(['python3', '-c', 'import sys; sys.stderr.write("bad"); sys.exit(2)'])
        self.assertIn('bad', str(ctx.exception))

    def test_resign_requires_ipa_payload_shape_before_codesign_identity(self):
        handler = object.__new__(module.Handler)
        payload = {
            'ipaBase64': base64.b64encode(b'not-a-zip').decode(),
            'p12Base64': base64.b64encode(b'p12').decode(),
            'p12Password': 'pw',
            'mobileProvisionBase64': base64.b64encode(b'profile').decode(),
            'entitlementsPlist': None,
        }
        if not all(module.shutil.which(tool) for tool in ['codesign', 'security', 'unzip', 'zip']):
            with self.assertRaises(RuntimeError):
                handler.resign(payload)

if __name__ == '__main__':
    unittest.main()
