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
        for tool in ["codesign", "security", "unzip", "zip"]:
            if not shutil.which(tool):
                raise RuntimeError("IPA resign requires macOS tool: " + tool)
        with tempfile.TemporaryDirectory() as td:
            ipa = os.path.join(td, "input.ipa")
            p12 = os.path.join(td, "identity.p12")
            profile = os.path.join(td, "embedded.mobileprovision")
            keychain = os.path.join(td, "signforge.keychain-db")
            work = os.path.join(td, "work")
            out = os.path.join(td, "signed.ipa")
            open(ipa, "wb").write(base64.b64decode(payload["ipaBase64"]))
            open(p12, "wb").write(base64.b64decode(payload["p12Base64"]))
            open(profile, "wb").write(base64.b64decode(payload["mobileProvisionBase64"]))
            os.makedirs(work)
            log = run(["unzip", "-q", ipa, "-d", work])
            payload_dir = os.path.join(work, "Payload")
            apps = [os.path.join(payload_dir, name) for name in os.listdir(payload_dir) if name.endswith(".app")]
            if not apps:
                raise RuntimeError("IPA did not contain Payload/*.app")
            app = apps[0]
            shutil.copy(profile, os.path.join(app, "embedded.mobileprovision"))
            keychain_password = "signforge-temp"
            log += run(["security", "create-keychain", "-p", keychain_password, keychain])
            log += run(["security", "unlock-keychain", "-p", keychain_password, keychain])
            log += run(["security", "import", p12, "-k", keychain, "-P", payload["p12Password"], "-T", "/usr/bin/codesign"])
            log += run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", keychain_password, keychain])
            identities = run(["security", "find-identity", "-v", "-p", "codesigning", keychain])
            identity = None
            for line in identities.splitlines():
                parts = line.strip().split()
                if len(parts) >= 2 and parts[0].rstrip(")").isdigit():
                    identity = parts[1]
                    break
            if not identity:
                raise RuntimeError("No codesigning identity found in P12")
            entitlements = None
            if payload.get("entitlementsPlist"):
                entitlements = os.path.join(td, "entitlements.plist")
                open(entitlements, "w").write(payload["entitlementsPlist"])
            cmd = ["codesign", "-f", "-s", identity, "--keychain", keychain]
            if entitlements:
                cmd += ["--entitlements", entitlements]
            cmd += [app]
            log += run(cmd)
            log += run(["zip", "-qry", out, "Payload"], cwd=work)
            return {"filename": "signed.ipa", "base64": base64.b64encode(open(out, "rb").read()).decode(), "log": log + identities}

if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
