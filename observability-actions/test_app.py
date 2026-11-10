import json
import os
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch

os.environ.setdefault("ALERT_WEBHOOK_TOKEN", "test-token-that-is-long-enough-123456")
os.environ.setdefault("DISCORD_WEBHOOK_URL", "https://discord.com/api/webhooks/test/token")
os.environ.setdefault("KUBERNETES_SERVICE_HOST", "127.0.0.1")

import app


class SelfHealingTests(unittest.TestCase):
    def test_only_allowlisted_alerts_restart_deployments(self):
        payload = {
            "status": "firing",
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "AuthServiceHigh5xx"},
                    "fingerprint": "auth-alert",
                },
                {
                    "status": "firing",
                    "labels": {"alertname": "UnexpectedAlert"},
                    "fingerprint": "unexpected-alert",
                },
            ],
        }

        with patch("app._restart_deployment", return_value=True) as restart:
            restarted, skipped = app._process_self_healing(payload)

        self.assertEqual(restarted, ["auth-service"])
        self.assertEqual(skipped, ["UnexpectedAlert"])
        restart.assert_called_once_with("auth-service", "auth-alert", False)

    def test_unavailable_auth_alert_restores_one_replica(self):
        payload = {
            "status": "firing",
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "AuthServiceUnavailable"},
                    "fingerprint": "auth-unavailable",
                }
            ],
        }

        with patch("app._restart_deployment", return_value=True) as restart:
            restarted, skipped = app._process_self_healing(payload)

        self.assertEqual(restarted, ["auth-service"])
        self.assertEqual(skipped, [])
        restart.assert_called_once_with("auth-service", "auth-unavailable", True)

    def test_resolved_alert_does_not_restart_deployment(self):
        payload = {
            "status": "resolved",
            "alerts": [
                {
                    "status": "resolved",
                    "labels": {"alertname": "EvaluationServiceHigh5xx"},
                }
            ],
        }

        with patch("app._restart_deployment") as restart:
            restarted, skipped = app._process_self_healing(payload)

        self.assertEqual(restarted, [])
        self.assertEqual(skipped, [])
        restart.assert_not_called()

    def test_webhook_token_uses_bearer_authentication(self):
        self.assertTrue(app._authorized("Bearer test-token-that-is-long-enough-123456"))
        self.assertFalse(app._authorized("Bearer wrong-token"))
        self.assertFalse(app._authorized("test-token"))


class WebhookHandlerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), app.AlertHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def _post(self, path, payload, token="test-token-that-is-long-enough-123456"):
        request = Request(
            f"{self.base_url}{path}",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        return urlopen(request, timeout=2)

    def test_self_healing_webhook_rejects_missing_token(self):
        with self.assertRaises(HTTPError) as raised:
            self._post("/self-heal", {"status": "firing", "alerts": []}, token="invalid")

        self.assertEqual(raised.exception.code, 401)

    def test_self_healing_webhook_dispatches_valid_alert(self):
        payload = {
            "status": "firing",
            "alerts": [
                {
                    "status": "firing",
                    "labels": {"alertname": "AuthServiceUnavailable"},
                    "fingerprint": "auth-down",
                }
            ],
        }
        with patch("app._restart_deployment", return_value=True) as restart:
            with self._post("/self-heal", payload) as response:
                body = json.load(response)

        self.assertEqual(response.status, 200)
        self.assertEqual(body["restarted"], ["auth-service"])
        restart.assert_called_once_with("auth-service", "auth-down", True)


if __name__ == "__main__":
    unittest.main()
