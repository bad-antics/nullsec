"""
NullSec Prompt Armor — AI Security Toolkit v2.0

8-layer defense system against prompt injection attacks:
  • prompt_armor.armor — Prompt injection detection and sanitization
  • prompt_armor.racer — AI race condition auditing
  • prompt_armor.pro — Compliance reports, custom rules, audit trails

Usage:
    from prompt_armor import analyze, sanitize, ThreatLevel
    verdict = analyze("user input here")
    if verdict.threat_level != ThreatLevel.CLEAN:
        cleaned = sanitize("user input here")

    # Multi-turn tracking
    from prompt_armor import ConversationTracker
    tracker = ConversationTracker()
    verdict = analyze("user input", conversation_tracker=tracker)
"""

from prompt_armor.armor.engine import (
    analyze,
    sanitize,
    lexical_scan,
    structural_scan,
    entropy_scan,
    semantic_drift_scan,
    indirect_injection_scan,
    language_evasion_scan,
    deobfuscation_scan,
    deobfuscate,
    armor_guard,
    ConversationTracker,
    CanarySystem,
    ArmorVerdict,
    Finding,
    ThreatLevel,
    AttackVector,
)

# Pro features
from prompt_armor.pro import (
    generate_compliance_report,
    ComplianceReport,
    RulesEngine,
    CustomRule,
    AuditTrail,
    AuditEntry,
    batch_scan,
)

__version__ = "2.0.0"

__all__ = [
    "analyze",
    "sanitize",
    "lexical_scan",
    "structural_scan",
    "entropy_scan",
    "semantic_drift_scan",
    "indirect_injection_scan",
    "language_evasion_scan",
    "deobfuscation_scan",
    "deobfuscate",
    "armor_guard",
    "ConversationTracker",
    "CanarySystem",
    "ArmorVerdict",
    "Finding",
    "ThreatLevel",
    "AttackVector",
    "__version__",
    # Pro features
    "generate_compliance_report",
    "ComplianceReport",
    "RulesEngine",
    "CustomRule",
    "AuditTrail",
    "AuditEntry",
    "batch_scan",
]
