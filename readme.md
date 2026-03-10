# 🏢 FS25 Workplace Triggers
### *Placeable Off-Farm Work System*

[![Downloads](https://img.shields.io/github/downloads/TheCodingDad-TisonK/FS25_WorkplaceTriggers/total?style=for-the-badge&logo=github&color=4caf50&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases)
[![Release](https://img.shields.io/github/v/release/TheCodingDad-TisonK/FS25_WorkplaceTriggers?style=for-the-badge&logo=tag&color=76c442&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases/latest)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-lightgrey?style=for-the-badge&logo=creativecommons&logoColor=white)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

<br>

> *"I've always wanted to 'work' at the post office on Judith Plains, but there was no way to make it official. This mod makes those little roleplay moments count with real income."*

<br>

**Turn any location on any map into a legitimate workplace.** Place a trigger, name it, set a wage, and earn income while you're "on the clock." Perfect for roleplayers who want their farmers to have side jobs, or anyone who wants to supplement their farm income with off-farm work.

`Singleplayer` • `Multiplayer (host-authoritative)` • `Persistent saves` • `EN / DE / FR / IT / NL / PL`

> [!TIP]
> Want to be part of our community? Share tips, report issues, and chat with other farmers on the **[FS25 Modding Community Discord](https://discord.gg/Th2pnq36)**!

---

## ✨ Features

### 📍 Placeable Work Triggers

Create official workplaces anywhere on any map - buildings, parking lots, roads, anywhere.

| | Feature | Description |
|---|---|---|
| 🏢 | **Placeable trigger zones** | Drag and drop invisible trigger volumes anywhere on the map |
| 📝 | **Custom workplace names** | Call it "Post Office", "Feed Mill", "Grandpa's Workshop", anything you want |
| 💰 | **Flexible pay rates** | Set hourly wage, per-shift flat rate, or daily rate per location |
| 🎯 | **Proximity activation** | Press E when near trigger to start/stop your shift |
| 💾 | **Full persistence** | All triggers, names, wages, and shift history save with your farm |

### ⏰ Shift Tracking & Earnings

Track your work time and earn income based on real in-game time.

| Pay Type | How It Works | Best For |
|---|---|---|
| **Hourly Wage** | Earn wage × hours worked | Regular part-time jobs |
| **Flat Rate** | Fixed payment per shift | One-off tasks, commissions |
| **Daily Rate** | Pays once per in-game day | Salaried positions |

Shifts track elapsed game time and calculate earnings automatically. Income flows to your farm account when you end your shift.

### 📊 Work Shift HUD

Press `Shift+W` to open the active shift overlay. Shows:
- Current workplace name
- Time elapsed on current shift
- Current earnings for this shift
- Total earnings today/season

Drag the panel anywhere on screen by right-clicking to enter Edit Mode, then left-click dragging.

### 🛠️ Workplace Management

Press `Shift+M` to open the management interface. View all your placed triggers and:
- Edit workplace names
- Adjust pay rates and types
- Remove unwanted locations
- View shift history per location

### 🤝 Multiplayer Support

Each player tracks their own shifts independently. All earnings go to the shared farm account, so everyone benefits from off-farm work.

---

## ⚙️ Settings

Open via **ESC → Settings → Game Settings → Workplace Triggers**.

| Setting | Options | Notes |
|---|---|---|
| **Enable mod** | On / Off | Disables all workplace functionality when off |
| **HUD Position** | Bottom-Left / Bottom-Right / Top-Left / Top-Right | Default HUD location |
| **HUD Scale** | 0.8x / 1.0x / 1.2x / 1.5x | Resize the HUD panel |
| **HUD Visible** | On / Off | Toggle HUD visibility |
| **Shift Notifications** | On / Off | Show pop-up when starting/stopping shifts |
| **Auto-Save Triggers** | On / Off | Automatically save trigger changes |
| **Debug Mode** | On / Off | Verbose logging to `log.txt` |

> [!NOTE]
> Settings are **server-authoritative** in multiplayer — the host's settings are pushed to all clients on join.

---

## 🔌 Optional Mod Integration

All integrations are detected at runtime and fail gracefully if the mod is not installed.

| Mod | What it adds |
|---|---|
| **FS25_NPCFavor** | Working shifts at triggers near NPCs improves relationship with that NPC |
| **FS25_WorkerCosts** | Off-farm shift income appears in WorkerCosts dashboard as "off-farm income" |
| **FS25_BetterContracts** | Work triggers appear in contract/income overview screen |
| **AutoDrive** | AutoDrive can route to workplace triggers as destinations |

---

## 🛠️ Installation

**1. Download** `FS25_WorkplaceTriggers.zip` from the [latest release](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases/latest).

**2. Copy** the ZIP (do not extract) to your mods folder:

| Platform | Path |
|---|---|
| 🪟 Windows | `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods\` |
| 🍎 macOS | `~/Library/Application Support/FarmingSimulator2025/mods/` |

**3. Enable** *Workplace Triggers* in the in-game mod manager.

**4. Load** any career save — the mod activates automatically on load.

---

## 🎮 Quick Start

```
1. Load your farm — workplace system activates immediately
2. Open Shop → Buildings → Tools → Workplace Trigger
3. Place the trigger anywhere on your map
4. Press E near the trigger → set workplace name and pay rate
5. Press Shift+M → open management to view/edit all triggers
6. Enter a trigger zone → press E to start your shift
7. Press E again to end shift and collect earnings
8. Press Shift+W → view active shift HUD
```

> [!TIP]
> Open **ESC → Help → Workplace Triggers** for a full in-game guide covering everything from placement to shift management.

---

## ⌨️ Key Bindings

| Keys | Action |
|---|---|
| `Shift+W` | Toggle the Work Shift HUD |
| `Shift+M` | Open Workplace Management dialog |
| `E` *(near trigger)* | Start/stop shift at current workplace |
| `RMB` *(on HUD)* | Toggle Edit Mode — drag with `LMB` to reposition |

---

## 🖥️ Console Commands

Open the developer console with the **`~`** key:

| Command | Arguments | Description |
|---|---|---|
| `wtHelp` | — | List all Workplace Triggers commands |
| `wtStatus` | — | System overview: triggers, active shifts, total earnings |
| `wtList` | — | List all placed workplace triggers |
| `wtDebug` | — | Toggle verbose debug logging to `log.txt` |

---

## ⚠️ Known Limitations

| Issue | Details |
|---|---|
| 🏗️ **WIP Status** | Core trigger placement and wage system complete. Management GUI and advanced features in development. |
| 🎨 **Visual Feedback** | Triggers are invisible zones. No 3D marker or visual indicator currently. |
| 💰 **Economy Balance** | Pay rates are suggestions. Players should adjust based on their map's economy. |
| 🌐 **Multiplayer** | Shift tracking runs on host only. Clients see synced state but have no direct simulation authority. |

---

## 🚧 Development Status

**Current Version:** v0.1 WIP

**Phase 1 Complete:** Core trigger placement and wage system
- ✅ Placeable trigger zones
- ✅ Custom workplace names
- ✅ Flexible pay rates (hourly/flat/daily)
- ✅ Shift tracking and earnings calculation
- ✅ Basic HUD display
- ✅ Save/load functionality

**Phase 2 In Progress:** Management GUI + Pay Options
- 🔄 Workplace Management Dialog
- 🔄 Edit workplace names and wages
- 🔄 Shift history tracking
- 🔄 HUD drag and scale functionality

**Phase 3 Planned:** Shift History + Quality-of-Life
- ⏳ Detailed shift history per workplace
- ⏳ Earnings summary HUD
- ⏳ Multiplayer event synchronization
- ⏳ Additional console commands

**Phase 4 Future:** Third-Party Integration
- ⏳ NPCFavor relationship integration
- ⏳ WorkerCosts dashboard integration
- ⏳ BetterContracts income overview
- ⏳ AutoDrive destination routing

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, code standards, and the PR checklist.

Found a bug? [Open an issue](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/issues/new/choose) — the template will guide you through what information is needed.

Have ideas for new features? We're especially interested in:
- Different pay calculation methods
- Workplace-specific bonuses or penalties
- Integration with more mods in the ecosystem
- Visual indicators for active workplaces

---

## 📝 License

This mod is licensed under **[CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)**.

You may share it in its original form with attribution. You may not sell it, modify and redistribute it, or reupload it under a different name or authorship. Contributions via pull request are explicitly permitted and encouraged.

**Author:** TisonK · **Version:** 0.1.0.0 (WIP)

© 2026 TisonK — See [LICENSE](LICENSE) for full terms.

---

<div align="center">

*Farming Simulator 25 is published by GIANTS Software. This is an independent fan creation, not affiliated with or endorsed by GIANTS Software.*

*Work anywhere, earn everywhere.* 🏢💸

</div>