#!/usr/bin/env python3
import base64
import json
import os
import shutil
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("SIGNFORGE_HELPER_PORT", "8765"))

def run(cmd, cwd=None):
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr or result.stdout or "command failed")
    return result.stdout + result.stderr

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")
        try:
            if self.path == "/p12":
                response = self.make_p12(payload)
            elif self.path == "/resign":
                response = self.resign(payload)
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        except Exception as exc:
            self.send_response(500)
            self.send_header("content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(exc)}).encode())

    def log_message(self, fmt, *args):
        return

    def make_p12(self, payload):
        with tempfile.TemporaryDirectory() as td:
            cert = os.path.join(td, "cert.pem")
            key = os.path.join(td, "key.pem")
            out = os.path.join(td, "identity.p12")
            open(cert, "w").write(payload["certificatePEM"])
            open(key, "w").write(payload["privateKeyPEM"])
            log = run(["openssl", "pkcs12", "-export", "-in", cert, "-inkey", key, "-out", out, "-password", "pass:" + payload["password"]])
            return {"filename": "identity.p12", "base64": base64.b64encode(open(out, "rb").read()).decode(), "log": log}

    def resign(self, payload):
        if not shutil.which("codesign"):
            raise RuntimeError("IPA resign requires macOS codesign in this helper environment")
        with tempfile.TemporaryDirectory() as td:
            ipa = os.path.join(td, "app.ipa")
            open(ipa, "wb").write(base64.b64decode(payload["ipaBase64"]))
            log = "codesign integration point prepared; implement certificate import and app bundle signing here"
            return {"filename": "signed.ipa", "base64": base64.b64encode(open(ipa, "rb").read()).decode(), "log": log}

if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
