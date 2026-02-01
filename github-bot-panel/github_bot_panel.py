#!/usr/bin/env python3
"""
NULLSEC GITHUB BOT CONTROL PANEL v2.0
=====================================
Complete GitHub automation, monitoring, and maintenance platform

Features:
- Monitor ALL your repos automatically
- PR/Issue review and management  
- Auto-maintenance (star back, follow back, sync forks)
- Bulk operations across all repos
- Real-time activity feed
- Notification management
- Repository health dashboard

Author: bad-antics
License: MIT
"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Notify', '0.7')
from gi.repository import Gtk, Gdk, GLib, Pango, Notify
import os
import sys
import json
import subprocess
import threading
from datetime import datetime, timedelta
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional
import time

Notify.init("NullSec GitHub Bot")

CONFIG_DIR = Path.home() / ".config" / "nullsec-github-bot"
CONFIG_FILE = CONFIG_DIR / "config.json"

DEFAULT_CONFIG = {
    "github_username": "bad-antics",
    "auto_refresh_interval": 120,
    "notifications_enabled": True,
    "auto_maintenance": {
        "enabled": False,
        "star_back": True,
        "follow_back": True,
        "sync_forks": False,
        "auto_approve_bots": False
    },
    "priority_repos": [
        "awesome-julia-security",
        "securevault",
        "hashforensics", 
        "netprobe",
        "spectra",
        "oracle",
        "phantom",
        "vortex",
        "mirage"
    ],
    "ignored_repos": []
}

@dataclass
class Repository:
    name: str
    full_name: str
    description: str
    stars: int
    forks: int
    watchers: int
    open_issues: int
    is_fork: bool
    is_private: bool
    updated_at: str
    pushed_at: str
    language: str
    topics: List[str] = field(default_factory=list)

@dataclass
class PullRequest:
    number: int
    title: str
    author: str
    repo: str
    state: str
    created_at: str
    updated_at: str
    mergeable: bool
    draft: bool
    labels: List[str] = field(default_factory=list)
    review_state: str = "PENDING"

@dataclass
class Issue:
    number: int
    title: str
    author: str
    repo: str
    state: str
    created_at: str
    labels: List[str] = field(default_factory=list)
    comments: int = 0

@dataclass
class GitHubUser:
    login: str
    name: str
    followers: int
    following: int
    public_repos: int
    
@dataclass
class Activity:
    type: str
    repo: str
    actor: str
    timestamp: str
    details: str


class GitHubService:
    """Handles all GitHub API interactions via gh CLI"""
    
    def __init__(self, username: str = "bad-antics"):
        self.username = username
        
    def _run_gh(self, args: List[str], timeout: int = 60) -> Optional[str]:
        """Run gh CLI command and return output"""
        try:
            result = subprocess.run(
                ['gh'] + args,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if result.returncode == 0:
                return result.stdout.strip()
            return None
        except Exception as e:
            print(f"[GH ERROR] {e}")
            return None
    
    def get_user_info(self) -> Optional[GitHubUser]:
        """Get authenticated user info"""
        output = self._run_gh(['api', 'user'])
        if output:
            try:
                data = json.loads(output)
                return GitHubUser(
                    login=data.get('login', ''),
                    name=data.get('name', ''),
                    followers=data.get('followers', 0),
                    following=data.get('following', 0),
                    public_repos=data.get('public_repos', 0)
                )
            except:
                pass
        return None
    
    def get_all_repos(self, include_forks: bool = True) -> List[Repository]:
        """Get all user repositories"""
        output = self._run_gh([
            'api', 'user/repos', '--paginate',
            '-q', '.[] | {name: .name, full_name: .full_name, description: .description, stars: .stargazers_count, forks: .forks_count, watchers: .watchers_count, open_issues: .open_issues_count, is_fork: .fork, is_private: .private, updated_at: .updated_at, pushed_at: .pushed_at, language: .language, topics: .topics}'
        ])
        
        if not output:
            return []
        
        repos = []
        for line in output.strip().split('\n'):
            if line:
                try:
                    data = json.loads(line)
                    if not include_forks and data.get('is_fork'):
                        continue
                    repos.append(Repository(
                        name=data.get('name', ''),
                        full_name=data.get('full_name', ''),
                        description=data.get('description', '') or '',
                        stars=data.get('stars', 0),
                        forks=data.get('forks', 0),
                        watchers=data.get('watchers', 0),
                        open_issues=data.get('open_issues', 0),
                        is_fork=data.get('is_fork', False),
                        is_private=data.get('is_private', False),
                        updated_at=data.get('updated_at', ''),
                        pushed_at=data.get('pushed_at', ''),
                        language=data.get('language', '') or 'Unknown',
                        topics=data.get('topics', []) or []
                    ))
                except json.JSONDecodeError:
                    continue
        return repos
    
    def get_all_open_prs(self) -> List[PullRequest]:
        """Get all open PRs across all repos where user is involved"""
        output = self._run_gh([
            'search', 'prs', '--state=open', f'--involves={self.username}',
            '--json', 'number,title,author,repository,state,createdAt,updatedAt,isDraft,labels,reviewDecision'
        ])
        
        if not output:
            return []
        
        try:
            data = json.loads(output)
            prs = []
            for pr in data:
                repo_info = pr.get('repository', {})
                prs.append(PullRequest(
                    number=pr.get('number', 0),
                    title=pr.get('title', ''),
                    author=pr.get('author', {}).get('login', 'unknown'),
                    repo=repo_info.get('nameWithOwner', ''),
                    state=pr.get('state', 'OPEN'),
                    created_at=pr.get('createdAt', ''),
                    updated_at=pr.get('updatedAt', ''),
                    mergeable=True,
                    draft=pr.get('isDraft', False),
                    labels=[l.get('name', '') for l in pr.get('labels', [])],
                    review_state=pr.get('reviewDecision', 'PENDING') or 'PENDING'
                ))
            return prs
        except:
            return []
    
    def get_repo_prs(self, repo: str) -> List[PullRequest]:
        """Get open PRs for a specific repo"""
        output = self._run_gh([
            'pr', 'list', '--repo', repo, '--state', 'open',
            '--json', 'number,title,author,state,createdAt,updatedAt,isDraft,labels,reviewDecision'
        ])
        
        if not output:
            return []
        
        try:
            data = json.loads(output)
            return [PullRequest(
                number=pr.get('number', 0),
                title=pr.get('title', ''),
                author=pr.get('author', {}).get('login', 'unknown'),
                repo=repo,
                state=pr.get('state', 'OPEN'),
                created_at=pr.get('createdAt', ''),
                updated_at=pr.get('updatedAt', ''),
                mergeable=True,
                draft=pr.get('isDraft', False),
                labels=[l.get('name', '') for l in pr.get('labels', [])],
                review_state=pr.get('reviewDecision', 'PENDING') or 'PENDING'
            ) for pr in data]
        except:
            return []
    
    def get_all_open_issues(self) -> List[Issue]:
        """Get all open issues across repos"""
        output = self._run_gh([
            'search', 'issues', '--state=open', f'--involves={self.username}',
            '--json', 'number,title,author,repository,state,createdAt,labels,comments'
        ])
        
        if not output:
            return []
        
        try:
            data = json.loads(output)
            issues = []
            for issue in data:
                repo_info = issue.get('repository', {})
                issues.append(Issue(
                    number=issue.get('number', 0),
                    title=issue.get('title', ''),
                    author=issue.get('author', {}).get('login', 'unknown'),
                    repo=repo_info.get('nameWithOwner', ''),
                    state=issue.get('state', 'OPEN'),
                    created_at=issue.get('createdAt', ''),
                    labels=[l.get('name', '') for l in issue.get('labels', [])],
                    comments=len(issue.get('comments', []))
                ))
            return issues
        except:
            return []
    
    def get_repo_issues(self, repo: str) -> List[Issue]:
        """Get open issues for a specific repo"""
        output = self._run_gh([
            'issue', 'list', '--repo', repo, '--state', 'open',
            '--json', 'number,title,author,state,createdAt,labels,comments'
        ])
        
        if not output:
            return []
        
        try:
            data = json.loads(output)
            return [Issue(
                number=issue.get('number', 0),
                title=issue.get('title', ''),
                author=issue.get('author', {}).get('login', 'unknown'),
                repo=repo,
                state=issue.get('state', 'OPEN'),
                created_at=issue.get('createdAt', ''),
                labels=[l.get('name', '') for l in issue.get('labels', [])],
                comments=len(issue.get('comments', []))
            ) for issue in data]
        except:
            return []
    
    def get_notifications(self) -> List[Dict]:
        """Get unread notifications"""
        output = self._run_gh(['api', 'notifications'])
        if output:
            try:
                data = json.loads(output)
                return [{
                    'id': n.get('id'),
                    'type': n.get('subject', {}).get('type'),
                    'title': n.get('subject', {}).get('title'),
                    'repo': n.get('repository', {}).get('full_name'),
                    'unread': n.get('unread'),
                    'reason': n.get('reason'),
                    'updated_at': n.get('updated_at')
                } for n in data]
            except:
                pass
        return []
    
    def get_recent_activity(self) -> List[Activity]:
        """Get recent activity for user's repos"""
        output = self._run_gh(['api', f'users/{self.username}/received_events', '--jq', 
            '.[:30] | .[] | {type: .type, repo: .repo.name, actor: .actor.login, timestamp: .created_at}'])
        
        if not output:
            return []
        
        activities = []
        for line in output.strip().split('\n'):
            if line:
                try:
                    data = json.loads(line)
                    activity_type = data.get('type', '').replace('Event', '')
                    activities.append(Activity(
                        type=activity_type,
                        repo=data.get('repo', ''),
                        actor=data.get('actor', ''),
                        timestamp=data.get('timestamp', ''),
                        details=f"{data.get('actor')} {activity_type.lower()} {data.get('repo')}"
                    ))
                except:
                    continue
        return activities
    
    def get_followers(self) -> List[str]:
        """Get list of followers"""
        output = self._run_gh(['api', 'user/followers', '--paginate', '--jq', '.[].login'])
        if output:
            return output.strip().split('\n')
        return []
    
    def get_following(self) -> List[str]:
        """Get list of users being followed"""
        output = self._run_gh(['api', 'user/following', '--paginate', '--jq', '.[].login'])
        if output:
            return output.strip().split('\n')
        return []
    
    def follow_user(self, username: str) -> bool:
        """Follow a user"""
        return self._run_gh(['api', '-X', 'PUT', f'/user/following/{username}']) is not None
    
    def approve_pr(self, repo: str, pr_number: int, comment: str = "LGTM! 🚀") -> bool:
        """Approve a PR"""
        args = ['pr', 'review', str(pr_number), '--repo', repo, '--approve']
        if comment:
            args.extend(['--body', comment])
        return self._run_gh(args) is not None
    
    def merge_pr(self, repo: str, pr_number: int, method: str = 'squash') -> bool:
        """Merge a PR"""
        return self._run_gh([
            'pr', 'merge', str(pr_number), '--repo', repo, f'--{method}', '--delete-branch'
        ]) is not None
    
    def close_pr(self, repo: str, pr_number: int) -> bool:
        """Close a PR"""
        return self._run_gh(['pr', 'close', str(pr_number), '--repo', repo]) is not None
    
    def close_issue(self, repo: str, issue_number: int, comment: str = "") -> bool:
        """Close an issue"""
        if comment:
            self._run_gh(['issue', 'comment', str(issue_number), '--repo', repo, '--body', comment])
        return self._run_gh(['issue', 'close', str(issue_number), '--repo', repo]) is not None
    
    def add_comment(self, repo: str, number: int, comment: str, is_pr: bool = True) -> bool:
        """Add a comment"""
        cmd = 'pr' if is_pr else 'issue'
        return self._run_gh([cmd, 'comment', str(number), '--repo', repo, '--body', comment]) is not None
    
    def mark_notifications_read(self) -> bool:
        """Mark all notifications as read"""
        return self._run_gh(['api', '-X', 'PUT', '/notifications']) is not None
    
    def sync_fork(self, repo: str) -> bool:
        """Sync a fork with upstream"""
        return self._run_gh(['repo', 'sync', repo]) is not None


class GitHubBotPanel(Gtk.Window):
    """Main application window"""
    
    def __init__(self):
        super().__init__(title="NullSec GitHub Bot Control Panel v2.0")
        self.set_default_size(1500, 950)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        self.config = self.load_config()
        self.github = GitHubService(self.config.get('github_username', 'bad-antics'))
        
        self.user_info: Optional[GitHubUser] = None
        self.all_repos: List[Repository] = []
        self.all_prs: List[PullRequest] = []
        self.all_issues: List[Issue] = []
        self.notifications: List[Dict] = []
        self.activities: List[Activity] = []
        self.selected_repo: Optional[Repository] = None
        self.selected_pr: Optional[PullRequest] = None
        self.selected_issue: Optional[Issue] = None
        
        self.maintenance_running = False
        
        self.apply_css()
        self.build_ui()
        
        self.refresh_timer = None
        self.maintenance_timer = None
        self.start_auto_refresh()
        
        GLib.idle_add(self.refresh_all)
        self.connect("destroy", self.on_destroy)
    
    def load_config(self) -> Dict:
        """Load configuration"""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, 'r') as f:
                    loaded = json.load(f)
                    config = DEFAULT_CONFIG.copy()
                    config.update(loaded)
                    return config
            except:
                pass
        return DEFAULT_CONFIG.copy()
    
    def save_config(self):
        """Save configuration"""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def apply_css(self):
        """Apply dark theme CSS"""
        css = b"""
        window { background-color: #0a0a0a; }
        .header-bar {
            background: linear-gradient(to bottom, #2a0000, #1a0000);
            border-bottom: 2px solid #cc0000;
            padding: 10px;
        }
        .panel {
            background-color: #141414;
            border: 1px solid #333333;
            border-radius: 4px;
            padding: 5px;
        }
        .card {
            background-color: #1e1e1e;
            border: 1px solid #333333;
            border-radius: 4px;
            padding: 10px;
            margin: 5px;
        }
        .card:hover { border-color: #cc0000; }
        .stat-box {
            background: linear-gradient(to bottom, #1e1e1e, #141414);
            border: 1px solid #333;
            border-radius: 8px;
            padding: 15px;
            margin: 5px;
        }
        button {
            background: linear-gradient(to bottom, #333333, #222222);
            border: 1px solid #444444;
            border-radius: 4px;
            color: #e0e0e0;
            padding: 8px 16px;
            min-height: 30px;
        }
        button:hover {
            background: linear-gradient(to bottom, #444444, #333333);
            border-color: #cc0000;
        }
        button.approve-btn {
            background: linear-gradient(to bottom, #004400, #003300);
            border-color: #00cc00;
        }
        button.danger-btn {
            background: linear-gradient(to bottom, #440000, #330000);
            border-color: #cc0000;
        }
        button.action-btn {
            background: linear-gradient(to bottom, #003366, #002244);
            border-color: #3366ff;
        }
        entry, textview {
            background-color: #1e1e1e;
            border: 1px solid #333333;
            border-radius: 4px;
            color: #e0e0e0;
            padding: 5px;
        }
        textview text { background-color: #1e1e1e; color: #e0e0e0; }
        treeview { background-color: #141414; color: #e0e0e0; }
        treeview:selected { background-color: #2a0000; }
        notebook tab {
            background-color: #1a1a1a;
            border: 1px solid #333333;
            padding: 8px 16px;
        }
        notebook tab:checked {
            background-color: #2a0000;
            border-bottom: 2px solid #cc0000;
        }
        .log-view {
            font-family: monospace;
            font-size: 11px;
        }
        switch { min-width: 60px; }
        """
        
        style_provider = Gtk.CssProvider()
        style_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def build_ui(self):
        """Build the main UI"""
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_box)
        
        header = self.create_header()
        main_box.pack_start(header, False, False, 0)
        
        stats_bar = self.create_stats_bar()
        main_box.pack_start(stats_bar, False, False, 5)
        
        self.notebook = Gtk.Notebook()
        self.notebook.set_tab_pos(Gtk.PositionType.TOP)
        main_box.pack_start(self.notebook, True, True, 0)
        
        dashboard = self.create_dashboard_page()
        self.notebook.append_page(dashboard, Gtk.Label(label="📊 Dashboard"))
        
        repos_page = self.create_repos_page()
        self.notebook.append_page(repos_page, Gtk.Label(label="📁 Repositories"))
        
        pr_page = self.create_pr_page()
        self.notebook.append_page(pr_page, Gtk.Label(label="🔀 Pull Requests"))
        
        issues_page = self.create_issues_page()
        self.notebook.append_page(issues_page, Gtk.Label(label="🐛 Issues"))
        
        maintenance_page = self.create_maintenance_page()
        self.notebook.append_page(maintenance_page, Gtk.Label(label="🔧 Auto-Maintain"))
        
        activity_page = self.create_activity_page()
        self.notebook.append_page(activity_page, Gtk.Label(label="📜 Activity"))
        
        settings_page = self.create_settings_page()
        self.notebook.append_page(settings_page, Gtk.Label(label="⚙️ Settings"))
        
        self.status_bar = self.create_status_bar()
        main_box.pack_end(self.status_bar, False, False, 0)
    
    def create_header(self) -> Gtk.Box:
        """Create header bar"""
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header.get_style_context().add_class('header-bar')
        
        logo_label = Gtk.Label()
        logo_label.set_markup(
            '<span font="18" weight="bold" foreground="#cc0000">█▀█ </span>'
            '<span font="18" weight="bold" foreground="#ffffff">NULLSEC GITHUB BOT v2.0</span>'
            '<span font="18" weight="bold" foreground="#cc0000"> █▀█</span>'
        )
        header.pack_start(logo_label, False, False, 10)
        
        header.pack_start(Gtk.Box(), True, True, 0)
        
        self.user_label = Gtk.Label()
        self.user_label.set_markup('<span foreground="#00cc00">👤 Loading...</span>')
        header.pack_start(self.user_label, False, False, 10)
        
        self.notif_btn = Gtk.Button(label="🔔 0")
        self.notif_btn.connect("clicked", self.on_notif_clicked)
        header.pack_start(self.notif_btn, False, False, 5)
        
        refresh_btn = Gtk.Button(label="⟳ Refresh")
        refresh_btn.connect("clicked", lambda w: self.refresh_all())
        header.pack_start(refresh_btn, False, False, 5)
        
        self.time_label = Gtk.Label()
        self.time_label.set_markup(f'<span foreground="#888888">{datetime.now().strftime("%H:%M:%S")}</span>')
        header.pack_end(self.time_label, False, False, 10)
        
        GLib.timeout_add(1000, self.update_clock)
        
        return header
    
    def create_stats_bar(self) -> Gtk.Box:
        """Create stats bar"""
        stats_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        stats_bar.set_margin_start(10)
        stats_bar.set_margin_end(10)
        
        self.stat_repos = self.create_stat_widget("📁", "0", "Repos")
        self.stat_stars = self.create_stat_widget("⭐", "0", "Stars")
        self.stat_forks = self.create_stat_widget("🍴", "0", "Forks")
        self.stat_prs = self.create_stat_widget("🔀", "0", "Open PRs")
        self.stat_issues = self.create_stat_widget("🐛", "0", "Open Issues")
        self.stat_notifs = self.create_stat_widget("🔔", "0", "Notifications")
        
        stats_bar.pack_start(self.stat_repos, True, True, 0)
        stats_bar.pack_start(self.stat_stars, True, True, 0)
        stats_bar.pack_start(self.stat_forks, True, True, 0)
        stats_bar.pack_start(self.stat_prs, True, True, 0)
        stats_bar.pack_start(self.stat_issues, True, True, 0)
        stats_bar.pack_start(self.stat_notifs, True, True, 0)
        
        return stats_bar
    
    def create_stat_widget(self, icon: str, value: str, label: str) -> Gtk.Box:
        """Create a stat widget"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.get_style_context().add_class('stat-box')
        
        icon_label = Gtk.Label(label=icon)
        icon_label.set_markup(f'<span font="20">{icon}</span>')
        box.pack_start(icon_label, False, False, 5)
        
        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        
        value_label = Gtk.Label()
        value_label.set_markup(f'<span font="16" weight="bold" foreground="#cc0000">{value}</span>')
        value_label.set_halign(Gtk.Align.START)
        text_box.pack_start(value_label, False, False, 0)
        
        label_widget = Gtk.Label()
        label_widget.set_markup(f'<span foreground="#888888" font="10">{label}</span>')
        label_widget.set_halign(Gtk.Align.START)
        text_box.pack_start(label_widget, False, False, 0)
        
        box.pack_start(text_box, False, False, 0)
        box.value_label = value_label
        
        return box
    
    def update_stat(self, widget: Gtk.Box, value: str):
        """Update a stat widget value"""
        widget.value_label.set_markup(f'<span font="16" weight="bold" foreground="#cc0000">{value}</span>')
    
    def create_dashboard_page(self) -> Gtk.Box:
        """Create dashboard overview page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        priority_frame = Gtk.Frame(label=" 🌟 Priority Repositories ")
        self.priority_grid = Gtk.FlowBox()
        self.priority_grid.set_selection_mode(Gtk.SelectionMode.NONE)
        self.priority_grid.set_max_children_per_line(5)
        self.priority_grid.set_min_children_per_line(3)
        
        priority_scroll = Gtk.ScrolledWindow()
        priority_scroll.set_size_request(-1, 200)
        priority_scroll.add(self.priority_grid)
        priority_frame.add(priority_scroll)
        page.pack_start(priority_frame, False, False, 0)
        
        middle_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        activity_frame = Gtk.Frame(label=" 📜 Recent Activity ")
        self.dashboard_activity = Gtk.ListBox()
        self.dashboard_activity.set_selection_mode(Gtk.SelectionMode.NONE)
        activity_scroll = Gtk.ScrolledWindow()
        activity_scroll.add(self.dashboard_activity)
        activity_frame.add(activity_scroll)
        middle_box.pack_start(activity_frame, True, True, 0)
        
        pending_frame = Gtk.Frame(label=" ⏳ Pending Reviews ")
        self.dashboard_pending = Gtk.ListBox()
        self.dashboard_pending.set_selection_mode(Gtk.SelectionMode.SINGLE)
        pending_scroll = Gtk.ScrolledWindow()
        pending_scroll.add(self.dashboard_pending)
        pending_frame.add(pending_scroll)
        middle_box.pack_start(pending_frame, True, True, 0)
        
        page.pack_start(middle_box, True, True, 0)
        
        actions_frame = Gtk.Frame(label=" ⚡ Quick Actions ")
        actions_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        actions_box.set_margin_top(10)
        actions_box.set_margin_bottom(10)
        actions_box.set_margin_start(10)
        actions_box.set_margin_end(10)
        
        approve_all_btn = Gtk.Button(label="✓ Approve All PRs")
        approve_all_btn.get_style_context().add_class('approve-btn')
        approve_all_btn.connect("clicked", self.on_approve_all_prs)
        actions_box.pack_start(approve_all_btn, True, True, 0)
        
        mark_read_btn = Gtk.Button(label="📬 Mark All Read")
        mark_read_btn.connect("clicked", self.on_mark_all_read)
        actions_box.pack_start(mark_read_btn, True, True, 0)
        
        run_maintenance_btn = Gtk.Button(label="🔧 Run Maintenance")
        run_maintenance_btn.get_style_context().add_class('action-btn')
        run_maintenance_btn.connect("clicked", self.on_run_maintenance)
        actions_box.pack_start(run_maintenance_btn, True, True, 0)
        
        actions_frame.add(actions_box)
        page.pack_start(actions_frame, False, False, 0)
        
        return page
    
    def create_repos_page(self) -> Gtk.Box:
        """Create repositories management page"""
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        left_box.set_size_request(450, -1)
        
        filter_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        
        self.repo_search = Gtk.SearchEntry()
        self.repo_search.set_placeholder_text("Search repos...")
        self.repo_search.connect("search-changed", self.on_repo_search)
        filter_box.pack_start(self.repo_search, True, True, 0)
        
        self.repo_filter = Gtk.ComboBoxText()
        self.repo_filter.append_text("All")
        self.repo_filter.append_text("Original")
        self.repo_filter.append_text("Forks")
        self.repo_filter.append_text("Has Issues")
        self.repo_filter.set_active(0)
        self.repo_filter.connect("changed", self.on_repo_filter_changed)
        filter_box.pack_start(self.repo_filter, False, False, 0)
        
        left_box.pack_start(filter_box, False, False, 0)
        
        self.repo_listbox = Gtk.ListBox()
        self.repo_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.repo_listbox.connect("row-selected", self.on_repo_selected)
        
        repo_scroll = Gtk.ScrolledWindow()
        repo_scroll.add(self.repo_listbox)
        repo_scroll.get_style_context().add_class('panel')
        left_box.pack_start(repo_scroll, True, True, 0)
        
        page.pack_start(left_box, False, False, 0)
        
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_box.get_style_context().add_class('panel')
        right_box.set_margin_start(10)
        
        self.repo_detail_label = Gtk.Label()
        self.repo_detail_label.set_markup('<span font="14" foreground="#888888">Select a repository</span>')
        self.repo_detail_label.set_halign(Gtk.Align.START)
        self.repo_detail_label.set_line_wrap(True)
        self.repo_detail_label.set_margin_top(10)
        self.repo_detail_label.set_margin_start(10)
        right_box.pack_start(self.repo_detail_label, False, False, 0)
        
        self.repo_stats_grid = Gtk.Grid()
        self.repo_stats_grid.set_column_spacing(30)
        self.repo_stats_grid.set_row_spacing(10)
        self.repo_stats_grid.set_margin_top(10)
        self.repo_stats_grid.set_margin_start(10)
        right_box.pack_start(self.repo_stats_grid, False, False, 0)
        
        repo_actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        repo_actions.set_margin_top(20)
        repo_actions.set_margin_start(10)
        
        view_btn = Gtk.Button(label="👁 View on GitHub")
        view_btn.connect("clicked", self.on_view_repo)
        repo_actions.pack_start(view_btn, False, False, 0)
        
        clone_btn = Gtk.Button(label="📥 Clone")
        clone_btn.connect("clicked", self.on_clone_repo)
        repo_actions.pack_start(clone_btn, False, False, 0)
        
        self.sync_btn = Gtk.Button(label="🔄 Sync Fork")
        self.sync_btn.connect("clicked", self.on_sync_repo)
        repo_actions.pack_start(self.sync_btn, False, False, 0)
        
        right_box.pack_start(repo_actions, False, False, 0)
        
        repo_items_label = Gtk.Label()
        repo_items_label.set_markup('<span foreground="#888888" weight="bold">Open Items:</span>')
        repo_items_label.set_halign(Gtk.Align.START)
        repo_items_label.set_margin_top(20)
        repo_items_label.set_margin_start(10)
        right_box.pack_start(repo_items_label, False, False, 0)
        
        self.repo_items_list = Gtk.ListBox()
        self.repo_items_list.set_selection_mode(Gtk.SelectionMode.NONE)
        items_scroll = Gtk.ScrolledWindow()
        items_scroll.add(self.repo_items_list)
        right_box.pack_start(items_scroll, True, True, 0)
        
        page.pack_start(right_box, True, True, 0)
        
        return page
    
    def create_pr_page(self) -> Gtk.Box:
        """Create PR management page"""
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        left_box.set_size_request(500, -1)
        
        pr_header = Gtk.Label()
        pr_header.set_markup('<span font="14" weight="bold" foreground="#cc0000">🔀 OPEN PULL REQUESTS</span>')
        pr_header.set_halign(Gtk.Align.START)
        left_box.pack_start(pr_header, False, False, 5)
        
        self.pr_listbox = Gtk.ListBox()
        self.pr_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.pr_listbox.connect("row-selected", self.on_pr_selected)
        
        pr_scroll = Gtk.ScrolledWindow()
        pr_scroll.add(self.pr_listbox)
        pr_scroll.get_style_context().add_class('panel')
        left_box.pack_start(pr_scroll, True, True, 0)
        
        page.pack_start(left_box, False, False, 0)
        
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_box.get_style_context().add_class('panel')
        right_box.set_margin_start(10)
        
        self.pr_detail_label = Gtk.Label()
        self.pr_detail_label.set_markup('<span font="14" foreground="#888888">Select a PR to review</span>')
        self.pr_detail_label.set_halign(Gtk.Align.START)
        self.pr_detail_label.set_line_wrap(True)
        self.pr_detail_label.set_max_width_chars(60)
        self.pr_detail_label.set_margin_top(10)
        self.pr_detail_label.set_margin_start(10)
        right_box.pack_start(self.pr_detail_label, False, False, 0)
        
        self.pr_info_grid = Gtk.Grid()
        self.pr_info_grid.set_column_spacing(20)
        self.pr_info_grid.set_row_spacing(5)
        self.pr_info_grid.set_margin_top(10)
        self.pr_info_grid.set_margin_start(10)
        right_box.pack_start(self.pr_info_grid, False, False, 0)
        
        comment_label = Gtk.Label()
        comment_label.set_markup('<span foreground="#888888">Review Comment:</span>')
        comment_label.set_halign(Gtk.Align.START)
        comment_label.set_margin_top(15)
        comment_label.set_margin_start(10)
        right_box.pack_start(comment_label, False, False, 0)
        
        self.pr_comment = Gtk.TextView()
        self.pr_comment.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.pr_comment.get_buffer().set_text("LGTM! Thanks for the contribution. 🚀")
        
        comment_scroll = Gtk.ScrolledWindow()
        comment_scroll.set_size_request(-1, 100)
        comment_scroll.set_margin_start(10)
        comment_scroll.set_margin_end(10)
        comment_scroll.add(self.pr_comment)
        right_box.pack_start(comment_scroll, False, False, 0)
        
        action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        action_box.set_margin_top(10)
        action_box.set_margin_start(10)
        
        approve_btn = Gtk.Button(label="✓ Approve")
        approve_btn.get_style_context().add_class('approve-btn')
        approve_btn.connect("clicked", self.on_approve_pr)
        action_box.pack_start(approve_btn, True, True, 0)
        
        merge_btn = Gtk.Button(label="🔀 Merge")
        merge_btn.get_style_context().add_class('action-btn')
        merge_btn.connect("clicked", self.on_merge_pr)
        action_box.pack_start(merge_btn, True, True, 0)
        
        close_btn = Gtk.Button(label="✗ Close")
        close_btn.get_style_context().add_class('danger-btn')
        close_btn.connect("clicked", self.on_close_pr)
        action_box.pack_start(close_btn, True, True, 0)
        
        view_btn = Gtk.Button(label="👁 View")
        view_btn.connect("clicked", self.on_view_pr)
        action_box.pack_start(view_btn, True, True, 0)
        
        right_box.pack_start(action_box, False, False, 0)
        
        self.pr_log = Gtk.TextView()
        self.pr_log.set_editable(False)
        self.pr_log.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.pr_log.get_style_context().add_class('log-view')
        self.pr_log.set_margin_top(15)
        
        log_scroll = Gtk.ScrolledWindow()
        log_scroll.add(self.pr_log)
        right_box.pack_start(log_scroll, True, True, 0)
        
        page.pack_start(right_box, True, True, 0)
        
        return page
    
    def create_issues_page(self) -> Gtk.Box:
        """Create issues management page"""
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        left_box.set_size_request(500, -1)
        
        issue_header = Gtk.Label()
        issue_header.set_markup('<span font="14" weight="bold" foreground="#cc0000">🐛 OPEN ISSUES</span>')
        issue_header.set_halign(Gtk.Align.START)
        left_box.pack_start(issue_header, False, False, 5)
        
        self.issue_listbox = Gtk.ListBox()
        self.issue_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.issue_listbox.connect("row-selected", self.on_issue_selected)
        
        issue_scroll = Gtk.ScrolledWindow()
        issue_scroll.add(self.issue_listbox)
        issue_scroll.get_style_context().add_class('panel')
        left_box.pack_start(issue_scroll, True, True, 0)
        
        page.pack_start(left_box, False, False, 0)
        
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_box.get_style_context().add_class('panel')
        right_box.set_margin_start(10)
        
        self.issue_detail_label = Gtk.Label()
        self.issue_detail_label.set_markup('<span font="14" foreground="#888888">Select an issue</span>')
        self.issue_detail_label.set_halign(Gtk.Align.START)
        self.issue_detail_label.set_line_wrap(True)
        self.issue_detail_label.set_margin_top(10)
        self.issue_detail_label.set_margin_start(10)
        right_box.pack_start(self.issue_detail_label, False, False, 0)
        
        self.issue_comment = Gtk.TextView()
        self.issue_comment.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        
        comment_scroll = Gtk.ScrolledWindow()
        comment_scroll.set_size_request(-1, 150)
        comment_scroll.set_margin_start(10)
        comment_scroll.set_margin_end(10)
        comment_scroll.set_margin_top(15)
        comment_scroll.add(self.issue_comment)
        right_box.pack_start(comment_scroll, False, False, 0)
        
        action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        action_box.set_margin_top(10)
        action_box.set_margin_start(10)
        
        comment_btn = Gtk.Button(label="💬 Comment")
        comment_btn.connect("clicked", self.on_comment_issue)
        action_box.pack_start(comment_btn, True, True, 0)
        
        close_btn = Gtk.Button(label="✓ Close")
        close_btn.get_style_context().add_class('approve-btn')
        close_btn.connect("clicked", self.on_close_issue)
        action_box.pack_start(close_btn, True, True, 0)
        
        view_btn = Gtk.Button(label="👁 View")
        view_btn.connect("clicked", self.on_view_issue)
        action_box.pack_start(view_btn, True, True, 0)
        
        right_box.pack_start(action_box, False, False, 0)
        right_box.pack_start(Gtk.Box(), True, True, 0)
        
        page.pack_start(right_box, True, True, 0)
        
        return page
    
    def create_maintenance_page(self) -> Gtk.Box:
        """Create auto-maintenance page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header = Gtk.Label()
        header.set_markup('<span font="14" weight="bold" foreground="#cc0000">🔧 AUTO-MAINTENANCE</span>')
        header_box.pack_start(header, False, False, 0)
        
        header_box.pack_start(Gtk.Box(), True, True, 0)
        
        self.auto_maintain_switch = Gtk.Switch()
        self.auto_maintain_switch.set_active(self.config.get('auto_maintenance', {}).get('enabled', False))
        self.auto_maintain_switch.connect("notify::active", self.on_auto_maintain_toggled)
        
        switch_label = Gtk.Label(label="Auto-Maintenance:")
        header_box.pack_end(self.auto_maintain_switch, False, False, 0)
        header_box.pack_end(switch_label, False, False, 10)
        
        page.pack_start(header_box, False, False, 0)
        
        options_frame = Gtk.Frame(label=" Maintenance Options ")
        options_grid = Gtk.Grid()
        options_grid.set_column_spacing(30)
        options_grid.set_row_spacing(15)
        options_grid.set_margin_top(15)
        options_grid.set_margin_bottom(15)
        options_grid.set_margin_start(15)
        options_grid.set_margin_end(15)
        
        row = 0
        
        star_label = Gtk.Label(label="⭐ Star back users who star your repos:")
        star_label.set_halign(Gtk.Align.START)
        options_grid.attach(star_label, 0, row, 1, 1)
        
        self.star_back_switch = Gtk.Switch()
        self.star_back_switch.set_active(self.config.get('auto_maintenance', {}).get('star_back', True))
        options_grid.attach(self.star_back_switch, 1, row, 1, 1)
        row += 1
        
        follow_label = Gtk.Label(label="👤 Follow back users who follow you:")
        follow_label.set_halign(Gtk.Align.START)
        options_grid.attach(follow_label, 0, row, 1, 1)
        
        self.follow_back_switch = Gtk.Switch()
        self.follow_back_switch.set_active(self.config.get('auto_maintenance', {}).get('follow_back', True))
        options_grid.attach(self.follow_back_switch, 1, row, 1, 1)
        row += 1
        
        sync_label = Gtk.Label(label="🔄 Auto-sync forks with upstream:")
        sync_label.set_halign(Gtk.Align.START)
        options_grid.attach(sync_label, 0, row, 1, 1)
        
        self.sync_forks_switch = Gtk.Switch()
        self.sync_forks_switch.set_active(self.config.get('auto_maintenance', {}).get('sync_forks', False))
        options_grid.attach(self.sync_forks_switch, 1, row, 1, 1)
        row += 1
        
        bot_label = Gtk.Label(label="🤖 Auto-approve dependabot PRs:")
        bot_label.set_halign(Gtk.Align.START)
        options_grid.attach(bot_label, 0, row, 1, 1)
        
        self.auto_approve_switch = Gtk.Switch()
        self.auto_approve_switch.set_active(self.config.get('auto_maintenance', {}).get('auto_approve_bots', False))
        options_grid.attach(self.auto_approve_switch, 1, row, 1, 1)
        
        options_frame.add(options_grid)
        page.pack_start(options_frame, False, False, 0)
        
        run_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        run_btn = Gtk.Button(label="▶️ Run Maintenance Now")
        run_btn.get_style_context().add_class('action-btn')
        run_btn.connect("clicked", self.on_run_maintenance)
        run_box.pack_start(run_btn, False, False, 0)
        
        self.maintenance_status = Gtk.Label()
        self.maintenance_status.set_markup('<span foreground="#888888">Ready</span>')
        run_box.pack_start(self.maintenance_status, False, False, 10)
        
        page.pack_start(run_box, False, False, 10)
        
        log_frame = Gtk.Frame(label=" Maintenance Log ")
        
        self.maintenance_log = Gtk.TextView()
        self.maintenance_log.set_editable(False)
        self.maintenance_log.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.maintenance_log.get_style_context().add_class('log-view')
        
        log_scroll = Gtk.ScrolledWindow()
        log_scroll.add(self.maintenance_log)
        log_frame.add(log_scroll)
        page.pack_start(log_frame, True, True, 0)
        
        save_btn = Gtk.Button(label="💾 Save Settings")
        save_btn.connect("clicked", self.on_save_maintenance_settings)
        page.pack_start(save_btn, False, False, 0)
        
        return page
    
    def create_activity_page(self) -> Gtk.Box:
        """Create activity feed page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        header = Gtk.Label()
        header.set_markup('<span font="14" weight="bold" foreground="#cc0000">📜 RECENT ACTIVITY</span>')
        header.set_halign(Gtk.Align.START)
        page.pack_start(header, False, False, 5)
        
        self.activity_listbox = Gtk.ListBox()
        self.activity_listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        
        activity_scroll = Gtk.ScrolledWindow()
        activity_scroll.add(self.activity_listbox)
        activity_scroll.get_style_context().add_class('panel')
        page.pack_start(activity_scroll, True, True, 0)
        
        return page
    
    def create_settings_page(self) -> Gtk.Box:
        """Create settings page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        user_frame = Gtk.Frame(label=" GitHub Account ")
        user_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        user_box.set_margin_top(10)
        user_box.set_margin_bottom(10)
        user_box.set_margin_start(10)
        user_box.set_margin_end(10)
        
        user_label = Gtk.Label(label="Username:")
        user_box.pack_start(user_label, False, False, 0)
        
        self.username_entry = Gtk.Entry()
        self.username_entry.set_text(self.config.get('github_username', 'bad-antics'))
        user_box.pack_start(self.username_entry, True, True, 0)
        
        user_frame.add(user_box)
        page.pack_start(user_frame, False, False, 0)
        
        refresh_frame = Gtk.Frame(label=" Auto-Refresh ")
        refresh_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        refresh_box.set_margin_top(10)
        refresh_box.set_margin_bottom(10)
        refresh_box.set_margin_start(10)
        refresh_box.set_margin_end(10)
        
        refresh_label = Gtk.Label(label="Refresh interval (seconds):")
        refresh_box.pack_start(refresh_label, False, False, 0)
        
        self.refresh_spin = Gtk.SpinButton.new_with_range(30, 600, 30)
        self.refresh_spin.set_value(self.config.get('auto_refresh_interval', 120))
        refresh_box.pack_start(self.refresh_spin, False, False, 0)
        
        refresh_frame.add(refresh_box)
        page.pack_start(refresh_frame, False, False, 0)
        
        priority_frame = Gtk.Frame(label=" Priority Repositories ")
        priority_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        priority_box.set_margin_top(10)
        priority_box.set_margin_bottom(10)
        priority_box.set_margin_start(10)
        priority_box.set_margin_end(10)
        
        self.priority_textview = Gtk.TextView()
        self.priority_textview.set_wrap_mode(Gtk.WrapMode.WORD)
        buffer = self.priority_textview.get_buffer()
        buffer.set_text('\n'.join(self.config.get('priority_repos', [])))
        
        priority_scroll = Gtk.ScrolledWindow()
        priority_scroll.set_size_request(-1, 150)
        priority_scroll.add(self.priority_textview)
        priority_box.pack_start(priority_scroll, True, True, 0)
        
        hint = Gtk.Label()
        hint.set_markup('<span foreground="#888888" font="10">One repo name per line (without username/)</span>')
        hint.set_halign(Gtk.Align.START)
        priority_box.pack_start(hint, False, False, 0)
        
        priority_frame.add(priority_box)
        page.pack_start(priority_frame, False, False, 0)
        
        notif_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        notif_label = Gtk.Label(label="Desktop Notifications:")
        notif_box.pack_start(notif_label, False, False, 0)
        
        self.notif_switch = Gtk.Switch()
        self.notif_switch.set_active(self.config.get('notifications_enabled', True))
        notif_box.pack_start(self.notif_switch, False, False, 0)
        
        page.pack_start(notif_box, False, False, 0)
        
        save_btn = Gtk.Button(label="💾 Save Settings")
        save_btn.connect("clicked", self.on_save_settings)
        save_btn.set_margin_top(20)
        page.pack_start(save_btn, False, False, 0)
        
        page.pack_start(Gtk.Box(), True, True, 0)
        
        return page
    
    def create_status_bar(self) -> Gtk.Box:
        """Create status bar"""
        status_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        status_bar.set_margin_top(5)
        status_bar.set_margin_bottom(5)
        status_bar.set_margin_start(10)
        status_bar.set_margin_end(10)
        
        self.status_text = Gtk.Label()
        self.status_text.set_markup('<span foreground="#888888">Ready</span>')
        self.status_text.set_halign(Gtk.Align.START)
        status_bar.pack_start(self.status_text, True, True, 0)
        
        self.last_refresh_label = Gtk.Label()
        self.last_refresh_label.set_markup('<span foreground="#888888">Last refresh: Never</span>')
        status_bar.pack_end(self.last_refresh_label, False, False, 0)
        
        return status_bar
    
    def update_clock(self) -> bool:
        self.time_label.set_markup(f'<span foreground="#888888">{datetime.now().strftime("%H:%M:%S")}</span>')
        return True
    
    def start_auto_refresh(self):
        interval = self.config.get('auto_refresh_interval', 120) * 1000
        if self.refresh_timer:
            GLib.source_remove(self.refresh_timer)
        self.refresh_timer = GLib.timeout_add(interval, self.auto_refresh_tick)
    
    def auto_refresh_tick(self) -> bool:
        self.refresh_all()
        return True
    
    def refresh_all(self):
        self.set_status("Refreshing...")
        thread = threading.Thread(target=self._refresh_data)
        thread.daemon = True
        thread.start()
    
    def _refresh_data(self):
        try:
            user_info = self.github.get_user_info()
            repos = self.github.get_all_repos()
            prs = self.github.get_all_open_prs()
            issues = self.github.get_all_open_issues()
            notifs = self.github.get_notifications()
            activities = self.github.get_recent_activity()
            GLib.idle_add(self._update_ui, user_info, repos, prs, issues, notifs, activities)
        except Exception as e:
            GLib.idle_add(self.set_status, f"Error: {e}")
    
    def _update_ui(self, user_info, repos, prs, issues, notifs, activities):
        self.user_info = user_info
        self.all_repos = repos
        self.all_prs = prs
        self.all_issues = issues
        self.notifications = notifs
        self.activities = activities
        
        if user_info:
            self.user_label.set_markup(f'<span foreground="#00cc00">👤 {user_info.login}</span>')
        
        total_stars = sum(r.stars for r in repos if not r.is_fork)
        total_forks = sum(r.forks for r in repos if not r.is_fork)
        
        self.update_stat(self.stat_repos, str(len(repos)))
        self.update_stat(self.stat_stars, str(total_stars))
        self.update_stat(self.stat_forks, str(total_forks))
        self.update_stat(self.stat_prs, str(len(prs)))
        self.update_stat(self.stat_issues, str(len(issues)))
        self.update_stat(self.stat_notifs, str(len([n for n in notifs if n.get('unread')])))
        
        self.notif_btn.set_label(f"🔔 {len([n for n in notifs if n.get('unread')])}")
        
        self.update_repo_list()
        self.update_pr_list()
        self.update_issue_list()
        self.update_dashboard()
        self.update_activity_list()
        
        self.set_status(f"Loaded {len(repos)} repos, {len(prs)} PRs, {len(issues)} issues")
        self.last_refresh_label.set_markup(
            f'<span foreground="#888888">Last refresh: {datetime.now().strftime("%H:%M:%S")}</span>'
        )
        
        if self.config.get('notifications_enabled') and prs:
            pending = [pr for pr in prs if pr.review_state == 'PENDING' and pr.author != self.github.username]
            if pending:
                self.show_notification("PRs Need Review", f"{len(pending)} PR(s) pending review")
    
    def update_dashboard(self):
        for child in self.priority_grid.get_children():
            self.priority_grid.remove(child)
        
        priority_names = self.config.get('priority_repos', [])
        for repo in self.all_repos:
            if repo.name in priority_names:
                card = self.create_repo_card(repo)
                self.priority_grid.add(card)
        
        self.priority_grid.show_all()
        
        for child in self.dashboard_activity.get_children():
            self.dashboard_activity.remove(child)
        
        for activity in self.activities[:10]:
            row = self.create_activity_row(activity)
            self.dashboard_activity.add(row)
        
        self.dashboard_activity.show_all()
        
        for child in self.dashboard_pending.get_children():
            self.dashboard_pending.remove(child)
        
        pending = [pr for pr in self.all_prs if pr.review_state == 'PENDING' and not pr.draft]
        for pr in pending[:10]:
            row = self.create_pr_row(pr)
            self.dashboard_pending.add(row)
        
        self.dashboard_pending.show_all()
    
    def update_repo_list(self):
        for child in self.repo_listbox.get_children():
            self.repo_listbox.remove(child)
        
        search_text = self.repo_search.get_text().lower()
        filter_type = self.repo_filter.get_active_text()
        
        for repo in sorted(self.all_repos, key=lambda r: r.pushed_at or '', reverse=True):
            if search_text and search_text not in repo.name.lower():
                continue
            
            if filter_type == "Original" and repo.is_fork:
                continue
            elif filter_type == "Forks" and not repo.is_fork:
                continue
            elif filter_type == "Has Issues" and repo.open_issues == 0:
                continue
            
            row = self.create_repo_row(repo)
            self.repo_listbox.add(row)
        
        self.repo_listbox.show_all()
    
    def create_repo_card(self, repo: Repository) -> Gtk.FlowBoxChild:
        child = Gtk.FlowBoxChild()
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box.get_style_context().add_class('card')
        box.set_size_request(200, -1)
        
        name = Gtk.Label()
        name.set_markup(f'<span foreground="#cc0000" weight="bold">{repo.name}</span>')
        name.set_halign(Gtk.Align.START)
        name.set_ellipsize(Pango.EllipsizeMode.END)
        box.pack_start(name, False, False, 0)
        
        stats = Gtk.Label()
        stats.set_markup(f'<span foreground="#888888">⭐{repo.stars} 🍴{repo.forks} 🐛{repo.open_issues}</span>')
        stats.set_halign(Gtk.Align.START)
        box.pack_start(stats, False, False, 0)
        
        child.add(box)
        return child
    
    def create_repo_row(self, repo: Repository) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.repo = repo
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(10)
        box.set_margin_end(10)
        
        title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        name = Gtk.Label()
        fork_icon = "🍴 " if repo.is_fork else ""
        private_icon = "🔒 " if repo.is_private else ""
        name.set_markup(f'{fork_icon}{private_icon}<span foreground="#cc0000" weight="bold">{repo.name}</span>')
        name.set_halign(Gtk.Align.START)
        title_box.pack_start(name, True, True, 0)
        
        stats = Gtk.Label()
        stats.set_markup(f'<span foreground="#888888">⭐{repo.stars}</span>')
        title_box.pack_end(stats, False, False, 0)
        
        box.pack_start(title_box, False, False, 0)
        
        info = Gtk.Label()
        lang = repo.language or "Unknown"
        info.set_markup(f'<span foreground="#666666">{lang} • {self.format_time_ago(repo.pushed_at)}</span>')
        info.set_halign(Gtk.Align.START)
        box.pack_start(info, False, False, 0)
        
        row.add(box)
        return row
    
    def create_activity_row(self, activity: Activity) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.set_margin_top(5)
        box.set_margin_bottom(5)
        box.set_margin_start(10)
        box.set_margin_end(10)
        
        icons = {
            'Watch': '👁', 'Star': '⭐', 'Fork': '🍴', 'Push': '📤',
            'PullRequest': '🔀', 'Issues': '🐛', 'Create': '✨', 'Delete': '🗑'
        }
        icon = icons.get(activity.type, '📌')
        
        icon_label = Gtk.Label(label=icon)
        box.pack_start(icon_label, False, False, 0)
        
        text = Gtk.Label()
        text.set_markup(f'<span foreground="#e0e0e0">{activity.details}</span>')
        text.set_halign(Gtk.Align.START)
        text.set_ellipsize(Pango.EllipsizeMode.END)
        box.pack_start(text, True, True, 0)
        
        time_label = Gtk.Label()
        time_label.set_markup(f'<span foreground="#666666">{self.format_time_ago(activity.timestamp)}</span>')
        box.pack_end(time_label, False, False, 0)
        
        row.add(box)
        return row
    
    def update_pr_list(self):
        for child in self.pr_listbox.get_children():
            self.pr_listbox.remove(child)
        
        for pr in self.all_prs:
            row = self.create_pr_row(pr)
            self.pr_listbox.add(row)
        
        self.pr_listbox.show_all()
    
    def create_pr_row(self, pr: PullRequest) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.pr = pr
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(10)
        box.set_margin_end(10)
        
        if pr.review_state == 'APPROVED':
            status = '<span foreground="#00cc00">✓</span>'
        elif pr.review_state == 'CHANGES_REQUESTED':
            status = '<span foreground="#cc0000">✗</span>'
        else:
            status = '<span foreground="#cccc00">●</span>'
        
        title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        
        status_label = Gtk.Label()
        status_label.set_markup(status)
        title_box.pack_start(status_label, False, False, 0)
        
        title = Gtk.Label()
        draft = "[DRAFT] " if pr.draft else ""
        title.set_markup(f'<span foreground="#cc0000">#{pr.number}</span> {draft}{pr.title[:45]}{"..." if len(pr.title) > 45 else ""}')
        title.set_halign(Gtk.Align.START)
        title.set_ellipsize(Pango.EllipsizeMode.END)
        title_box.pack_start(title, True, True, 0)
        
        box.pack_start(title_box, False, False, 0)
        
        info = Gtk.Label()
        info.set_markup(f'<span foreground="#666666">{pr.repo} • by {pr.author}</span>')
        info.set_halign(Gtk.Align.START)
        box.pack_start(info, False, False, 0)
        
        row.add(box)
        return row
    
    def update_issue_list(self):
        for child in self.issue_listbox.get_children():
            self.issue_listbox.remove(child)
        
        for issue in self.all_issues:
            row = self.create_issue_row(issue)
            self.issue_listbox.add(row)
        
        self.issue_listbox.show_all()
    
    def create_issue_row(self, issue: Issue) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.issue = issue
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(10)
        box.set_margin_end(10)
        
        title = Gtk.Label()
        title.set_markup(f'<span foreground="#cc0000">#{issue.number}</span> {issue.title[:50]}{"..." if len(issue.title) > 50 else ""}')
        title.set_halign(Gtk.Align.START)
        box.pack_start(title, False, False, 0)
        
        info = Gtk.Label()
        info.set_markup(f'<span foreground="#666666">{issue.repo} • by {issue.author} • 💬{issue.comments}</span>')
        info.set_halign(Gtk.Align.START)
        box.pack_start(info, False, False, 0)
        
        row.add(box)
        return row
    
    def update_activity_list(self):
        for child in self.activity_listbox.get_children():
            self.activity_listbox.remove(child)
        
        for activity in self.activities:
            row = self.create_activity_row(activity)
            self.activity_listbox.add(row)
        
        self.activity_listbox.show_all()
    
    def on_repo_search(self, entry):
        self.update_repo_list()
    
    def on_repo_filter_changed(self, combo):
        self.update_repo_list()
    
    def on_repo_selected(self, listbox, row):
        if row is None:
            return
        
        repo = row.repo
        self.selected_repo = repo
        
        self.repo_detail_label.set_markup(
            f'<span font="14" foreground="#cc0000" weight="bold">{repo.name}</span>\n'
            f'<span foreground="#888888">{repo.description[:100] if repo.description else "No description"}</span>'
        )
        
        for child in self.repo_stats_grid.get_children():
            self.repo_stats_grid.remove(child)
        
        stats = [
            ("⭐ Stars:", str(repo.stars)),
            ("🍴 Forks:", str(repo.forks)),
            ("🐛 Issues:", str(repo.open_issues)),
            ("📝 Language:", repo.language),
            ("🔄 Updated:", self.format_time_ago(repo.pushed_at)),
            ("📦 Type:", "Fork" if repo.is_fork else "Original"),
        ]
        
        for i, (label, value) in enumerate(stats):
            l = Gtk.Label()
            l.set_markup(f'<span foreground="#888888">{label}</span>')
            l.set_halign(Gtk.Align.START)
            self.repo_stats_grid.attach(l, 0, i, 1, 1)
            
            v = Gtk.Label()
            v.set_markup(f'<span foreground="#e0e0e0">{value}</span>')
            v.set_halign(Gtk.Align.START)
            self.repo_stats_grid.attach(v, 1, i, 1, 1)
        
        self.repo_stats_grid.show_all()
        
        self.sync_btn.set_visible(repo.is_fork)
        
        self.load_repo_items(repo)
    
    def load_repo_items(self, repo: Repository):
        for child in self.repo_items_list.get_children():
            self.repo_items_list.remove(child)
        
        def fetch():
            prs = self.github.get_repo_prs(repo.full_name)
            issues = self.github.get_repo_issues(repo.full_name)
            GLib.idle_add(self._show_repo_items, prs, issues)
        
        threading.Thread(target=fetch, daemon=True).start()
    
    def _show_repo_items(self, prs, issues):
        for child in self.repo_items_list.get_children():
            self.repo_items_list.remove(child)
        
        for pr in prs:
            row = Gtk.ListBoxRow()
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            box.set_margin_top(5)
            box.set_margin_bottom(5)
            box.set_margin_start(10)
            
            label = Gtk.Label()
            label.set_markup(f'<span foreground="#3366ff">🔀 #{pr.number}</span> {pr.title[:40]}')
            label.set_halign(Gtk.Align.START)
            box.pack_start(label, True, True, 0)
            
            row.add(box)
            self.repo_items_list.add(row)
        
        for issue in issues:
            row = Gtk.ListBoxRow()
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            box.set_margin_top(5)
            box.set_margin_bottom(5)
            box.set_margin_start(10)
            
            label = Gtk.Label()
            label.set_markup(f'<span foreground="#00cc00">🐛 #{issue.number}</span> {issue.title[:40]}')
            label.set_halign(Gtk.Align.START)
            box.pack_start(label, True, True, 0)
            
            row.add(box)
            self.repo_items_list.add(row)
        
        if not prs and not issues:
            row = Gtk.ListBoxRow()
            label = Gtk.Label()
            label.set_markup('<span foreground="#888888">No open items</span>')
            label.set_margin_top(10)
            label.set_margin_bottom(10)
            row.add(label)
            self.repo_items_list.add(row)
        
        self.repo_items_list.show_all()
    
    def on_view_repo(self, button):
        if self.selected_repo:
            subprocess.run(['xdg-open', f'https://github.com/{self.selected_repo.full_name}'])
    
    def on_clone_repo(self, button):
        if self.selected_repo:
            subprocess.Popen(['gnome-terminal', '--', 'gh', 'repo', 'clone', self.selected_repo.full_name])
    
    def on_sync_repo(self, button):
        if self.selected_repo and self.selected_repo.is_fork:
            self.set_status(f"Syncing {self.selected_repo.name}...")
            
            def sync():
                success = self.github.sync_fork(self.selected_repo.full_name)
                GLib.idle_add(self.set_status, f"Sync {'succeeded' if success else 'failed'}")
            
            threading.Thread(target=sync, daemon=True).start()
    
    def on_pr_selected(self, listbox, row):
        if row is None:
            return
        
        pr = row.pr
        self.selected_pr = pr
        
        self.pr_detail_label.set_markup(
            f'<span font="14" foreground="#cc0000">#{pr.number}</span> '
            f'<span font="14" foreground="#ffffff">{pr.title}</span>'
        )
        
        for child in self.pr_info_grid.get_children():
            self.pr_info_grid.remove(child)
        
        items = [
            ("Repository:", pr.repo),
            ("Author:", pr.author),
            ("State:", pr.state),
            ("Review:", pr.review_state),
            ("Created:", self.format_time_ago(pr.created_at)),
        ]
        
        for i, (label, value) in enumerate(items):
            l = Gtk.Label()
            l.set_markup(f'<span foreground="#888888">{label}</span>')
            l.set_halign(Gtk.Align.START)
            self.pr_info_grid.attach(l, 0, i, 1, 1)
            
            v = Gtk.Label()
            v.set_markup(f'<span foreground="#e0e0e0">{value}</span>')
            v.set_halign(Gtk.Align.START)
            self.pr_info_grid.attach(v, 1, i, 1, 1)
        
        self.pr_info_grid.show_all()
        self.log_pr(f"Selected PR #{pr.number}")
    
    def on_approve_pr(self, button):
        if not self.selected_pr:
            return
        
        pr = self.selected_pr
        comment = self.get_pr_comment()
        
        self.log_pr(f"Approving PR #{pr.number}...")
        
        def approve():
            success = self.github.approve_pr(pr.repo, pr.number, comment)
            GLib.idle_add(self._handle_pr_action, success, f"Approved PR #{pr.number}" if success else f"Failed to approve PR #{pr.number}")
        
        threading.Thread(target=approve, daemon=True).start()
    
    def on_merge_pr(self, button):
        if not self.selected_pr:
            return
        
        pr = self.selected_pr
        self.log_pr(f"Merging PR #{pr.number}...")
        
        def merge():
            success = self.github.merge_pr(pr.repo, pr.number)
            GLib.idle_add(self._handle_pr_action, success, f"Merged PR #{pr.number}" if success else f"Failed to merge PR #{pr.number}")
        
        threading.Thread(target=merge, daemon=True).start()
    
    def on_close_pr(self, button):
        if not self.selected_pr:
            return
        
        pr = self.selected_pr
        self.log_pr(f"Closing PR #{pr.number}...")
        
        def close():
            success = self.github.close_pr(pr.repo, pr.number)
            GLib.idle_add(self._handle_pr_action, success, f"Closed PR #{pr.number}" if success else f"Failed to close PR #{pr.number}")
        
        threading.Thread(target=close, daemon=True).start()
    
    def on_view_pr(self, button):
        if self.selected_pr:
            subprocess.run(['xdg-open', f'https://github.com/{self.selected_pr.repo}/pull/{self.selected_pr.number}'])
    
    def _handle_pr_action(self, success, message):
        self.log_pr(f"{'✓' if success else '✗'} {message}")
        if success:
            self.refresh_all()
    
    def on_issue_selected(self, listbox, row):
        if row is None:
            return
        
        issue = row.issue
        self.selected_issue = issue
        
        self.issue_detail_label.set_markup(
            f'<span font="14" foreground="#cc0000">#{issue.number}</span> '
            f'<span font="14" foreground="#ffffff">{issue.title}</span>\n'
            f'<span foreground="#888888">{issue.repo} • by {issue.author}</span>'
        )
    
    def on_comment_issue(self, button):
        if not self.selected_issue:
            return
        
        issue = self.selected_issue
        buffer = self.issue_comment.get_buffer()
        start, end = buffer.get_bounds()
        comment = buffer.get_text(start, end, True)
        
        if not comment:
            return
        
        def add():
            success = self.github.add_comment(issue.repo, issue.number, comment, is_pr=False)
            GLib.idle_add(self.set_status, f"Comment {'added' if success else 'failed'}")
            if success:
                GLib.idle_add(buffer.set_text, "")
        
        threading.Thread(target=add, daemon=True).start()
    
    def on_close_issue(self, button):
        if not self.selected_issue:
            return
        
        issue = self.selected_issue
        buffer = self.issue_comment.get_buffer()
        start, end = buffer.get_bounds()
        comment = buffer.get_text(start, end, True)
        
        def close():
            success = self.github.close_issue(issue.repo, issue.number, comment)
            GLib.idle_add(self.set_status, f"Issue {'closed' if success else 'close failed'}")
            if success:
                GLib.idle_add(self.refresh_all)
        
        threading.Thread(target=close, daemon=True).start()
    
    def on_view_issue(self, button):
        if self.selected_issue:
            subprocess.run(['xdg-open', f'https://github.com/{self.selected_issue.repo}/issues/{self.selected_issue.number}'])
    
    def on_notif_clicked(self, button):
        self.notebook.set_current_page(5)
    
    def on_mark_all_read(self, button):
        self.set_status("Marking notifications read...")
        
        def mark():
            success = self.github.mark_notifications_read()
            GLib.idle_add(self.set_status, "Notifications marked read" if success else "Failed")
            if success:
                GLib.idle_add(self.refresh_all)
        
        threading.Thread(target=mark, daemon=True).start()
    
    def on_approve_all_prs(self, button):
        pending = [pr for pr in self.all_prs 
                   if pr.review_state == 'PENDING' 
                   and not pr.draft 
                   and pr.author != self.github.username]
        
        if not pending:
            self.set_status("No PRs to approve")
            return
        
        self.set_status(f"Approving {len(pending)} PRs...")
        
        def approve_all():
            for pr in pending:
                self.github.approve_pr(pr.repo, pr.number, "LGTM! 🚀")
                time.sleep(1)
            GLib.idle_add(self.set_status, f"Approved {len(pending)} PRs")
            GLib.idle_add(self.refresh_all)
        
        threading.Thread(target=approve_all, daemon=True).start()
    
    def on_auto_maintain_toggled(self, switch, gparam):
        enabled = switch.get_active()
        self.config['auto_maintenance']['enabled'] = enabled
        self.save_config()
        
        if enabled:
            self.start_maintenance_timer()
            self.log_maintenance("Auto-maintenance ENABLED")
        else:
            if self.maintenance_timer:
                GLib.source_remove(self.maintenance_timer)
                self.maintenance_timer = None
            self.log_maintenance("Auto-maintenance DISABLED")
    
    def start_maintenance_timer(self):
        if self.maintenance_timer:
            GLib.source_remove(self.maintenance_timer)
        self.maintenance_timer = GLib.timeout_add(300000, self.run_maintenance)
    
    def on_run_maintenance(self, button):
        self.run_maintenance()
    
    def run_maintenance(self) -> bool:
        if self.maintenance_running:
            return True
        
        self.maintenance_running = True
        self.maintenance_status.set_markup('<span foreground="#cccc00">Running...</span>')
        
        def do_maintenance():
            try:
                config = self.config.get('auto_maintenance', {})
                
                if config.get('follow_back'):
                    GLib.idle_add(self.log_maintenance, "Checking followers...")
                    followers = set(self.github.get_followers())
                    following = set(self.github.get_following())
                    to_follow = followers - following
                    
                    for user in list(to_follow)[:10]:
                        if self.github.follow_user(user):
                            GLib.idle_add(self.log_maintenance, f"✓ Followed back: {user}")
                        time.sleep(1)
                
                if config.get('sync_forks'):
                    GLib.idle_add(self.log_maintenance, "Syncing forks...")
                    for repo in self.all_repos:
                        if repo.is_fork:
                            if self.github.sync_fork(repo.full_name):
                                GLib.idle_add(self.log_maintenance, f"✓ Synced: {repo.name}")
                            time.sleep(2)
                
                if config.get('auto_approve_bots'):
                    GLib.idle_add(self.log_maintenance, "Checking bot PRs...")
                    for pr in self.all_prs:
                        if 'dependabot' in pr.author.lower() or 'bot' in pr.author.lower():
                            if pr.review_state == 'PENDING':
                                if self.github.approve_pr(pr.repo, pr.number, "Auto-approved bot PR 🤖"):
                                    GLib.idle_add(self.log_maintenance, f"✓ Auto-approved: {pr.repo}#{pr.number}")
                                time.sleep(1)
                
                GLib.idle_add(self._maintenance_complete)
                
            except Exception as e:
                GLib.idle_add(self.log_maintenance, f"Error: {e}")
                GLib.idle_add(self._maintenance_complete)
        
        threading.Thread(target=do_maintenance, daemon=True).start()
        return True
    
    def _maintenance_complete(self):
        self.maintenance_running = False
        self.maintenance_status.set_markup('<span foreground="#00cc00">Complete</span>')
        self.log_maintenance("Maintenance complete")
        self.refresh_all()
    
    def on_save_maintenance_settings(self, button):
        self.config['auto_maintenance'] = {
            'enabled': self.auto_maintain_switch.get_active(),
            'star_back': self.star_back_switch.get_active(),
            'follow_back': self.follow_back_switch.get_active(),
            'sync_forks': self.sync_forks_switch.get_active(),
            'auto_approve_bots': self.auto_approve_switch.get_active()
        }
        self.save_config()
        self.set_status("Maintenance settings saved")
    
    def on_save_settings(self, button):
        self.config['github_username'] = self.username_entry.get_text()
        self.config['auto_refresh_interval'] = int(self.refresh_spin.get_value())
        self.config['notifications_enabled'] = self.notif_switch.get_active()
        
        buffer = self.priority_textview.get_buffer()
        start, end = buffer.get_bounds()
        repos_text = buffer.get_text(start, end, True)
        self.config['priority_repos'] = [r.strip() for r in repos_text.split('\n') if r.strip()]
        
        self.save_config()
        self.github.username = self.config['github_username']
        self.start_auto_refresh()
        self.set_status("Settings saved")
        self.refresh_all()
    
    def get_pr_comment(self) -> str:
        buffer = self.pr_comment.get_buffer()
        start, end = buffer.get_bounds()
        return buffer.get_text(start, end, True)
    
    def set_status(self, message: str):
        self.status_text.set_markup(f'<span foreground="#888888">{message}</span>')
    
    def log_pr(self, message: str):
        buffer = self.pr_log.get_buffer()
        timestamp = datetime.now().strftime("%H:%M:%S")
        buffer.insert(buffer.get_end_iter(), f"[{timestamp}] {message}\n")
        mark = buffer.create_mark(None, buffer.get_end_iter(), False)
        self.pr_log.scroll_to_mark(mark, 0, False, 0, 0)
    
    def log_maintenance(self, message: str):
        buffer = self.maintenance_log.get_buffer()
        timestamp = datetime.now().strftime("%H:%M:%S")
        buffer.insert(buffer.get_end_iter(), f"[{timestamp}] {message}\n")
        mark = buffer.create_mark(None, buffer.get_end_iter(), False)
        self.maintenance_log.scroll_to_mark(mark, 0, False, 0, 0)
    
    def show_notification(self, title: str, body: str):
        if self.config.get('notifications_enabled'):
            notification = Notify.Notification.new(title, body, "dialog-information")
            notification.show()
    
    def format_time_ago(self, iso_time: str) -> str:
        if not iso_time:
            return "unknown"
        try:
            dt = datetime.fromisoformat(iso_time.replace('Z', '+00:00'))
            now = datetime.now(dt.tzinfo)
            diff = now - dt
            
            if diff.days > 30:
                return f"{diff.days // 30}mo ago"
            elif diff.days > 0:
                return f"{diff.days}d ago"
            elif diff.seconds > 3600:
                return f"{diff.seconds // 3600}h ago"
            elif diff.seconds > 60:
                return f"{diff.seconds // 60}m ago"
            else:
                return "just now"
        except:
            return iso_time[:10]
    
    def on_destroy(self, widget):
        if self.refresh_timer:
            GLib.source_remove(self.refresh_timer)
        if self.maintenance_timer:
            GLib.source_remove(self.maintenance_timer)
        Notify.uninit()
        Gtk.main_quit()


def main():
    try:
        result = subprocess.run(['gh', 'auth', 'status'], capture_output=True, text=True)
        if result.returncode != 0:
            print("Error: GitHub CLI not authenticated. Run 'gh auth login' first.")
            sys.exit(1)
    except FileNotFoundError:
        print("Error: GitHub CLI (gh) not found.")
        sys.exit(1)
    
    win = GitHubBotPanel()
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
