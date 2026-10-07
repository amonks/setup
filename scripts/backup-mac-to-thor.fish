#!/bin/sh
# Keep the historical cron entry and log name; Python supervises the worker.
exec /usr/bin/python3 "$HOME/scripts/backup-mac-to-thor-run.py" "$@"
