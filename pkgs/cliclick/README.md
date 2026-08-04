# cliclick-swift

A small macOS CLI tool that simulates keyboard events, inspired by [cliclick](https://github.com/BlueM/cliclick). Written in Swift.

## Usage

```bash
./cliclick.swift [options] key-combo [key-combo ...]
```

Key combo format: `[modifier+...]key` — modifiers are joined with `+`.

| Category | Values |
|---|---|
| Modifiers | `ctrl`, `shift`, `alt`/`option`/`opt`, `cmd`/`command`, `fn` |
| Character keys | `a`-`z` (uppercase adds Shift automatically), `0`-`9`, symbols (`! @ # $` etc. add Shift automatically), `+`, `-`, space |
| Named keys | `space`, `return`/`enter`, `tab`, `esc`/`escape`, `backspace`/`delete`, `forward-delete`, `home`, `end`, `pageup`, `pagedown`, `up`/`down`/`left`/`right`, `capslock`, `f1`-`f20` |

## Examples

```bash
./cliclick.swift ctrl+shift+space      # Ctrl+Shift+Space (IME switch)
./cliclick.swift cmd+c                 # Copy
./cliclick.swift cmd+shift+4           # Screenshot
./cliclick.swift cmd+shift+!           # Cmd+Shift+1 (! adds Shift automatically)
./cliclick.swift a b c                 # Press a, b, c in sequence
./cliclick.swift -d 0.3 cmd+1 cmd+2    # Press with 0.3s interval
./cliclick.swift -n cmd+c              # Dry-run: print parsed events only
```

## Options

- `-d, --delay seconds` — interval between key combos
- `-n, --dry-run` — parse and print only; do not actually press keys
- `-h, --help` — show help

## Permissions

On first use, grant your terminal app **Accessibility** permission in
**System Settings → Privacy & Security → Accessibility**, otherwise key
presses are ignored.

## Notes

- Key code mapping follows the US layout; a few symbol keys may not match
  the keycap label on other layouts (keyboard shortcuts are usually unaffected).
- Running `./cliclick.swift` interprets the script on every invocation. For
  faster startup, compile it: `swiftc -O cliclick.swift -o cliclick`
