"""
🎪 nullsec-freakshow — The Freakshow Suite
20 weird & creepy security tools by bad-antics.
"""
__version__ = "1.0.0"
__author__ = "bad-antics"

TOOLS = [
    {"name": "sigil",        "package": "nullsec-sigil",        "emoji": "🔮", "desc": "Visual hash fingerprinting"},
    {"name": "dead-drop",    "package": "nullsec-dead-drop",    "emoji": "📦", "desc": "LSB steganography"},
    {"name": "entropy",      "package": "nullsec-entropy",      "emoji": "📊", "desc": "Shannon entropy analyzer"},
    {"name": "temporal",     "package": "nullsec-temporal",     "emoji": "⏰", "desc": "Forensic timestamp analyzer"},
    {"name": "hexspeak",     "package": "nullsec-hexspeak",     "emoji": "🔢", "desc": "Hex word encoder/decoder"},
    {"name": "whisper",      "package": "nullsec-whisper",      "emoji": "👁️", "desc": "Spectral audio steganography"},
    {"name": "skinwalker",   "package": "nullsec-skinwalker",   "emoji": "🐺", "desc": "Process mimicry detector"},
    {"name": "ouija",        "package": "nullsec-ouija",        "emoji": "🔮", "desc": "File carving & recovery"},
    {"name": "phantom",      "package": "nullsec-phantom",      "emoji": "👻", "desc": "Ghost network packets"},
    {"name": "doppelganger", "package": "nullsec-doppelganger", "emoji": "👥", "desc": "File identity crisis detector"},
    {"name": "seance",       "package": "nullsec-seance",       "emoji": "🕯️", "desc": "Network necromancy"},
    {"name": "parasite",     "package": "nullsec-parasite",     "emoji": "🦠", "desc": "Dependency infection analyzer"},
    {"name": "voodoo",       "package": "nullsec-voodoo",       "emoji": "🪡", "desc": "Live process memory analysis"},
    {"name": "cryptid",      "package": "nullsec-cryptid",      "emoji": "🦎", "desc": "Hidden API & endpoint hunter"},
    {"name": "poltergeist",  "package": "nullsec-poltergeist",  "emoji": "👻", "desc": "Filesystem chaos agent"},
    {"name": "grimoire",     "package": "nullsec-grimoire",     "emoji": "📖", "desc": "Occult password generator"},
    {"name": "wendigo",      "package": "nullsec-wendigo",      "emoji": "🦌", "desc": "Resource devourer detector"},
    {"name": "banshee",      "package": "nullsec-banshee",      "emoji": "👻", "desc": "Log scream detector"},
    {"name": "revenant",     "package": "nullsec-revenant",     "emoji": "🧟", "desc": "Zombie process hunter"},
    {"name": "necronomicon", "package": "nullsec-necronomicon", "emoji": "📕", "desc": "System dark assessment"},
]

__all__ = ["TOOLS"]
