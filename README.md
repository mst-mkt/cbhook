# 📋 cbhook

Watch the clipboard and rewrite copied text through configurable hooks.

## Install

### Nix

```nix
{
  inputs.cbhook.url = "github:mst-mkt/cbhook";

  imports = [ cbhook.homeManagerModules.default ];
  programs.cbhook = {
    enable = true;
    hooks = [
      {
        action.replace = {
          pattern = "(https?://)x\\.com\\b";
          replacement = "$1twitter.com";
        };
      }
    ];
  };
}
```

### Build from source

```sh
moon build --target native --release   # -> _build/native/release/build/cbhook.exe
cbhook service install                 # run as a user service (systemd / launchd)
```

On Linux, `wl-clipboard` (Wayland) or `xclip` (X11) is required at runtime.

## Configuration

The config is JSON or [pkl](https://pkl-lang.org/), resolved from the first match:

1. `--config <path>`
2. `$CBHOOK_CONFIG`
3. `$XDG_CONFIG_HOME/cbhook/config.{pkl,json}`
4. `$HOME/.config/cbhook/config.{pkl,json}`

`hooks` is an ordered list; each hook applies its `action` when its `match`
(optional regex) hits.

```json
{
  "log_level": "info",
  "hooks": [
    {
      "name": "x.com -> twitter.com",
      "match": { "pattern": "https?://x\\.com\\b" },
      "action": {
        "type": "replace",
        "pattern": "(https?://)x\\.com\\b",
        "replacement": "$1twitter.com"
      }
    }
  ]
}
```

The same config in pkl:

```pkl
hooks = new Listing {
  new {
    name = "x.com -> twitter.com"
    match = new { pattern = "https?://x\\.com\\b" }
    action = new {
      type = "replace"
      pattern = "(https?://)x\\.com\\b"
      replacement = "$1twitter.com"
    }
  }
}
```

## Actions

### replace

Substitute regex matches in the clipboard text.

| field         | required | description                                         |
| ------------- | -------- | --------------------------------------------------- |
| `pattern`     | x        | Regular expression to match.                        |
| `replacement` | x        | Result; `$1` / `${name}` expand groups, `$$` → `$`. |
| `flags`       |          | Regex flags, e.g. `"i"`.                            |

```json
{
  "type": "replace",
  "pattern": "(https?://)x\\.com\\b",
  "replacement": "$1twitter.com",
  "flags": "i"
}
```

### pipe

Replace the clipboard with the command's stdout.

| field        | required | description                                  |
| ------------ | -------- | -------------------------------------------- |
| `run`        | x        | Command and arguments (at least one).        |
| `timeout_ms` |          | Timeout in milliseconds; `0` means no limit. |
| `on_error`   |          | `"skip"` (default) or `"abort"`.             |

```json
{ "type": "pipe", "run": ["jq", "."], "timeout_ms": 2000, "on_error": "skip" }
```

### exec

Run a command for its side effects. Its stdout is ignored and the clipboard is
left unchanged. Takes the same fields as [`pipe`](#pipe).

```json
{ "type": "exec", "run": ["notify-send", "clipboard changed"] }
```

> [!CAUTION]
> `pipe` and `exec` pass the **entire clipboard** — which may include passwords,
> 2FA codes, or private keys — to the command's stdin and inherited environment.
> Scope them with a `match` pattern so they only run on the content you intend.

## Commands

| command                  | description                                          |
| ------------------------ | ---------------------------------------------------- |
| `cbhook watch`           | Watch the clipboard and apply hooks on each change.  |
| `cbhook check`           | Validate the config and exit.                        |
| `cbhook eval [text]`     | Apply hooks to text (or stdin) and print the result. |
| `cbhook schema`          | Print the config JSON Schema.                        |
| `cbhook service install` | Install the user service (systemd / launchd).        |

| option                | description                     |
| --------------------- | ------------------------------- |
| `-c, --config <path>` | Config file (`.json` / `.pkl`). |
| `-v, --verbose`       | Verbose (debug) logging.        |
| `-q, --quiet`         | Quiet (warnings only).          |

## License

[MIT](./LICENSE)
