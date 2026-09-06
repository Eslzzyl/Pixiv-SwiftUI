---
name: xcstrings-manager
description: Manage Xcode String Catalog (.xcstrings) localization files through a command-line interface. Used when adding, updating, or querying localization strings.
---

When managing localization strings in `Pixiv-SwiftUI/Localizable.xcstrings`, run the commands from the repository root and use `.agents/skills/xcstrings-manager/localization_manager.py`:

- **Check statistics**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py stats` to see source-key and explicit localization coverage
- **List keys**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py list [pattern]` to browse existing keys
- **Get details**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py get <key>` to view translations for a specific key
- **Search**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py search <query>` to find keys by content
- **Add new strings**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py add <key> [zh_value] [en_value]`
  - If `zh_value` is omitted, no explicit Chinese entry is created; Xcode uses the source key as the fallback
  - If `en_value` is omitted, no explicit English entry is created; quote `""` when an explicit empty value is required
- **Update translations**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py update <key> <lang> <value>`
  - lang can be `zh-Hans` or `en`
  - Placeholder types and counts must match the source key; failures return a non-zero exit status
- **Remove strings**: Run `python3 .agents/skills/xcstrings-manager/localization_manager.py remove <key>`
- **Use another catalog**: Prefix a command with `XCSTRINGS_PATH=/path/to/catalog.xcstrings`

Mutation failures return a non-zero exit status and do not rewrite the catalog. After a successful mutation, verify with `get` or `list`, then validate the file with `jq empty`.
