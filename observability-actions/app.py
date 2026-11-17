import hmac
import json
import logging
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("observability-actions")

ALERT_WEBHOOK_TOKEN = os.environ["ALERT_WEBHOOK_TOKEN"]
DISCORD_WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]
KUBERNETES_API = f"https://{os.environ['KUBERNETES_SERVICE_HOST']}:{os.environ.get('KUBERNETES_SERVICE_PORT_HTTPS', '443')}"
SERVICE_ACCOUNT = Path("/var/run/secrets/kubernetes.io/serviceaccount")
RESTART_COOLDOWN_SECONDS = 600
ALERT_DEPLOYMENTS = {
    "AuthServiceHigh5xx": ("auth-service", False),
    "EvaluationServiceHigh5xx": ("evaluation-service", False),
    "AuthServiceUnavailable": ("auth-service", True),
}
if len(ALERT_WEBHOOK_TOKEN) < 32 or not DISCORD_WEBHOOK_URL.startswith(
    "https://discord.com/api/webhooks/"
):
    raise RuntimeError("Webhook token ou URL do Discord inválidos")

_restart_times = {}
_restart_lock = threading.Lock()


def _authorized(header):
    scheme, separator, token = header.partition(" ")
    return (
        separator == " "
        and scheme.lower() == "bearer"
        and hmac.compare_digest(token, ALERT_WEBHOOK_TOKEN)
    )


def _post_discord(payload):
    alerts = payload.get("alerts", [])
    lines = []
    for alert in alerts[:10]:
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        alert_name = labels.get("alertname", "Alert")
        status = alert.get("status", payload.get("status", "unknown"))
        summary = annotations.get("summary", "Sem resumo")
        lines.append(f"**{status.upper()} — {alert_name}**\n{summary[:500]}")

    content = "\n\n".join(lines) or f"Alerta ToggleMaster: {payload.get('status', 'unknown')}"
    response = requests.post(
        DISCORD_WEBHOOK_URL,
        json={"content": content[:1900], "allowed_mentions": {"parse": []}},
        timeout=5,
    )
    response.raise_for_status()


def _restart_deployment(deployment_name, fingerprint, restore_replica=False):
    now = time.monotonic()
    with _restart_lock:
        last_restart = _restart_times.get(fingerprint, 0)
        if now - last_restart < RESTART_COOLDOWN_SECONDS:
            return False

        token = (SERVICE_ACCOUNT / "token").read_text(encoding="utf-8").strip()
        ca_path = SERVICE_ACCOUNT / "ca.crt"
        url = (
            f"{KUBERNETES_API}/apis/apps/v1/namespaces/togglemaster/"
            f"deployments/{deployment_name}"
        )
        deployment_patch = {
            "template": {
                "metadata": {
                    "annotations": {
                        "kubectl.kubernetes.io/restartedAt": time.strftime(
                            "%Y-%m-%dT%H:%M:%SZ", time.gmtime()
                        )
                    }
                }
            }
        }
        if restore_replica:
            deployment_patch["replicas"] = 1

        response = requests.patch(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/merge-patch+json",
            },
            json={"spec": deployment_patch},
            verify=str(ca_path),
            timeout=10,
        )
        response.raise_for_status()
        _restart_times[fingerprint] = now
        return True


def _process_self_healing(payload):
    restarted = []
    skipped = []
    if payload.get("status") == "firing":
        for alert in payload["alerts"]:
            if not isinstance(alert, dict) or alert.get("status") != "firing":
                continue
            labels = alert.get("labels", {})
            if not isinstance(labels, dict):
                skipped.append("unknown")
                continue
            alert_name = labels.get("alertname", "unknown")
            deployment_action = ALERT_DEPLOYMENTS.get(alert_name)
            if not deployment_action:
                skipped.append(alert_name)
                continue
            deployment, restore_replica = deployment_action
            fingerprint = alert.get("fingerprint", labels.get("alertname", deployment))
            if _restart_deployment(deployment, fingerprint, restore_replica):
                restarted.append(deployment)
            else:
                skipped.append(deployment)
    return restarted, skipped


class AlertHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        else:
            self._respond(404, {"error": "not found"})

    def do_POST(self):
        if self.path not in {"/discord", "/self-heal"}:
            self._respond(404, {"error": "not found"})
            return
        if not _authorized(self.headers.get("Authorization", "")):
            self._respond(401, {"error": "unauthorized"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > 1_000_000:
                self._respond(413, {"error": "invalid payload size"})
                return
            payload = json.loads(self.rfile.read(content_length))
            if not isinstance(payload, dict) or not isinstance(payload.get("alerts"), list):
                self._respond(400, {"error": "alerts must be a list"})
                return

            if self.path == "/discord":
                _post_discord(payload)
                self._respond(200, {"status": "notified"})
                return

            restarted, skipped = _process_self_healing(payload)
            log.info("Self-healing: reiniciados=%s ignorados=%s", restarted, skipped)
            self._respond(200, {"restarted": restarted, "skipped": skipped})
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            self._respond(400, {"error": "invalid JSON payload"})
        except requests.RequestException as exc:
            response = getattr(exc, "response", None)
            status = response.status_code if response is not None else "sem resposta"
            log.error(
                "Falha na integração externa (%s, HTTP %s)",
                type(exc).__name__,
                status,
            )
            self._respond(502, {"error": "automation request failed"})
        except OSError:
            log.exception("Falha ao ler credenciais da ServiceAccount")
            self._respond(500, {"error": "service account credentials unavailable"})

    def _respond(self, status, body):
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        log.info("%s - %s", self.address_string(), fmt % args)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), AlertHandler)  # nosec B104 - bind necessario para funcionar em container
    log.info("Webhook de alertas ouvindo na porta %s", server.server_port)
    server.serve_forever()
