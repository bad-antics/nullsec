"""NullSec WebTools — Configuration"""

import os
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent
NULLSEC_DIR = Path.home() / ".nullsec"
CLUSTER_DIR = NULLSEC_DIR / "cluster"
NODES_CONF = CLUSTER_DIR / "nodes.conf"

# Hak5 pineapple suite
HAK5_DIR = Path.home() / "nullsec" / "hak5-pineapple"
SUITE_DIR = HAK5_DIR / "nullsec-suite"
TOOLS_DIR = HAK5_DIR / "tools"
FIRMWARE_DIR = HAK5_DIR / "nullsec-firmware"

# Loot
LOOT_BASE = Path("/mmc/nullsec") if Path("/mmc/nullsec").exists() else NULLSEC_DIR / "loot"

# Web
APP_NAME = "NullSec WebTools"
APP_VERSION = "1.0.0"
SECRET_KEY = os.environ.get("NULLSEC_SECRET", os.urandom(32).hex())
DEBUG = os.environ.get("NULLSEC_DEBUG", "0") == "1"
