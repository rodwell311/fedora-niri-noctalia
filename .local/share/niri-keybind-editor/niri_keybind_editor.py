#!/usr/bin/env python3
"""Small Tk editor for every Niri key binding in the active config tree."""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import messagebox, ttk


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    start: int
    end: int
    line: int


@dataclass(frozen=True)
class Binding:
    path: Path
    line: int
    key: str
    description: str
    action: str
    key_start: int
    key_end: int
    action_start: int
    action_end: int

    @property
    def category(self) -> str:
        action = self.action.lower()
        if self.key.lower().startswith("xf86audio"):
            return "Media"
        if self.key.lower().startswith("xf86monbrightness") or "brightness" in action:
            return "Brightness"
        if "screenshot" in action or "ocr-snip" in action:
            return "Screenshots"
        if "focus-workspace" in action or "move-column-to-workspace" in action:
            return "Workspaces"
        if any(word in action for word in ("focus-column", "focus-window", "move-column", "move-window", "consume-", "expel-")):
            return "Navigation"
        if any(word in action for word in ("spawn", "exec", "panel-toggle", "settings-toggle")):
            return "Applications"
        if any(word in action for word in ("quit", "power-off", "lock")):
            return "System"
        if any(word in action for word in ("window", "column", "layout", "fullscreen", "floating")):
            return "Window"
        return "Other"


def window_geometry(screen_width: int, screen_height: int) -> tuple[int, int, int, int]:
    width = round(screen_width * (2 / 3))
    height = round(screen_height * (2 / 3))
    return width, height, (screen_width - width) // 2, (screen_height - height) // 2


def tokenize(text: str) -> list[Token]:
    out: list[Token] = []
    i = 0
    line = 1
    n = len(text)
    while i < n:
        ch = text[i]
        if ch.isspace():
            if ch == "\n":
                line += 1
            i += 1
            continue
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            i = n if end < 0 else end
            continue
        if text.startswith("/*", i):
            start = i
            i += 2
            depth = 1
            while i < n and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    if text[i] == "\n":
                        line += 1
                    i += 1
            if depth:
                raise ValueError(f"Komentar blok belum ditutup pada baris {text.count(chr(10), 0, start) + 1}")
            continue
        start, start_line = i, line
        if ch == '"':
            triple = text.startswith('"""', i)
            delimiter = '"""' if triple else '"'
            i += len(delimiter)
            body_start = i
            while i < n:
                if text[i] == "\\" and not triple:
                    i += 2
                    continue
                if triple and text.startswith(delimiter, i):
                    break
                if not triple and text[i] == '"':
                    break
                if text[i] == "\n":
                    line += 1
                i += 1
            if i >= n:
                raise ValueError(f"String belum ditutup pada baris {start_line}")
            body = text[body_start:i]
            i += len(delimiter)
            try:
                value = body if triple else json.loads('"' + body + '"')
            except (ValueError, json.JSONDecodeError):
                value = body
            out.append(Token("string", value, start, i, start_line))
            continue
        if ch == "#":
            hashes = 0
            while i + hashes < n and text[i + hashes] == "#":
                hashes += 1
            quote = i + hashes
            if quote < n and text[quote] == '"':
                start = i
                i = quote + 1
                body_start = i
                closing = '"' + ("#" * hashes)
                end = text.find(closing, i)
                if end < 0:
                    raise ValueError(f"Raw string belum ditutup pada baris {start_line}")
                body = text[body_start:end]
                line += body.count("\n")
                i = end + len(closing)
                out.append(Token("string", body, start, i, start_line))
                continue
        if text.startswith("/-", i):
            out.append(Token("slashdash", "/-", i, i + 2, line))
            i += 2
            continue
        if ch in "{};":
            out.append(Token(ch, ch, i, i + 1, line))
            i += 1
            continue
        while i < n and not text[i].isspace() and text[i] not in '{};"':
            if text.startswith("//", i) or text.startswith("/*", i) or text.startswith("/-", i):
                break
            i += 1
        if i == start:
            i += 1
        else:
            out.append(Token("word", text[start:i], start, i, start_line))
    return out


def _matching_brace(tokens: list[Token], opening: int) -> int:
    depth = 0
    for i in range(opening, len(tokens)):
        if tokens[i].kind == "{":
            depth += 1
        elif tokens[i].kind == "}":
            depth -= 1
            if depth == 0:
                return i
    raise ValueError(f"Blok '{{' belum ditutup pada baris {tokens[opening].line}")


def _skip_node(tokens: list[Token], start: int) -> int:
    line = tokens[start].line
    i = start + 1
    while i < len(tokens):
        token = tokens[i]
        if token.kind == "{":
            return _matching_brace(tokens, i) + 1
        if token.kind in (";", "}") or token.line > line:
            return i + (token.kind == ";")
        i += 1
    return i


def _description(header: str) -> str:
    match = re.search(r'hotkey-overlay-title\s*=\s*("(?:\\.|[^"\\])*")', header)
    if not match:
        return ""
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return match.group(1)[1:-1]


def parse_bindings(text: str, path: Path) -> list[Binding]:
    tokens = tokenize(text)
    result: list[Binding] = []
    for i, token in enumerate(tokens[:-1]):
        if token.kind != "word" or token.value != "binds" or tokens[i + 1].kind != "{":
            continue
        opening = i + 1
        closing = _matching_brace(tokens, opening)
        cursor = opening + 1
        while cursor < closing:
            token = tokens[cursor]
            if token.kind == ";":
                cursor += 1
                continue
            if token.kind == "slashdash":
                cursor = min(_skip_node(tokens, cursor + 1), closing)
                continue
            if token.kind == "}":
                break
            start = cursor
            # Key chords and node attributes are on the binding header. Stop at
            # its first action block, a KDL separator, or the next line's node.
            action_open = None
            while cursor < closing:
                current = tokens[cursor]
                if current.kind == "{":
                    action_open = cursor
                    break
                if current.kind in (";", "}"):
                    break
                if cursor > start and current.line > tokens[start].line:
                    break
                cursor += 1
            if action_open is None:
                cursor = max(cursor, start + 1)
                continue
            action_close = _matching_brace(tokens, action_open)
            key_token = tokens[start]
            if key_token.kind == "word":
                header = text[key_token.end:tokens[action_open].start]
                result.append(Binding(
                    path=path,
                    line=key_token.line,
                    key=key_token.value,
                    description=_description(header),
                    action=text[tokens[action_open].end:tokens[action_close].start],
                    key_start=key_token.start,
                    key_end=key_token.end,
                    action_start=tokens[action_open].end,
                    action_end=tokens[action_close].start,
                ))
            cursor = action_close + 1
            if cursor < closing and tokens[cursor].kind == ";":
                cursor += 1
    return result


def read_all_bindings(root: Path) -> list[Binding]:
    root = root.expanduser().resolve()
    found: list[Binding] = []
    seen: set[Path] = set()
    pending = [root]
    while pending:
        path = pending.pop(0).resolve()
        if path in seen:
            continue
        seen.add(path)
        if len(seen) > 256:
            raise ValueError("Konfigurasi memuat lebih dari 256 file include")
        text = path.read_text(encoding="utf-8")
        tokens = tokenize(text)
        for i, token in enumerate(tokens[:-1]):
            if token.kind != "word" or token.value != "include" or tokens[i + 1].kind != "string":
                continue
            expression = tokens[i + 1].value
            pattern = Path(expression).expanduser()
            if not pattern.is_absolute():
                pattern = path.parent / pattern
            candidates = sorted(glob.glob(str(pattern))) if glob.has_magic(str(pattern)) else [str(pattern)]
            pending.extend(Path(candidate) for candidate in candidates if Path(candidate).is_file())
        found.extend(parse_bindings(text, path))
    return found


def apply_edit(text: str, binding: Binding, key: str, action: str) -> str:
    if not key.strip() or any(ch in key for ch in "{};\r\n"):
        raise ValueError("Shortcut harus satu baris dan tidak boleh memuat kurung kurawal atau titik koma")
    leading = re.match(r"\s*", binding.action).group(0)
    trailing = re.search(r"\s*$", binding.action).group(0)
    replacement = action.strip()
    edits = [
        (binding.key_start, binding.key_end, key.strip()),
        (binding.action_start, binding.action_end, leading + replacement + trailing),
    ]
    for start, end, value in sorted(edits, reverse=True):
        text = text[:start] + value + text[end:]
    return text


def _atomic_write(path: Path, data: bytes, mode: int) -> None:
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def save_binding(root: Path, binding: Binding, key: str, action: str) -> None:
    path = binding.path
    original = path.read_bytes()
    mode = path.stat().st_mode & 0o777
    decoded = original.decode("utf-8")
    updated = apply_edit(decoded, binding, key, action).encode("utf-8")
    if updated == original:
        return
    # Do not overwrite changes made by another editor since this window opened.
    all_now = read_all_bindings(root)
    if not any(x.path == path and x.line == binding.line and x.key == binding.key for x in all_now):
        raise RuntimeError("Binding berubah sejak editor dibuka. Muat ulang sebelum mengedit.")
    backup = path.with_name(path.name + ".keybind-editor.bak")
    if not backup.exists():
        shutil.copy2(path, backup)
    _atomic_write(path, updated, mode)
    try:
        validation = subprocess.run(
            ["niri", "validate", "--config", str(root)],
            capture_output=True, text=True, timeout=12,
        )
        if validation.returncode:
            raise RuntimeError((validation.stderr or validation.stdout or "Validasi konfigurasi Niri gagal").strip())
        reload_result = subprocess.run(
            ["niri", "msg", "action", "load-config-file"],
            capture_output=True, text=True, timeout=6,
        )
        if reload_result.returncode:
            raise RuntimeError((reload_result.stderr or reload_result.stdout or "Niri gagal memuat ulang konfigurasi").strip())
    except Exception:
        # Restore only while the file still contains our own complete write.
        if path.read_bytes() == updated:
            _atomic_write(path, original, mode)
            subprocess.run(["niri", "msg", "action", "load-config-file"], capture_output=True, timeout=6)
        raise


class Editor:
    BG = "#171416"
    PANEL = "#211d20"
    SURFACE = "#292428"
    BORDER = "#393238"
    TEXT = "#f5eef1"
    MUTED = "#b8aeb4"
    ACCENT = "#ffb3b5"
    ACCENT_DARK = "#38272c"

    def __init__(self, root: Path):
        self.root_path = root.expanduser().resolve()
        self.rows: list[Binding] = []
        self.category = "All"
        self.root = tk.Tk()
        self.root.title("Keybinds")
        self.root.configure(bg=self.BG)
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)
        self.root.option_add("*Font", "TkDefaultFont 10")
        self._style()
        width, height, x, y = window_geometry(self.root.winfo_screenwidth(), self.root.winfo_screenheight())
        self.root.geometry(f"{width}x{height}+{x}+{y}")
        self.root.minsize(720, 380)

        shell = tk.Frame(self.root, bg=self.BG, padx=22, pady=16)
        shell.grid(row=0, column=0, rowspan=3, sticky="nsew")
        shell.columnconfigure(0, weight=1)
        shell.rowconfigure(3, weight=1)

        titlebar = tk.Frame(shell, bg=self.BG)
        titlebar.grid(row=0, column=0, sticky="ew", pady=(0, 16))
        titlebar.columnconfigure(1, weight=1)
        lights = tk.Frame(titlebar, bg=self.BG)
        lights.grid(row=0, column=0, sticky="w")
        for color in ("#ff5f57", "#febc2e", "#28c840"):
            tk.Canvas(lights, width=13, height=13, bg=self.BG, highlightthickness=0).pack(side="left", padx=(0, 7))
            lights.winfo_children()[-1].create_oval(2, 2, 11, 11, fill=color, outline=color)
        tk.Label(titlebar, text="Keybinds", bg=self.BG, fg=self.TEXT, font=("SF Pro Display", 14, "bold")).grid(row=0, column=1)
        self._button(titlebar, "×", self.root.destroy, quiet=True, width=3).grid(row=0, column=2, sticky="e")

        heading = tk.Frame(shell, bg=self.BG)
        heading.grid(row=1, column=0, sticky="ew", pady=(0, 14))
        heading.columnconfigure(1, weight=1)
        tk.Label(heading, text="Keyboard Shortcuts", bg=self.BG, fg=self.TEXT,
                 font=("SF Pro Display", 22, "bold")).grid(row=0, column=0, sticky="w")
        self.search = tk.StringVar()
        self.search.trace_add("write", lambda *_: self.populate())
        search = tk.Entry(heading, textvariable=self.search, bg=self.SURFACE, fg=self.TEXT,
                          insertbackground=self.ACCENT, relief="flat", highlightthickness=1,
                          highlightbackground=self.BORDER, highlightcolor=self.ACCENT,
                          font=("SF Pro Text", 11), width=30)
        search.insert(0, "")
        search.grid(row=0, column=1, sticky="e", padx=(15, 10), ipady=8, ipadx=10)
        search.bind("<Return>", lambda _event: self.tree.focus_set())
        self._button(heading, "↻  Refresh", self.reload, quiet=True).grid(row=0, column=2, sticky="e")

        tabs = tk.Frame(shell, bg=self.BG)
        tabs.grid(row=2, column=0, sticky="ew", pady=(0, 12))
        self.tab_buttons: dict[str, tk.Button] = {}
        for name in ("All", "Applications", "Window", "Navigation", "Workspaces", "Media", "System", "Other"):
            button = tk.Button(tabs, text=name, command=lambda value=name: self.set_category(value),
                               bd=0, relief="flat", padx=13, pady=7, cursor="hand2",
                               font=("SF Pro Text", 10, "bold"))
            button.pack(side="left", padx=(0, 5))
            self.tab_buttons[name] = button
        self._paint_tabs()

        content = tk.Frame(shell, bg=self.PANEL, highlightbackground=self.BORDER, highlightthickness=1)
        content.grid(row=3, column=0, sticky="nsew")
        content.columnconfigure(0, weight=1)
        content.rowconfigure(1, weight=1)
        self.count_label = tk.Label(content, text="", bg=self.PANEL, fg=self.MUTED,
                                    font=("SF Pro Text", 9), anchor="w")
        self.count_label.grid(row=0, column=0, sticky="ew", padx=14, pady=(10, 5))
        tree_frame = tk.Frame(content, bg=self.PANEL)
        tree_frame.grid(row=1, column=0, sticky="nsew", padx=8, pady=(0, 8))
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)
        self.tree = ttk.Treeview(tree_frame, columns=("key", "description", "action"),
                                 show="headings", selectmode="browse")
        for col, title, width in (("key", "SHORTCUT", 175), ("description", "DESCRIPTION", 280), ("action", "ACTION", 400)):
            self.tree.heading(col, text=title)
            self.tree.column(col, width=width, minwidth=90, anchor="w", stretch=col != "key")
        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.tree.bind("<Double-1>", lambda _event: self.edit_selected())
        self.tree.bind("<Return>", lambda _event: self.edit_selected())
        self.tree.bind("<<TreeviewSelect>>", lambda _event: self._update_edit_button())

        footer = tk.Frame(shell, bg=self.BG)
        footer.grid(row=4, column=0, sticky="ew", pady=(10, 0))
        footer.columnconfigure(0, weight=1)
        self.status = tk.StringVar(value="")
        tk.Label(footer, textvariable=self.status, bg=self.BG, fg=self.MUTED,
                 font=("SF Pro Text", 9), anchor="w").grid(row=0, column=0, sticky="w")
        self.edit_button = self._button(footer, "Edit selected", self.edit_selected, primary=True)
        self.edit_button.grid(row=0, column=1, sticky="e")
        self.reload()

    def _style(self) -> None:
        style = ttk.Style(self.root)
        style.theme_use("clam")
        style.configure("Treeview", background=self.PANEL, fieldbackground=self.PANEL,
                        foreground=self.TEXT, borderwidth=0, rowheight=34, font=("SF Pro Text", 10))
        style.map("Treeview", background=[("selected", self.ACCENT_DARK)],
                  foreground=[("selected", self.ACCENT)])
        style.configure("Treeview.Heading", background=self.SURFACE, foreground=self.MUTED,
                        relief="flat", borderwidth=0, font=("SF Pro Text", 9, "bold"), padding=(10, 8))
        style.map("Treeview.Heading", background=[("active", self.SURFACE)])
        style.configure("Vertical.TScrollbar", background=self.SURFACE, troughcolor=self.PANEL,
                        bordercolor=self.PANEL, arrowcolor=self.MUTED, relief="flat")

    def _button(self, parent, text: str, command, *, primary=False, quiet=False, width=None):
        button = tk.Button(parent, text=text, command=command, bd=0, relief="flat", cursor="hand2",
                           padx=14, pady=8, font=("SF Pro Text", 10, "bold"),
                           bg=self.ACCENT if primary else (self.BG if quiet else self.SURFACE),
                           fg="#2a171d" if primary else self.TEXT,
                           activebackground=self.ACCENT_DARK if not primary else self.ACCENT,
                           activeforeground=self.ACCENT if not primary else "#2a171d")
        if width is not None:
            button.configure(width=width, padx=2, pady=3)
        return button

    def _paint_tabs(self) -> None:
        for name, button in self.tab_buttons.items():
            active = name == self.category
            button.configure(bg=self.ACCENT if active else self.SURFACE,
                             fg="#2a171d" if active else self.MUTED,
                             activebackground=self.ACCENT_DARK,
                             activeforeground=self.ACCENT)

    def set_category(self, name: str) -> None:
        self.category = name
        self._paint_tabs()
        self.populate()

    def _update_edit_button(self) -> None:
        selected = bool(self.tree.selection())
        self.edit_button.configure(state="normal" if selected else "disabled")

    def reload(self) -> None:
        try:
            self.rows = read_all_bindings(self.root_path)
            self.populate()
            self.status.set(f"{len(self.rows)} shortcuts  ·  Niri config and included files")
        except Exception as exc:
            messagebox.showerror("Could not read shortcuts", str(exc), parent=self.root)

    def populate(self) -> None:
        if not hasattr(self, "tree"):
            return
        self.tree.delete(*self.tree.get_children())
        needle = self.search.get().casefold().strip()
        shown = 0
        for index, row in enumerate(self.rows):
            values = (row.key, row.description or "—", " ".join(row.action.split()))
            searchable = " ".join((*values, row.category, str(row.path))).casefold()
            if (not needle or needle in searchable) and (self.category == "All" or row.category == self.category):
                self.tree.insert("", "end", iid=str(index), values=values)
                shown += 1
        self.count_label.configure(text=f"{shown} SHORTCUTS" if not needle and self.category == "All"
                                   else f"{shown} OF {len(self.rows)} SHORTCUTS")
        self._update_edit_button()

    def edit_selected(self) -> None:
        selection = self.tree.selection()
        if not selection:
            return
        binding = self.rows[int(selection[0])]
        dialog = tk.Toplevel(self.root)
        dialog.title(f"Edit {binding.key}")
        dialog.configure(bg=self.BG)
        dialog.transient(self.root)
        dialog.grab_set()
        dialog.geometry("700x470")
        dialog.columnconfigure(0, weight=1)
        dialog.rowconfigure(4, weight=1)
        pad = {"padx": 18}
        tk.Label(dialog, text=f"{binding.category}  ·  {binding.path.name}:{binding.line}",
                 bg=self.BG, fg=self.MUTED, font=("SF Pro Text", 9)).grid(row=0, column=0, sticky="w", pady=(18, 8), **pad)
        tk.Label(dialog, text="Shortcut", bg=self.BG, fg=self.TEXT,
                 font=("SF Pro Text", 11, "bold")).grid(row=1, column=0, sticky="w", **pad)
        key = tk.StringVar(value=binding.key)
        key_entry = tk.Entry(dialog, textvariable=key, bg=self.SURFACE, fg=self.TEXT,
                             insertbackground=self.ACCENT, relief="flat", highlightthickness=1,
                             highlightbackground=self.BORDER, highlightcolor=self.ACCENT)
        key_entry.grid(row=2, column=0, sticky="ew", pady=(5, 12), ipady=7, **pad)
        tk.Label(dialog, text="Niri action", bg=self.BG, fg=self.TEXT,
                 font=("SF Pro Text", 11, "bold")).grid(row=3, column=0, sticky="w", pady=(0, 5), **pad)
        action = tk.Text(dialog, wrap="none", undo=True, height=12, bg=self.SURFACE, fg=self.TEXT,
                         insertbackground=self.ACCENT, relief="flat", padx=10, pady=10,
                         font=("SF Mono", 10))
        action.grid(row=4, column=0, sticky="nsew", **pad)
        action.insert("1.0", binding.action.strip())
        tk.Label(dialog, text="Existing description and header options are preserved.",
                 bg=self.BG, fg=self.MUTED, font=("SF Pro Text", 9)).grid(row=5, column=0, sticky="w", pady=8, **pad)
        controls = tk.Frame(dialog, bg=self.BG)
        controls.grid(row=6, column=0, sticky="e", pady=(0, 16), **pad)

        def save() -> None:
            try:
                save_binding(self.root_path, binding, key.get(), action.get("1.0", "end-1c"))
            except Exception as exc:
                messagebox.showerror("Not saved", f"{exc}\n\nThe original file is restored if validation fails.", parent=dialog)
                return
            dialog.destroy()
            self.reload()
            self.status.set(f"Saved and reloaded  ·  Backup: {binding.path.name}.keybind-editor.bak")

        self._button(controls, "Cancel", dialog.destroy, quiet=True).pack(side="right", padx=(8, 0))
        self._button(controls, "Validate & Save", save, primary=True).pack(side="right")
        key_entry.focus_set()

    def run(self) -> None:
        self.root.mainloop()


def editor_launch_args(script: Path, config: Path, query: str = "", category: str = "All") -> list[str]:
    command = [sys.executable, str(script), "--config", str(config), "--category", category]
    if query.strip():
        command.extend(("--search", query.strip()))
    return command


def main() -> None:
    parser = argparse.ArgumentParser(description="Browse and edit Niri shortcuts")
    parser.add_argument("--config", type=Path, help="Niri config file")
    parser.add_argument("--search", default="", help="Initial search")
    parser.add_argument("--category", default="All", help="Initial category")
    parser.add_argument("--launch-editor", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    root = args.config or Path(os.environ.get("NIRI_CONFIG", config_home / "niri/config.kdl"))
    if args.launch_editor:
        subprocess.Popen(editor_launch_args(Path(__file__).resolve(), root, args.search, args.category),
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    app = Editor(root)
    if args.search:
        app.search.set(args.search)
    if args.category:
        app.category = args.category
        app._paint_tabs()
        app.populate()
    app.run()


if __name__ == "__main__":
    main()
