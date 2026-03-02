"""
Grimoire Engine — The Dark Book of Password Arts.
Generates occult-themed passwords, passphrases, and credential sets.
Analyzes password strength using entropy and pattern detection.
"""

import os
import hashlib
import math
import secrets
import string
from typing import List, Dict, Optional

# The Dark Lexicon — words for passphrase generation
DARK_NOUNS = [
    "abyss", "altar", "banshee", "basilisk", "blight", "blood", "bone",
    "cauldron", "cinder", "coffin", "corpse", "coven", "crypt", "daemon",
    "darkness", "death", "demon", "dirge", "doom", "dread", "eclipse",
    "ember", "fang", "fear", "flame", "ghost", "ghoul", "grave", "grim",
    "hex", "horror", "howl", "inferno", "jinx", "karma", "lich", "lurker",
    "malice", "miasma", "midnight", "moon", "nectar", "night", "oblivion",
    "omen", "oracle", "pact", "plague", "phantom", "poison", "portal",
    "reaper", "relic", "ritual", "rune", "shadow", "shroud", "sigil",
    "skull", "sorcery", "soul", "specter", "spider", "spirit", "storm",
    "thorn", "tomb", "toxin", "undead", "venom", "void", "vortex",
    "warden", "whisper", "witch", "wolf", "wraith", "wrath", "zombie",
]

DARK_ADJECTIVES = [
    "abyssal", "ancient", "arcane", "ashen", "baleful", "bitter", "black",
    "blighted", "bloody", "burning", "chaotic", "cold", "crimson", "cruel",
    "cursed", "dark", "dead", "deathly", "deep", "dire", "dread", "ebon",
    "eldritch", "eternal", "fallen", "fatal", "fell", "feral", "fierce",
    "forsaken", "frozen", "ghastly", "grim", "grisly", "haunted", "hollow",
    "howling", "iron", "jagged", "lost", "mad", "malign", "morbid",
    "necrotic", "nether", "obsidian", "pallid", "profane", "putrid",
    "raging", "rotten", "ruined", "sacred", "savage", "scarlet", "secret",
    "shadow", "shattered", "silent", "sinister", "spectral", "stark",
    "twisted", "unholy", "vile", "wicked", "wild", "withered", "wretched",
]

DARK_VERBS = [
    "binds", "bleeds", "burns", "consumes", "corrupts", "crawls", "curses",
    "decays", "destroys", "devours", "drowns", "echoes", "endures", "engulfs",
    "festers", "haunts", "howls", "hunts", "infects", "lurks", "poisons",
    "reaps", "rises", "rots", "screams", "seethes", "shadows", "shatters",
    "slithers", "smolders", "stalks", "stings", "strikes", "suffers",
    "swallows", "taints", "tears", "trembles", "twists", "wails", "wanders",
    "watches", "withers", "writhes",
]

# Leet speak substitution map for the dark arts
DARK_LEET = {
    'a': ['@', '4', 'Λ'], 'e': ['3', '€', 'Ξ'], 'i': ['1', '!', '¡'],
    'o': ['0', 'Ø', 'θ'], 's': ['$', '5', '§'], 't': ['7', '†', '+'],
    'l': ['1', '|', 'ℓ'], 'b': ['8', 'ß'], 'g': ['9', 'ğ'],
    'c': ['(', '¢'], 'h': ['#', 'ħ'], 'n': ['π', 'η'],
}


def conjure_password(length: int = 24, style: str = "chaos") -> Dict:
    """Conjure a password from the dark arts."""
    if style == "chaos":
        # Pure random chaos
        chars = string.ascii_letters + string.digits + "!@#$%^&*()-_=+[]{}|;:,.<>?"
        password = ''.join(secrets.choice(chars) for _ in range(length))

    elif style == "hex":
        # Hexadecimal darkness
        password = secrets.token_hex(length // 2)

    elif style == "rune":
        # Unicode rune-style password
        runes = "ᚠᚢᚦᚨᚱᚲᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛗᛚᛜᛞᛟ"
        extras = string.digits + "!@#$"
        password = ''.join(secrets.choice(runes + extras) for _ in range(length))

    elif style == "sigil":
        # Mixed sigil/ASCII
        sigils = "⛧⛤☠☽☾⚔🗡🔮🕯💀👁🌑"
        ascii_chars = string.ascii_letters + string.digits
        password = ''.join(secrets.choice(sigils + ascii_chars) for _ in range(length))

    elif style == "leet":
        # Dark leet speak passphrase
        words = [secrets.choice(DARK_NOUNS) for _ in range(3)]
        password = '-'.join(words)
        # Apply dark leet
        new_pass = ""
        for char in password:
            if char.lower() in DARK_LEET and secrets.randbelow(3) == 0:
                new_pass += secrets.choice(DARK_LEET[char.lower()])
            else:
                new_pass += char
        password = new_pass

    else:
        password = secrets.token_urlsafe(length)

    entropy = _calc_password_entropy(password)

    return {
        "password": password,
        "style": style,
        "length": len(password),
        "entropy_bits": entropy,
        "strength": _rate_strength(entropy),
        "hash_sha256": hashlib.sha256(password.encode('utf-8')).hexdigest(),
    }


def conjure_passphrase(words: int = 5, separator: str = "-",
                       capitalize: bool = True,
                       include_number: bool = True) -> Dict:
    """Conjure a dark passphrase from the grimoire."""
    chosen = []
    # Pattern: adj-noun-verb-adj-noun
    pattern = ["adj", "noun", "verb", "adj", "noun"] * ((words // 5) + 1)

    for i in range(words):
        word_type = pattern[i % len(pattern)]
        if word_type == "adj":
            word = secrets.choice(DARK_ADJECTIVES)
        elif word_type == "verb":
            word = secrets.choice(DARK_VERBS)
        else:
            word = secrets.choice(DARK_NOUNS)

        if capitalize:
            word = word.capitalize()
        chosen.append(word)

    passphrase = separator.join(chosen)

    if include_number:
        passphrase += separator + str(secrets.randbelow(9999))

    entropy = _calc_password_entropy(passphrase)

    return {
        "passphrase": passphrase,
        "words": words,
        "entropy_bits": entropy,
        "strength": _rate_strength(entropy),
        "hash_sha256": hashlib.sha256(passphrase.encode('utf-8')).hexdigest(),
    }


def analyze_password(password: str) -> Dict:
    """Analyze a password — how strong is this incantation?"""
    analysis = {
        "password": password[:3] + "*" * (len(password) - 3),
        "length": len(password),
        "entropy_bits": _calc_password_entropy(password),
    }

    # Character class analysis
    has_lower = bool(set(password) & set(string.ascii_lowercase))
    has_upper = bool(set(password) & set(string.ascii_uppercase))
    has_digit = bool(set(password) & set(string.digits))
    has_special = bool(set(password) - set(string.ascii_letters + string.digits))

    analysis["char_classes"] = sum([has_lower, has_upper, has_digit, has_special])
    analysis["has_lower"] = has_lower
    analysis["has_upper"] = has_upper
    analysis["has_digit"] = has_digit
    analysis["has_special"] = has_special

    # Pattern detection
    analysis["weaknesses"] = []

    # Repeated characters
    for i in range(len(password) - 2):
        if password[i] == password[i + 1] == password[i + 2]:
            analysis["weaknesses"].append(f"Triple repeat: '{password[i]}' × 3")
            break

    # Sequential characters
    for i in range(len(password) - 2):
        if (ord(password[i]) + 1 == ord(password[i + 1]) and
                ord(password[i + 1]) + 1 == ord(password[i + 2])):
            analysis["weaknesses"].append("Sequential characters detected")
            break

    # Common patterns
    common_patterns = ["password", "123456", "qwerty", "admin", "letmein"]
    for pat in common_patterns:
        if pat in password.lower():
            analysis["weaknesses"].append(f"Contains common pattern: '{pat}'")

    analysis["strength"] = _rate_strength(analysis["entropy_bits"])

    # Crack time estimation (rough)
    combinations = 2 ** analysis["entropy_bits"]
    attempts_per_sec = 10_000_000_000  # 10B/s (GPU-based)
    seconds = combinations / attempts_per_sec
    analysis["crack_time"] = _human_time(seconds)

    return analysis


def generate_credential_set(count: int = 5) -> List[Dict]:
    """Generate a full set of dark credentials."""
    creds = []
    for i in range(count):
        user_adj = secrets.choice(DARK_ADJECTIVES)
        user_noun = secrets.choice(DARK_NOUNS)
        username = f"{user_adj}_{user_noun}_{secrets.randbelow(999)}"

        pw = conjure_password(length=secrets.choice([16, 20, 24, 32]))

        creds.append({
            "id": i + 1,
            "username": username,
            "password": pw["password"],
            "entropy": pw["entropy_bits"],
            "strength": pw["strength"],
        })

    return creds


def _calc_password_entropy(password: str) -> float:
    charset_size = 0
    chars = set(password)
    if chars & set(string.ascii_lowercase): charset_size += 26
    if chars & set(string.ascii_uppercase): charset_size += 26
    if chars & set(string.digits): charset_size += 10
    if chars - set(string.ascii_letters + string.digits): charset_size += 33

    if charset_size == 0:
        return 0.0
    return round(len(password) * math.log2(max(charset_size, 2)), 1)


def _rate_strength(entropy: float) -> str:
    if entropy >= 128: return "🟣 TRANSCENDENT"
    if entropy >= 80: return "🔴 FORTRESS"
    if entropy >= 60: return "🟠 STRONG"
    if entropy >= 40: return "🟡 MODERATE"
    if entropy >= 20: return "🟢 WEAK"
    return "⚪ PATHETIC"


def _human_time(seconds: float) -> str:
    if seconds < 1: return "instant"
    if seconds < 60: return f"{seconds:.0f} seconds"
    if seconds < 3600: return f"{seconds / 60:.0f} minutes"
    if seconds < 86400: return f"{seconds / 3600:.0f} hours"
    if seconds < 86400 * 365: return f"{seconds / 86400:.0f} days"
    if seconds < 86400 * 365 * 1000: return f"{seconds / (86400 * 365):.0f} years"
    if seconds < 86400 * 365 * 1e9: return f"{seconds / (86400 * 365 * 1e6):.0f} million years"
    return "heat death of universe"
