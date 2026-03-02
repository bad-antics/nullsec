"""
🎪 nullsec-freakshow — The Freakshow Suite
30 weird & creepy security tools by bad-antics.
"""
__version__ = "2.0.0"
__author__ = "bad-antics"

TOOLS = [
    # ── Original 20 ──
    {"name": "sigil",        "package": "nullsec-sigil",        "emoji": "🔮", "desc": "Visual hash fingerprinting"},
    {"name": "dead-drop",    "package": "nullsec-dead-drop",    "emoji": "📦", "desc": "LSB steganography"},
    {"name": "miasma",      "package": "nullsec-miasma",      "emoji": "🎲", "desc": "Shannon entropy analyzer"},
    {"name": "temporal",     "package": "nullsec-temporal",     "emoji": "⏰", "desc": "Forensic timestamp analyzer"},
    {"name": "hexspeak",     "package": "nullsec-hexspeak",     "emoji": "🔢", "desc": "Hex word encoder/decoder"},
    {"name": "whisper",      "package": "nullsec-whisper",      "emoji": "👁️", "desc": "Spectral audio steganography"},
    {"name": "skinwalker",   "package": "nullsec-skinwalker",   "emoji": "🐺", "desc": "Process mimicry detector"},
    {"name": "ouija",        "package": "nullsec-ouija",        "emoji": "🔮", "desc": "File carving & recovery"},
    {"name": "eidolon",     "package": "nullsec-eidolon",     "emoji": "👻", "desc": "Ghost network packets"},
    {"name": "doppelganger", "package": "nullsec-doppelganger", "emoji": "👥", "desc": "File identity crisis detector"},
    {"name": "seance",       "package": "nullsec-seance",       "emoji": "🕯️", "desc": "Network necromancy"},
    {"name": "lamprey",     "package": "nullsec-lamprey",     "emoji": "🐟", "desc": "Dependency infection analyzer"},
    {"name": "voodoo",       "package": "nullsec-voodoo",       "emoji": "🪡", "desc": "Live process memory analysis"},
    {"name": "cryptid",      "package": "nullsec-cryptid",      "emoji": "🦎", "desc": "Hidden API & endpoint hunter"},
    {"name": "gremlin",     "package": "nullsec-gremlin",     "emoji": "👹", "desc": "Filesystem chaos agent"},
    {"name": "grimoire",     "package": "nullsec-grimoire",     "emoji": "📖", "desc": "Occult password generator"},
    {"name": "wendigo",      "package": "nullsec-wendigo",      "emoji": "🦌", "desc": "Resource devourer detector"},
    {"name": "harbinger",   "package": "nullsec-harbinger",   "emoji": "🔔", "desc": "Log scream detector"},
    {"name": "revenant",     "package": "nullsec-revenant",     "emoji": "🧟", "desc": "Zombie process hunter"},
    {"name": "necronomicon", "package": "nullsec-necronomicon", "emoji": "📕", "desc": "System dark assessment"},
    # ── New 10 ──
    {"name": "chimera",     "package": "nullsec-chimera",     "emoji": "🐉", "desc": "Binary polyglot structure validator"},
    {"name": "basilisk",    "package": "nullsec-basilisk",    "emoji": "🐍", "desc": "DNS resolver security audit"},
    {"name": "apparition",  "package": "nullsec-apparition",  "emoji": "👤", "desc": "Environment variable security audit"},
    {"name": "manticore",   "package": "nullsec-manticore",   "emoji": "🦂", "desc": "TLS/SSL certificate chain analyzer"},
    {"name": "ghoul",       "package": "nullsec-ghoul",       "emoji": "👹", "desc": "Shared library injection detector"},
    {"name": "lich",        "package": "nullsec-lich",        "emoji": "💀", "desc": "Kernel module & rootkit scanner"},
    {"name": "imp",         "package": "nullsec-imp",         "emoji": "😈", "desc": "Shell history auditor"},
    {"name": "shade",       "package": "nullsec-shade",       "emoji": "🌑", "desc": "File permission anomaly hunter"},
    {"name": "djinn",       "package": "nullsec-djinn",       "emoji": "🧞", "desc": "Container escape surface analyzer"},
    {"name": "mothman",     "package": "nullsec-mothman",     "emoji": "🦇", "desc": "Network promiscuity & ARP detector"},
]

__all__ = ["TOOLS"]
