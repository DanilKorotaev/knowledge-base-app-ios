#!/usr/bin/env python3
"""
POST iOS CI events to KB App per-user ingress.

Env (GitHub Actions repository secret — full URL including token):
  KBAPP_INGRESS_URL=https://<host>/api/ingress/<token>

Optional:
  KBAPP_INGRESS_DISABLED=1
  KBAPP_INGRESS_SOURCE=github_actions

Telegram notify stays separate. Body schema is fixed; routing is server-side.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEST_OUTPUT = REPO_ROOT / "fastlane" / "test_output"


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def github_run_url() -> str | None:
    server = _env("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    repo = _env("GITHUB_REPOSITORY")
    run_id = _env("GITHUB_RUN_ID")
    if repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return None


def git_commit_message() -> str:
    sha = _env("GITHUB_SHA")
    if not sha:
        return ""
    try:
        proc = subprocess.run(
            ["git", "log", "-1", "--pretty=%B", sha],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if proc.returncode == 0:
            return proc.stdout.strip()
    except (subprocess.SubprocessError, OSError):
        pass
    return ""


def collect_failed_tests(output_dir: Path) -> list[str]:
    """Best-effort: reuse telegram_notify helpers when available."""
    try:
        from telegram_notify import (  # type: ignore
            collect_failed_tests as _collect,
            find_xcresult,
        )
    except Exception:
        return []
    xc = find_xcresult(output_dir)
    if not xc:
        return []
    try:
        return list(_collect(xc) or [])[:40]
    except Exception:
        return []


def post_json(url: str, payload: dict) -> None:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = response.read().decode("utf-8", errors="replace")
            print(f"ingress HTTP {response.status}: {body[:500]}")
    except urllib.error.HTTPError as exc:
        err = exc.read().decode("utf-8", errors="replace")
        print(f"ingress HTTP {exc.code}: {err}", file=sys.stderr)
        sys.exit(0)
    except urllib.error.URLError as exc:
        print(f"ingress URL error: {exc}", file=sys.stderr)
        sys.exit(0)


def build_envelope(*, kind: str, outcome: str, failed_tests: list[str]) -> dict:
    source = _env("KBAPP_INGRESS_SOURCE", "github_actions")
    repo = _env("GITHUB_REPOSITORY") or "unknown"
    ref = _env("GITHUB_REF_NAME")
    sha = _env("GITHUB_SHA")
    run_url = github_run_url()
    ok = outcome == "success"
    event_type = f"ci.{kind}_{'succeeded' if ok else 'failed'}"
    summary = f"{repo}: {kind} {'OK' if ok else 'FAILED'}"
    if ref:
        summary = f"{summary} ({ref})"

    detail_parts = [
        f"repository: {repo}",
        f"kind: {kind}",
        f"outcome: {outcome}",
        f"ref: {ref or '-'}",
        f"sha: {sha or '-'}",
    ]
    if run_url:
        detail_parts.append(f"run: {run_url}")
    if failed_tests:
        detail_parts.append("failed_tests:")
        detail_parts.extend(f"- {name}" for name in failed_tests)

    links = [{"title": "Workflow run", "url": run_url}] if run_url else []
    dedupe = _env("GITHUB_RUN_ID") or sha or "local"

    return {
        "source": source,
        "type": event_type,
        "summary": summary,
        "detail": "\n".join(detail_parts),
        "hints": {
            "commit_sha": sha,
            "commit_message": git_commit_message(),
            "repository": repo,
            "ref": ref,
            "workflow": _env("GITHUB_WORKFLOW"),
            "run_id": _env("GITHUB_RUN_ID"),
            "kind": kind,
            "outcome": outcome,
        },
        "payload": {
            "failed_tests": failed_tests,
            "outcome": outcome,
            "kind": kind,
        },
        "links": links,
        "dedupe_key": f"gha:{repo}:{kind}:{dedupe}:{outcome}",
        "adapter_key": "github_actions",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=["tests", "testflight", "build"])
    parser.add_argument("--outcome", required=True)
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_TEST_OUTPUT),
        help="fastlane test_output directory for xcresult scrape",
    )
    args = parser.parse_args()

    if _env("KBAPP_INGRESS_DISABLED") in ("1", "true", "yes"):
        print("KBAPP_INGRESS_DISABLED: skip")
        return

    url = _env("KBAPP_INGRESS_URL")
    if not url:
        print("KBAPP_INGRESS_URL not set; skip ingress notify")
        return

    failed: list[str] = []
    if args.kind == "tests" and args.outcome != "success":
        # Import sibling module from same scripts/ci directory.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        failed = collect_failed_tests(Path(args.output_dir))

    post_json(url, build_envelope(kind=args.kind, outcome=args.outcome, failed_tests=failed))


if __name__ == "__main__":
    main()
