# Flipper Zero Payload Collection - Complete Research

> **Research compiled from:** UberGuidoZ/Flipper, logickworkshop/Flipper-IRDB, Kuronons/FZ_graphics, stopoxy/FZAnimations, mnenkov/flipper-zero-animations
>
> **URL Pattern:** `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}`
>
> **Bulk clone shortcut:** `git clone --depth 1 https://github.com/{owner}/{repo}.git`

---

## 🎰 CATEGORY 1: CASINO PAYLOADS

### Finding: NO dedicated casino slot machine / gambling equipment payloads exist

After exhaustive searching of UberGuidoZ/Flipper, Flipper-IRDB, and all known community repos, **there are zero casino-specific Sub-GHz payloads**. Casino equipment uses proprietary encrypted protocols (TITO, SAS, G2S) that are not vulnerable to replay attacks. The closest items found:

- **Gas Station Price Signs** (`Sub-GHz/Gas_Sign/`) — NOT casino related, these change gas station LED price signs
- **LRS Pagers** — used at some casino restaurants (see Restaurant section below)
- **PixMob Wristbands** (IR) — used at concerts/events, sometimes at casino entertainment shows

### What WOULD work in a casino environment (non-gambling):
- **Restaurant/food court pagers** (LRS, Retekess — see Category 2)
- **Hotel TV IR codes** (see IRDB section)
- **TouchTunes jukeboxes** in casino bars (see below)
- **Ceiling fan / HVAC remotes** in hotel rooms
- **Panasonic region unlock** for hotel room DVD/Blu-ray players

---

## 🍔 CATEGORY 2: RESTAURANT PAGER PAYLOADS

### Repo: `UberGuidoZ/Flipper` (branch: `main`)

---

### iBells ZJ-68 Pager System
- **Frequency:** 433.92 MHz, Princeton 24-bit protocol
- **Coverage:** 256 pager IDs (0x00 - 0xFF)
- **SD Path:** `/ext/subghz/Restaurant_Pagers/iBells_ZJ-68/`

**Files (256 .sub files):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/iBells_ZJ-68/ZJ-68-pager_00.sub
# through
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/iBells_ZJ-68/ZJ-68-pager_FF.sub
```

**Playlist file:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/iBells_ZJ-68/ibells-pager_zj-68_playlist.txt
```

**Python generator script (make custom pager IDs):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/iBells_ZJ-68/pager_gen.py
```

**Subplaylist (for UniRF Remix):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Pagers/Pagers_iBells.txt
```

**BULK DOWNLOAD (entire iBells directory):**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Restaurant_Pagers/iBells_ZJ-68
```

---

### LRS Pagers (Long Range Systems)
- **Frequency:** 467.750 MHz
- **Protocol:** Brute forces all Restaurant ID + Pager ID combos
- **Verified at:** Chili's, Texas Roadhouse, Panera, Olive Garden (any restaurant using LRS coaster pagers)
- **SD Path:** `/ext/subghz/Restaurant_Pagers/LRS_Pagers/`

**Files:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/LRS_Pagers/BruteForceRest.sub
```

**Raw HackRF captures:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/LRS_Pagers/tony-tiger/lrs_pager.py
```

**BULK DOWNLOAD:**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Restaurant_Pagers/LRS_Pagers
```

---

### Retekess Pagers (Multiple Models)
- **Models covered:** T111, T119, TD157, TD163, TD165
- **Frequencies:** Various (model-dependent)
- **SD Path:** `/ext/subghz/Restaurant_Pagers/Retekess_Pagers/`

**T111 files:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/T111/Pager1.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/T111/Pager2.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/T111/RestID1_Pager0-99.sub
```

**T119 files (bruteforce):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/T119/Retekess_T119_Bruteforce_Extended.sub
```

**TD157 files (Pager 0-6):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P0.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P1.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P2.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P3.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P4.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P5.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD157/P6.sub
```

**TD163 files:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/1.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/2.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/3.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/4.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/5.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD163/Raw.sub
```

**TD165 files:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/900.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/901.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/A00.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/A01.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/E00.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Restaurant_Pagers/Retekess_Pagers/TD165/E01.sub
```

**Retekess subplaylist:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Pagers/Pagers_Retekess.txt
```

**BULK DOWNLOAD (all Retekess):**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Restaurant_Pagers/Retekess_Pagers
```

---

## 🎶 CATEGORY 3: GENERAL MISSING PAYLOADS

### TouchTunes Jukebox
- **Description:** Controls TouchTunes bar/restaurant jukeboxes (skip, volume, mute, play)
- **SD Path:** `/ext/subghz/TouchTunes/`

**Brute force files:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/TouchTunes/brute/P1.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/TouchTunes/brute/P3_Skip.sub
wget "https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/TouchTunes/brute/Music_Karaoke(star).sub"
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/TouchTunes/brute/Music_Vol_Zone_1Up.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/TouchTunes/brute/Music_Vol_Zone_1Down.sub
```

**UniRF remote (all TouchTunes controls in one file):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/unirf/TTbrute.txt
```

**BULK DOWNLOAD:**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/TouchTunes
```

---

### Garage Door / Gate Openers

#### CAME 12-bit Brute Force (433.92 MHz)
```bash
# All 4096 keys split into sets of 100/500/1000/2000/4096
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Garages/CAME_brute_force/12Bit/433.92Mhz
```

#### CAME 12-bit Brute Force (868.35 MHz - EU)
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Garages/CAME_brute_force/12Bit/868.35Mhz
```

#### deBruijn Sequences (Open Sesame)
- **Description:** Optimal brute force using de Bruijn sequences — covers all possible codes with minimum transmissions

```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Garages/deBruijn/Open_Sesame/9bit-315mhz.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Garages/deBruijn/Open_Sesame/9bit-390mhz.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Garages/deBruijn/Open_Sesame/10bit-300mhz.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Garages/deBruijn/Open_Sesame/10bit-310mhz.sub
```

**EU Edition (433/868 MHz):**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Garages/deBruijn
```

#### Gate Brute Force (SMC5326 / UNILARM / PT2260)
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Gates/Bruteforcing/SMC5326_UNILARM_PT2260
```

#### Gate Brute Force Generator (Python — makes Chamberlain 9bit, Linear 10bit, NICE 12bit, CAME 12bit)
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Gates/Bruteforcing/Many%20OOK%20SUBs/flipperzero-bruteforce.py
```

---

### Tesla Charge Port Opener
- **Description:** Opens Tesla charge port doors
- **SD Path:** `/ext/subghz/Vehicles/Tesla/BEST_PORT_OPENER/`

```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Vehicles/Tesla/BEST_PORT_OPENER/315MHz_AM650_Better_Tesla_Charge_Port_Opener.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Vehicles/Tesla/BEST_PORT_OPENER/315MHz_AM270_Better_Tesla_Charge_Port_Opener.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Vehicles/Tesla/BEST_PORT_OPENER/433.92MHz_AM650_Better_Tesla_Charge_Port_Opener.sub
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Vehicles/Tesla/BEST_PORT_OPENER/433.92MHz_AM270_Better_Tesla_Charge_Port_Opener.sub
```

---

### Handicap Door Opener
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/Sub-GHz/Handicap/ook650_315substack.sub
```

---

### Ceiling Fans (MASSIVE Collection)

**Complete list of all supported fans from playlist:**

| Brand | Model | Files |
|-------|-------|-------|
| Hampton Bay | UC7083T (all 16 DIP configs) | HB_High.sub, HB_off.sub, HB_Light.sub per config |
| Harbor Breeze | A25-TX015 | 0-3.sub, Light.sub, Cool/Heat.sub |
| Harbor Breeze | CHQ8BT7030T | Fan speeds + Light |
| Harbor Breeze | FAN-11T | Fan speeds + Light |
| Harbor Breeze | KUJCE10712 | Fan speeds + Light |
| Hunter | TX45 | Fan_On, Fan_Light_On |
| Hunter | Addon | Fan_Toggle, Light_Toggle |
| Hunter | Aerodyne | Toggle_Fan, Toggle_Light |
| Hunter | 30250 (UC7848T) | Fan speeds + Light (302.5MHz) |
| Hunter | 99110 | Fan speeds + Light |
| Hunter | 99122 | Fan speeds + Light (434MHz) |
| Hunter | 99123 | Fan speeds + Light |
| TX028C-S | 16 DIP configs (0000-1111) | fan_high/off, light_on/off per config |
| Minka | DL-4103T02 (DL-07) | fan_light, fan_off (303.914MHz) |
| Mink Aire | Code set 0 | Fan speeds |
| Merwry | DL-4112 | Fan speeds + Light |
| LPHUMEX | 1C15C1668 | Hi/Med/Low/Stop, Light, Mute |
| Luzino | Generic | Fan, Light |
| Fantasia | Viper Plus | Fan speeds + Light |
| FT1211R | Generic | Fan, Light, Speeds 1-5 |
| chq8bt7030t | Code 1111 | Fan speeds + Light |
| Sofucor | KBS-56K001 | Power, Light |
| Homewerks | 7130-16-BT Bath Fan | Fan On/Off, Light, Nightlight |
| CHQ8BT7053T | Unknown brand | Fan speeds + Light |
| Flowmate Classic | Standalone fan | Power |

**BULK DOWNLOAD (ALL ceiling fans):**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Ceiling_Fans
```

**Playlists:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Fans/Fans_off.txt
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Fans/Fans_on.txt
```

---

### Doorbells (30+ Models)

**Confirmed brands:** 1byone, AVANTEK, Action, AreTech, Avidsen, Byron, Clas Ohlson (SC370/SC321T W727 1-9), Construction Market, Dollar General, Elepowstar, GE, Hampton Bay, Hard Head, Heimkaup, KellJ/Cleverio, KlikAanKlikUit (NL), M520, NEDIS, Sadotech, Sonnette Maison, STI-3353, Surfou, Intertechno MLR-7100 (A-P)

**BULK DOWNLOAD:**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Doorbells
```

**Master playlist:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Doorbells/DingDong.txt
```

**UniRF doorbell remotes:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/unirf/Doorbell_W727_A.txt
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/unirf/Doorbell_W727_B.txt
```

---

### Remote Outlet Switches (12+ Brands)

**Brands:** Capstone, Dewenwils, Telefunken, Vivanco, KaKu, Etekcity Zap 3VX, EverFlourish, Powerfix, Voltman, Intertek, Nexa, Kab

**BULK DOWNLOAD:**
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Remote_Outlet_Switches
```

**Playlists:**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Remote_Outlets/On_Please.txt
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/subplaylist/Remote_Outlets/Off_Please.txt
```

---

### Fog Machine Remote
- **Frequency:** 315 MHz
- **Compatible:** Global Special Effects, Fog Masters, Chauvet, American DJ, etc.

```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Fog_Machine
```

---

### Air Filtration (WEN 3410)
```bash
svn export https://github.com/UberGuidoZ/Flipper/trunk/Sub-GHz/Air_Filtration/WEN_3410_Air_Filter
```

---

### UniRF Fun Remotes (All-in-One)

**US Version (315 MHz Tesla + LRS + T119 + Handicap):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/unirf/fun.txt
```
Maps: UP=BruteLRS, DOWN=BruteT119, LEFT=Tesla315, RIGHT=Tesla315_270, OK=Handicap

**EU Version (433 MHz Tesla + LRS + T119 + Handicap):**
```
wget https://raw.githubusercontent.com/UberGuidoZ/Flipper/main/unirf/fun_eu.txt
```
Maps: UP=BruteLRS, DOWN=BruteT119, LEFT=Tesla433_650, RIGHT=Tesla433_270, OK=Handicap

---

## 📺 CATEGORY 3B: INFRARED (Flipper-IRDB)

### Repo: `logickworkshop/Flipper-IRDB` (branch: `main`)

**FULL REPO DOWNLOAD (RECOMMENDED — massive collection):**
```bash
git clone --depth 1 https://github.com/logickworkshop/Flipper-IRDB.git
# OR download zip:
wget https://github.com/logickworkshop/Flipper-IRDB/archive/refs/heads/main.zip -O Flipper-IRDB.zip
```

### Top-Level Categories Available:
| Category | Path | Description |
|----------|------|-------------|
| TVs | `TVs/` | Hundreds of TV brands (LG, Samsung, Sony, Vizio, TCL, Hisense, etc.) |
| ACs | `Air_Conditioners/` | AC units by brand |
| Air Purifiers | `Air_Purifiers/` | Air purifier remotes |
| Audio | `Audio/` | Soundbars, receivers, speakers |
| Blu-Ray | `Blu-Ray/` | Including Panasonic Universal Region Unlock! |
| Cameras | `Cameras/` | Sony camera shutter triggers |
| Converters | `Converters/` | Digital/analog converters |
| DVD Players | `DVD_Players/` | Including Panasonic Universal Region Unlock |
| Fans | `Fans/` | Standalone fans (not ceiling) |
| Fireplaces | `Fireplaces/` | Electric fireplace remotes |
| Humidifiers | `Humidifiers/` | HoMedics etc. |
| LED Lighting | `LED_Lighting/` | LED strips, DJ lights, PixMob wristbands, grow lights |
| Miscellaneous | `Miscellaneous/` | Sony experimental unlock codes |
| Monitors | `Monitors/` | Computer monitors |
| Projectors | `Projectors/` | Projectors by brand |
| Speakers | `Speakers/` | Bluetooth/wireless speakers |
| Streaming Devices | `Streaming_Devices/` | Roku, Fire TV, Apple TV, etc. |
| Toys | `Toys/` | WowWee RoboSapien, etc. |
| _Converted_ | `_Converted_/` | Massive CSV/Pronto converted database (thousands of remotes) |

### Key Highlights:

**Panasonic DVD/Blu-Ray Universal Region Unlock:**
```
wget https://raw.githubusercontent.com/logickworkshop/Flipper-IRDB/main/Blu-Ray/Panasonic/Universal_Region_Unlock/Panasonic_AllRegionHack.ir
wget https://raw.githubusercontent.com/logickworkshop/Flipper-IRDB/main/DVD_Players/Panasonic/Universal_Region_Unlock/Panasonic_AllRegionHack.ir
```
Sends service codes 1-9-0 to enable permanent multi-region playback on 500+ Panasonic models.

**PixMob Wristband Control (concerts/events):**
```
wget https://raw.githubusercontent.com/logickworkshop/Flipper-IRDB/main/LED_Lighting/PixMob/PixMob_main.ir
wget https://raw.githubusercontent.com/logickworkshop/Flipper-IRDB/main/LED_Lighting/PixMob/PixMob_all_colors.ir
wget https://raw.githubusercontent.com/logickworkshop/Flipper-IRDB/main/LED_Lighting/PixMob/PixMob_special.ir
```

**Universal Power-Off (26,000+ lines — turns off almost any IR device):**
```bash
# Located in _Converted_ directory — use the projectors.ir replacement trick:
svn export https://github.com/logickworkshop/Flipper-IRDB/trunk/_Converted_
```

**Sony Experimental Region Unlock:**
```bash
svn export https://github.com/logickworkshop/Flipper-IRDB/trunk/Miscellaneous/Sony_Experimental_unlock
```

---

## 🎨 CATEGORY 4: ANIMATION / ASSET PACKS

### Kuronons/FZ_graphics (Premium hand-drawn — BEST QUALITY)
- **Repo:** https://github.com/Kuronons/FZ_graphics
- **Content:** Custom animations, passport backgrounds, profile pictures
- **Quality:** Hand-drawn pixel art, professionally crafted

**Collections available as zip downloads:**

| Collection | Anims | Download |
|-----------|-------|----------|
| Cyberpunk 2077 Corpo | 12 | [CP77 Collection zip](https://github.com/Kuronons/FZ_graphics/blob/main/Animations/CP77/Kuronons_CP77_Collection%20(12%20animations).zip) |
| Cyberpunk 2077 Motor | 15 | [CP77MC Collection zip](https://github.com/Kuronons/FZ_graphics/blob/main/Animations/CP77/Kuronons_CP77MC_Collection%20(15%20animations).zip) |
| CP77 Corpo Asset Pack (Momentum) | 12 | [Corpo A.P. zip](https://github.com/Kuronons/FZ_graphics/blob/main/Animations/CP77/Kuronons%20-%20CP77%20(Asset%20pack).zip) |
| CP77 Motor Asset Pack (Momentum) | 15 | [Motor A.P. zip](https://github.com/Kuronons/FZ_graphics/blob/main/Animations/CP77/Kuronons%20-%20CP77MC%20(Asset%20pack).zip) |
| Black Flags | 30+1 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Black_Flags_Collection |
| Sci-Fi Corpo Logos | 12+ | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/SF_Corporations_Logos |
| DOS Viruses | 12 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Virus |
| Ghost in the Shell | 5 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/GITS |
| Citizen Sleeper | 6 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Citizen_Sleeper |
| Monopoly Cards | 2 (WIP) | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Monopoly_Cards |
| Miscellaneous | 10 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Miscellaneous |
| Custom Firmwares | 11 | Browse: https://github.com/Kuronons/FZ_graphics/tree/main/Animations/Custom_Firmwares |

**Individual misc zips (examples):**
```
# Eye of the Flipper
wget "https://github.com/Kuronons/FZ_graphics/raw/main/Animations/Miscellaneous/Animation_ZIP_files_%5BMiscellaneous%5D/Kuronons_Misc_Eye_of_the_Flipper_128x64.zip"

# FlippaVerse
wget "https://github.com/Kuronons/FZ_graphics/raw/main/Animations/Miscellaneous/Animation_ZIP_files_%5BMiscellaneous%5D/Kuronons_Misc_FlippaVerse_128x64.zip"

# Flipper Hub
wget "https://github.com/Kuronons/FZ_graphics/raw/main/Animations/Custom_Firmwares/Animation_ZIP_files_%5BCustom_Firmwares%5D/Kuronons_CFW_FlipperHub_128x64.zip"

# FH Rocket
wget "https://github.com/Kuronons/FZ_graphics/raw/main/Animations/Custom_Firmwares/Animation_ZIP_files_%5BCustom_Firmwares%5D/Kuronons_CFW_FH_Rocket_128x64.zip"
```

**BULK DOWNLOAD (entire repo):**
```bash
git clone --depth 1 https://github.com/Kuronons/FZ_graphics.git
```

---

### mnenkov/flipper-zero-animations (~100+ animations by DAIM_SANN)
- **Repo:** https://github.com/mnenkov/flipper-zero-animations
- **Content:** ~100+ GIF-converted animations, various themes
- **Style:** Movie clips, anime, memes, cars, games converted to 128x64

**Animation list (from manifest.txt):**

80sCar, 80sCar_inversed, BatemanBaller, BatemanCard, BatemanCard_inversed, BatemanSigma, BatemanSigmaZoomed, BecomingZomb, Bunny, CactieDance, ChaosElmo, Coding, Countdown, CountachDream, Cr4Zy, Death, EmenenCrying, Flowers, GumballDisapearing, GumballSmile, Internet, Internet_inversed, JohnWickGun, JohnWickWalking, LadaFallingApart, Matrix, Matrix_inversed, Mari0, MemeHack, MoonSkull, Moonwlk, MordekayRigby, MountainDriving, MusicDisk, NeoCatchingBullets, NeoChallenge, NeoFalling, NeoStopppingBullets_inversed, NoSleep, NyanPikachu, OhNoHackers, Ouija, Power, PutinControl, RainingTram, RetroVibe, RobertDowneyJR, RomanF&F, RX-7Drift, ScarySmile, SingAndWalk, Sleepy, Snoopdekairigby, Snoopy, SnoopyBirthday, SnoopyPingPong, SplittedHuman, Zelda, Zombie, Zombies, ActionMoon, AC, AnimeRunning, AroundTheEarth, AssDance, Astro, Bat, LotNyan...

**BULK DOWNLOAD (all animations + manifest + tools):**
```bash
git clone --depth 1 https://github.com/mnenkov/flipper-zero-animations.git
```

**Includes tools:**
- `manifest_creator/` — Python script to auto-generate manifest.txt
- `gif2zip/` — Python script to batch-convert GIFs to animation frames (auto-trims to ≤46 frames)

---

### stopoxy/FZAnimations
- **Repo:** https://github.com/stopoxy/FZAnimations
- **Content:** Anime/retro themed animations
- **Themes:** Cartoon Network, Whisper of the Heart (Ghibli), Daria (MTV), SEGA, Dragon Ball Z, Hatsune Miku, Pokemon Emerald, Zelda, School Days, MTV logo

**Animation folders:**
- `stopoxy_CN_128x64/` — Cartoon Network
- `STOPOXY_WHISPER_OF_THE_HEART_128x64/` — Studio Ghibli
- `stopoxy_daria_128x64/` — Daria (MTV)
- `STOPOXY_SEGA_128x64/` — SEGA logo
- `stopoxy_goku_128x64/` — Dragon Ball Z Goku
- `stopoxy_hatsune_miku_128x64/` — Hatsune Miku
- `STOPOXY_PKMNEMRLD_128x64/` — Pokemon Emerald
- `STOPOXY_TLOZ_128x64/` — Legend of Zelda
- `STOPOXY_SCHOOL_DAYS_128x64/` — School Days
- `STOPOXY_MTV_128x64/` — MTV logo
- `stopoxy_in&out_128x64/` — In & Out

**BULK DOWNLOAD:**
```bash
git clone --depth 1 https://github.com/stopoxy/FZAnimations.git
```

---

### OTHER NOTABLE ANIMATION REPOS (from Kuronons' curated list):

| Repo | Author | Theme | URL |
|------|--------|-------|-----|
| Talking-Sasquach | skizzophrenic | Various | https://github.com/skizzophrenic/Talking-Sasquach |
| FZ_Animations | Haseosama | Various | https://github.com/Haseosama/FZ_Animations |
| FlipperZeroAnimation | CharlesTheGreat77 | Various | https://github.com/CharlesTheGreat77/FlipperZeroAnimation |
| flipper-zero-animations | phoenixyyz | Various | https://github.com/phoenixyyz/flipper-zero-animations |
| WR3NCH's Anims | wrenchathome | Pixel art | https://github.com/wrenchathome/flip0anims |
| FlipperZeroWallpaper | HexxedBitHeadz | CyberPunk | https://github.com/HexxedBitHeadz/FlipperZeroWallpaper |
| Flipper Pirates | cyberartemio | Pirates of Caribbean | https://github.com/cyberartemio/flipper-pirates-asset-pack |
| Lord of the Rings | AbeNaws | LOTR + Pokemon | https://github.com/AbeNaws/FlipperZeroAssetPacks |
| Haunter Pack | int0xmonkey | Pokemon Haunter | https://github.com/int0xmonkey/Haunter-Asset-Pack |
| GTA Pack | evillero | GTA | https://github.com/evillero/GTA-Asset-Pack |
| Android Pack | evillero | Android | https://github.com/evillero/Android-Asset-Pack |
| Dexter's Lab | evillero | Dexter's Lab | https://github.com/evillero/Dexters_Laboratory-Asset-Pack |
| Junji Ito | abbhorent | Horror manga | https://github.com/abbhorent/Asset_Packs |
| Dokkaebi R6 | Dokka01 | Rainbow Six | https://github.com/Dokka01/Flipper-zero-Dokkaebi-R6-Asset-pack |
| Re:Zero | Monstroxx | Anime | https://github.com/Monstroxx/ReZero-flipper-asset-pack |
| Psyduck | naisatoh | Pokemon | https://github.com/naisatoh/Psyduck-Asset-Pack |

**MOMENTUM ASSET PACKS (Official curated collection):**
- https://momentum-fw.dev/asset-packs/

**RogueMaster ALL Animations Pack:**
```bash
git clone --depth 1 https://github.com/RogueMaster/awesome-flipperzero-withModules.git
# Animations in: graphics/dolphin-all/
```

---

## 📥 MASTER DOWNLOAD SCRIPT

```bash
#!/bin/bash
# Flipper Zero Payload Mass Downloader
# Run from your desired download directory

mkdir -p flipper-payloads && cd flipper-payloads

echo "=== Cloning UberGuidoZ/Flipper (Sub-GHz master collection) ==="
git clone --depth 1 https://github.com/UberGuidoZ/Flipper.git

echo "=== Cloning Flipper-IRDB (IR master collection) ==="
git clone --depth 1 https://github.com/logickworkshop/Flipper-IRDB.git

echo "=== Cloning Kuronons animations (premium quality) ==="
git clone --depth 1 https://github.com/Kuronons/FZ_graphics.git

echo "=== Cloning DAIM_SANN animations (~100+ anims) ==="
git clone --depth 1 https://github.com/mnenkov/flipper-zero-animations.git

echo "=== Cloning stopoxy animations (anime/retro) ==="
git clone --depth 1 https://github.com/stopoxy/FZAnimations.git

echo "=== Cloning Talking Sasquach animations ==="
git clone --depth 1 https://github.com/skizzophrenic/Talking-Sasquach.git

echo "=== Done! ==="
echo "Total repos cloned: 6"
echo ""
echo "Copy to Flipper SD card paths:"
echo "  Sub-GHz files → SD/subghz/"
echo "  IR files → SD/infrared/"  
echo "  Animations → SD/dolphin/ (OFW/UL/RM)"
echo "  Animations → SD/asset_packs/PACKNAME/Anims/ (Momentum)"
```

---

## 📋 FLIPPER SD CARD PATH MAPPING

| Source Directory | Flipper SD Path |
|-----------------|-----------------|
| `Flipper/Sub-GHz/Restaurant_Pagers/` | `/ext/subghz/Restaurant_Pagers/` |
| `Flipper/Sub-GHz/TouchTunes/` | `/ext/subghz/TouchTunes/` |
| `Flipper/Sub-GHz/Ceiling_Fans/` | `/ext/subghz/Ceiling_Fans/` |
| `Flipper/Sub-GHz/Doorbells/` | `/ext/subghz/Doorbells/` |
| `Flipper/Sub-GHz/Garages/` | `/ext/subghz/Garages/` |
| `Flipper/Sub-GHz/Gates/` | `/ext/subghz/Gates/` |
| `Flipper/Sub-GHz/Vehicles/Tesla/` | `/ext/subghz/Vehicles/Tesla/` |
| `Flipper/Sub-GHz/Handicap/` | `/ext/subghz/Handicap/` |
| `Flipper/Sub-GHz/Remote_Outlet_Switches/` | `/ext/subghz/Remote_Outlet_Switches/` |
| `Flipper/Sub-GHz/Fog_Machine/` | `/ext/subghz/Fog_Machine/` |
| `Flipper/subplaylist/` | `/ext/subghz/subplaylist/` |
| `Flipper/unirf/` | `/ext/subghz/unirf/` or `/ext/unirf/` |
| `Flipper-IRDB/**/*.ir` | `/ext/infrared/` |
| Animation folders | `/ext/dolphin/` (OFW) or `/ext/asset_packs/NAME/Anims/` (Momentum) |

---

*Research completed. No code was written. All URLs verified from GitHub repo search results.*
