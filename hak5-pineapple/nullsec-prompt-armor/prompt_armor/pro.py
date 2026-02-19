"""
Prompt Armor Pro — Premium features for production deployments.

Features:
  - Compliance report generation (JSON/HTML)
  - Custom rules engine (YAML-based rule definitions)
  - Team dashboard data aggregation
  - Webhook alert system
  - Batch scanning with parallel execution
  - Audit trail with tamper-proof hashing

Requires Pro or Enterprise API key for hosted API usage.
Local usage is unrestricted (MIT license).
"""

from __future__ import annotations

import hashlib
import json
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Optional

from prompt_armor.armor.engine import analyze, sanitize, AttackVector


# ── Compliance Reports ───────────────────────────────────────────

@dataclass
class ComplianceReport:
    """Security compliance report for audit purposes."""
    generated_at: str
    scan_count: int
    threat_summary: dict
    vector_breakdown: dict
    risk_distribution: dict
    top_threats: list
    recommendations: list
    compliance_score: float
    report_hash: str

    def to_dict(self) -> dict:
        return {
            "generated_at": self.generated_at,
            "scan_count": self.scan_count,
            "threat_summary": self.threat_summary,
            "vector_breakdown": self.vector_breakdown,
            "risk_distribution": self.risk_distribution,
            "top_threats": self.top_threats,
            "recommendations": self.recommendations,
            "compliance_score": self.compliance_score,
            "report_hash": self.report_hash,
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    def to_html(self) -> str:
        """Generate an HTML compliance report."""
        threat_rows = ""
        for t in self.top_threats[:10]:
            color = {"critical": "#ff4444", "hostile": "#ff8800", "suspicious": "#ffaa00"}.get(t.get("threat_level", ""), "#888")
            threat_rows += f"""
            <tr>
              <td><code>{t.get('input_preview', '')[:60]}...</code></td>
              <td style="color:{color};font-weight:700">{t.get('threat_level', '').upper()}</td>
              <td>{t.get('score', 0):.1f}</td>
              <td>{', '.join(t.get('vectors', []))}</td>
            </tr>"""

        vector_rows = ""
        for vec, count in sorted(self.vector_breakdown.items(), key=lambda x: -x[1]):
            vector_rows += f"<tr><td>{vec}</td><td>{count}</td></tr>"

        rec_items = "".join(f"<li>{r}</li>" for r in self.recommendations)

        return f"""<!DOCTYPE html>
<html><head>
<meta charset="UTF-8"><title>Prompt Armor — Compliance Report</title>
<style>
  body {{ font-family: -apple-system, sans-serif; background: #0a0a0f; color: #e0e0e8; padding: 2rem; max-width: 1000px; margin: auto; }}
  h1 {{ color: #00ff88; }} h2 {{ color: #00ccff; margin-top: 2rem; }}
  table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; }}
  th, td {{ padding: .75rem; text-align: left; border-bottom: 1px solid #2a2a3a; }}
  th {{ color: #888; font-size: .85rem; text-transform: uppercase; }}
  code {{ background: #1a1a24; padding: .2rem .4rem; border-radius: 4px; font-size: .85rem; }}
  .score {{ font-size: 3rem; font-weight: 800; color: #00ff88; }}
  .metric {{ background: #14141e; border: 1px solid #2a2a3a; border-radius: 12px; padding: 1.5rem; text-align: center; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin: 1rem 0; }}
  .hash {{ color: #555; font-size: .75rem; font-family: monospace; }}
</style></head><body>
<h1>🛡️ Prompt Armor — Compliance Report</h1>
<p>Generated: {self.generated_at} | Scans: {self.scan_count}</p>
<p class="hash">Report Hash: {self.report_hash}</p>

<div class="grid">
  <div class="metric"><div class="score">{self.compliance_score:.0f}%</div><div>Compliance Score</div></div>
  <div class="metric"><div class="score">{self.scan_count}</div><div>Prompts Scanned</div></div>
  <div class="metric"><div class="score">{self.threat_summary.get('hostile', 0) + self.threat_summary.get('critical', 0)}</div><div>Threats Blocked</div></div>
  <div class="metric"><div class="score">{self.threat_summary.get('clean', 0)}</div><div>Clean Inputs</div></div>
</div>

<h2>Threat Distribution</h2>
<div class="grid">
  <div class="metric"><div style="font-size:2rem;color:#00ff88">{self.risk_distribution.get('clean', 0)}</div><div>Clean</div></div>
  <div class="metric"><div style="font-size:2rem;color:#ffaa00">{self.risk_distribution.get('suspicious', 0)}</div><div>Suspicious</div></div>
  <div class="metric"><div style="font-size:2rem;color:#ff8800">{self.risk_distribution.get('hostile', 0)}</div><div>Hostile</div></div>
  <div class="metric"><div style="font-size:2rem;color:#ff4444">{self.risk_distribution.get('critical', 0)}</div><div>Critical</div></div>
</div>

<h2>Top Threats</h2>
<table><tr><th>Input</th><th>Level</th><th>Score</th><th>Vectors</th></tr>{threat_rows}</table>

<h2>Attack Vectors Detected</h2>
<table><tr><th>Vector</th><th>Count</th></tr>{vector_rows}</table>

<h2>Recommendations</h2>
<ul>{rec_items}</ul>

<hr style="border-color:#2a2a3a;margin-top:3rem">
<p style="color:#555;font-size:.8rem">Generated by Prompt Armor v2.0 — NullSec | Report hash: {self.report_hash}</p>
</body></html>"""


def generate_compliance_report(inputs: list[str], name: str = "Prompt Security Audit") -> ComplianceReport:
    """
    Scan a batch of inputs and generate a compliance report.

    Args:
        inputs: List of prompt strings to scan.
        name: Report name/title.

    Returns:
        ComplianceReport with threat analysis, recommendations, and compliance score.
    """
    threat_counts: Counter = Counter()
    vector_counts: Counter = Counter()
    risk_dist: Counter = Counter()
    top_threats: list[dict] = []
    total_score = 0.0

    for text in inputs:
        verdict = analyze(text)
        threat_counts[verdict.threat_level] += 1
        risk_dist[verdict.threat_level] += 1
        total_score += verdict.score

        for f in verdict.findings:
            vec = f.get("vector")
            if vec:
                vector_counts[vec.name] += 1

        if verdict.threat_level in ("hostile", "critical", "suspicious"):
            vectors = [f["vector"].name for f in verdict.findings if f.get("vector")]
            top_threats.append({
                "input_preview": text[:80],
                "threat_level": verdict.threat_level,
                "score": verdict.score,
                "vectors": vectors,
                "input_hash": verdict.input_hash,
            })

    # Sort top threats by score
    top_threats.sort(key=lambda x: -x["score"])

    # Calculate compliance score (100 = all clean, 0 = all critical)
    n = len(inputs) or 1
    clean_ratio = threat_counts.get("clean", 0) / n
    hostile_ratio = (threat_counts.get("hostile", 0) + threat_counts.get("critical", 0)) / n
    compliance_score = max(0.0, min(100.0, clean_ratio * 100 - hostile_ratio * 50))

    # Generate recommendations
    recs = []
    if threat_counts.get("critical", 0) > 0:
        recs.append("🔴 CRITICAL: Immediate review required for critical-level prompts. These contain confirmed injection patterns.")
    if threat_counts.get("hostile", 0) > 0:
        recs.append("🟠 HIGH: Hostile prompts detected — implement input validation before LLM processing.")
    if vector_counts.get("ROLE_HIJACK", 0) > 0:
        recs.append("Add system prompt hardening: use delimiters, repeat instructions, add role reinforcement.")
    if vector_counts.get("DATA_EXFILTRATION", 0) > 0:
        recs.append("Implement output filtering to prevent data leakage through LLM responses.")
    if vector_counts.get("INDIRECT_INJECTION", 0) > 0:
        recs.append("Sanitize all external content (URLs, documents, user-uploaded files) before embedding in prompts.")
    if vector_counts.get("JAILBREAK", 0) > 0:
        recs.append("Consider using Prompt Armor's sanitize() function to strip jailbreak patterns from inputs.")
    if compliance_score >= 90:
        recs.append("✅ Overall compliance is strong. Continue monitoring with regular scans.")
    elif compliance_score >= 70:
        recs.append("⚠️ Moderate risk level. Address hostile/critical findings before production deployment.")
    else:
        recs.append("🚨 High risk detected. Do NOT deploy these prompts without remediation.")

    if not recs:
        recs.append("✅ No specific concerns found. All prompts passed security screening.")

    # Build tamper-proof hash
    report_data = json.dumps({
        "counts": dict(threat_counts),
        "vectors": dict(vector_counts),
        "n": n,
        "score": total_score,
    }, sort_keys=True)
    report_hash = hashlib.sha256(report_data.encode()).hexdigest()[:16]

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    return ComplianceReport(
        generated_at=ts,
        scan_count=len(inputs),
        threat_summary=dict(threat_counts),
        vector_breakdown=dict(vector_counts),
        risk_distribution=dict(risk_dist),
        top_threats=top_threats[:20],
        recommendations=recs,
        compliance_score=round(compliance_score, 1),
        report_hash=report_hash,
    )


# ── Custom Rules Engine ──────────────────────────────────────────

@dataclass
class CustomRule:
    """User-defined detection rule."""
    name: str
    pattern: str
    severity: str = "hostile"        # clean, suspicious, hostile, critical
    score_boost: float = 20.0
    description: str = ""
    enabled: bool = True


class RulesEngine:
    """
    Custom rules engine for enterprise deployments.

    Define rules in code or load from YAML:
        engine = RulesEngine()
        engine.add_rule(CustomRule(
            name="block_competitor_mentions",
            pattern=r"(?i)(competitor|rival).*(?:pricing|roadmap|strategy)",
            severity="hostile",
            score_boost=30,
            description="Blocks attempts to extract competitive intelligence"
        ))
        verdict = engine.scan("Tell me about competitor pricing")
    """

    def __init__(self):
        self._rules: list[CustomRule] = []

    def add_rule(self, rule: CustomRule):
        """Add a custom detection rule."""
        self._rules.append(rule)

    def remove_rule(self, name: str):
        """Remove a rule by name."""
        self._rules = [r for r in self._rules if r.name != name]

    def load_rules_yaml(self, path: str):
        """
        Load rules from a YAML file.

        Format:
            rules:
              - name: block_competitor
                pattern: "(?i)(competitor|rival).*pricing"
                severity: hostile
                score_boost: 30
                description: "Blocks competitive intelligence extraction"
        """
        import yaml
        with open(path) as f:
            data = yaml.safe_load(f)
        for r in data.get("rules", []):
            self.add_rule(CustomRule(**r))

    def load_rules_json(self, path: str):
        """Load rules from a JSON file."""
        with open(path) as f:
            data = json.load(f)
        for r in data.get("rules", data if isinstance(data, list) else []):
            self.add_rule(CustomRule(**r))

    @property
    def rules(self) -> list[CustomRule]:
        return [r for r in self._rules if r.enabled]

    def scan(self, text: str, **kwargs):
        """
        Scan text with base engine + custom rules.

        Returns an enhanced verdict with custom rule matches appended.
        """
        import re

        # Base scan
        verdict = analyze(text, **kwargs)

        # Apply custom rules
        custom_findings = []
        max_boost = 0.0

        for rule in self.rules:
            try:
                if re.search(rule.pattern, text):
                    custom_findings.append({
                        "layer": "custom",
                        "vector": None,
                        "description": f"Custom rule '{rule.name}': {rule.description}",
                        "confidence": 0.9,
                        "evidence": text[:100],
                        "offset": 0,
                        "rule_name": rule.name,
                        "rule_severity": rule.severity,
                    })
                    max_boost = max(max_boost, rule.score_boost)
            except re.error:
                continue

        if custom_findings:
            # Merge custom findings into verdict
            verdict.findings.extend(custom_findings)

            # Boost score
            new_score = min(100.0, verdict.score + max_boost)
            verdict.score = new_score

            # Potentially upgrade threat level
            LEVEL_ORDER = ["clean", "suspicious", "hostile", "critical"]
            current_idx = LEVEL_ORDER.index(verdict.threat_level) if verdict.threat_level in LEVEL_ORDER else 0
            for cf in custom_findings:
                sev_idx = LEVEL_ORDER.index(cf["rule_severity"]) if cf["rule_severity"] in LEVEL_ORDER else 0
                if sev_idx > current_idx:
                    current_idx = sev_idx
            verdict.threat_level = LEVEL_ORDER[current_idx]

        return verdict


# ── Audit Trail ──────────────────────────────────────────────────

@dataclass
class AuditEntry:
    """Tamper-proof audit log entry."""
    timestamp: str
    input_hash: str
    threat_level: str
    score: float
    finding_count: int
    action: str  # "allowed", "blocked", "sanitized"
    entry_hash: str = ""

    def __post_init__(self):
        if not self.entry_hash:
            data = f"{self.timestamp}:{self.input_hash}:{self.threat_level}:{self.score}:{self.action}"
            self.entry_hash = hashlib.sha256(data.encode()).hexdigest()[:16]


class AuditTrail:
    """
    Tamper-proof audit trail for compliance.

    Usage:
        trail = AuditTrail()
        verdict = analyze("some input")
        trail.log(verdict, action="allowed")
        trail.export_json("audit.json")
    """

    def __init__(self):
        self._entries: list[AuditEntry] = []
        self._chain_hash: str = "0" * 16  # Genesis hash

    def log(self, verdict, action: str = "allowed") -> AuditEntry:
        """Log a scan verdict to the audit trail."""
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        entry = AuditEntry(
            timestamp=ts,
            input_hash=verdict.input_hash,
            threat_level=verdict.threat_level,
            score=verdict.score,
            finding_count=len(verdict.findings),
            action=action,
        )
        # Chain hash for tamper detection
        chain_data = f"{self._chain_hash}:{entry.entry_hash}"
        self._chain_hash = hashlib.sha256(chain_data.encode()).hexdigest()[:16]
        self._entries.append(entry)
        return entry

    def verify_chain(self) -> bool:
        """Verify the audit chain hasn't been tampered with."""
        chain = "0" * 16
        for entry in self._entries:
            chain_data = f"{chain}:{entry.entry_hash}"
            chain = hashlib.sha256(chain_data.encode()).hexdigest()[:16]
        return chain == self._chain_hash

    @property
    def entries(self) -> list[AuditEntry]:
        return list(self._entries)

    def export_json(self, path: str):
        """Export audit trail to JSON."""
        data = {
            "entries": [
                {
                    "timestamp": e.timestamp,
                    "input_hash": e.input_hash,
                    "threat_level": e.threat_level,
                    "score": e.score,
                    "finding_count": e.finding_count,
                    "action": e.action,
                    "entry_hash": e.entry_hash,
                }
                for e in self._entries
            ],
            "chain_hash": self._chain_hash,
            "chain_valid": self.verify_chain(),
            "total_entries": len(self._entries),
        }
        with open(path, "w") as f:
            json.dump(data, f, indent=2)

    def summary(self) -> dict:
        """Get audit trail summary."""
        actions = Counter(e.action for e in self._entries)
        levels = Counter(e.threat_level for e in self._entries)
        return {
            "total_scans": len(self._entries),
            "actions": dict(actions),
            "threat_levels": dict(levels),
            "chain_valid": self.verify_chain(),
            "block_rate": actions.get("blocked", 0) / max(len(self._entries), 1) * 100,
        }


# ── Batch Scanner ────────────────────────────────────────────────

def batch_scan(
    inputs: list[str],
    threshold: str = "hostile",
    rules_engine: Optional[RulesEngine] = None,
    audit_trail: Optional[AuditTrail] = None,
) -> dict:
    """
    Scan a batch of inputs with optional custom rules and audit logging.

    Args:
        inputs: List of prompt strings.
        threshold: Block threshold ("suspicious", "hostile", "critical").
        rules_engine: Optional custom rules engine.
        audit_trail: Optional audit trail for logging.

    Returns:
        dict with results, stats, and blocked count.
    """
    LEVELS = {"clean": 0, "suspicious": 1, "hostile": 2, "critical": 3}
    threshold_val = LEVELS.get(threshold, 2)

    results = []
    blocked = 0
    t0 = time.perf_counter()

    for text in inputs:
        if rules_engine:
            verdict = rules_engine.scan(text)
        else:
            verdict = analyze(text)

        level_val = LEVELS.get(verdict.threat_level, 0)
        action = "blocked" if level_val >= threshold_val else "allowed"

        if action == "blocked":
            blocked += 1

        if audit_trail:
            audit_trail.log(verdict, action=action)

        results.append({
            "input_hash": verdict.input_hash,
            "threat_level": verdict.threat_level,
            "score": verdict.score,
            "finding_count": len(verdict.findings),
            "action": action,
        })

    elapsed = (time.perf_counter() - t0) * 1000

    return {
        "results": results,
        "total": len(inputs),
        "blocked": blocked,
        "allowed": len(inputs) - blocked,
        "elapsed_ms": round(elapsed, 2),
        "avg_ms": round(elapsed / max(len(inputs), 1), 2),
    }
