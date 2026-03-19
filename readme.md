# 🏢 FS25 Workplace Triggers
### *Placeable Off-Farm Work System*

[![Downloads](https://img.shields.io/github/downloads/TheCodingDad-TisonK/FS25_WorkplaceTriggers/total?style=for-the-badge&logo=github&color=4caf50&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases)
[![Release](https://img.shields.io/github/v/release/TheCodingDad-TisonK/FS25_WorkplaceTriggers?style=for-the-badge&logo=tag&color=76c442&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/releases/latest)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-lightgrey?style=for-the-badge&logo=creativecommons&logoColor=white)](https://creativecommons.org/licenses/by-nc-nd/4.0/)
<a href="https://paypal.me/TheCodingDad">
  <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif" alt="Donate via PayPal" height="50">
</a>

<br>

> *"I've always wanted to 'work' at the post office on Judith Plains, but there was no way to make it official. This mod makes those little roleplay moments count with real income."*

<br>

**Turn any location on any map into a legitimate workplace.** Place a trigger, name it, set a wage and pay schedule, and earn income while you're "on the clock." Perfect for roleplayers who want their farmers to have side jobs, or anyone who wants to supplement their farm income with off-farm work.

`Singleplayer` · `Multiplayer` · `Persistent saves` · `EN / DE / FR / IT / NL / PL`

---

## Features

**Placeable trigger zones** — invisible zones you drop anywhere on any map, indoors or outdoors. No 3D object cluttering your scenery, just a named work location.

**Custom workplace names** — call it Post Office, Feed Mill, Grandpa's Workshop, or anything that fits your map and your roleplay.

**Three pay schedules** — choose per trigger how you get paid:
- **Hourly** — wage x in-game hours worked (classic time-on-clock pay)
- **Flat Rate** — a fixed amount paid out at the end of every shift
- **Daily** — wage x number of in-game days you worked

**Shift tracking HUD** — while on shift, a panel shows your active workplace, time elapsed, and current earnings in real time. Drag it anywhere on screen, resize it, and the position is saved.

**Workplace Manager (F4)** — a full list dialog showing all your placed triggers with name, wage, and coordinates. Edit or delete any trigger from one screen.

**Shift history log** — the last 50 completed shifts are recorded with workplace name, duration, payout, and in-game day.

**Persistent saves** — all trigger placements, names, wages, and pay schedules survive game saves and reloads. Each savegame has its own set.

**Multiplayer** — each player tracks their own shifts independently; earnings go into the shared farm account. Shift start and end are synced to the server so the economy stays consistent.

**Optional integrations:**
- *FS25_NPCFavor* — completing shifts builds your relationship with the NPC you work for
- *FS25_WorkerCosts* — shift income is tracked alongside AI worker wages for a balanced economy view

Both integrations are silently skipped if those mods are not loaded.

---

## How to Use

1. Press **[F4]** to open the Workplace Manager and click **Add** to create a new trigger
2. Name the workplace, set a wage, and choose a pay schedule — then confirm
3. Place the trigger at any location on the map
4. Walk into the trigger zone and press **[E]** to start your shift
5. Press **[E]** again to end your shift and collect your wages

**Controls:**

| Key | Action |
|-----|--------|
| `E` | Start / end shift (when inside a trigger zone) |
| `F4` | Open / close Workplace Manager |
| `Left Shift` | Toggle HUD edit mode (drag and resize the panel) |

---

## Console Commands

Open the developer console (default: `~`) and type:

| Command | Description |
|---------|-------------|
| `wtHelp` | Show all available commands |
| `wtStatus` | Show current shift status |
| `wtList` | List all placed workplace triggers |
| `wtDebug` | Toggle debug logging |
| `wtGui` | Toggle the Workplace Manager GUI |

---

## Settings

Available under **ESC > Settings > General Settings > Workplace Triggers:**

- Show Shift HUD
- HUD Scale
- Show Notifications
- Wage Multiplier (global multiplier on top of per-trigger wages)
- End Shift on Leave (auto-cancel shift when you leave the zone)
- Show Earnings in HUD
- Debug Mode

---

## Changelog

### v1.0.0.0
- Pay schedules: Hourly, Flat Rate, and Daily options per trigger
- Multiplayer sync: shift start/end routed through network events, server-authoritative
- Shift history log: last 50 completed shifts stored per session
- FS25_NPCFavor integration: optional, graceful, builds NPC favor on shift completion
- FS25_WorkerCosts integration: optional, graceful, registers triggers as off-farm jobs

### v0.1.0.0
- Initial release: trigger placement, hourly wages, shift HUD, Workplace Manager GUI, settings, save/load, map icons, console commands

---

## Contributing

Found a bug? [Open an issue](https://github.com/TheCodingDad-TisonK/FS25_WorkplaceTriggers/issues/new/choose) — the template will guide you through what information is needed.

---

## License

This mod is licensed under **[CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)**.

You may share it in its original form with attribution. You may not sell it, modify and redistribute it, or reupload it under a different name or authorship. Contributions via pull request are explicitly permitted and encouraged.

**Author:** TisonK · **Version:** 1.0.0.0

© 2026 TisonK — See [LICENSE](LICENSE) for full terms.

---

<div align="center">

*Farming Simulator 25 is published by GIANTS Software. This is an independent fan creation, not affiliated with or endorsed by GIANTS Software.*

*Work anywhere, earn everywhere.* 🏢💸

</div>
