#!/usr/bin/env python3
"""Resolve a T3 thread ID to its provider-native session cursor, read-only."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path
from urllib.parse import quote


def default_database() -> Path:
    return Path.home() / ".t3" / "userdata" / "state.sqlite"


def read_only_uri(path: Path) -> str:
    # SQLite URI paths use forward slashes on every platform. Keep the
    # database read-only and let SQLite include the live WAL snapshot.
    return "file:" + quote(path.resolve().as_posix(), safe="/:\\") + "?mode=ro"


def resolve(database: Path, thread_id: str) -> dict[str, object]:
    if not database.is_file():
        raise FileNotFoundError(f"T3 state database was not found: {database}")

    connection = sqlite3.connect(read_only_uri(database), uri=True, timeout=2)
    connection.row_factory = sqlite3.Row
    try:
        required = {
            "provider_session_runtime",
            "projection_thread_sessions",
            "projection_threads",
        }
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        missing = sorted(required - tables)
        if missing:
            raise RuntimeError(
                "T3 state database is missing expected table(s): "
                + ", ".join(missing)
            )

        row = connection.execute(
            """
            SELECT
                r.thread_id AS t3_thread_id,
                r.provider_name,
                r.adapter_key,
                r.runtime_mode,
                r.status AS runtime_status,
                r.last_seen_at,
                r.resume_cursor_json,
                r.runtime_payload_json,
                s.status AS projection_status,
                s.provider_session_id,
                s.provider_thread_id,
                t.project_id,
                t.title,
                t.branch,
                t.worktree_path
            FROM provider_session_runtime AS r
            LEFT JOIN projection_thread_sessions AS s
                ON s.thread_id = r.thread_id
            LEFT JOIN projection_threads AS t
                ON t.thread_id = r.thread_id
            WHERE r.thread_id = ?
            """,
            (thread_id,),
        ).fetchone()
        if row is None:
            raise LookupError(f"No T3 provider runtime was found for thread: {thread_id}")

        resume_cursor = {}
        if row["resume_cursor_json"]:
            try:
                parsed = json.loads(row["resume_cursor_json"])
            except json.JSONDecodeError as error:
                raise RuntimeError(
                    f"T3 resume cursor is not valid JSON for thread: {thread_id}"
                ) from error
            if isinstance(parsed, dict):
                resume_cursor = parsed

        runtime_payload = {}
        if row["runtime_payload_json"]:
            try:
                parsed = json.loads(row["runtime_payload_json"])
            except json.JSONDecodeError:
                parsed = {}
            if isinstance(parsed, dict):
                runtime_payload = parsed

        native_id = resume_cursor.get("threadId")
        if not native_id:
            raise LookupError(
                "T3 has no provider-native resume cursor for thread: " + thread_id
            )

        return {
            "t3_thread_id": row["t3_thread_id"],
            "provider": row["provider_name"],
            "adapter": row["adapter_key"],
            "native_session_id": native_id,
            "runtime_mode": row["runtime_mode"],
            "runtime_status": row["runtime_status"],
            "projection_status": row["projection_status"],
            "last_seen_at": row["last_seen_at"],
            "provider_session_id": row["provider_session_id"],
            "provider_thread_id": row["provider_thread_id"],
            "cwd": runtime_payload.get("cwd"),
            "project_id": row["project_id"],
            "branch": row["branch"],
            "worktree_path": row["worktree_path"],
            "source": "provider_session_runtime.resume_cursor_json.threadId",
        }
    finally:
        connection.close()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Resolve a T3 thread UUID to its provider-native session ID."
    )
    parser.add_argument("thread_id", help="T3 thread/conversation UUID")
    parser.add_argument(
        "--db",
        type=Path,
        default=default_database(),
        help="Path to T3 state.sqlite (default: ~/.t3/userdata/state.sqlite)",
    )
    args = parser.parse_args()

    try:
        result = resolve(args.db, args.thread_id)
    except (FileNotFoundError, LookupError, RuntimeError, sqlite3.Error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
