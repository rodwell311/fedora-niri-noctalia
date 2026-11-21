import importlib.util
import tempfile
import unittest
import sys
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
APP = REPO / ".local/share/niri-keybind-editor/niri_keybind_editor.py"
PLUGIN_SOURCE = REPO / ".local/share/noctalia/plugins/keybind-editor/launcher.luau"
if not PLUGIN_SOURCE.exists():
    REPO = Path(__file__).resolve().parents[1]
PLUGIN_SOURCE = REPO / ".local/share/noctalia/plugins/keybind-editor/launcher.luau"
spec = importlib.util.spec_from_file_location("niri_keybind_editor", APP)
app = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = app
spec.loader.exec_module(app)


class ParseBindingsTests(unittest.TestCase):
    def test_reads_all_bind_nodes_and_preserves_action_span(self):
        source = '''binds {
    Mod+K hotkey-overlay-title="Launcher" { spawn "alacritty"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }
    Mod+X { spawn "app"; set-column-width "-10%"; }
}
'''
        rows = app.parse_bindings(source, Path("config.kdl"))
        self.assertEqual([row.key for row in rows], ["Mod+K", "XF86AudioMute", "Mod+X"])
        self.assertEqual(rows[0].description, "Launcher")
        self.assertEqual(rows[2].action.strip(), 'spawn "app"; set-column-width "-10%";')
        updated = app.apply_edit(source, rows[2], "Mod+Y", 'spawn "other";')
        changed = app.parse_bindings(updated, Path("config.kdl"))
        self.assertEqual(changed[2].key, "Mod+Y")
        self.assertEqual(changed[2].action.strip(), 'spawn "other";')

    def test_window_is_centered_and_two_thirds_of_screen(self):
        self.assertEqual(app.window_geometry(1366, 768), (911, 512, 227, 128))

    def test_category_filters_cover_shortcuts(self):
        source = '''binds {
    Mod+Return { spawn "alacritty"; }
    Mod+H { focus-column-left; }
    XF86AudioMute { spawn-sh "noctalia msg volume-mute"; }
}
'''
        rows = app.parse_bindings(source, Path("config.kdl"))
        self.assertEqual([row.category for row in rows], ["Applications", "Navigation", "Media"])

    def test_editor_launch_args_preserve_filter_and_config(self):
        script = REPO / ".local/share/niri-keybind-editor/niri_keybind_editor.py"
        config = Path("/home/user/.config/niri/config.kdl")
        self.assertEqual(app.editor_launch_args(script, config, "Mod+K"),
                         [app.sys.executable, str(script), "--config", str(config), "--category", "All", "--search", "Mod+K"])
        self.assertEqual(app.editor_launch_args(script, config, "", "Media"),
                         [app.sys.executable, str(script), "--config", str(config), "--category", "Media"])

    def test_launcher_provider_defers_search_results_and_actions_to_editor(self):
        source = PLUGIN_SOURCE
        text = source.read_text()
        self.assertIn("launcher.setResults", text)
        self.assertIn("--launch-editor", text)
        self.assertIn("noctalia.runAsync(command)", text)
        self.assertNotIn("noctalia.runAsync(command, function", text)
        self.assertIn("Search:", text)
        self.assertIn("local search", text)


    def test_rejects_invalid_shortcut(self):
        source = "binds { Mod+K { close-window; } }"
        row = app.parse_bindings(source, Path("config.kdl"))[0]
        with self.assertRaises(ValueError):
            app.apply_edit(source, row, "Mod+K; Mod+X", "close-window;")

    def test_ignores_comments_and_nested_action_braces(self):
        source = '''binds {
    // Mod+Z { close-window; }
    Mod+X { spawn-sh "if true; then echo ok; fi"; }
}
'''
        rows = app.parse_bindings(source, Path("config.kdl"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].key, "Mod+X")

    def test_follows_nested_include_and_avoids_cycles(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "config.kdl"
            part = Path(temp) / "parts" / "keys.kdl"
            part.parent.mkdir()
            root.write_text('include "parts/keys.kdl"\nbinds { Mod+A { close-window; } }\n')
            part.write_text('include "../config.kdl"\nbinds { Mod+B { fullscreen-window; } }\n')
            rows = app.read_all_bindings(root)
            self.assertEqual({row.key for row in rows}, {"Mod+A", "Mod+B"})

    def test_valid_edit_persists_and_reloads_config(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "config.kdl"
            original = "binds { Mod+A { close-window; } }\n"
            root.write_text(original)
            row = app.read_all_bindings(root)[0]
            calls = []

            def run(args, **kwargs):
                calls.append(args)
                return app.subprocess.CompletedProcess(args, 0, "valid", "")

            with patch.object(app.subprocess, "run", side_effect=run):
                app.save_binding(root, row, "Mod+B", "fullscreen-window;")

            updated = app.read_all_bindings(root)
            self.assertEqual((updated[0].key, updated[0].action.strip()), ("Mod+B", "fullscreen-window;"))
            self.assertEqual(root.with_name("config.kdl.keybind-editor.bak").read_text(), original)
            self.assertEqual([call[1] for call in calls], ["validate", "msg"])

    def test_invalid_edit_restores_original_config(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "config.kdl"
            root.write_text("binds { Mod+A { close-window; } }\n")
            row = app.read_all_bindings(root)[0]

            def run(args, **kwargs):
                if args[1] == "validate":
                    return app.subprocess.CompletedProcess(args, 1, "", "invalid test config")
                return app.subprocess.CompletedProcess(args, 0, "", "")

            with patch.object(app.subprocess, "run", side_effect=run):
                with self.assertRaisesRegex(RuntimeError, "invalid test config"):
                    app.save_binding(root, row, "Mod+B", "close-window;")

            self.assertEqual(root.read_text(), "binds { Mod+A { close-window; } }\n")
            self.assertTrue(root.with_name("config.kdl.keybind-editor.bak").exists())


if __name__ == "__main__":
    unittest.main()
