#!/usr/bin/env python3
"""
Send Knowledge Base iOS CI/CD notifications to Telegram.

Requires secrets (GitHub Actions or env):
  TELEGRAM_BOT_TOKEN — bot token from @BotFather
  TELEGRAM_CHAT_ID   — chat / channel id (e.g. from @userinfobot)

Optional:
  TELEGRAM_NOTIFY_DISABLED=1 — skip sending (no error)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEST_OUTPUT = REPO_ROOT / "fastlane" / "test_output"
DEFAULT_UI_TEST_OUTPUT = REPO_ROOT / "fastlane" / "ui_test_output"
MAX_FAILED_TESTS = 25


def html_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def github_run_url() -> str | None:
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    run_id = os.environ.get("GITHUB_RUN_ID", "").strip()
    if repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return None


def ci_context_lines() -> list[str]:
    lines: list[str] = []
    ref = os.environ.get("GITHUB_REF_NAME", "").strip()
    event = os.environ.get("GITHUB_EVENT_NAME", "").strip()
    if ref:
        lines.append(f"Ветка: <code>{html_escape(ref)}</code>")
    if event:
        lines.append(f"Событие: <code>{html_escape(event)}</code>")
    url = github_run_url()
    if url:
        lines.append(f'<a href="{html_escape(url)}">Workflow run</a>')
    return lines


def send_telegram(text: str) -> None:
    if os.environ.get("TELEGRAM_NOTIFY_DISABLED", "").strip() in ("1", "true", "yes"):
        print("TELEGRAM_NOTIFY_DISABLED: skip")
        return

    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    if not token or not chat_id:
        print("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set; skip notify")
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = urllib.parse.urlencode(
        {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
            "disable_web_page_preview": "true",
        }
    ).encode("utf-8")
    request = urllib.request.Request(url, data=payload, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        print(f"Telegram API HTTP {exc.code}: {err_body}", file=sys.stderr)
        sys.exit(1)

    if not body.get("ok"):
        print(f"Telegram API error: {body}", file=sys.stderr)
        sys.exit(1)


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True)


def find_xcresult(output_dir: Path) -> Path | None:
    if not output_dir.is_dir():
        return None
    results = sorted(output_dir.glob("*.xcresult"), key=lambda p: p.stat().st_mtime, reverse=True)
    return results[0] if results else None


def parse_test_summary(xcresult: Path) -> dict[str, int]:
    proc = run_command(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(xcresult)]
    )
    if proc.returncode != 0:
        print(proc.stderr or proc.stdout, file=sys.stderr)
        return {"passed": 0, "failed": 0, "skipped": 0}

    data = json.loads(proc.stdout)
    passed = failed = skipped = 0
    for block in data.get("devicesAndConfigurations", []):
        passed += int(block.get("passedTests", 0))
        failed += int(block.get("failedTests", 0))
        skipped += int(block.get("skippedTests", 0))
    return {"passed": passed, "failed": failed, "skipped": skipped}


def collect_failed_tests(xcresult: Path) -> list[str]:
    proc = run_command(
        [
            "xcrun",
            "xcresulttool",
            "get",
            "test-results",
            "tests",
            "--path",
            str(xcresult),
            "--format",
            "json",
            "--legacy",
        ]
    )
    if proc.returncode != 0:
        return []

    data = json.loads(proc.stdout)
    failed: list[str] = []

    def walk(nodes: list[dict[str, Any]] | None) -> None:
        for node in nodes or []:
            result = str(node.get("result", "")).lower()
            node_type = node.get("nodeType", "")
            name = node.get("name", "")
            if node_type == "Test Case" and result in ("failed", "failure"):
                identifier = node.get("nodeIdentifier") or name
                failed.append(str(identifier))
            walk(node.get("children"))

    walk(data.get("testNodes"))
    return failed


def parse_coverage_percent(output_dir: Path) -> float | None:
    xcresult = find_xcresult(output_dir)
    if not xcresult:
        return None

    proc = run_command(["xcrun", "xccov", "view", "--report", "--json", str(xcresult)])
    if proc.returncode != 0:
        return None

    data = json.loads(proc.stdout)
    for target in data.get("targets", []):
        if target.get("name") == "KnowledgeBaseApp.app":
            return round(float(target.get("lineCoverage", 0)) * 100, 2)
    return None


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def empty_counts() -> dict[str, int]:
    return {"passed": 0, "failed": 0, "skipped": 0}


def suite_counts(output_dir: Path) -> tuple[dict[str, int], Path | None]:
    xcresult = find_xcresult(output_dir)
    if not xcresult:
        return empty_counts(), None
    return parse_test_summary(xcresult), xcresult


def format_suite_block(
    title: str,
    outcome: str,
    counts: dict[str, int],
    xcresult: Path | None,
    *,
    coverage: float | None = None,
    min_cov: str | None = None,
    ran: bool,
) -> list[str]:
    """One Unit/UI block for the combined tests Telegram message."""
    lines = [f"<b>{html_escape(title)}</b>"]

    if not ran or outcome == "skipped":
        lines.append("Статус: <code>skipped</code>")
        return lines

    suite_ok = outcome == "success" and counts["failed"] == 0
    status = "✅ success" if suite_ok else "❌ failure"
    if outcome == "cancelled":
        status = "⏹ cancelled"
    lines.extend(
        [
            f"Статус: <code>{html_escape(status)}</code>",
            f"Успешно: <b>{counts['passed']}</b>",
            f"Провалено: <b>{counts['failed']}</b>",
            f"Пропущено: <b>{counts['skipped']}</b>",
        ]
    )

    if coverage is not None and min_cov is not None:
        lines.append(f"Покрытие (app): <b>{coverage}%</b> (мин. {html_escape(min_cov)}%)")
    elif title.startswith("Unit") and not suite_ok and ran:
        lines.append("Покрытие: не удалось прочитать из .xcresult")

    if xcresult and counts["failed"] > 0:
        failed_tests = collect_failed_tests(xcresult)
        if failed_tests:
            lines.append("Упавшие:")
            for name in failed_tests[:MAX_FAILED_TESTS]:
                lines.append(f"• <code>{html_escape(name)}</code>")
            if len(failed_tests) > MAX_FAILED_TESTS:
                lines.append(f"• … и ещё {len(failed_tests) - MAX_FAILED_TESTS}")

    if outcome != "success" and counts["failed"] == 0 and ran:
        lines.append(
            "<i>Шаг завершился с ошибкой (сборка / покрытие / fastlane), "
            "но Failed test case в отчёте нет.</i>"
        )

    return lines


def build_tests_message(
    outcome: str,
    output_dir: Path,
    *,
    ui_outcome: str = "skipped",
    ui_output_dir: Path | None = None,
) -> str:
    ui_dir = ui_output_dir or DEFAULT_UI_TEST_OUTPUT
    unit_counts, unit_xc = suite_counts(output_dir)
    ui_counts, ui_xc = suite_counts(ui_dir)
    coverage = parse_coverage_percent(output_dir)
    min_cov = os.environ.get("MIN_COVERAGE", "35").strip()

    unit_ran = outcome != "skipped"
    ui_ran = ui_outcome not in {"skipped", ""}
    unit_ok = outcome == "success" and unit_counts["failed"] == 0
    ui_ok = (not ui_ran) or (ui_outcome == "success" and ui_counts["failed"] == 0)
    success = unit_ok and ui_ok

    title = (
        "✅ <b>Knowledge Base iOS — тесты пройдены</b>"
        if success
        else "❌ <b>Knowledge Base iOS — тесты упали</b>"
    )

    lines = [title, ""] + ci_context_lines() + [""]
    lines.extend(
        format_suite_block(
            "Unit",
            outcome,
            unit_counts,
            unit_xc,
            coverage=coverage,
            min_cov=min_cov,
            ran=unit_ran,
        )
    )
    lines.append("")
    lines.extend(
        format_suite_block(
            "UI",
            ui_outcome,
            ui_counts,
            ui_xc,
            ran=ui_ran,
        )
    )
    return "\n".join(lines)


def build_testflight_message(
    outcome: str,
    output_dir: Path,
    *,
    release_git_outcome: str = "skipped",
) -> str:
    meta = load_json(output_dir / "ci_testflight.json") or {}
    version = str(meta.get("marketing_version", "?"))
    build = str(meta.get("build_number", "?"))
    app_id = str(meta.get("app_identifier", ""))
    file_version = ""
    version_path = REPO_ROOT / "VERSION"
    if version_path.is_file():
        file_version = version_path.read_text(encoding="utf-8").strip()
    if version in ("", "?"):
        version = file_version or "?"

    upload_ok = outcome == "success"
    release_git = (release_git_outcome or "skipped").strip().lower()
    # Upload OK but tag/commit failed → do not claim full success
    full_ok = upload_ok and release_git in {"success", "skipped"}
    partial = upload_ok and release_git not in {"success", "skipped"}

    if full_ok:
        title = "✅ <b>Knowledge Base iOS — TestFlight</b>"
    elif partial:
        title = "⚠️ <b>Knowledge Base iOS — TestFlight загружен, релизный тег не создан</b>"
    else:
        title = "❌ <b>Knowledge Base iOS — сборка TestFlight не удалась</b>"

    lines = [
        title,
        "",
        *ci_context_lines(),
        "",
        f"Версия: <b>{html_escape(version)}</b> ({html_escape(build)})",
    ]
    if app_id:
        lines.append(f"Bundle ID: <code>{html_escape(app_id)}</code>")

    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    if repo:
        changelog_url = f"{server}/{repo}/blob/main/CHANGELOG.md"
        lines.append(f'<a href="{html_escape(changelog_url)}">CHANGELOG</a>')
        if version not in ("", "?"):
            tag = f"ios/v{version}"
            tag_url = f"{server}/{repo}/releases/tag/{tag}"
            lines.append(f'Tag: <a href="{html_escape(tag_url)}"><code>{html_escape(tag)}</code></a>')

    lines.append("")
    if full_ok:
        lines.append("Сборка собрана и отправлена в App Store Connect (TestFlight).")
        if release_git == "success":
            lines.append("Релизный коммит и тег <code>ios/v*</code> запушены.")
    elif partial:
        lines.append(
            "IPA в App Store Connect есть, но шаг <code>commit_and_tag_release</code> упал "
            f"(outcome=<code>{html_escape(release_git)}</code>). "
            "Тег/CHANGELOG на main могут отсутствовать — смотри логи workflow."
        )
    else:
        lines.append("См. логи workflow для деталей (match, archive, upload).")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Telegram CI notifications for Knowledge Base iOS")
    parser.add_argument(
        "event",
        choices=["tests", "testflight"],
        help="Notification type",
    )
    parser.add_argument(
        "--outcome",
        required=True,
        choices=["success", "failure", "cancelled", "skipped"],
        help="GitHub Actions step outcome (unit tests for event=tests)",
    )
    parser.add_argument(
        "--ui-outcome",
        default="skipped",
        choices=["success", "failure", "cancelled", "skipped"],
        help="GitHub Actions UI test step outcome (event=tests)",
    )
    parser.add_argument(
        "--release-git-outcome",
        default="skipped",
        choices=["success", "failure", "cancelled", "skipped"],
        help="Outcome of commit_and_tag_release step (testflight only)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_TEST_OUTPUT,
        help="fastlane test_output directory (unit xcresult / ci_testflight.json)",
    )
    parser.add_argument(
        "--ui-output-dir",
        type=Path,
        default=DEFAULT_UI_TEST_OUTPUT,
        help="fastlane ui_test_output directory (UI xcresult)",
    )
    args = parser.parse_args()

    if args.event == "tests":
        message = build_tests_message(
            args.outcome,
            args.output_dir,
            ui_outcome=args.ui_outcome,
            ui_output_dir=args.ui_output_dir,
        )
    else:
        message = build_testflight_message(
            args.outcome,
            args.output_dir,
            release_git_outcome=args.release_git_outcome,
        )

    send_telegram(message)
    print("Telegram notification sent.")


if __name__ == "__main__":
    main()
