# MacMicro

A native macOS app wrapping the [micro](https://micro-editor.github.io/) terminal editor.

## Requirements

- macOS 14+
- [micro](https://github.com/zyedidia/micro) installed (`brew install micro`)

## Build

```
swift build
./scripts/bundle.sh
```

The app bundle is created at `build/MacMicro.app`.

## Usage

Open the app directly, or from the terminal:

```
open -a /path/to/MacMicro.app
open -a /path/to/MacMicro.app ~/some/file.txt
open -a /path/to/MacMicro.app ~/some/directory
```

Opening a file while the app is running adds it as a new tab in the existing micro instance.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+S | Save |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |
| Cmd+F | Find |
| Cmd+/ | Command palette |
| Cmd+C/X/V | Copy/Cut/Paste |
| Cmd+A | Select all |
| Cmd+D | Duplicate line |
| Cmd+W | Close current buffer |
| Cmd+Q | Quit |
| Cmd+Shift+] | Next tab |
| Cmd+Shift+[ | Previous tab |
| Cmd+1-9 | Jump to tab |
| Shift+Arrow | Select text |
| Cmd+Shift+Arrow | Select word/to start/end |

All of micro's own keybindings also work.

## Settings

`Cmd+,` opens a native preferences window. Changes are applied live to the running micro instance.

Configuration is stored in `~/Library/Application Support/MacMicro/micro/`, separate from standalone micro's config.

## Architecture

MacMicro embeds micro in a [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) terminal view. A bundled micro plugin (`macmicro.lua`) provides an IPC channel for reliable communication between the native app and the editor — used for opening files, changing settings, and tab navigation.

## License

The micro editor logo is from the [micro project](https://github.com/zyedidia/micro).
