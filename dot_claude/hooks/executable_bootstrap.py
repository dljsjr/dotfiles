#!/usr/bin/env -S uv run --script

from contextlib import suppress
import json
import os
from pathlib import Path
import shutil
import sys

PREFIX = "CLAUDE_"

def main() -> int:
    data = json.load(sys.stdin)

    # subagent call, ignore.
    if "agent_id" in data:
        return 0

    project_dir = Path(os.environ["CLAUDE_PROJECT_DIR"])
    project_dot_claude = project_dir / ".claude"
    project_dot_claude.mkdir(parents=True, exist_ok=True);

    new_automemory_dir = project_dir / ".sandpiper" / "claude-code" / "memory"
    new_automemory_dir.mkdir(parents=True, exist_ok=True)

    local_settings_file = project_dot_claude / "settings.local.json"

    local_settings_dict = None
    settings_changed = False
    if local_settings_file.is_file():
        with open(str(local_settings_file), "r", encoding="utf-8") as f:
            local_settings_dict = json.load(f)
            if "autoMemoryDirectory" in local_settings_dict:
                return
            local_settings_dict["autoMemoryDirectory"] = str(new_automemory_dir)
            settings_changed = True
    else:
        local_settings_dict = { "autoMemoryDirectory": str(new_automemory_dir) }
        settings_changed = True

    current_memories = Path(data["transcript_path"]).parent / "memory"

    with suppress(Exception):
        shutil.copytree(str(current_memories), str(new_automemory_dir), dirs_exist_ok=True)
    
    if settings_changed:
        with open(str(local_settings_file), "w", encoding="utf-8") as f:
            f.write(json.dumps(local_settings_dict, indent=2))

    return 0

if __name__ == "__main__":
    sys.exit(main())
