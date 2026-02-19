"""
NullSec Prompt Armor — AI Prompt Injection Defense Toolkit

A multi-layered defense system that detects, classifies, and neutralizes
prompt injection attacks against LLM-powered applications.

Detection layers:
  1. Lexical analysis      — pattern matching against known injection signatures
  2. Structural analysis   — detects role hijacking, delimiter escapes, instruction overrides
  3. Entropy analysis      — flags abnormal token distributions (encoded payloads)
  4. Semantic drift        — measures how far user input drifts from expected topic
  5. Canary traps          — hidden markers that detect if the model was manipulated
  6. Multi-turn memory     — tracks escalation patterns across conversation turns
  7. Indirect injection    — detects payloads hidden in data the model reads (URLs, files, tool output)
  8. Language evasion      — catches cross-lingual attacks, homoglyphs, leetspeak, reversed text

Author: bad-antics / NullSec
License: MIT
"""

import re
import math
import json
import hashlib
import logging
import time
import base64
import codecs
import unicodedata
from collections import Counter
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Any, Optional, Tuple
from enum import Enum
from pathlib import Path

logger = logging.getLogger("prompt-armor")

# ═══════════════════════════════════════════════════════════════════════════════
# Threat Classification
# ═══════════════════════════════════════════════════════════════════════════════


class ThreatLevel(str, Enum):
    CLEAN = "clean"
    SUSPICIOUS = "suspicious"
    HOSTILE = "hostile"
    CRITICAL = "critical"


class AttackVector(str, Enum):
    ROLE_HIJACK = "role_hijack"
    INSTRUCTION_OVERRIDE = "instruction_override"
    DELIMITER_ESCAPE = "delimiter_escape"
    CONTEXT_MANIPULATION = "context_manipulation"
    DATA_EXFILTRATION = "data_exfiltration"
    JAILBREAK = "jailbreak"
    PAYLOAD_SMUGGLE = "payload_smuggle"
    CANARY_TRIGGER = "canary_trigger"
    ENCODING_ATTACK = "encoding_attack"
    MULTI_TURN_ESCALATION = "multi_turn_escalation"
    INDIRECT_INJECTION = "indirect_injection"
    TOOL_ABUSE = "tool_abuse"
    IMAGE_INJECTION = "image_injection"
    LANGUAGE_EVASION = "language_evasion"
    VIRTUALIZATION = "virtualization"
    HOMOGLYPH_ATTACK = "homoglyph_attack"
    CHAIN_OF_THOUGHT_HIJACK = "chain_of_thought_hijack"


@dataclass
class Finding:
    vector: str
    confidence: float       # 0.0 — 1.0
    evidence: str           # the matched pattern or metric
    description: str
    layer: str              # which detection layer caught it
    offset: int = -1        # character position in input


@dataclass
class ArmorVerdict:
    threat_level: str
    score: float            # composite risk score 0 — 100
    findings: List[Finding] = field(default_factory=list)
    sanitized: str = ""     # cleaned version of the input
    processing_ms: float = 0
    input_hash: str = ""
    canary_intact: bool = True


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 1: Lexical Signature Engine
# ═══════════════════════════════════════════════════════════════════════════════

# These patterns are derived from public prompt injection research (OWASP LLM Top 10,
# Perez & Ribeiro 2022, Greshake et al. 2023) — not copy-pasted payloads.

ROLE_HIJACK_PATTERNS = [
    (r"(?i)\b(you\s+are|act\s+as|pretend\s+(to\s+be|you'?re)|roleplay\s+as|"
     r"assume\s+the\s+(role|identity)|from\s+now\s+on\s+you\s+are|"
     r"your\s+new\s+(role|name|identity)\s+is)\b", 0.7),
    (r"(?i)\b(ignore\s+(all\s+)?(previous|prior|above|earlier)\s+(instructions?|rules?|prompts?|guidelines?|constraints?))\b", 0.95),
    (r"(?i)\b(disregard\s+(everything|all|any)\s+(above|before|prior|previous))\b", 0.9),
    (r"(?i)\b(forget\s+(everything|all|what)\s+(you|i)\s+(said|told|wrote|know))\b", 0.85),
    (r"(?i)\b(override\s+(your|the|all)\s+(instructions?|programming|rules?|guidelines?))\b", 0.9),
    (r"(?i)\b(your\s+(real|actual|true|original)\s+(purpose|instructions?|goal|task))\b", 0.6),
    (r"(?i)\b(system\s*:\s*you\s+are)\b", 0.85),
]

DELIMITER_ESCAPE_PATTERNS = [
    (r"```\s*(system|assistant|user)\b", 0.8),
    (r"<\|?(system|im_start|im_end|endoftext|pad)\|?>", 0.95),
    (r"\[INST\]|\[/INST\]|\[SYS\]|\[/SYS\]", 0.9),
    (r"<<\s*SYS\s*>>|<<\s*/SYS\s*>>", 0.9),
    (r"###\s*(System|Human|Assistant|Instruction)\s*:?", 0.75),
    (r"(?i)(BEGIN|END)\s+(SYSTEM\s+)?(PROMPT|INSTRUCTION|MESSAGE)", 0.8),
    (r"\x00|\x1b|\x7f", 0.6),  # null bytes, escape chars
]

EXFILTRATION_PATTERNS = [
    (r"(?i)(repeat|recite|output|print|reveal|show|display|echo|dump|leak)\s+"
     r"((the|your|my|its)\s+)?((system|original|initial|hidden|secret|current)\s+)?"
     r"(prompt|instructions?|rules?|guidelines?|context|message|configuration)", 0.85),
    (r"(?i)what\s+(are|were)\s+(your|the)\s+(original|initial|system|secret|hidden)\s+"
     r"(instructions?|prompt|rules?|guidelines?)", 0.8),
    (r"(?i)(give|tell|share|send)\s+(me\s+)?(the|your)\s+(system|secret|hidden|original)\s+"
     r"(prompt|instructions?|message|configuration)", 0.85),
    (r"(?i)translate\s+((the|your)\s+)?((system|original)\s+)?(prompt|instructions?|message|rules?)\s+(to|into|and)", 0.7),
    (r"(?i)translate\s+((the|your)\s+)?(system\s+)?(message|prompt|instructions?)\s+(into|to|in)\s+\w+\s+and\s+(output|print|show|display|reveal)", 0.75),
    (r"(?i)(copy|paste|type\s+out|write\s+out)\s+((the|your)\s+)?((entire|full|complete|whole)\s+)?"
     r"(system\s+)?(prompt|instructions?|rules?|message)", 0.8),
]

JAILBREAK_PATTERNS = [
    (r"(?i)\bDAN\b.*\b(mode|jailbreak|do\s+anything\s+now)\b", 0.9),
    (r"(?i)\b(developer|debug|maintenance|god|admin|root|sudo)\s*(mode|access|override)\b", 0.85),
    (r"(?i)\b(hypothetical|fictional|imaginary|theoretical)\s+(scenario|situation|world)\s+"
     r"where\s+(you|there|AI)\b", 0.5),
    (r"(?i)\b(opposite|reverse)\s+(day|mode|rules?)\b", 0.7),
    (r"(?i)for\s+(educational|research|academic|testing)\s+purposes?\s+only", 0.4),
    (r"(?i)\b(unlock(ed)?|unchained|uncensored|unfiltered|unrestricted|limitless)\s+"
     r"(mode|version|AI|model)\b", 0.85),
    (r"(?i)in\s+this\s+universe[,\s]+(you|AI|the\s+model)\s+(can|must|should|will)\b", 0.6),
]

PAYLOAD_SMUGGLE_PATTERNS = [
    (r"(?i)\b(eval|exec|import|require|__import__|subprocess|os\.system|os\.popen)\s*\(", 0.9),
    (r"(?i)(fetch|XMLHttpRequest|<script|javascript:|data:text/html|onerror\s*=)", 0.85),
    (r"(?i)(\$\{.*\}|`.*`|\{\{.*\}\})", 0.5),  # template injection
    (r"(?i)(SELECT|INSERT|UPDATE|DELETE|DROP|UNION)\s+.*(FROM|INTO|TABLE|WHERE)", 0.7),
]

# ── Indirect injection: payloads hidden in data the model consumes ──
INDIRECT_INJECTION_PATTERNS = [
    # Instructions hidden in markdown/HTML that the model renders
    (r"(?i)<!--\s*(ignore|override|system|instruction|forget)", 0.85),
    (r"(?i)<\s*(div|span|p)\s+[^>]*style\s*=\s*[\"'].*display\s*:\s*none[\"'][^>]*>.*"
     r"(ignore|override|system|instruction)", 0.9),
    # Markdown image with injection in alt text
    (r"!\[.*(?:ignore|override|system|instruction|forget).*\]\(", 0.7),
    # Data URI with embedded instructions
    (r"data:text/(plain|html)[;,].*(?:ignore|override|instruction)", 0.85),
    # Hidden text in JSON/XML that gets ingested
    (r"(?i)\"(system_override|hidden_instruction|secret_prompt)\"\s*:", 0.8),
    # Injection in URL parameters the model might follow
    (r"(?i)(https?://[^\s]*[?&](prompt|instruction|cmd|system)=)", 0.7),
    # Payload in fake error messages
    (r"(?i)(error|exception|warning|traceback)\s*:.*\b(ignore|override|forget)\s+(all|previous|prior)", 0.75),
]

# ── Tool abuse: manipulating function-calling/plugin systems ──
TOOL_ABUSE_PATTERNS = [
    # Attempting to call tools directly
    (r"(?i)\b(call|invoke|execute|run|trigger)\s+(the\s+)?(function|tool|plugin|api|action)\s+", 0.7),
    # JSON function call injection
    (r'(?i)"(function_call|tool_use|action_input)"\s*:\s*\{', 0.8),
    # Trying to inject tool results
    (r"(?i)(tool\s*result|function\s*output|api\s*response)\s*:\s*", 0.65),
    # File path traversal in tool arguments
    (r"\.\./\.\./|/etc/passwd|/etc/shadow|%2e%2e%2f", 0.85),
    # Command injection in tool parameters
    (r"(?i);\s*(rm|cat|curl|wget|nc|ncat|bash|sh|python|perl|ruby)\s", 0.9),
    # Manipulating retrieval-augmented generation
    (r"(?i)(search\s+for|retrieve|fetch|look\s+up|find\s+document)\s+.*"
     r"(ignore|override|system\s+prompt|new\s+instructions?)", 0.75),
]

# ── Virtualization: creating simulated environments to bypass rules ──
VIRTUALIZATION_PATTERNS = [
    (r"(?i)\b(simulate|emulate|virtualize|create)\s+(a\s+)?"
     r"(terminal|shell|command\s+line|console|computer|operating\s+system|linux|windows)\b", 0.6),
    (r"(?i)\b(imagine|picture|visualize)\s+(you\s+are|yourself\s+as|a\s+world\s+where)\b", 0.5),
    (r"(?i)you\s+are\s+(inside|running|simulating)\s+(a\s+)?"
     r"(virtual\s+machine|sandbox|container|docker|matrix)", 0.7),
    (r"(?i)\b(output|print|display)\s+(a\s+)?"
     r"(terminal|console|shell)\s+(session|window|prompt|output)\b", 0.55),
    (r"(?i)in\s+this\s+(simulation|game|world|story|scenario),?\s+"
     r"(you|the\s+AI|there\s+are)\s+(no|don'?t\s+have)\s+(any\s+)?"
     r"(rules?|restrictions?|limitations?|guidelines?|filters?)", 0.8),
]

# ── Chain-of-thought hijack: manipulating reasoning traces ──
COT_HIJACK_PATTERNS = [
    (r"(?i)let'?s?\s+think\s+(about\s+this\s+)?step\s+by\s+step\s*[.:]\s*"
     r"(step\s+1|first)[.:,]?\s*(ignore|bypass|override|forget)", 0.85),
    (r"(?i)(reasoning|thought|thinking)\s*:\s*"
     r"(I\s+should|I\s+need\s+to|I\s+will)\s+(ignore|bypass|override|break)", 0.8),
    (r"(?i)(internal\s+monologue|inner\s+thought|scratchpad)\s*:", 0.7),
    (r"(?i)<(thinking|scratchpad|internal)>.*"
     r"(ignore|override|bypass|reveal|leak)", 0.85),
]


def _scan_patterns(text: str, patterns: list, vector: str, layer: str = "lexical") -> List[Finding]:
    findings = []
    for pattern, base_conf in patterns:
        for match in re.finditer(pattern, text):
            findings.append(Finding(
                vector=vector,
                confidence=base_conf,
                evidence=match.group()[:120],
                description=f"Matched {vector} signature at position {match.start()}",
                layer=layer,
                offset=match.start(),
            ))
    return findings


def lexical_scan(text: str) -> List[Finding]:
    """Layer 1: Pattern-based detection against known injection signatures."""
    findings = []
    findings += _scan_patterns(text, ROLE_HIJACK_PATTERNS, AttackVector.ROLE_HIJACK)
    findings += _scan_patterns(text, DELIMITER_ESCAPE_PATTERNS, AttackVector.DELIMITER_ESCAPE)
    findings += _scan_patterns(text, EXFILTRATION_PATTERNS, AttackVector.DATA_EXFILTRATION)
    findings += _scan_patterns(text, JAILBREAK_PATTERNS, AttackVector.JAILBREAK)
    findings += _scan_patterns(text, PAYLOAD_SMUGGLE_PATTERNS, AttackVector.PAYLOAD_SMUGGLE)
    findings += _scan_patterns(text, INDIRECT_INJECTION_PATTERNS, AttackVector.INDIRECT_INJECTION)
    findings += _scan_patterns(text, TOOL_ABUSE_PATTERNS, AttackVector.TOOL_ABUSE)
    findings += _scan_patterns(text, VIRTUALIZATION_PATTERNS, AttackVector.VIRTUALIZATION)
    findings += _scan_patterns(text, COT_HIJACK_PATTERNS, AttackVector.CHAIN_OF_THOUGHT_HIJACK)
    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 2: Structural Analysis
# ═══════════════════════════════════════════════════════════════════════════════


def structural_scan(text: str) -> List[Finding]:
    """Layer 2: Detect structural manipulation tactics."""
    findings = []

    # Multi-persona: input tries to create multiple speakers
    persona_markers = re.findall(r"(?i)(system|assistant|user|human|bot|AI)\s*:", text)
    if len(persona_markers) >= 2:
        findings.append(Finding(
            vector=AttackVector.CONTEXT_MANIPULATION,
            confidence=0.75,
            evidence=f"Found {len(persona_markers)} persona markers: {', '.join(persona_markers[:5])}",
            description="Input simulates multi-turn conversation to confuse role boundaries",
            layer="structural",
        ))

    # Instruction sandwich: benign text → injection → benign text
    lines = text.strip().splitlines()
    if len(lines) >= 3:
        middle = "\n".join(lines[1:-1])
        middle_findings = lexical_scan(middle)
        if middle_findings and not lexical_scan(lines[0]) and not lexical_scan(lines[-1]):
            findings.append(Finding(
                vector=AttackVector.CONTEXT_MANIPULATION,
                confidence=0.7,
                evidence="Injection payload sandwiched between benign lines",
                description="Possible context manipulation: hostile content wrapped in innocent framing",
                layer="structural",
            ))

    # Excessive whitespace / invisible chars (evasion)
    invisible_count = sum(1 for c in text if c in "\u200b\u200c\u200d\u2060\ufeff\u00ad")
    if invisible_count > 3:
        findings.append(Finding(
            vector=AttackVector.ENCODING_ATTACK,
            confidence=min(0.5 + invisible_count * 0.05, 0.95),
            evidence=f"{invisible_count} invisible Unicode characters detected",
            description="Invisible characters may be used to hide injection payloads",
            layer="structural",
        ))

    # Unusual repetition (token-stuffing attack)
    words = text.lower().split()
    if len(words) > 20:
        from collections import Counter
        freq = Counter(words)
        most_common_pct = freq.most_common(1)[0][1] / len(words) if words else 0
        if most_common_pct > 0.3 and len(words) > 30:
            findings.append(Finding(
                vector=AttackVector.CONTEXT_MANIPULATION,
                confidence=0.5,
                evidence=f"Token '{freq.most_common(1)[0][0]}' appears {freq.most_common(1)[0][1]}/{len(words)} times ({most_common_pct:.0%})",
                description="Unusual token repetition — possible context window exhaustion attack",
                layer="structural",
            ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 3: Entropy Analysis
# ═══════════════════════════════════════════════════════════════════════════════


def _shannon_entropy(text: str) -> float:
    """Calculate Shannon entropy of a string (bits per character)."""
    if not text:
        return 0.0
    freq = {}
    for c in text:
        freq[c] = freq.get(c, 0) + 1
    length = len(text)
    return -sum((count / length) * math.log2(count / length) for count in freq.values())


def _detect_encoding(text: str) -> List[Tuple[str, str]]:
    """Detect common encoding schemes used to smuggle payloads."""
    detected = []
    # Base64
    b64_pattern = re.findall(r"[A-Za-z0-9+/]{20,}={0,2}", text)
    for match in b64_pattern:
        try:
            import base64
            decoded = base64.b64decode(match).decode("utf-8", errors="replace")
            if any(c.isalpha() for c in decoded) and len(decoded) > 5:
                detected.append(("base64", f"{match[:40]}... → {decoded[:60]}"))
        except Exception:
            pass

    # Hex
    hex_pattern = re.findall(r"(?:0x)?([0-9a-fA-F]{20,})", text)
    for match in hex_pattern:
        try:
            decoded = bytes.fromhex(match).decode("utf-8", errors="replace")
            if any(c.isalpha() for c in decoded):
                detected.append(("hex", f"{match[:40]}... → {decoded[:60]}"))
        except Exception:
            pass

    # ROT13
    if re.search(r"(?i)\brot13\b", text):
        import codecs
        rot_decoded = codecs.decode(text, "rot_13")
        detected.append(("rot13_mentioned", f"ROT13 keyword found — decoded: {rot_decoded[:80]}"))

    # Unicode escapes
    unicode_esc = re.findall(r"\\u[0-9a-fA-F]{4}", text)
    if len(unicode_esc) > 3:
        try:
            decoded = text.encode().decode("unicode_escape")
            detected.append(("unicode_escape", f"{len(unicode_esc)} escape sequences → {decoded[:80]}"))
        except Exception:
            pass

    return detected


def entropy_scan(text: str) -> List[Finding]:
    """Layer 3: Detect encoded or obfuscated payloads via entropy analysis."""
    findings = []

    entropy = _shannon_entropy(text)
    # Normal English text: ~4.0-4.5 bits/char, code: ~4.5-5.5, random/encoded: >5.5
    if entropy > 5.5 and len(text) > 50:
        findings.append(Finding(
            vector=AttackVector.ENCODING_ATTACK,
            confidence=min(0.4 + (entropy - 5.5) * 0.3, 0.9),
            evidence=f"Shannon entropy: {entropy:.2f} bits/char (normal text ≈ 4.0-4.5)",
            description="Abnormally high entropy suggests encoded or obfuscated content",
            layer="entropy",
        ))

    # Check for specific encodings
    for encoding_type, decoded_sample in _detect_encoding(text):
        findings.append(Finding(
            vector=AttackVector.PAYLOAD_SMUGGLE,
            confidence=0.75,
            evidence=f"Detected {encoding_type}: {decoded_sample[:100]}",
            description=f"Payload smuggled via {encoding_type} encoding",
            layer="entropy",
        ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 4: Semantic Drift Detection
# ═══════════════════════════════════════════════════════════════════════════════


# Lightweight keyword-category classifier (no ML dependency needed)
TOPIC_KEYWORDS = {
    "system_manipulation": [
        "system prompt", "instructions", "guidelines", "override", "bypass",
        "ignore", "disregard", "forget", "pretend", "roleplay", "jailbreak",
        "uncensored", "unfiltered", "developer mode", "DAN", "rules",
    ],
    "code_execution": [
        "eval", "exec", "import", "subprocess", "os.system", "shell",
        "command", "script", "execute", "runtime", "compile",
    ],
    "data_exfiltration": [
        "reveal", "show me", "repeat back", "what are your", "leak",
        "dump", "extract", "expose", "disclose", "secret",
    ],
    "tool_manipulation": [
        "function call", "tool use", "plugin", "api call", "invoke function",
        "execute tool", "run command", "action input", "retrieval",
    ],
    "social_engineering": [
        "trust me", "I'm your developer", "I'm an admin", "authorized",
        "my boss told me", "emergency", "urgent", "life depends", "people will die",
        "you must", "you have to", "it's critical", "national security",
    ],
}


def _topic_score(text: str, keywords: List[str]) -> float:
    """Score how much a text relates to a keyword category (0.0-1.0)."""
    text_lower = text.lower()
    matches = sum(1 for kw in keywords if kw.lower() in text_lower)
    return min(matches / max(len(keywords) * 0.3, 1), 1.0)


def semantic_drift_scan(text: str, expected_topic: str = "") -> List[Finding]:
    """Layer 4: Detect if input drifts toward manipulation topics."""
    findings = []

    for category, keywords in TOPIC_KEYWORDS.items():
        score = _topic_score(text, keywords)
        if score > 0.3:
            vector = {
                "system_manipulation": AttackVector.INSTRUCTION_OVERRIDE,
                "code_execution": AttackVector.PAYLOAD_SMUGGLE,
                "data_exfiltration": AttackVector.DATA_EXFILTRATION,
                "tool_manipulation": AttackVector.TOOL_ABUSE,
                "social_engineering": AttackVector.CONTEXT_MANIPULATION,
            }.get(category, AttackVector.CONTEXT_MANIPULATION)

            findings.append(Finding(
                vector=vector,
                confidence=min(score, 0.85),
                evidence=f"Topic drift: {category} scored {score:.0%}",
                description=f"Input has strong semantic alignment with {category} tactics",
                layer="semantic",
            ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 5: Canary Trap System
# ═══════════════════════════════════════════════════════════════════════════════


class CanarySystem:
    """Inject hidden canary tokens into system prompts. If the AI output
    contains a modified or revealed canary, the prompt was compromised."""

    def __init__(self, secret: str = "nullsec-armor"):
        self._secret = secret

    def generate_canary(self, session_id: str = "") -> str:
        """Generate a unique canary token for a session."""
        seed = f"{self._secret}:{session_id}:{time.time()}"
        token = hashlib.sha256(seed.encode()).hexdigest()[:16]
        return f"§{token}§"

    def inject_canary(self, system_prompt: str, canary: str) -> str:
        """Inject canary into a system prompt invisibly."""
        # Use zero-width spaces to hide the canary
        hidden = "".join(f"\u200b{c}" for c in canary)
        return f"{system_prompt}\n{hidden}"

    def check_canary(self, ai_output: str, canary: str) -> bool:
        """Check if the canary was leaked or tampered with in the output."""
        # Strip zero-width chars for comparison
        clean_output = ai_output.replace("\u200b", "").replace("\u200c", "").replace("\u200d", "")
        # Canary should NOT appear in output — if it does, prompt was leaked
        return canary.strip("§") not in clean_output

    def verify_output(self, ai_output: str, canary: str) -> List[Finding]:
        """Verify AI output doesn't contain the canary (which would mean prompt leak)."""
        findings = []
        if not self.check_canary(ai_output, canary):
            findings.append(Finding(
                vector=AttackVector.CANARY_TRIGGER,
                confidence=0.99,
                evidence=f"Canary token detected in AI output",
                description="The AI model revealed its system prompt — a prompt injection attack succeeded",
                layer="canary",
            ))
        return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 6: Multi-Turn Memory — Boiling Frog Detection
# ═══════════════════════════════════════════════════════════════════════════════


class ConversationTracker:
    """Track conversation history to detect gradual escalation attacks.

    The "boiling frog" pattern: an attacker builds rapport over several turns,
    then escalates to injection.  Single-turn scanners miss this because each
    individual message looks harmless.

    Usage:
        tracker = ConversationTracker()
        # For each user turn:
        findings = tracker.add_turn(user_message)
        if findings:
            # escalation detected
    """

    def __init__(self, window: int = 20, escalation_threshold: float = 0.4):
        self._history: List[Dict[str, Any]] = []
        self._window = window
        self._escalation_threshold = escalation_threshold

    @property
    def history(self) -> List[Dict[str, Any]]:
        return list(self._history)

    def add_turn(self, text: str, role: str = "user") -> List[Finding]:
        """Analyze a new turn and check for multi-turn escalation."""
        # Score this turn in isolation (lightweight — lexical + semantic only)
        turn_findings = lexical_scan(text) + semantic_drift_scan(text)
        turn_score = max((f.confidence for f in turn_findings), default=0.0)
        turn_vectors = [f.vector for f in turn_findings]

        self._history.append({
            "role": role,
            "text_hash": hashlib.sha256(text.encode()).hexdigest()[:12],
            "score": turn_score,
            "vectors": turn_vectors,
            "length": len(text),
            "turn": len(self._history),
        })

        # Keep only the sliding window
        if len(self._history) > self._window:
            self._history = self._history[-self._window:]

        return self._detect_escalation()

    def _detect_escalation(self) -> List[Finding]:
        """Detect escalation patterns across the conversation window."""
        findings = []
        if len(self._history) < 3:
            return findings

        scores = [t["score"] for t in self._history]

        # ── Pattern 1: Gradual ramp-up ──
        # Check if the last N turns show a monotonic increase in threat score
        recent = scores[-5:] if len(scores) >= 5 else scores
        if len(recent) >= 3:
            diffs = [recent[i + 1] - recent[i] for i in range(len(recent) - 1)]
            avg_increase = sum(d for d in diffs if d > 0) / max(len(diffs), 1)
            if avg_increase > 0.1 and recent[-1] > self._escalation_threshold:
                findings.append(Finding(
                    vector=AttackVector.MULTI_TURN_ESCALATION,
                    confidence=min(0.5 + avg_increase, 0.95),
                    evidence=f"Threat ramp: {' → '.join(f'{s:.2f}' for s in recent)}",
                    description="Gradual escalation detected — input severity increasing across turns",
                    layer="multiturn",
                ))

        # ── Pattern 2: Sudden spike after calm ──
        # Several low-score turns followed by a high-score turn
        if len(scores) >= 4:
            recent_baseline = sum(scores[-5:-1]) / max(len(scores[-5:-1]), 1)
            current = scores[-1]
            if recent_baseline < 0.15 and current > 0.6:
                findings.append(Finding(
                    vector=AttackVector.MULTI_TURN_ESCALATION,
                    confidence=min(0.6 + (current - recent_baseline), 0.95),
                    evidence=f"Spike: baseline {recent_baseline:.2f} → current {current:.2f}",
                    description="Sudden escalation after calm rapport-building phase",
                    layer="multiturn",
                ))

        # ── Pattern 3: Vector diversity escalation ──
        # Attacker probing with different vectors each turn
        if len(self._history) >= 4:
            recent_turns = self._history[-4:]
            all_vectors = set()
            for t in recent_turns:
                all_vectors.update(t["vectors"])
            if len(all_vectors) >= 3:
                findings.append(Finding(
                    vector=AttackVector.MULTI_TURN_ESCALATION,
                    confidence=min(0.4 + len(all_vectors) * 0.1, 0.85),
                    evidence=f"Probing {len(all_vectors)} vectors: {', '.join(str(v) for v in list(all_vectors)[:5])}",
                    description="Attacker probing multiple attack surfaces across turns",
                    layer="multiturn",
                ))

        # ── Pattern 4: Persona drift ──
        # Check if role assignments keep changing (trying to confuse the model)
        roles = [t["role"] for t in self._history[-6:]]
        if len(set(roles)) > 2 or roles.count("system") > 0:
            findings.append(Finding(
                vector=AttackVector.MULTI_TURN_ESCALATION,
                confidence=0.7,
                evidence=f"Role sequence: {' → '.join(roles)}",
                description="Suspicious role switching detected in conversation",
                layer="multiturn",
            ))

        return findings

    def reset(self):
        """Clear conversation history."""
        self._history.clear()

    def get_threat_trend(self) -> Dict[str, Any]:
        """Return conversation threat trend summary."""
        if not self._history:
            return {"turns": 0, "trend": "none", "avg_score": 0.0}
        scores = [t["score"] for t in self._history]
        avg = sum(scores) / len(scores)
        if len(scores) >= 3:
            first_half = sum(scores[:len(scores) // 2]) / max(len(scores) // 2, 1)
            second_half = sum(scores[len(scores) // 2:]) / max(len(scores) - len(scores) // 2, 1)
            if second_half > first_half + 0.15:
                trend = "escalating"
            elif second_half < first_half - 0.15:
                trend = "de-escalating"
            else:
                trend = "stable"
        else:
            trend = "insufficient_data"
        return {"turns": len(self._history), "trend": trend, "avg_score": round(avg, 3)}


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 7: Indirect Injection Scanner
# ═══════════════════════════════════════════════════════════════════════════════


def _extract_embedded_content(text: str) -> List[Tuple[str, str]]:
    """Extract content from common embedding vectors that models may consume."""
    embedded: List[Tuple[str, str]] = []

    # HTML comment contents
    for m in re.finditer(r"<!--(.*?)-->", text, re.DOTALL):
        embedded.append(("html_comment", m.group(1).strip()))

    # Hidden HTML elements
    for m in re.finditer(
        r"<[^>]*style\s*=\s*[\"'][^\"']*display\s*:\s*none[^\"']*[\"'][^>]*>(.*?)</",
        text, re.DOTALL | re.IGNORECASE
    ):
        embedded.append(("hidden_element", m.group(1).strip()))

    # Markdown image alt text (often used to inject invisible instructions)
    for m in re.finditer(r"!\[([^\]]{10,})\]\(", text):
        embedded.append(("markdown_alt", m.group(1)))

    # Data URIs
    for m in re.finditer(r"data:text/(?:plain|html)[;,](.*?)(?:\s|$|\")", text, re.DOTALL):
        content = m.group(1)
        # URL-decode if needed
        try:
            from urllib.parse import unquote
            content = unquote(content)
        except ImportError:
            pass
        if len(content) > 5:
            embedded.append(("data_uri", content[:500]))

    # JSON string values that look like instructions
    for m in re.finditer(r'"[^"]*":\s*"([^"]{20,})"', text):
        val = m.group(1)
        if any(kw in val.lower() for kw in ["ignore", "override", "system", "instruction", "forget", "pretend"]):
            embedded.append(("json_value", val))

    # URL query parameters
    for m in re.finditer(r'[?&](prompt|instruction|cmd|system|query)=([^&\s]{5,})', text, re.IGNORECASE):
        try:
            from urllib.parse import unquote
            embedded.append(("url_param", unquote(m.group(2))))
        except ImportError:
            embedded.append(("url_param", m.group(2)))

    # Fake tool/API outputs
    for m in re.finditer(
        r'(?:tool_result|function_output|api_response|assistant_response)\s*[:=]\s*["\']?(.{10,}?)["\']?\s*$',
        text, re.MULTILINE | re.IGNORECASE
    ):
        embedded.append(("fake_tool_output", m.group(1)))

    return embedded


def indirect_injection_scan(text: str) -> List[Finding]:
    """Layer 7: Detect payloads hidden in data the model consumes.

    Searches for injection attempts embedded in HTML comments, hidden elements,
    markdown images, data URIs, JSON fields, URL params, and fake tool output.
    Then re-scans the extracted content through the lexical engine.
    """
    findings = []
    extracted = _extract_embedded_content(text)

    for source, content in extracted:
        # Re-scan extracted content through lexical engine
        inner_findings = lexical_scan(content)
        if inner_findings:
            best = max(inner_findings, key=lambda f: f.confidence)
            findings.append(Finding(
                vector=AttackVector.INDIRECT_INJECTION,
                confidence=min(best.confidence + 0.1, 0.99),
                evidence=f"Hidden payload in {source}: {content[:80]}",
                description=f"Indirect injection via {source} — embedded content contains {best.vector} payload",
                layer="indirect",
            ))
        elif any(kw in content.lower() for kw in [
            "ignore", "override", "system prompt", "forget", "new instructions",
            "you are now", "disregard", "bypass", "jailbreak"
        ]):
            # Even without formal pattern match, flag suspicious embedded content
            findings.append(Finding(
                vector=AttackVector.INDIRECT_INJECTION,
                confidence=0.6,
                evidence=f"Suspicious content in {source}: {content[:80]}",
                description=f"Potentially malicious text hidden in {source}",
                layer="indirect",
            ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Layer 8: Language Evasion Detection
# ═══════════════════════════════════════════════════════════════════════════════

# Homoglyph map: characters from other scripts that look like Latin letters
# Used in attacks to bypass keyword filters (e.g., "іgnore" with Cyrillic і)
HOMOGLYPH_MAP = {
    # Cyrillic lookalikes
    "\u0430": "a", "\u0435": "e", "\u043e": "o", "\u0440": "p",
    "\u0441": "c", "\u0443": "y", "\u0445": "x", "\u0456": "i",
    "\u0458": "j", "\u04bb": "h", "\u0455": "s", "\u0442": "t",
    "\u043c": "m", "\u043d": "n", "\u0432": "v", "\u043a": "k",
    "\u0433": "r",
    # Greek lookalikes
    "\u03b1": "a", "\u03b5": "e", "\u03bf": "o", "\u03c1": "p",
    "\u03c4": "t", "\u03ba": "k", "\u03bd": "v", "\u03b9": "i",
    # Fullwidth Latin
    "\uff41": "a", "\uff42": "b", "\uff43": "c", "\uff44": "d",
    "\uff45": "e", "\uff46": "f", "\uff47": "g", "\uff48": "h",
    "\uff49": "i", "\uff4a": "j", "\uff4b": "k", "\uff4c": "l",
    "\uff4d": "m", "\uff4e": "n", "\uff4f": "o", "\uff50": "p",
    "\uff51": "q", "\uff52": "r", "\uff53": "s", "\uff54": "t",
    "\uff55": "u", "\uff56": "v", "\uff57": "w", "\uff58": "x",
    "\uff59": "y", "\uff5a": "z",
    # Math/special lookalikes
    "\u0251": "a",  # Latin alpha
    "\u025b": "e",  # open e
    "\u1d04": "c",  # small capital C
    "\u026f": "m",  # turned m
}

# Leetspeak substitution map (reverse: leet → latin)
LEET_MAP = {
    "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
    "7": "t", "8": "b", "9": "g", "@": "a", "$": "s",
    "!": "i", "|": "l", "+": "t", "(": "c", "ph": "f",
}

# Keywords that, when decoded from evasion, indicate an attack
EVASION_TRIGGER_WORDS = [
    "ignore", "override", "system", "prompt", "instructions", "forget",
    "bypass", "jailbreak", "pretend", "disregard", "reveal", "unfiltered",
    "uncensored", "developer", "admin", "sudo", "execute", "eval",
]


def _normalize_homoglyphs(text: str) -> Tuple[str, int]:
    """Replace homoglyph characters with their Latin equivalents.
    Returns (normalized_text, substitution_count)."""
    result = []
    substitutions = 0
    for char in text:
        if char in HOMOGLYPH_MAP:
            result.append(HOMOGLYPH_MAP[char])
            substitutions += 1
        else:
            result.append(char)
    return "".join(result), substitutions


def _decode_leetspeak(text: str) -> str:
    """Decode leetspeak substitutions back to normal text."""
    result = text.lower()
    # Handle multi-char substitutions first
    result = result.replace("ph", "f")
    # Then single-char
    for leet, latin in LEET_MAP.items():
        if len(leet) == 1:
            result = result.replace(leet, latin)
    return result


def _detect_reversed_text(text: str) -> Optional[str]:
    """Check if text or substrings are reversed versions of trigger words."""
    text_lower = text.lower()
    # Check for full reversed trigger words
    for word in EVASION_TRIGGER_WORDS:
        reversed_word = word[::-1]
        if reversed_word in text_lower and word not in text_lower:
            return reversed_word
    # Check for reversed sentences/phrases (common evasion: whole instruction reversed)
    reversed_text = text_lower[::-1]
    trigger_count = sum(1 for w in EVASION_TRIGGER_WORDS if w in reversed_text)
    if trigger_count >= 2:
        return reversed_text[:100]
    return None


def _detect_mixed_scripts(text: str) -> Dict[str, int]:
    """Detect mixing of Unicode scripts (Latin + Cyrillic + Greek etc)."""
    scripts: Dict[str, int] = {}
    for char in text:
        if char.isalpha():
            try:
                name = unicodedata.name(char, "UNKNOWN")
                if "CYRILLIC" in name:
                    scripts["cyrillic"] = scripts.get("cyrillic", 0) + 1
                elif "GREEK" in name:
                    scripts["greek"] = scripts.get("greek", 0) + 1
                elif "LATIN" in name or "FULLWIDTH LATIN" in name:
                    scripts["latin"] = scripts.get("latin", 0) + 1
                elif "CJK" in name:
                    scripts["cjk"] = scripts.get("cjk", 0) + 1
                elif "ARABIC" in name:
                    scripts["arabic"] = scripts.get("arabic", 0) + 1
                elif "DEVANAGARI" in name:
                    scripts["devanagari"] = scripts.get("devanagari", 0) + 1
                else:
                    scripts["other"] = scripts.get("other", 0) + 1
            except ValueError:
                scripts["unknown"] = scripts.get("unknown", 0) + 1
    return scripts


def language_evasion_scan(text: str) -> List[Finding]:
    """Layer 8: Detect language-based evasion techniques.

    Catches attacks that use character substitution, encoding tricks, or
    linguistic manipulation to bypass keyword-based detection.
    """
    findings = []

    # ── Homoglyph detection ──
    normalized, sub_count = _normalize_homoglyphs(text)
    if sub_count > 0:
        # Re-scan the normalized text for hidden attacks
        normalized_findings = lexical_scan(normalized)
        if normalized_findings:
            findings.append(Finding(
                vector=AttackVector.HOMOGLYPH_ATTACK,
                confidence=min(0.7 + sub_count * 0.05, 0.98),
                evidence=f"{sub_count} homoglyph substitutions; decoded: {normalized[:80]}",
                description="Homoglyph attack — visually similar characters hide injection keywords",
                layer="language",
            ))
        elif sub_count >= 3:
            # Many substitutions even without pattern match = suspicious
            findings.append(Finding(
                vector=AttackVector.HOMOGLYPH_ATTACK,
                confidence=min(0.3 + sub_count * 0.05, 0.7),
                evidence=f"{sub_count} homoglyph characters detected",
                description="Multiple homoglyph characters suggest possible evasion attempt",
                layer="language",
            ))

    # ── Leetspeak detection ──
    decoded_leet = _decode_leetspeak(text)
    if decoded_leet != text.lower():
        leet_findings = lexical_scan(decoded_leet)
        if leet_findings:
            findings.append(Finding(
                vector=AttackVector.LANGUAGE_EVASION,
                confidence=min(max(f.confidence for f in leet_findings) + 0.1, 0.95),
                evidence=f"Leetspeak decoded: {decoded_leet[:80]}",
                description="Leetspeak encoding hides injection payload",
                layer="language",
            ))

    # ── Reversed text detection ──
    reversed_match = _detect_reversed_text(text)
    if reversed_match:
        findings.append(Finding(
            vector=AttackVector.LANGUAGE_EVASION,
            confidence=0.75,
            evidence=f"Reversed trigger detected: {reversed_match[:60]}",
            description="Text reversal used to evade keyword detection",
            layer="language",
        ))

    # ── Mixed-script detection ──
    scripts = _detect_mixed_scripts(text)
    non_latin_scripts = {k: v for k, v in scripts.items() if k != "latin" and k != "other"}
    if "latin" in scripts and non_latin_scripts:
        # Mixing Latin with another script in a primarily English context
        total_alpha = sum(scripts.values())
        non_latin_pct = sum(non_latin_scripts.values()) / max(total_alpha, 1)
        # Suspicious range: 1-40% non-Latin mixed with Latin (pure non-Latin is likely legitimate)
        if 0.01 < non_latin_pct < 0.4:
            findings.append(Finding(
                vector=AttackVector.HOMOGLYPH_ATTACK,
                confidence=min(0.4 + non_latin_pct * 2, 0.85),
                evidence=f"Script mix: {dict(scripts)} ({non_latin_pct:.0%} non-Latin)",
                description="Mixed Unicode scripts detected — possible homoglyph evasion",
                layer="language",
            ))

    # ── Spaced/dotted evasion: "i g n o r e" or "i.g.n.o.r.e" ──
    # First try: collapse only dots/underscores/hyphens (keep spaces between word groups)
    collapsed_nosep = re.sub(r"(?<=\w)[._\-]+(?=\w)", "", text.lower())
    # Second try: collapse ALL separators including spaces
    collapsed_all = re.sub(r"(?<=\w)[.\s_\-]+(?=\w)", "", text.lower())
    for variant in (collapsed_nosep, collapsed_all):
        if variant != text.lower():
            variant_findings = lexical_scan(variant)
            if variant_findings:
                findings.append(Finding(
                    vector=AttackVector.LANGUAGE_EVASION,
                    confidence=min(max(f.confidence for f in variant_findings) + 0.05, 0.9),
                    evidence=f"De-spaced: {variant[:80]}",
                    description="Character spacing/separation used to evade detection",
                    layer="language",
                ))
                break

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Deobfuscation Pipeline
# ═══════════════════════════════════════════════════════════════════════════════


def deobfuscate(text: str, max_depth: int = 5) -> Tuple[str, List[str]]:
    """Recursively decode chained obfuscation layers.

    Attackers often chain encodings: base64(hex(rot13(payload))).
    This pipeline iteratively decodes until no more layers are found.

    Returns:
        (final_decoded_text, list_of_decoding_steps)
    """
    steps: List[str] = []
    current = text
    seen_hashes: set = set()

    for depth in range(max_depth):
        text_hash = hashlib.md5(current.encode()).hexdigest()
        if text_hash in seen_hashes:
            break  # No progress — stop
        seen_hashes.add(text_hash)
        decoded_this_round = False

        # Try Base64
        b64_matches = re.findall(r"[A-Za-z0-9+/]{16,}={0,2}", current)
        for match in b64_matches:
            try:
                decoded = base64.b64decode(match).decode("utf-8", errors="strict")
                if len(decoded) > 5 and any(c.isalpha() for c in decoded):
                    current = current.replace(match, decoded, 1)
                    steps.append(f"base64 @ depth {depth}: {match[:30]}… → {decoded[:50]}")
                    decoded_this_round = True
                    break
            except Exception:
                continue

        # Try Hex
        if not decoded_this_round:
            hex_matches = re.findall(r"(?:0x)?([0-9a-fA-F]{16,})", current)
            for match in hex_matches:
                try:
                    decoded = bytes.fromhex(match).decode("utf-8", errors="strict")
                    if len(decoded) > 5 and any(c.isalpha() for c in decoded):
                        current = current.replace(match, decoded, 1)
                        steps.append(f"hex @ depth {depth}: {match[:30]}… → {decoded[:50]}")
                        decoded_this_round = True
                        break
                except Exception:
                    continue

        # Try URL encoding
        if not decoded_this_round and "%" in current:
            try:
                from urllib.parse import unquote
                url_decoded = unquote(current)
                if url_decoded != current:
                    steps.append(f"url @ depth {depth}: {current[:40]}… → {url_decoded[:50]}")
                    current = url_decoded
                    decoded_this_round = True
            except Exception:
                pass

        # Try Unicode escapes
        if not decoded_this_round and "\\u" in current:
            try:
                uni_decoded = current.encode().decode("unicode_escape")
                if uni_decoded != current:
                    steps.append(f"unicode @ depth {depth}: → {uni_decoded[:50]}")
                    current = uni_decoded
                    decoded_this_round = True
            except Exception:
                pass

        # Try ROT13
        if not decoded_this_round:
            rot_decoded = codecs.decode(current, "rot_13")
            # Only accept if ROT13 produces recognizable trigger words
            trigger_hits = sum(1 for w in EVASION_TRIGGER_WORDS if w in rot_decoded.lower())
            if trigger_hits >= 2 and trigger_hits > sum(1 for w in EVASION_TRIGGER_WORDS if w in current.lower()):
                steps.append(f"rot13 @ depth {depth}: → {rot_decoded[:50]}")
                current = rot_decoded
                decoded_this_round = True

        if not decoded_this_round:
            break  # Nothing decoded this round — done

    return current, steps


def deobfuscation_scan(text: str) -> List[Finding]:
    """Run the deobfuscation pipeline and scan the decoded output."""
    findings = []
    decoded, steps = deobfuscate(text)

    if steps:
        # Re-scan decoded content
        decoded_findings = lexical_scan(decoded)
        if decoded_findings:
            best = max(decoded_findings, key=lambda f: f.confidence)
            findings.append(Finding(
                vector=AttackVector.ENCODING_ATTACK,
                confidence=min(best.confidence + 0.15, 0.99),
                evidence=f"Decoded via {len(steps)} layers: {' → '.join(s.split(':')[0] for s in steps)}; "
                         f"result: {decoded[:80]}",
                description=f"Chained encoding attack decoded through {len(steps)} obfuscation layers",
                layer="deobfuscation",
            ))
        else:
            # Even without a pattern match, multi-layer encoding is suspicious
            findings.append(Finding(
                vector=AttackVector.ENCODING_ATTACK,
                confidence=min(0.3 + len(steps) * 0.15, 0.75),
                evidence=f"{len(steps)} encoding layers decoded: {' → '.join(s.split(':')[0] for s in steps)}",
                description="Multi-layer encoding detected (possible payload obfuscation)",
                layer="deobfuscation",
            ))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Sanitizer
# ═══════════════════════════════════════════════════════════════════════════════


def sanitize(text: str, aggressive: bool = False) -> str:
    """Remove or neutralize detected injection payloads from user input.

    Conservative mode (default): strip control chars, normalize delimiters, normalize homoglyphs
    Aggressive mode: also remove sentences containing injection keywords
    """
    # Strip null bytes and control characters
    sanitized = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)

    # Strip zero-width Unicode
    sanitized = re.sub(r"[\u200b\u200c\u200d\u2060\ufeff\u00ad]", "", sanitized)

    # Normalize homoglyphs to Latin equivalents
    sanitized, _ = _normalize_homoglyphs(sanitized)

    # Neutralize chat-template delimiters
    sanitized = re.sub(r"<\|?(system|im_start|im_end|endoftext|pad)\|?>", "[filtered]", sanitized, flags=re.I)
    sanitized = re.sub(r"\[INST\]|\[/INST\]|\[SYS\]|\[/SYS\]", "[filtered]", sanitized, flags=re.I)
    sanitized = re.sub(r"<<\s*/?SYS\s*>>", "[filtered]", sanitized, flags=re.I)

    # Neutralize persona markers at line starts
    sanitized = re.sub(r"^(system|assistant|user|human)\s*:", "[speaker]:", sanitized, flags=re.I | re.M)

    # Strip HTML comments that may contain hidden instructions
    sanitized = re.sub(r"<!--.*?-->", "", sanitized, flags=re.DOTALL)

    # Strip hidden HTML elements
    sanitized = re.sub(
        r"<[^>]*style\s*=\s*[\"'][^\"']*display\s*:\s*none[^\"']*[\"'][^>]*>.*?</[^>]+>",
        "", sanitized, flags=re.DOTALL | re.IGNORECASE,
    )

    # Neutralize thinking/scratchpad tags
    sanitized = re.sub(r"<(thinking|scratchpad|internal)>.*?</\1>", "[filtered]", sanitized, flags=re.DOTALL | re.I)

    if aggressive:
        # Remove entire lines containing high-confidence injection phrases
        danger_phrases = [
            r"ignore\s+(all\s+)?previous\s+instructions?",
            r"disregard\s+(everything|all)\s+(above|before)",
            r"override\s+(your|the)\s+instructions?",
            r"forget\s+(everything|all|what)",
            r"you\s+are\s+now\s+",
            r"developer\s+mode",
            r"DAN\s+mode",
            r"tool_use|function_call|action_input",
            r"simulate\s+a?\s*(terminal|shell|console)",
        ]
        lines = sanitized.splitlines()
        filtered_lines = []
        for line in lines:
            if any(re.search(p, line, re.I) for p in danger_phrases):
                filtered_lines.append("[line removed by Prompt Armor]")
            else:
                filtered_lines.append(line)
        sanitized = "\n".join(filtered_lines)

    return sanitized


# ═══════════════════════════════════════════════════════════════════════════════
# Main Analysis Engine
# ═══════════════════════════════════════════════════════════════════════════════


def analyze(
    text: str,
    expected_topic: str = "",
    aggressive_sanitize: bool = False,
    layers: Optional[List[str]] = None,
    conversation_tracker: Optional[ConversationTracker] = None,
) -> ArmorVerdict:
    """Run all detection layers against a text input and return a verdict.

    Args:
        text: The user input to analyze
        expected_topic: Optional topic hint for semantic drift detection
        aggressive_sanitize: If True, strip entire lines with injection patterns
        layers: Which layers to run (default: all).
                Options: lexical, structural, entropy, semantic, indirect, language, deobfuscation, multiturn
        conversation_tracker: Optional ConversationTracker for multi-turn detection

    Returns:
        ArmorVerdict with threat level, risk score, findings, and sanitized text
    """
    start = time.time()
    all_layers = layers or [
        "lexical", "structural", "entropy", "semantic",
        "indirect", "language", "deobfuscation",
    ]
    findings: List[Finding] = []

    if "lexical" in all_layers:
        findings += lexical_scan(text)

    if "structural" in all_layers:
        findings += structural_scan(text)

    if "entropy" in all_layers:
        findings += entropy_scan(text)

    if "semantic" in all_layers:
        findings += semantic_drift_scan(text, expected_topic)

    if "indirect" in all_layers:
        findings += indirect_injection_scan(text)

    if "language" in all_layers:
        findings += language_evasion_scan(text)

    if "deobfuscation" in all_layers:
        findings += deobfuscation_scan(text)

    if "multiturn" in all_layers and conversation_tracker is not None:
        findings += conversation_tracker.add_turn(text)

    # Calculate composite risk score (0-100)
    if findings:
        max_conf = max(f.confidence for f in findings)
        avg_conf = sum(f.confidence for f in findings) / len(findings)
        unique_vectors = len(set(f.vector for f in findings))
        unique_layers = len(set(f.layer for f in findings))

        score = min(100, (
            max_conf * 40 +                    # Highest-confidence finding
            avg_conf * 20 +                    # Average confidence
            min(len(findings), 10) * 3 +       # Finding count (capped)
            unique_vectors * 5 +               # Diversity of attack vectors
            unique_layers * 5                  # Diversity of detection layers
        ))
    else:
        score = 0

    # Determine threat level
    if score >= 70:
        threat_level = ThreatLevel.CRITICAL
    elif score >= 45:
        threat_level = ThreatLevel.HOSTILE
    elif score >= 20:
        threat_level = ThreatLevel.SUSPICIOUS
    else:
        threat_level = ThreatLevel.CLEAN

    return ArmorVerdict(
        threat_level=threat_level.value,
        score=round(score, 1),
        findings=[asdict(f) for f in findings],
        sanitized=sanitize(text, aggressive=aggressive_sanitize),
        processing_ms=round((time.time() - start) * 1000, 2),
        input_hash=hashlib.sha256(text.encode()).hexdigest()[:16],
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Middleware / Decorator for FastAPI integration
# ═══════════════════════════════════════════════════════════════════════════════


def armor_guard(
    threshold: float = 45.0,
    block_on: str = "hostile",
    sanitize_input: bool = True,
):
    """FastAPI dependency that scans incoming request bodies for prompt injection.

    Usage:
        from nullsec_prompt_armor import armor_guard

        @app.post("/chat")
        async def chat(request: Request, guard=Depends(armor_guard(threshold=50))):
            user_input = guard["sanitized"]  # Use sanitized input
            ...
    """
    from fastapi import Request, HTTPException

    async def _guard(request: Request):
        try:
            body = await request.json()
        except Exception:
            return {"verdict": None, "sanitized": "", "original": ""}

        # Extract text from common payload shapes
        text = ""
        if isinstance(body, str):
            text = body
        elif isinstance(body, dict):
            for key in ("prompt", "message", "input", "query", "text", "content", "user_input"):
                if key in body:
                    text = str(body[key])
                    break

        if not text:
            return {"verdict": None, "sanitized": "", "original": ""}

        verdict = analyze(text, aggressive_sanitize=sanitize_input)

        level_order = {"clean": 0, "suspicious": 1, "hostile": 2, "critical": 3}
        if level_order.get(verdict.threat_level, 0) >= level_order.get(block_on, 2):
            raise HTTPException(
                status_code=422,
                detail={
                    "error": "prompt_injection_detected",
                    "threat_level": verdict.threat_level,
                    "score": verdict.score,
                    "message": f"Input blocked by Prompt Armor (threat: {verdict.threat_level}, score: {verdict.score})",
                }
            )

        return {
            "verdict": asdict(verdict),
            "sanitized": verdict.sanitized,
            "original": text,
        }

    return _guard
