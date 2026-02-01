#!/usr/bin/env python3
"""
NullSec Network Manager v1.2
A curses-based network and process monitoring utility for NullSec Linux.
Provides real-time connection monitoring, process listing, and logging.
"""
import curses
import subprocess
import time
import os
from datetime import datetime

__version__ = "1.2"
__author__ = "bad-antics"

# Helpers

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output

def list_connections():
    # ss is faster; fallback to netstat
    out = run("ss -tunap || netstat -tunap")
    return out.splitlines()

def list_processes():
    out = run("ps -eo pid,comm,cmd --sort=comm")
    return out.splitlines()

def save_log(lines, prefix):
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    path = f"logs/{prefix}-{ts}.log"
    os.makedirs('logs', exist_ok=True)
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    return path

# UI

MENU_ITEMS = [
    "Connections",
    "Processes",
    "Dump connections log",
    "Dump processes log",
    "Quit",
]


def draw_menu(stdscr, selected):
    h, w = stdscr.getmaxyx()
    title = "Home Network Device Manager"
    stdscr.clear()
    stdscr.addstr(0, 2, title)
    stdscr.addstr(1, 2, "Use ↑ ↓ to navigate, Enter to select. 'r' to refresh. 'q' to quit.")
    for idx, item in enumerate(MENU_ITEMS):
        x = 4
        y = 3 + idx
        if idx == selected:
            stdscr.attron(curses.A_REVERSE)
        stdscr.addstr(y, x, item)
        if idx == selected:
            stdscr.attroff(curses.A_REVERSE)
    stdscr.refresh()


def draw_list(stdscr, header, lines, selected_idx):
    h, w = stdscr.getmaxyx()
    stdscr.clear()
    stdscr.addstr(0, 2, header)
    stdscr.addstr(1, 2, "Up/Down to select, 's' save log, 'b' back, 'q' quit")
    max_items = h - 5
    start = max(0, selected_idx - max_items // 2)
    visible = lines[start:start+max_items]
    for i, line in enumerate(visible):
        y = 3 + i
        if start + i == selected_idx:
            stdscr.attron(curses.A_REVERSE)
        stdscr.addstr(y, 2, line[:w-4])
        if start + i == selected_idx:
            stdscr.attroff(curses.A_REVERSE)
    stdscr.refresh()


def curses_main(stdscr):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    stdscr.nodelay(False)
    selected = 0
    connections = list_connections()
    processes = list_processes()
    while True:
        draw_menu(stdscr, selected)
        ch = stdscr.getch()
        if ch in (curses.KEY_UP, ord('k')):
            selected = (selected - 1) % len(MENU_ITEMS)
        elif ch in (curses.KEY_DOWN, ord('j')):
            selected = (selected + 1) % len(MENU_ITEMS)
        elif ch == ord('q'):
            break
        elif ch == ord('r'):
            connections = list_connections()
            processes = list_processes()
        elif ch in (curses.KEY_ENTER, 10, 13):
            if MENU_ITEMS[selected] == "Connections":
                idx = 0
                while True:
                    draw_list(stdscr, "Connections", connections, idx)
                    ch2 = stdscr.getch()
                    if ch2 in (curses.KEY_UP, ord('k')):
                        idx = max(0, idx - 1)
                    elif ch2 in (curses.KEY_DOWN, ord('j')):
                        idx = min(len(connections)-1, idx + 1)
                    elif ch2 == ord('s'):
                        path = save_log(connections, 'connections')
                        stdscr.addstr(2, 2, f"Saved: {path}      ")
                        stdscr.refresh()
                        time.sleep(0.8)
                    elif ch2 == ord('b'):
                        break
                    elif ch2 == ord('q'):
                        return
                    elif ch2 == ord('r'):
                        connections = list_connections()
                        idx = min(idx, len(connections)-1)
            elif MENU_ITEMS[selected] == "Processes":
                idx = 0
                while True:
                    draw_list(stdscr, "Processes", processes, idx)
                    ch2 = stdscr.getch()
                    if ch2 in (curses.KEY_UP, ord('k')):
                        idx = max(0, idx - 1)
                    elif ch2 in (curses.KEY_DOWN, ord('j')):
                        idx = min(len(processes)-1, idx + 1)
                    elif ch2 == ord('s'):
                        path = save_log(processes, 'processes')
                        stdscr.addstr(2, 2, f"Saved: {path}      ")
                        stdscr.refresh()
                        time.sleep(0.8)
                    elif ch2 == ord('b'):
                        break
                    elif ch2 == ord('q'):
                        return
                    elif ch2 == ord('r'):
                        processes = list_processes()
                        idx = min(idx, len(processes)-1)
            elif MENU_ITEMS[selected] == "Dump connections log":
                save_log(connections, 'connections')
            elif MENU_ITEMS[selected] == "Dump processes log":
                save_log(processes, 'processes')
            elif MENU_ITEMS[selected] == "Quit":
                break

if __name__ == '__main__':
    curses.wrapper(curses_main)
