---
description: Switch to a recent Claude project — opens a new terminal session in the chosen directory
---

Read the project list directly (do NOT call `qd list`):

1. Scan `~/.claude/projects/*/` — for each subdirectory, find the first `.jsonl` file, read its first line, and extract the `"cwd"` field using Python:
```bash
python3 -c "
import os, sys, json, glob

projects_dir = os.path.expanduser('~/.claude/projects')
entries = []

for proj in os.listdir(projects_dir):
    proj_path = os.path.join(projects_dir, proj)
    if not os.path.isdir(proj_path):
        continue
    jsonl_files = sorted(glob.glob(os.path.join(proj_path, '*.jsonl')))
    if not jsonl_files:
        continue
    jsonl = jsonl_files[0]
    try:
        with open(jsonl, encoding='utf-8') as f:
            first_line = f.readline()
        data = json.loads(first_line)
        cwd = data.get('cwd')
        if cwd and os.path.exists(cwd):
            mtime = os.path.getmtime(jsonl)
            entries.append((mtime, cwd))
    except Exception:
        pass

entries.sort(reverse=True)

seen = set()
for _, cwd in entries:
    key = cwd.lower().rstrip('/\\\\')
    if key not in seen:
        seen.add(key)
        print(cwd)
"
```

2. Read bookmarks from `~/.config/quickdir/bookmarks.txt` (one path per line). Append any paths not already in the list above (case-insensitive, ignoring trailing slashes).

3. If the combined list is empty, tell the user:
> "No recent projects found. Open a project with Claude Code first, or create a bookmark by running `qd add` in your terminal (requires shell setup)."

4. Display the results as a numbered list.

Ask the user: "Which project? Enter a number (or press Enter to cancel):"

Wait for the user's reply.

If the user cancels or enters nothing, stop here.

If the input is not a valid number from the list, tell the user and show the list again.

Once a valid number is chosen, detect the OS:
- Check `$OS` env var: if it equals `Windows_NT` → Windows
- Otherwise run `uname -s`: `Darwin` → macOS, `Linux` → Linux

Open a new terminal window in the selected directory and start Claude:

**Windows (Git Bash / WSL):**
```
cmd.exe /c start cmd /k "cd /d {selected_path} && claude"
```

**macOS:**
```
osascript -e 'tell application "Terminal" to do script "cd '"'"'{escaped_path}'"'"' && claude"'
```
(single-quote-escape the path before substitution: replace each `'` in the path with `'\''`)

**Linux (with display):**
```
x-terminal-emulator -e bash -c 'cd {selected_path} && claude; exec bash'
```

If OS detection is ambiguous (neither `Windows_NT` nor `Darwin`/`Linux` recognized), ask the user:
> "Are you on Windows, macOS, or Linux?"
Then use the appropriate command above.

**Important:** This command opens a *new* terminal session. Your current Claude session continues unchanged.
