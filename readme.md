<div align="center">

# 🏢 FS25 Workplace Triggers
### *Placeable Off-Farm Work System*

[![Downloads](https://img.shields.io/github/downloads/TheCodingDad-TisonK/FS25_WorkplaceTriggers/total?style=for-the-badge&logo=github&color=4caf50&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases)
[![Release](https://img.shields.io/github/v/release/TheCodingDad-TisonK/FS25_WorkplaceTriggers?style=for-the-badge&logo=tag&color=76c442&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases/latest)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-lightgrey?style=for-the-badge&logo=creativecommons&logoColor=white)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

<br>

> *"I've always wanted to 'work' at the post office on Judith Plains, but there was no way to make it official. This mod makes those little roleplay moments count with real income."*

<br>

**Turn any location on any map into a legitimate workplace.** Place a trigger zone, give it a name and an hourly wage, walk inside, and clock in. Wages accumulate in real in-game time and deposit directly into your farm account when you clock out. No missions. No deliveries. No vehicles required. Just show up, press E, and get paid.

`Singleplayer` • `Multiplayer (host-authoritative)` • `Persistent saves` • `EN / DE / FR / IT / NL / PL`

</div>

> [!TIP]
> Want to be part of our community? Share tips, report issues, and chat with other farmers on the **[FS25 Modding Community Discord](https://discord.gg/Th2pnq36)**!

---

## ✨ Features

### 🏗️ Placeable Trigger Zones

Buy the **Work Trigger Zone** from the shop and place it anywhere on any map.

| | Feature | Description |
|---|---|---|
| 📍 | **Place anywhere** | Any map, any location — use the standard FS25 placement system |
| 🔤 | **Custom name** | Name each workplace anything you like — Post Office, Lumber Yard, Feed Mill |
| 💰 | **Configurable wage** | Set hourly wages from $0 to $99,999 per in-game hour |
| 📏 | **Adjustable radius** | Trigger zone size from 1 m to 50 m to fit any location |
| 💾 | **Full persistence** | All workplace data saves with your career and restores on reload |

### ⏱️ Shift Tracking

| | Feature | Description |
|---|---|---|
| ⏱️ | **In-game time wages** | Earnings scale with FS25 time speed — faster time = faster pay |
| 📊 | **Live HUD panel** | Shows workplace, elapsed time, and current earnings while on shift |
| ⚠️ | **Grace period** | 10-second warning countdown before a shift auto-cancels if you wander off |
| 💵 | **Instant payout** | Wages deposit into your farm account the moment you clock out |

### 🗺️ Map Integration

| | Feature | Description |
|---|---|---|
| 🟩 | **Map icons** | Each workplace gets a coloured icon on both the mini-map and full map |
| 🟡 | **Active highlight** | Icon turns gold while a shift is running at that location |
| 🏷️ | **Name labels** | Workplace names shown directly on the map — no guessing which icon is which |

### ⚙️ Settings & HUD Customisation

- Global **Wage Multiplier** (0.5x – 2.0x) to tune overall income without editing each trigger
- Drag and resize the **shift HUD panel** with Left Shift + mouse
- Toggle the earnings row, notifications, and automatic shift-cancel on zone leave

---

## ⚙️ Settings

Open via **ESC → Settings → General Settings → Workplace Triggers**.

| Setting | Options | Notes |
|---|---|---|
| **Show Shift HUD** | On / Off | Toggle the shift info panel entirely |
| **HUD Scale** | 0.75x / 1.0x / 1.25x / 1.5x / 2.0x | Preset size for the HUD panel |
| **Show Notifications** | On / Off | Flash messages on shift start and end |
| **Wage Multiplier** | 0.5x / 0.75x / 1.0x / 1.25x / 1.5x / 2.0x | Applied on top of every trigger's wage |
| **End Shift on Leave** | On / Off | Auto-cancel shift when leaving the trigger zone |
| **Show Earnings in HUD** | On / Off | Show the current earnings row in the panel |
| **Debug Mode** | On / Off | Verbose logging to `log.txt` for troubleshooting |

> [!NOTE]
> Settings are saved **per savegame** in `workplace_triggers_settings.xml` inside your save folder.

---

## 🛠️ Installation

**1. Download** `FS25_WorkplaceTriggers.zip` from the [latest release](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases/latest).

**2. Copy** the ZIP (do not extract) to your mods folder:

| Platform | Path |
|---|---|
| 🪟 Windows | `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods\` |
| 🍎 macOS | `~/Library/Application Support/FarmingSimulator2025/mods/` |

**3. Enable** *Workplace Triggers* in the in-game mod manager.

**4. Load** any career save — the mod activates automatically.

---

## 🎮 Quick Start

```
1. Open the shop (B) → Objects → Work Trigger Zone → Buy and place it
2. Press F4 → Workplace Manager → select your new trigger → Edit
3. Type a name, set a wage, adjust the radius, confirm
4. Walk to the trigger location — an action prompt appears at the bottom of the screen
5. Press E  →  shift starts, HUD panel opens, earnings accumulate
6. Press E again inside the zone  →  shift ends, wages paid to your farm account
```

> [!TIP]
> Open **ESC → Help → Workplace Triggers** for a full in-game guide covering every feature in detail.

---

## ⌨️ Key Bindings

| Key | Action |
|---|---|
| `E` *(inside trigger zone)* | Start or end a shift |
| `F4` | Open / close the Workplace Manager |
| `Left Shift` | Toggle HUD Edit Mode (drag and resize the panel) |

All bindings can be remapped in **ESC → Settings → Controls**.

---

## 🖥️ Console Commands

Open the developer console with the **`~`** key (developer mode required):

| Command | Description |
|---|---|
| `wtHelp` | List all available Workplace Triggers commands |
| `wtStatus` | Show current shift status: workplace, elapsed time, earnings |
| `wtList` | Print all placed workplace triggers to the console |
| `wtDebug` | Toggle verbose debug logging |
| `wtGui` | Open or close the Workplace Manager from the console |

---

## 🗂️ How Earnings Are Calculated

Wages use **in-game time**, not real-world clock time. By default, one real second equals one in-game minute in FS25, so a one in-game hour shift takes 60 real seconds. If you increase the time speed in settings, shifts pay out proportionally faster.

```
payout = hourlyWage × inGameHoursWorked × wageMultiplier
```

**Example:** A $500/hr workplace, 2 in-game hours, 1.5x multiplier → **$1,500 payout**

Fractions of an hour count: a 30-minute in-game shift at $500/hr pays **$250**.

---

## 🗺️ Managing Workplaces

Press **F4** at any time to open the **Workplace Manager**.

- **New Trigger** — opens the Edit dialog with position snapped to your current location
- **Edit** — change name, wage, and radius; changes apply immediately
- **Delete** — removes the trigger; if a shift is active, you are paid first before removal

> [!IMPORTANT]
> The **Work Trigger Zone placeable** (the i3d object in the world) and the **trigger data entry** in the Manager are separate. If you sell the placeable from the construction menu, the Manager entry remains until you also delete it there. For a clean removal: **delete in the Manager first, then sell the placeable**.

---

## ⚠️ Known Limitations

| Issue | Details |
|---|---|
| 🎨 **Placeholder 3D marker** | The floating marker above trigger zones uses a shared shopping icon from the base game. Custom art is planned for a future release. |
| 🌐 **Multiplayer** | Shift state is per-player. Workplace placement and configuration is host-authoritative. Clients can start and end shifts freely at any configured location. |
| 🔄 **Radius not resized live** | Changing trigger radius in the Edit dialog updates saved data and zone-check logic immediately, but the visual ground ring on the placeable reflects the radius set at placement time. |

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, code standards, and the PR checklist.

Found a bug? [Open an issue](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/issues/new/choose) — the template will guide you through what information is needed.

---

## 📝 License

This mod is licensed under **[CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)**.

You may share it in its original form with attribution. You may not sell it, modify and redistribute it, or reupload it under a different name or authorship. Contributions via pull request are explicitly permitted and encouraged.

**Author:** TisonK · **Version:** 0.1.0.0

© 2026 TisonK — See [LICENSE](LICENSE) for full terms.

---

<div align="center">

*Farming Simulator 25 is published by GIANTS Software. This is an independent fan creation, not affiliated with or endorsed by GIANTS Software.*

*Work anywhere. Earn everywhere.* 🏢💸

</div>
