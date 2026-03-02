"""
Core timestamp analysis engine.
Detects timestomping, future files, epoch artifacts, and other anomalies.
"""

import os
import stat
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional, Tuple


@dataclass
class TimestampInfo:
    """Timestamp details for a single file."""
    filepath: str
    atime: float       # access time
    mtime: float       # modification time
    ctime: float       # status change time (Unix) / creation time (Windows)
    size: int
    is_dir: bool
    anomalies: List[str] = field(default_factory=list)
    severity: str = "clean"  # clean, info, suspicious, critical


@dataclass
class ScanResult:
    """Result of scanning a directory for timestamp anomalies."""
    path: str
    total_files: int
    total_anomalies: int
    critical: int
    suspicious: int
    info: int
    files: List[TimestampInfo] = field(default_factory=list)
    clusters: List[dict] = field(default_factory=list)
    timeline_gaps: List[dict] = field(default_factory=list)


# Detection constants
UNIX_EPOCH = 0.0
WIN_EPOCH = -11644473600.0  # Jan 1, 1601 in Unix time
SUSPICIOUS_HOUR_START = 2   # 2 AM
SUSPICIOUS_HOUR_END = 5     # 5 AM
CLUSTER_THRESHOLD = 5       # files with identical timestamps
FUTURE_TOLERANCE = 300      # 5 minutes grace for clock skew


def check_file(filepath: str) -> TimestampInfo:
    """Analyze timestamps of a single file for anomalies."""
    try:
        st = os.stat(filepath)
    except (PermissionError, FileNotFoundError, OSError) as e:
        return TimestampInfo(
            filepath=filepath, atime=0, mtime=0, ctime=0,
            size=0, is_dir=False,
            anomalies=[f"Cannot stat: {e}"], severity="info"
        )

    info = TimestampInfo(
        filepath=filepath,
        atime=st.st_atime,
        mtime=st.st_mtime,
        ctime=st.st_ctime,
        size=st.st_size,
        is_dir=stat.S_ISDIR(st.st_mode),
    )

    now = time.time()
    anomalies = []

    # 1. Timestomping: mtime < ctime (modified before metadata changed)
    # On Linux, ctime is metadata change time, not creation
    # A file modified before its metadata was last changed could indicate tampering
    if info.mtime < info.ctime - 1.0:  # 1 second tolerance
        # This is actually normal on Linux when file content hasn't changed
        # but attributes have. Only flag if the gap is suspicious.
        gap = info.ctime - info.mtime
        if gap > 86400:  # More than 1 day difference
            anomalies.append(
                f"Timestomping candidate: mtime is {_format_delta(gap)} before ctime"
            )

    # 2. Future timestamps
    if info.mtime > now + FUTURE_TOLERANCE:
        delta = info.mtime - now
        anomalies.append(f"Future mtime: {_format_delta(delta)} ahead of current time")

    if info.atime > now + FUTURE_TOLERANCE:
        delta = info.atime - now
        anomalies.append(f"Future atime: {_format_delta(delta)} ahead of current time")

    if info.ctime > now + FUTURE_TOLERANCE:
        delta = info.ctime - now
        anomalies.append(f"Future ctime: {_format_delta(delta)} ahead of current time")

    # 3. Epoch artifacts
    if abs(info.mtime - UNIX_EPOCH) < 86400:  # Within 1 day of Unix epoch
        anomalies.append("mtime at Unix epoch (Jan 1, 1970) — likely reset or artifact")

    if abs(info.ctime - UNIX_EPOCH) < 86400:
        anomalies.append("ctime at Unix epoch (Jan 1, 1970) — likely reset or artifact")

    # 4. Ancient timestamps (before 2000 for modern systems)
    ancient_threshold = datetime(2000, 1, 1, tzinfo=timezone.utc).timestamp()
    if info.mtime < ancient_threshold and info.mtime > 86400:
        dt = datetime.fromtimestamp(info.mtime, tz=timezone.utc)
        anomalies.append(f"Ancient mtime: {dt.strftime('%Y-%m-%d')} — suspicious for modern file")

    # 5. Suspicious hours (2-5 AM local time)
    mtime_local = datetime.fromtimestamp(info.mtime)
    if SUSPICIOUS_HOUR_START <= mtime_local.hour < SUSPICIOUS_HOUR_END:
        anomalies.append(
            f"Modified at {mtime_local.strftime('%H:%M')} (unusual hours)"
        )

    # 6. Year 2038 problem vicinity
    if info.mtime > 2145916800:  # Jan 1, 2038
        anomalies.append("Timestamp near/past Y2038 — possible overflow artifact")

    # 7. Exact round timestamps (suspicious precision)
    if info.mtime > 0 and info.mtime % 3600 == 0:
        anomalies.append("mtime is exactly on the hour — possible manual timestamp")

    if info.mtime > 0 and info.mtime % 86400 == 0:
        anomalies.append("mtime is exactly at midnight — possible tool artifact")

    # Set severity
    info.anomalies = anomalies
    if any("Timestomping" in a or "Future" in a or "Ancient" in a for a in anomalies):
        info.severity = "critical"
    elif any("epoch" in a.lower() or "unusual" in a or "manual" in a for a in anomalies):
        info.severity = "suspicious"
    elif anomalies:
        info.severity = "info"

    return info


def scan_path(path: str, recursive: bool = False) -> ScanResult:
    """Scan a directory for timestamp anomalies."""
    files_info = []
    all_mtimes = []

    if os.path.isfile(path):
        info = check_file(path)
        files_info.append(info)
    elif os.path.isdir(path):
        if recursive:
            for root, dirs, fnames in os.walk(path):
                for f in fnames:
                    fp = os.path.join(root, f)
                    info = check_file(fp)
                    files_info.append(info)
                    all_mtimes.append((info.mtime, fp))
        else:
            for entry in os.listdir(path):
                fp = os.path.join(path, entry)
                if os.path.isfile(fp):
                    info = check_file(fp)
                    files_info.append(info)
                    all_mtimes.append((info.mtime, fp))

    # Cluster detection — files with identical timestamps
    clusters = _detect_clusters(files_info)

    # Timeline gap detection
    gaps = _detect_gaps(all_mtimes)

    # Count severities
    critical = sum(1 for f in files_info if f.severity == "critical")
    suspicious = sum(1 for f in files_info if f.severity == "suspicious")
    info_count = sum(1 for f in files_info if f.severity == "info")
    total_anomalies = sum(1 for f in files_info if f.anomalies)

    return ScanResult(
        path=path,
        total_files=len(files_info),
        total_anomalies=total_anomalies,
        critical=critical,
        suspicious=suspicious,
        info=info_count,
        files=files_info,
        clusters=clusters,
        timeline_gaps=gaps,
    )


def build_timeline(path: str, recursive: bool = True,
                   last_seconds: Optional[float] = None) -> List[dict]:
    """Build a chronological timeline of file modifications."""
    entries = []
    cutoff = time.time() - last_seconds if last_seconds else 0

    def process(fp):
        try:
            st = os.stat(fp)
            if st.st_mtime >= cutoff:
                entries.append({
                    "time": st.st_mtime,
                    "datetime": datetime.fromtimestamp(
                        st.st_mtime, tz=timezone.utc
                    ).isoformat(),
                    "file": fp,
                    "size": st.st_size,
                    "type": "dir" if stat.S_ISDIR(st.st_mode) else "file",
                })
        except (PermissionError, OSError):
            pass

    if os.path.isfile(path):
        process(path)
    elif os.path.isdir(path):
        if recursive:
            for root, dirs, fnames in os.walk(path):
                for f in fnames:
                    process(os.path.join(root, f))
        else:
            for entry in os.listdir(path):
                process(os.path.join(path, entry))

    return sorted(entries, key=lambda e: e["time"])


def _detect_clusters(files: List[TimestampInfo]) -> List[dict]:
    """Find groups of files with identical timestamps."""
    mtime_groups = defaultdict(list)
    for f in files:
        # Round to second for clustering
        key = int(f.mtime)
        mtime_groups[key].append(f.filepath)

    clusters = []
    for ts, paths in mtime_groups.items():
        if len(paths) >= CLUSTER_THRESHOLD:
            clusters.append({
                "timestamp": ts,
                "datetime": datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(),
                "count": len(paths),
                "files": paths[:20],  # cap display
            })

    return sorted(clusters, key=lambda c: c["count"], reverse=True)


def _detect_gaps(mtimes: List[Tuple[float, str]]) -> List[dict]:
    """Detect suspicious gaps in file modification timeline."""
    if len(mtimes) < 3:
        return []

    sorted_times = sorted(mtimes, key=lambda x: x[0])
    gaps = []

    # Calculate median inter-file gap
    deltas = []
    for i in range(1, len(sorted_times)):
        delta = sorted_times[i][0] - sorted_times[i - 1][0]
        if delta > 0:
            deltas.append(delta)

    if not deltas:
        return []

    deltas.sort()
    median = deltas[len(deltas) // 2]
    threshold = max(median * 10, 86400 * 7)  # 10x median or 7 days

    for i in range(1, len(sorted_times)):
        delta = sorted_times[i][0] - sorted_times[i - 1][0]
        if delta > threshold:
            gaps.append({
                "gap_seconds": delta,
                "gap_human": _format_delta(delta),
                "before": {
                    "file": sorted_times[i - 1][1],
                    "time": datetime.fromtimestamp(
                        sorted_times[i - 1][0], tz=timezone.utc
                    ).isoformat(),
                },
                "after": {
                    "file": sorted_times[i][1],
                    "time": datetime.fromtimestamp(
                        sorted_times[i][0], tz=timezone.utc
                    ).isoformat(),
                },
            })

    return gaps


def _format_delta(seconds: float) -> str:
    """Format a time delta into human-readable string."""
    seconds = abs(seconds)
    if seconds < 60:
        return f"{seconds:.0f}s"
    elif seconds < 3600:
        return f"{seconds / 60:.0f}m"
    elif seconds < 86400:
        return f"{seconds / 3600:.1f}h"
    elif seconds < 86400 * 365:
        return f"{seconds / 86400:.0f}d"
    else:
        return f"{seconds / (86400 * 365):.1f}y"
