#!/usr/bin/env python3
"""
Localization Manager for Xcode String Catalog (.xcstrings)

This script provides a simple interface for coding agents to manage
Localizable.xcstrings files without directly editing the large JSON file.

Usage:
    python3 .agents/skills/xcstrings-manager/localization_manager.py <command> [args]

Commands:
    list [pattern]              List all keys (optional: filter by pattern)
    get <key>                   Get a specific key's translations
    add <key> [zh] [en]         Add a new key with optional translations
    update <key> <lang> <val>   Update translation for a specific language
    remove <key>                Remove a key
    stats                       Show statistics about the catalog
    search <query>              Search keys and translations
"""

import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from collections import Counter
from typing import Optional

DEFAULT_CATALOG_PATH = Path(__file__).resolve().parents[3] / "Pixiv-SwiftUI" / "Localizable.xcstrings"
SUPPORTED_LANGUAGES = ("zh-Hans", "en")
PLACEHOLDER_PATTERN = re.compile(
    r"%(?:\d+\$)?(#@[^@]+@|@|lld|llu|llx|llX|ld|lu|lx|lX|d|u|x|X|o|i|f|F|e|E|g|G|c|s|p|%)"
)


class CatalogError(Exception):
    """Raised when a catalog cannot be loaded or saved safely."""


def load_catalog(path: Path) -> dict:
    """Load the xcstrings catalog from file."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            catalog = json.load(f)
    except OSError as e:
        raise CatalogError(f"Unable to read catalog '{path}': {e.strerror or e}") from e
    except json.JSONDecodeError as e:
        raise CatalogError(f"Invalid JSON in catalog file: {e}") from e

    if not isinstance(catalog, dict):
        raise CatalogError("Catalog root must be a JSON object")
    if not isinstance(catalog.get("strings"), dict):
        raise CatalogError("Catalog must contain a 'strings' object")

    for key, entry in catalog["strings"].items():
        if not isinstance(entry, dict):
            raise CatalogError(f"Catalog entry for '{key}' must be a JSON object")
        localizations = entry.get("localizations")
        if "localizations" in entry and not isinstance(localizations, dict):
            raise CatalogError(f"Localizations for '{key}' must be a JSON object")

    return catalog


def save_catalog(path: Path, data: dict) -> None:
    """Save the xcstrings catalog to file with proper formatting."""
    temporary_path: Optional[Path] = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as f:
            temporary_path = Path(f.name)
            json.dump(data, f, ensure_ascii=False, indent=2, separators=(",", " : "))
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())

        if path.exists():
            shutil.copymode(path, temporary_path)
        os.replace(temporary_path, path)
        temporary_path = None
    except OSError as e:
        raise CatalogError(f"Unable to save catalog '{path}': {e.strerror or e}") from e
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except OSError:
                pass


def placeholder_signature(value: str) -> Counter:
    """Return placeholder types while ignoring positional argument indexes."""
    return Counter(
        match.group(1)
        for match in PLACEHOLDER_PATTERN.finditer(value)
        if match.group(1) != "%"
    )


def validate_placeholders(key: str, value: str, language: str) -> bool:
    """Validate that a translation preserves the source string's placeholders."""
    expected = placeholder_signature(key)
    actual = placeholder_signature(value)

    if expected == actual:
        return True

    print(
        f"Error: Placeholder mismatch for '{key}' [{language}]. "
        f"Expected {dict(expected)}, got {dict(actual)}",
        file=sys.stderr,
    )
    return False


def localization_value(entry: dict, language: str) -> str:
    """Return a string localization value for display or searching."""
    value = (
        entry.get("localizations", {})
        .get(language, {})
        .get("stringUnit", {})
        .get("value", "N/A")
    )
    return value if isinstance(value, str) else str(value)


def localization_languages(catalog: dict) -> set[str]:
    """Return all explicitly stored localization languages."""
    languages: set[str] = set()
    for entry in catalog.get("strings", {}).values():
        for language in entry.get("localizations", {}):
            languages.add(language)
    return languages


def list_keys(catalog: dict, pattern: Optional[str] = None, limit: int = 50) -> None:
    """List all keys in the catalog, optionally filtered by pattern."""
    strings = catalog.get("strings", {})
    keys = list(strings.keys())

    if pattern:
        keys = [k for k in keys if pattern.lower() in k.lower()]

    print(f"\nFound {len(keys)} keys" + (f" (filtered by '{pattern}')" if pattern else "") + ":\n")

    for key in keys[:limit]:
        localizations = strings[key].get("localizations", {})
        en_val = localization_value(strings[key], "en")
        status = "✓" if "en" in localizations else "✗"
        print(f"  [{status}] {key}")
        print(f"      EN: {en_val[:60]}{'...' if len(en_val) > 60 else ''}")

    if len(keys) > limit:
        print(f"\n  ... and {len(keys) - limit} more (use a more specific pattern to filter)")


def get_key(catalog: dict, key: str) -> bool:
    """Get details for a specific key."""
    strings = catalog.get("strings", {})

    if key not in strings:
        print(f"Error: Key '{key}' not found", file=sys.stderr)
        # Try to suggest similar keys
        similar = [
            k for k in strings.keys()
            if k and (key.lower() in k.lower() or k.lower() in key.lower())
        ]
        if similar:
            print(f"\nDid you mean one of these?", file=sys.stderr)
            for s in similar[:5]:
                print(f"  - {s}", file=sys.stderr)
        return False

    entry = strings[key]
    print(f"\nKey: {key}")
    print("=" * 60)

    localizations = entry.get("localizations", {})

    # Show all available languages
    for lang, data in localizations.items():
        unit = data.get("stringUnit", {})
        state = unit.get("state", "unknown")
        value = unit.get("value", "")
        print(f"\n  Language: {lang}")
        print(f"  State: {state}")
        print(f"  Value: {value}")

    if not localizations:
        print("  No localizations found")

    return True


def add_key(
    catalog: dict,
    key: str,
    zh_value: Optional[str] = None,
    en_value: Optional[str] = None,
) -> Optional[bool]:
    """Add a new key to the catalog."""
    strings = catalog.get("strings", {})

    if key in strings:
        print(f"Error: Key '{key}' already exists", file=sys.stderr)
        return None

    if zh_value is not None and not validate_placeholders(key, zh_value, "zh-Hans"):
        return None
    if en_value is not None and not validate_placeholders(key, en_value, "en"):
        return None

    entry = {}
    localizations = {}

    if zh_value is not None:
        localizations["zh-Hans"] = {
            "stringUnit": {
                "state": "translated",
                "value": zh_value,
            }
        }

    if en_value is not None:
        localizations["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": en_value,
            }
        }

    if localizations:
        entry["localizations"] = localizations

    strings[key] = entry
    catalog["strings"] = strings

    print(f"✓ Added key: '{key}'")
    print(f"  zh-Hans: {zh_value if zh_value is not None else '(source key fallback)'}")
    print(f"  en: {en_value if en_value is not None else '(source key fallback)'}")
    return True


def update_translation(catalog: dict, key: str, language: str, value: str) -> Optional[bool]:
    """Update translation for a specific language."""
    strings = catalog.get("strings", {})

    if key not in strings:
        print(f"Error: Key '{key}' not found", file=sys.stderr)
        return None

    if language not in SUPPORTED_LANGUAGES:
        print(
            f"Error: Unsupported language '{language}'. Use 'zh-Hans' or 'en'",
            file=sys.stderr,
        )
        return None

    if not validate_placeholders(key, value, language):
        return None

    entry = strings[key]
    localizations = entry.setdefault("localizations", {})
    localization = localizations.get(language)
    if not isinstance(localization, dict):
        localization = {}

    string_unit = localization.get("stringUnit")
    if not isinstance(string_unit, dict):
        string_unit = {}

    changed = string_unit.get("state") != "translated" or string_unit.get("value") != value
    string_unit["state"] = "translated"
    string_unit["value"] = value
    localization["stringUnit"] = string_unit
    localizations[language] = localization

    print(f"✓ Updated '{key}' [{language}]: {value}")
    return changed


def remove_key(catalog: dict, key: str) -> Optional[bool]:
    """Remove a key from the catalog."""
    strings = catalog.get("strings", {})

    if key not in strings:
        print(f"Error: Key '{key}' not found", file=sys.stderr)
        return None

    del strings[key]
    print(f"✓ Removed key: '{key}'")
    return True


def show_stats(catalog: dict) -> None:
    """Show statistics about the catalog."""
    strings = catalog.get("strings", {})
    source_lang = catalog.get("sourceLanguage", "unknown")

    total_keys = len(strings)
    languages = localization_languages(catalog)

    print("\nLocalization Catalog Statistics")
    print("=" * 40)
    print(f"Source Language: {source_lang}")
    print(f"Total Keys: {total_keys}")
    source_coverage = "100.0%" if total_keys else "N/A"
    print(f"\nSource Key Coverage ({source_lang}): {total_keys}/{total_keys} ({source_coverage})")
    print("Explicit Localization Entries:")

    if not languages:
        print("  (none)")
        return

    for language in sorted(languages):
        count = sum(1 for entry in strings.values() if language in entry.get("localizations", {}))
        coverage = f"{100 * count / total_keys:.1f}%" if total_keys else "N/A"
        print(f"  {language}: {count}/{total_keys} ({coverage})")


def search_catalog(catalog: dict, query: str) -> None:
    """Search for keys and translations."""
    strings = catalog.get("strings", {})
    query_lower = query.lower()

    results = []
    for key, entry in strings.items():
        if query_lower in key.lower():
            results.append((key, "key"))
            continue

        localizations = entry.get("localizations", {})
        for lang, data in localizations.items():
            value = data.get("stringUnit", {}).get("value", "")
            if isinstance(value, str) and query_lower in value.lower():
                results.append((key, f"translation ({lang})"))
                break

    print(f"\nSearch results for '{query}' ({len(results)} matches):\n")
    for key, match_type in results[:20]:
        print(f"  [{match_type}] {key}")
    if len(results) > 20:
        print(f"\n  ... and {len(results) - 20} more")


def print_usage(message: str, usage: str) -> int:
    """Print a command-line argument error and return its exit status."""
    print(f"Error: {message}", file=sys.stderr)
    print(f"Usage: {usage}", file=sys.stderr)
    return 2


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    command = sys.argv[1]
    args = sys.argv[2:]

    # Allow custom path via environment variable
    catalog_path = Path(os.environ.get("XCSTRINGS_PATH", DEFAULT_CATALOG_PATH)).expanduser()

    try:
        catalog = load_catalog(catalog_path)
    except CatalogError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if command == "list":
        if len(args) > 1:
            return print_usage("Too many arguments", "list [pattern]")
        pattern = args[0] if args else None
        list_keys(catalog, pattern)
        return 0

    elif command == "get":
        if len(args) != 1:
            return print_usage("Expected exactly one key argument", "get <key>")
        return 0 if get_key(catalog, args[0]) else 1

    elif command == "add":
        if not 1 <= len(args) <= 3:
            return print_usage("Expected one to three arguments", "add <key> [zh_value] [en_value]")
        key = args[0]
        zh_value = args[1] if len(args) > 1 else None
        en_value = args[2] if len(args) > 2 else None
        result = add_key(catalog, key, zh_value, en_value)

    elif command == "update":
        if len(args) != 3:
            return print_usage("Expected exactly three arguments", "update <key> <language> <value>")
        result = update_translation(catalog, args[0], args[1], args[2])

    elif command == "remove":
        if len(args) != 1:
            return print_usage("Expected exactly one key argument", "remove <key>")
        result = remove_key(catalog, args[0])

    elif command == "stats":
        if args:
            return print_usage("stats does not accept arguments", "stats")
        show_stats(catalog)
        return 0

    elif command == "search":
        if len(args) != 1:
            return print_usage("Expected exactly one query argument", "search <query>")
        search_catalog(catalog, args[0])
        return 0

    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        return 1

    if result is None:
        return 1

    if result:
        try:
            save_catalog(catalog_path, catalog)
        except CatalogError as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1
        print(f"\n✓ Changes saved to {catalog_path}")
    else:
        print("\nNo changes needed")

    return 0


if __name__ == "__main__":
    sys.exit(main())
