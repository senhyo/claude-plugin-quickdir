---
description: Switch to a recent Claude project — opens a new terminal session in the chosen directory
---

Run the shell command `qd list` and display the output as a numbered list.

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

If `qd list` returns no output, tell the user:
> "No recent projects found. Run `qd add /your/project/path` in your terminal to add a bookmark."

If `qd` is not installed (command not found), tell the user:
> "`qd` is not installed. Add this to your ~/.bashrc or ~/.zshrc:
> `source /path/to/claude-plugin-quickdir/shell/quickdir.sh`
> Then restart your terminal and try again."

**Important:** This command opens a *new* terminal session. Your current Claude session continues unchanged.
