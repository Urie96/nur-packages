#!/usr/bin/env swift
//
// cliclick-swift — Simulate keyboard events from the command line.
//
// Usage:
//   cliclick ctrl+shift+space        # Press Ctrl+Shift+Space (IME switch)
//   cliclick cmd+c                   # Copy
//   cliclick cmd+shift+4             # Screenshot
//   cliclick a b c                   # Press a, b, c in sequence
//   cliclick -d 0.3 cmd+1 cmd+2      # Press with 0.3s interval
//
// Requires Accessibility permission:
//   System Settings → Privacy & Security → Accessibility

import Cocoa
import CoreGraphics
import ApplicationServices

// MARK: - Key code tables (US layout virtual key codes)

let charKeyCodes: [String: UInt16] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
    "-": 27, "8": 28, "0": 29, "]": 30,
    "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
    "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
    ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50, " ": 49,
]

// Symbols that need Shift on a US layout, mapped to their base key codes
let shiftCharKeyCodes: [String: UInt16] = [
    "~": 50, "!": 18, "@": 19, "#": 20, "$": 21, "%": 23, "^": 22, "&": 26,
    "*": 28, "(": 25, ")": 29, "_": 27, "+": 24, "{": 33, "}": 30, "|": 42,
    ":": 41, "\"": 39, "<": 43, ">": 47, "?": 44,
]

let namedKeyCodes: [String: UInt16] = [
    "space": 49, "spc": 49,
    "return": 36, "enter": 36, "ret": 36,
    "tab": 48,
    "esc": 53, "escape": 53,
    "backspace": 51, "delete": 51, "bs": 51,
    "forward-delete": 117, "del": 117,
    "home": 115, "end": 119,
    "pageup": 116, "pgup": 116, "pagedown": 121, "pgdn": 121,
    "up": 126, "down": 125, "left": 123, "right": 124,
    "capslock": 57, "caps": 57,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64, "f18": 79,
    "f19": 80, "f20": 90,
    "help": 114,
]

let modifierFlags: [String: CGEventFlags] = [
    "ctrl": .maskControl, "control": .maskControl,
    "shift": .maskShift,
    "alt": .maskAlternate, "option": .maskAlternate, "opt": .maskAlternate,
    "cmd": .maskCommand, "command": .maskCommand,
    "fn": .maskSecondaryFn,
]

// MARK: - Parsing

struct KeyPress {
    let name: String
    let keyCode: UInt16
    let flags: CGEventFlags
}

enum CliError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self {
        case .message(let m): return m
        }
    }
}

func parseCombo(_ token: String) throws -> KeyPress {
    // "+" is the separator between modifiers and the key. A lone "+" is
    // special-cased so the plus key itself can still be pressed.
    if token == "+" {
        return KeyPress(name: token, keyCode: 24, flags: .maskShift)
    }

    let parts = token.split(separator: "+", omittingEmptySubsequences: true)
        .map(String.init)   // keep original case to detect uppercase letters
    guard !parts.isEmpty else {
        throw CliError.message("empty key combo: \"\(token)\"")
    }

    // The last part is the key; everything before it is a modifier.
    var flags: CGEventFlags = []
    for mod in parts.dropLast() {
        guard let flag = modifierFlags[mod.lowercased()] else {
            throw CliError.message(
                "unknown modifier: \"\(mod)\" (available: ctrl, shift, alt/option, cmd/command, fn)")
        }
        flags.insert(flag)
    }

    let keyPart = parts[parts.count - 1]
    let key = keyPart.lowercased()

    // Named keys
    if let code = namedKeyCodes[key] {
        return KeyPress(name: token, keyCode: code, flags: flags)
    }
    // Plain characters; uppercase letters get Shift automatically
    if let code = charKeyCodes[key] {
        if keyPart != keyPart.lowercased() {
            flags.insert(.maskShift)
        }
        return KeyPress(name: token, keyCode: code, flags: flags)
    }
    // Symbols that need Shift (e.g. ! @ # $) get Shift automatically
    if keyPart.count == 1, let code = shiftCharKeyCodes[key] {
        flags.insert(.maskShift)
        return KeyPress(name: token, keyCode: code, flags: flags)
    }

    throw CliError.message(
        "unrecognized key: \"\(key)\" (run `cliclick --help` to see supported keys)")
}

// MARK: - Posting events

func postKey(_ press: KeyPress, dryRun: Bool) {
    if dryRun {
        print("  [dry-run] \(press.name)  keyCode=\(press.keyCode)  flags=0x\(String(press.flags.rawValue, radix: 16))")
        return
    }
    let source = CGEventSource(stateID: .combinedSessionState)
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: press.keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: press.keyCode, keyDown: false) else {
        print("error: failed to create keyboard event")
        exit(1)
    }
    down.flags = press.flags
    up.flags = press.flags
    down.post(tap: .cghidEventTap)
    usleep(20_000) // small gap between down and up; some apps drop instant events
    up.post(tap: .cghidEventTap)
}

func checkPermissions() {
    var denied = !AXIsProcessTrusted()
    if #available(macOS 10.15, *) {
        denied = denied || !CGPreflightPostEventAccess()
    }
    if denied {
        print("⚠️  No Accessibility permission — key presses may be ignored.")
        print("   Grant it in System Settings → Privacy & Security → Accessibility,")
        print("   then re-run.")
    }
}

// MARK: - Help

func printUsage() {
    print("""
    cliclick-swift — Simulate keyboard events from the command line

    Usage: cliclick [options] key-combo [key-combo ...]

    Key combo format: [modifier+...]key
      Modifiers: ctrl, shift, alt(option), cmd(command), fn
      Key:       a single character (a-z, 0-9, symbols) or a named key

    Named keys: space, return/enter, tab, esc/escape, backspace/delete,
                forward-delete, home, end, pageup, pagedown,
                up/down/left/right, capslock, f1-f20

    Examples:
      cliclick ctrl+shift+space       # Ctrl+Shift+Space
      cliclick cmd+c                  # Copy
      cliclick cmd+tab                # Switch apps
      cliclick cmd+shift+4            # Screenshot
      cliclick cmd+shift+!            # Cmd+Shift+1 (! adds Shift automatically)
      cliclick a b c                  # Press a, b, c in sequence
      cliclick -d 0.3 cmd+1 cmd+2     # Press with 0.3s interval

    Options:
      -d, --delay seconds   Interval between combos
      -n, --dry-run         Parse and print only; do not actually press keys
      -h, --help            Show this help

    Note: Requires Accessibility permission
          (System Settings → Privacy & Security → Accessibility)
    """)
}

// MARK: - Main

var args = Array(CommandLine.arguments.dropFirst())
var combos: [String] = []
var delay: Double = 0.0
var dryRun = false

var i = 0
while i < args.count {
    switch args[i] {
    case "-h", "--help":
        printUsage()
        exit(0)
    case "-n", "--dry-run":
        dryRun = true
        i += 1
    case "-d", "--delay":
        guard i + 1 < args.count, let d = Double(args[i + 1]) else {
            print("error: --delay requires a number of seconds, e.g. -d 0.3")
            exit(1)
        }
        delay = d
        i += 2
    default:
        combos.append(args[i])
        i += 1
    }
}

guard !combos.isEmpty else {
    printUsage()
    exit(1)
}

checkPermissions()

for (idx, combo) in combos.enumerated() {
    do {
        let press = try parseCombo(combo)
        postKey(press, dryRun: dryRun)
    } catch {
        print("error: \(error)")
        exit(1)
    }
    if idx < combos.count - 1 && delay > 0 {
        Thread.sleep(forTimeInterval: delay)
    }
}
