# quickdir

Quickly jump between recent Claude Code project directories.

## Install

### Shell function (`qd`)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/claude-plugin-quickdir/shell/quickdir.sh
```

Restart your terminal or run `source ~/.bashrc`.

### Claude plugin (`/quickdir`)

```
/plugin install local /path/to/claude-plugin-quickdir
```

Optional: install [fzf](https://github.com/junegunn/fzf) for a fuzzy picker UI.

## Usage

| Command | Description |
|---------|-------------|
| `qd` | Pick a recent project and launch Claude |
| `qd add [path]` | Bookmark a directory (defaults to current dir) |
| `qd rm` | Remove a bookmark |
| `qd list` | List all known directories |
| `/quickdir` | (In Claude) Open a new Claude session in a selected project |
