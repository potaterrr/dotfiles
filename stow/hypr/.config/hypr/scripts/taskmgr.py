#!/usr/bin/env python3
"""potato-taskmgr — a Windows-style Task Manager for Hyprland.

Ctrl+Alt+Delete opens a floating window with:
  * live process table (CPU%, MEM, PID, user, command) — sortable, searchable
  * End Task (SIGTERM, then SIGKILL for the stubborn ones)
  * CPU / RAM / swap usage bars
  * system actions tab: lock / logout / reboot / shutdown

Data comes from /proc directly (psutil-free, no extra deps).
Styling matches the Catppuccin Mocha hyprlock theme.
"""

import gi
import os
import signal
import subprocess
import time

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk, Pango

try:
    import cairo
except ImportError:
    cairo = None

# ---------------------------------------------------------------- Catppuccin Mocha
BASE = "#1e1e2e"
MANTLE = "#181825"
SURFACE0 = "#313244"
SURFACE1 = "#45475a"
TEXT = "#cdd6f4"
SUBTEXT = "#a6adc8"
OVERLAY = "#7f849c"
MAUVE = "#cba6f7"
BLUE = "#89b4fa"
RED = "#f38ba8"
YELLOW = "#f9e2af"

SORT_KEYS = {0: "pid", 1: "name", 2: "user", 3: "cpu", 4: "mem", 5: "state"}
STATE_MAP = {"R": "Running", "S": "Sleeping", "D": "Disk wait", "Z": "Zombie", "T": "Stopped"}

# Row backgrounds as Gdk.RGBA so treeview cells paint translucent dark
# regardless of what the system GTK theme wants (no white patches).
ROW_BG = Gdk.RGBA()
ROW_BG.parse("rgba(24, 24, 37, 0.50)")
SEL_BG = Gdk.RGBA()
SEL_BG.parse("rgba(69, 71, 90, 0.90)")


def read_first_line(path):
    try:
        with open(path, "r") as fh:
            return fh.readline()
    except OSError:
        return ""


def get_uid_map():
    users = {}
    try:
        with open("/etc/passwd", "r") as fh:
            for line in fh:
                parts = line.split(":")
                if len(parts) >= 3:
                    try:
                        users[int(parts[2])] = parts[0]
                    except ValueError:
                        continue
    except OSError:
        pass
    return users


def cpu_times():
    parts = read_first_line("/proc/stat").split()
    if len(parts) < 8:
        return 0, 0
    vals = [int(x) for x in parts[1:8]]  # user nice system idle iowait irq softirq
    return sum(vals), vals[3] + vals[4]


def mem_info():
    out = {}
    try:
        with open("/proc/meminfo", "r") as fh:
            for line in fh:
                key, _, rest = line.partition(":")
                out[key.strip()] = int(rest.strip().split()[0])  # kB
    except (OSError, ValueError):
        pass
    return out


def scan_processes(prev_ticks, total_delta, uid_map, page_size):
    """One /proc pass. Returns (samples, cumulative_ticks_map_for_next_pass)."""
    procs = []
    new_ticks = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat", "r") as fh:
                stat = fh.read()
            rp = stat.rfind(")")
            if rp < 0:
                continue
            comm = stat[stat.find("(") + 1: rp]
            fields = stat[rp + 2:].split()  # fields[0]=state, 11=utime, 12=stime
            state = fields[0]
            ticks = int(fields[11]) + int(fields[12])
            new_ticks[pid] = ticks
            prev = prev_ticks.get(pid)
            delta = (ticks - prev) if prev is not None else 0
            cpu_pct = (delta / total_delta * 100.0) if total_delta > 0 else 0.0
            with open(f"/proc/{pid}/statm", "r") as fh:
                rss_pages = int(fh.read().split()[1])
            owner = uid_map.get(os.stat(f"/proc/{pid}").st_uid, "?")
            procs.append({
                "pid": int(pid), "name": comm, "user": owner,
                "cpu": cpu_pct, "mem": rss_pages * page_size / 1048576.0,
                "state": state,
            })
        except (OSError, ValueError, IndexError):
            continue
    return procs, new_ticks


class TaskManager(Gtk.Window):
    REFRESH_MS = 2000

    def __init__(self):
        super().__init__(title="Task Manager — potato edition 🥔")
        self.set_default_size(880, 620)
        self.connect("destroy", Gtk.main_quit)

        # RGBA visual so CSS rgba backgrounds actually translucify (blur shows
        # through, frosted by Hyprland's decoration blur — same as kitty).
        visual = Gdk.Screen.get_default().get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)

        self.prev_ticks = {}
        self.prev_total, self.prev_idle = cpu_times()
        self.procs_cache = []
        self.sort_idx = 3  # CPU%
        self.sort_asc = False
        self.uid_map = get_uid_map()
        self.page_size = os.sysconf("SC_PAGE_SIZE")

        self.apply_css()
        self.build_ui()

        GLib.timeout_add(self.REFRESH_MS, self.tick)
        self.show_all()
        self.tick()

    # ---------------------------------------------------------------- styling
    def apply_css(self):
        css = f"""
        window {{ background-color: rgba(30, 30, 46, 0.75); }}
        * {{
            color: {TEXT};
            font-size: 13px;
            font-family: "JetBrains Mono", "Fira Code", "DejaVu Sans Mono", monospace;
        }}
        /* every container goes transparent — the window's rgba is the only frost */
        box, grid, flowbox, flowboxchild, label, stack, notebook, scrolledwindow,
        viewport, separator, levelbar trough {{ background-color: transparent; }}

        /* Adwaita paints buttons/entries with background-image GRADIENTS that sit
           on top of background-color — kill them everywhere or white shows */
        button, entry, spinbutton {{
            background-image: none;
            box-shadow: none;
            text-shadow: none;
            -gtk-icon-shadow: none;
            outline: none;
        }}
        button:active, button:hover, button:focus, button:checked,
        button:disabled {{ background-image: none; box-shadow: none; }}

        .tm-header {{ padding: 10px 14px 6px 14px; }}
        .tm-search {{
            background-color: rgba(49, 50, 68, 0.55);
            color: {TEXT};
            border: 1px solid {SURFACE1};
            border-radius: 8px;
            padding: 6px 10px;
        }}
        notebook header {{ background-color: rgba(24, 24, 37, 0.45); }}
        notebook header tabs tab {{
            background-color: transparent;
            padding: 6px 16px;
        }}
        notebook header tabs tab:checked {{
            background-color: rgba(69, 71, 90, 0.75);
            border-radius: 8px;
        }}
        .tm-list, scrolledwindow {{
            background-color: rgba(24, 24, 37, 0.35);
            border-radius: 10px;
            border: 1px solid {SURFACE0};
        }}
        treeview {{
            background-color: rgba(24, 24, 37, 0.35);
            color: {TEXT};
        }}
        treeview:selected {{ color: {TEXT}; }}
        treeview header button {{
            background-color: rgba(49, 50, 68, 0.55);
            color: {SUBTEXT};
            border: none;
            border-right: 1px solid {MANTLE};
            padding: 6px 8px;
            font-weight: bold;
        }}
        levelbar {{ border-radius: 3px; }}
        levelbar block.filled {{ background-color: {BLUE}; border-radius: 3px; }}
        levelbar block.empty {{ background-color: rgba(49, 50, 68, 0.45); border-radius: 3px; }}
        .tm-btn {{
            background-color: rgba(49, 50, 68, 0.60);
            color: {TEXT};
            border: 1px solid {SURFACE1};
            border-radius: 8px;
            padding: 7px 14px;
        }}
        .tm-btn:hover {{ background-color: rgba(69, 71, 90, 0.85); }}
        .tm-btn:active, .tm-btn:focus {{ background-color: rgba(69, 71, 90, 0.95); }}
        .tm-btn-danger {{
            background-color: {RED};
            color: {BASE};
            font-weight: bold;
            border: none;
        }}
        .tm-btn-danger:hover {{ background-color: #f5a0b8; }}
        .tm-statusbar {{
            background-color: rgba(24, 24, 37, 0.55);
            color: {OVERLAY};
            font-size: 11px;
            padding: 4px 10px;
            border-top: 1px solid rgba(49, 50, 68, 0.6);
        }}
        dialog {{ background-color: rgba(30, 30, 46, 0.95); }}
        messagedialog .titlebar {{
            background-color: transparent;
            border: none;
            border-bottom: none;
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    # ---------------------------------------------------------------- UI
    def build_ui(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.add(vbox)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header.get_style_context().add_class("tm-header")
        title = Gtk.Label(xalign=0)
        title.set_markup(f"<span foreground='{MAUVE}' size='x-large'><b>Task Manager</b></span> 🥔")
        header.pack_start(title, False, False, 0)

        self.search = Gtk.SearchEntry()
        self.search.get_style_context().add_class("tm-search")
        self.search.set_placeholder_text("$ grep processes…")
        self.search.connect("search-changed", lambda _e: self.refresh_tree())
        header.pack_end(self.search, False, False, 0)
        vbox.pack_start(header, False, False, 0)

        nb = Gtk.Notebook()
        vbox.pack_start(nb, True, True, 0)

        # --- tab 1: processes
        proc_tab = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        proc_tab.set_border_width(10)
        nb.append_page(proc_tab, Gtk.Label(label="Processes"))

        res_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=18)
        self.cpu_bar = self.make_res_bar()
        self.mem_bar = self.make_res_bar()
        self.swap_bar = self.make_res_bar()
        res_box.pack_start(self.cpu_bar["box"], True, True, 0)
        res_box.pack_start(self.mem_bar["box"], True, True, 0)
        res_box.pack_start(self.swap_bar["box"], True, True, 0)
        proc_tab.pack_start(res_box, False, False, 0)

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroller.set_shadow_type(Gtk.ShadowType.NONE)  # no theme frame — CSS border only
        scroller.get_style_context().add_class("tm-list")

        self.store = Gtk.ListStore(int, str, str, float, float, str)
        self.tree = Gtk.TreeView(model=self.store, enable_search=True)
        self.tree.set_search_column(1)

        cols = [
            ("PID", 0, 70, self.cell_int),
            ("Name", 1, 300, self.cell_text),
            ("User", 2, 110, self.cell_text),
            ("CPU %", 3, 90, self.cell_pct),
            ("Memory", 4, 90, self.cell_mem),
            ("State", 5, 90, self.cell_text),
        ]
        for title, idx, width, cellfn in cols:
            cell = Gtk.CellRendererText()
            cell.set_property("ellipsize", Pango.EllipsizeMode.END)
            col = Gtk.TreeViewColumn(title, cell)
            col.set_cell_data_func(cell, cellfn, idx)
            col.set_resizable(True)
            col.set_min_width(width)
            col.connect("clicked", self.on_col_clicked, idx)
            self.tree.append_column(col)

        self.tree.connect("row-activated", self.on_row_activate)
        scroller.add(self.tree)
        proc_tab.pack_start(scroller, True, True, 0)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.count_label = Gtk.Label(xalign=0)
        self.count_label.get_style_context().add_class("tm-statusbar")
        actions.pack_start(self.count_label, True, True, 0)

        refresh_btn = Gtk.Button(label="Refresh now")
        refresh_btn.get_style_context().add_class("tm-btn")
        refresh_btn.connect("clicked", lambda _b: self.tick())
        actions.pack_end(refresh_btn, False, False, 0)

        end_btn = Gtk.Button(label="End Task")
        end_btn.get_style_context().add_class("tm-btn-danger")
        end_btn.connect("clicked", self.on_end_task)
        actions.pack_end(end_btn, False, False, 0)
        proc_tab.pack_start(actions, False, False, 0)

        # --- tab 2: system actions
        sys_tab = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        sys_tab.set_border_width(20)
        nb.append_page(sys_tab, Gtk.Label(label="System"))

        sys_hint = Gtk.Label(xalign=0)
        sys_hint.set_markup(f"<span foreground='{SUBTEXT}'>Session &amp; power actions — same as wlogout.</span>")
        sys_tab.pack_start(sys_hint, False, False, 0)

        grid = Gtk.FlowBox()
        grid.set_max_children_per_line(2)
        grid.set_min_children_per_line(2)
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        grid.set_hexpand(True)
        for label, cmd in [
            ("🔒  Lock session", "hyprlock"),
            ("🚪  Logout", "hyprctl dispatch exit"),
            ("🔄  Reboot", "systemctl reboot"),
            ("⏻  Shutdown", "systemctl poweroff"),
        ]:
            b = Gtk.Button(label=label)
            b.get_style_context().add_class("tm-btn")
            b.set_hexpand(True)
            b.connect("clicked", self.on_system_action, cmd)
            grid.add(b)
        sys_tab.pack_start(grid, True, True, 0)

        self.statusbar = Gtk.Label(xalign=0)
        self.statusbar.get_style_context().add_class("tm-statusbar")
        self.statusbar.set_text("collecting first sample…")
        vbox.pack_start(self.statusbar, False, False, 0)

        # keyboard: Esc closes, Ctrl+K ends the selected task
        accel = Gtk.AccelGroup()
        accel.connect(Gdk.keyval_from_name("Escape"), 0, Gtk.AccelFlags.VISIBLE,
                      self.on_accel_quit)
        accel.connect(Gdk.keyval_from_name("k"), Gdk.ModifierType.CONTROL_MASK,
                      Gtk.AccelFlags.VISIBLE, self.on_accel_kill)
        self.add_accel_group(accel)

    def on_accel_quit(self, *args):
        Gtk.main_quit()
        return True

    def on_accel_kill(self, *args):
        self.on_end_task()
        return True

    def make_res_bar(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        cap = Gtk.Label(xalign=0)
        level = Gtk.LevelBar(min_value=0, max_value=100)
        level.set_mode(Gtk.LevelBarMode.CONTINUOUS)
        level.set_size_request(-1, 8)
        box.pack_start(cap, False, False, 0)
        box.pack_start(level, False, False, 0)
        return {"box": box, "cap": cap, "level": level}

    # ---------------------------------------------------------------- cells
    def _cell_bg(self, model, it):
        """Translucent dark everywhere; lighter slate on the selected row."""
        _m, sel = self.tree.get_selection().get_selected()
        selected = sel is not None and model.get_path(sel) == model.get_path(it)
        return SEL_BG if selected else ROW_BG

    def cell_text(self, _col, cell, model, it, idx):
        cell.set_property("text", model[it][idx])
        cell.set_property("cell-background-rgba", self._cell_bg(model, it))

    def cell_int(self, _col, cell, model, it, idx):
        cell.set_property("text", str(model[it][idx]))
        cell.set_property("cell-background-rgba", self._cell_bg(model, it))

    def cell_pct(self, _col, cell, model, it, idx):
        v = model[it][idx]
        cell.set_property("text", f"{v:5.1f}")
        cell.set_property("cell-background-rgba", self._cell_bg(model, it))
        if v > 60:
            cell.set_property("foreground", RED)
        elif v > 25:
            cell.set_property("foreground", YELLOW)
        else:
            cell.set_property("foreground", TEXT)

    def cell_mem(self, _col, cell, model, it, idx):
        cell.set_property("text", f"{model[it][idx]:.0f} MB")
        cell.set_property("cell-background-rgba", self._cell_bg(model, it))

    # ---------------------------------------------------------------- data
    def tick(self):
        total, idle = cpu_times()
        d_total = total - self.prev_total
        d_idle = idle - self.prev_idle
        self.prev_total, self.prev_idle = total, idle

        procs, self.prev_ticks = scan_processes(self.prev_ticks, d_total, self.uid_map, self.page_size)
        self.procs_cache = procs

        mem = mem_info()
        mem_total = mem.get("MemTotal", 1)
        mem_avail = mem.get("MemAvailable", 0)
        mem_used_pct = 100.0 * (mem_total - mem_avail) / max(mem_total, 1)
        swap_total = mem.get("SwapTotal", 0)
        swap_free = mem.get("SwapFree", 0)
        swap_pct = 100.0 * (swap_total - swap_free) / swap_total if swap_total else 0.0
        cpu_used = 100.0 * (d_total - d_idle) / d_total if d_total else 0.0

        self.cpu_bar["level"].set_value(min(cpu_used, 100))
        self.mem_bar["level"].set_value(min(mem_used_pct, 100))
        self.swap_bar["level"].set_value(min(swap_pct, 100))
        self.cpu_bar["cap"].set_markup(
            f"<span foreground='{SUBTEXT}'><b>CPU</b></span> <span foreground='{OVERLAY}'>{cpu_used:.0f}%</span>")
        self.mem_bar["cap"].set_markup(
            f"<span foreground='{SUBTEXT}'><b>Memory</b></span> "
            f"<span foreground='{OVERLAY}'>{(mem_total - mem_avail) / 1048576:.1f}/{mem_total / 1048576:.1f} GB</span>")
        self.swap_bar["cap"].set_markup(
            f"<span foreground='{SUBTEXT}'><b>Swap</b></span> <span foreground='{OVERLAY}'>{swap_pct:.0f}%</span>")

        self.refresh_tree()
        return True

    def refresh_tree(self):
        query = self.search.get_text().strip().lower() if hasattr(self, "search") else ""
        procs = self.procs_cache
        filtered = [p for p in procs if not query or query in p["name"].lower() or query in p["user"].lower()]
        sort_key = {
            "pid": lambda p: p["pid"],
            "name": lambda p: p["name"].lower(),
            "user": lambda p: p["user"],
            "cpu": lambda p: p["cpu"],
            "mem": lambda p: p["mem"],
            "state": lambda p: p["state"],
        }[SORT_KEYS[self.sort_idx]]
        filtered.sort(key=sort_key, reverse=not self.sort_asc)

        self.store.clear()
        for p in filtered:
            self.store.append([p["pid"], p["name"], p["user"], p["cpu"], p["mem"],
                               STATE_MAP.get(p["state"], p["state"])])
        self.count_label.set_text(f"{len(filtered)} shown / {len(procs)} processes")

    def on_col_clicked(self, col, idx):
        if self.sort_idx == idx:
            self.sort_asc = not self.sort_asc
        else:
            self.sort_idx = idx
            self.sort_asc = False
        self.refresh_tree()

    # ---------------------------------------------------------------- actions
    def selected_pid(self):
        model, it = self.tree.get_selection().get_selected()
        return model[it][0] if it is not None else None

    def kill_process(self, pid, sig):
        try:
            os.kill(pid, sig)
            self.statusbar.set_text(f"signal {sig} → PID {pid}")
            return True
        except ProcessLookupError:
            self.statusbar.set_text(f"process {pid} already gone")
        except PermissionError:
            self.statusbar.set_text(f"permission denied for PID {pid}")
        return False

    def on_end_task(self, *args):
        pid = self.selected_pid()
        if pid is None:
            self.statusbar.set_text("select a process first")
            return
        dlg = Gtk.MessageDialog(transient_for=self, modal=True,
                                message_type=Gtk.MessageType.QUESTION,
                                text=f"End task PID {pid}?",
                                secondary_text="SIGTERM first, SIGKILL if it refuses to die.")
        dlg.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dlg.add_button("End Task", Gtk.ResponseType.OK)
        resp = dlg.run()
        dlg.destroy()
        if resp != Gtk.ResponseType.OK:
            return
        if not self.kill_process(pid, signal.SIGTERM):
            return

        def escalate():
            try:
                os.kill(pid, 0)  # still alive?
                os.kill(pid, signal.SIGKILL)
                self.statusbar.set_text(f"PID {pid} force-killed (SIGKILL)")
            except OSError:
                pass
            return False

        GLib.timeout_add(3000, escalate)
        GLib.timeout_add(600, self.tick)

    def on_row_activate(self, _tree, _path, _col):
        self.on_end_task()

    def on_system_action(self, _btn, cmd):
        confirm = Gtk.MessageDialog(transient_for=self, modal=True,
                                    message_type=Gtk.MessageType.WARNING,
                                    text=f"Run: {cmd}?",
                                    secondary_text="This takes effect immediately.")
        confirm.add_button("Cancel", Gtk.ResponseType.CANCEL)
        confirm.add_button("Confirm", Gtk.ResponseType.OK)
        resp = confirm.run()
        confirm.destroy()
        if resp == Gtk.ResponseType.OK:
            subprocess.Popen(cmd, shell=True)
            if "exit" in cmd or "poweroff" in cmd or "reboot" in cmd:
                Gtk.main_quit()


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    # WM_CLASS must be "potato-taskmgr" — the Hyprland windowrules target it
    GLib.set_prgname("potato-taskmgr")
    GLib.set_application_name("Task Manager — potato edition")
    TaskManager()
    Gtk.main()


if __name__ == "__main__":
    main()
