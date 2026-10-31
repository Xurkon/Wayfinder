#!/usr/bin/env python3
"""Build Wayfinder's title-verified quest metadata from aagamedump's SQLite parts."""

from __future__ import annotations

import argparse
import os
import sqlite3
import tempfile
from pathlib import Path


PARTS = ("195-english.part_aa", "195-english.part_ab")
CATALOG_VERSION = "AA 10.8.1.0 English (2024-05-02)"


def lua_string(value: str) -> str:
    escaped = []
    for char in value:
        codepoint = ord(char)
        if char == "\\":
            escaped.append("\\\\")
        elif char == '"':
            escaped.append('\\"')
        elif char == "\n":
            escaped.append("\\n")
        elif char == "\r":
            escaped.append("\\r")
        elif char == "\t":
            escaped.append("\\t")
        elif codepoint < 32 or codepoint == 127:
            escaped.append(f"\\{codepoint:03d}")
        else:
            escaped.append(char)
    return '"' + "".join(escaped) + '"'


def continent_for(zone_group: str | None) -> str:
    if not isinstance(zone_group, str):
        return "Other"
    # Cross-checked against ArcheRage's official zone data: w_two_crowns is
    # Nuia, e_ynystere is Haranya, and o_abyss_gate is Auroria. Sea, instance,
    # and special groups intentionally fall back to Other.
    if zone_group.startswith("w_"):
        return "Nuia"
    if zone_group.startswith("e_"):
        return "Haranya"
    if zone_group.startswith("o_"):
        return "Auroria"
    return "Other"


def build_catalog(db_directory: Path) -> list[tuple[int, str, str, str, bool, bool]]:
    missing = [name for name in PARTS if not (db_directory / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing SQLite part(s) in {db_directory}: {', '.join(missing)}")

    file_descriptor, temp_name = tempfile.mkstemp(suffix=".sqlite")
    os.close(file_descriptor)
    temp_path = Path(temp_name)
    try:
        with temp_path.open("wb") as output:
            for part in PARTS:
                with (db_directory / part).open("rb") as source:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)

        connection = sqlite3.connect(f"file:{temp_path.as_posix()}?mode=ro", uri=True)
        try:
            saga_ids = {row[0] for row in connection.execute(
                "SELECT DISTINCT quest_context_id FROM saga_quests"
            )}
            today_ids = {row[0] for row in connection.execute(
                "SELECT DISTINCT quest_context_id FROM today_quest_group_quests"
            )}
            rows = connection.execute(
                """
                SELECT q.id, q.name, zg.name, zg.display_text
                FROM quest_contexts AS q
                LEFT JOIN zones AS z ON z.id = q.zone_id
                LEFT JOIN zone_groups AS zg ON zg.id = z.group_id
                ORDER BY q.id
                """
            )
            catalog = []
            seen_ids: set[int] = set()
            for quest_id, title, zone_group, zone_name in rows:
                if not isinstance(quest_id, int) or quest_id <= 0:
                    raise ValueError(f"Invalid quest context ID: {quest_id!r}")
                if quest_id in seen_ids:
                    raise ValueError(f"Duplicate quest context ID: {quest_id}")
                seen_ids.add(quest_id)
                if not isinstance(title, str):
                    continue
                title = "".join(" " if ord(char) < 32 or ord(char) == 127 else char for char in title).strip()
                if title == "":
                    continue
                if "DO NOT TRANSLATE" in title.upper():
                    continue
                if isinstance(zone_name, str) and zone_name.strip():
                    zone = zone_name.strip()
                else:
                    # A quest category is not necessarily a geographical zone.
                    # Keep the fallback explicit rather than publishing a false location.
                    zone = "Unknown Zone"
                catalog.append((
                    quest_id,
                    title,
                    zone,
                    continent_for(zone_group),
                    quest_id in saga_ids,
                    quest_id in today_ids,
                ))
            return catalog
        finally:
            connection.close()
    finally:
        temp_path.unlink(missing_ok=True)


def write_catalog(output_path: Path, catalog: list[tuple[int, str, str, str, bool, bool]]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    seen_ids: set[int] = set()
    for quest_id, title, zone, continent, is_saga, is_today in catalog:
        if not isinstance(quest_id, int) or quest_id <= 0 or quest_id in seen_ids:
            raise ValueError(f"Invalid or duplicate quest context ID: {quest_id!r}")
        if not all(isinstance(value, str) and value.strip() for value in (title, zone, continent)):
            raise ValueError(f"Quest {quest_id} has invalid title or geography metadata")
        if not isinstance(is_saga, bool) or not isinstance(is_today, bool):
            raise ValueError(f"Quest {quest_id} has invalid catalog flags")
        seen_ids.add(quest_id)

    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            prefix=f".{output_path.name}.",
            suffix=".tmp",
            dir=output_path.parent,
            delete=False,
        ) as output:
            temporary_path = Path(output.name)
            output.write("-- Generated from aagamedump/db/195-english.part_*.\n")
            output.write(f"-- Source game data: {CATALOG_VERSION}.\n")
            output.write("-- Runtime metadata is used only when the API title exactly matches.\n")
            output.write("-- Explicit untranslated placeholders are omitted; missing zones stay Unknown Zone.\n")
            output.write("_G.WAYFINDER_QUEST_CATALOG_VERSION = ")
            output.write(lua_string(CATALOG_VERSION))
            output.write("\n_G.WAYFINDER_QUEST_CATALOG = {\n")
            for quest_id, title, zone, continent, is_saga, is_today in catalog:
                output.write(
                    f"  [{quest_id}] = {{{lua_string(title)}, {lua_string(zone)}, "
                    f"{lua_string(continent)}, {str(is_saga).lower()}, {str(is_today).lower()}}},\n"
                )
            output.write("}\n")
        os.replace(temporary_path, output_path)
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db-directory", type=Path, required=True, help="aagamedump/db directory")
    parser.add_argument("--output", type=Path, required=True, help="generated quest_catalog.lua path")
    args = parser.parse_args()
    catalog = build_catalog(args.db_directory)
    write_catalog(args.output, catalog)
    print(f"Wrote {len(catalog)} title-verified quest metadata rows to {args.output}")


if __name__ == "__main__":
    main()
