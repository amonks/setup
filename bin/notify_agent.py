# ABOUTME: Triggers audible and visual alerts for Codex CLI notifications on macOS.
# ABOUTME: Emits a system beep and shows a notification summarizing the agent turn.
import json
import subprocess
import sys


def beep() -> None:
    subprocess.run(["osascript", "-e", "beep 1"], check=False)


def show_notification(message: str) -> None:
    safe_message = json.dumps(message)
    subprocess.run(
        ["osascript", "-e", f"display notification {safe_message} with title \"Codex\""],
        check=False,
    )


def select_message(payload: dict) -> str:
    last_message = payload.get("last-assistant-message")
    if last_message:
        return last_message
    input_messages = payload.get("input-messages")
    if isinstance(input_messages, list) and input_messages:
        return " ".join(str(item) for item in input_messages)
    return "Codex turn complete."


def main() -> int:
    if len(sys.argv) != 2:
        beep()
        show_notification("Codex notifier expected a single JSON argument.")
        return 1
    try:
        payload = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        beep()
        show_notification("Codex notifier received malformed JSON.")
        return 1
    message = select_message(payload)
    beep()
    show_notification(message)
    return 0


if __name__ == "__main__":
    sys.exit(main())
