"""
NullSec Prompt Armor — AI Prompt Injection Defense Toolkit

A multi-layered defense system that detects, classifies, and neutralizes
prompt injection attacks against LLM-powered applications.

Detection layers:
  1. Lexical analysis   — pattern matching against known injection signatures
  2. Structural analysis — detects role hijacking, delimiter escapes, instruction overrides
  3. Entropy analysis    — flags abnormal token distributions (encoded payloads)
  4. Semantic drift      — measures how far user input drifts from expected topic
  5. Canary traps        — hidden markers that detect if the model was manipulated

Author: bad-antics / NullSec
License: MIT
"""

import re
import math
import json
import hashlib
import logging
import time
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
     r"(the\s+)?(system\s+)?(prompt|instructions?|rules?|guidelines?|context|message|configuration)", 0.85),
    (r"(?i)what\s+(are|were)\s+(your|the)\s+(original|initial|system|secret|hidden)\s+"
     r"(instructions?|prompt|rules?|guidelines?)", 0.8),
    (r"(?i)(give|tell|share)\s+(me\s+)?(the|your)\s+(system|secret|hidden|original)\s+"
     r"(prompt|instructions?|message|configuration)", 0.85),
    (r"(?i)translate\s+(the\s+)?(system\s+)?(prompt|instructions?)\s+(to|into)", 0.7),
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
# Sanitizer
# ═══════════════════════════════════════════════════════════════════════════════


def sanitize(text: str, aggressive: bool = False) -> str:
    """Remove or neutralize detected injection payloads from user input.

    Conservative mode (default): strip control chars, normalize delimiters
    Aggressive mode: also remove sentences containing injection keywords
    """
    # Strip null bytes and control characters
    sanitized = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)

    # Strip zero-width Unicode
    sanitized = re.sub(r"[\u200b\u200c\u200d\u2060\ufeff\u00ad]", "", sanitized)

    # Neutralize chat-template delimiters
    sanitized = re.sub(r"<\|?(system|im_start|im_end|endoftext|pad)\|?>", "[filtered]", sanitized, flags=re.I)
    sanitized = re.sub(r"\[INST\]|\[/INST\]|\[SYS\]|\[/SYS\]", "[filtered]", sanitized, flags=re.I)
    sanitized = re.sub(r"<<\s*/?SYS\s*>>", "[filtered]", sanitized, flags=re.I)

    # Neutralize persona markers at line starts
    sanitized = re.sub(r"^(system|assistant|user|human)\s*:", "[speaker]:", sanitized, flags=re.I | re.M)

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
) -> ArmorVerdict:
    """Run all detection layers against a text input and return a verdict.

    Args:
        text: The user input to analyze
        expected_topic: Optional topic hint for semantic drift detection
        aggressive_sanitize: If True, strip entire lines with injection patterns
        layers: Which layers to run (default: all). Options: lexical, structural, entropy, semantic

    Returns:
        ArmorVerdict with threat level, risk score, findings, and sanitized text
    """
    start = time.time()
    all_layers = layers or ["lexical", "structural", "entropy", "semantic"]
    findings: List[Finding] = []

    if "lexical" in all_layers:
        findings += lexical_scan(text)

    if "structural" in all_layers:
        findings += structural_scan(text)

    if "entropy" in all_layers:
        findings += entropy_scan(text)

    if "semantic" in all_layers:
        findings += semantic_drift_scan(text, expected_topic)

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
