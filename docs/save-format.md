# Save Format

## Files Written Per Savegame

Both files live inside the savegame directory (e.g. `FarmingSimulator2025/savegame1/`). They are written on save and read once on mission load (server only; clients receive data via network sync).

---

### `FS25_WorkplaceTriggers.xml`

Stores all placed trigger definitions and the HUD panel layout. Written by `WorkplaceSaveLoad`.

```xml
<workplaceTriggers>
    <triggers count="2">
        <trigger id="wt_12345_1" name="Post Office"
                 hourlyWage="750" paySchedule="hourly" timeMultiplier="0"
                 triggerRadius="8.0"
                 posX="123.4" posY="0.0" posZ="-456.7" rotY="0.0"/>
        <trigger id="wt_12345_2" name="Feed Mill"
                 hourlyWage="1200" paySchedule="flat" timeMultiplier="3"
                 triggerRadius="12.0"
                 posX="55.0" posY="0.0" posZ="88.2" rotY="0.0"/>
    </triggers>
    <hudLayout posX="0.02" posY="0.85" scale="1.0" widthMult="1.0"/>
</workplaceTriggers>
```

#### Trigger attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | Stable cross-machine ID in format `wt_<time>_<counter>` |
| `name` | string | Workplace display name |
| `hourlyWage` | int | Base wage value (meaning depends on `paySchedule`) |
| `paySchedule` | string | `hourly`, `flat`, or `daily` |
| `timeMultiplier` | int | 0=Auto, 1=x1, 3=x3, 5=x5, 10=x10 |
| `triggerRadius` | float | Zone radius in metres (1 – 300) |
| `posX` | float | World X position |
| `posY` | float | World Y position |
| `posZ` | float | World Z position |
| `rotY` | float | Y-axis rotation (radians) |

#### HUD layout attributes (`hudLayout`)

| Attribute | Type | Description |
|-----------|------|-------------|
| `posX` | float | Normalized screen X (0–1, left edge) |
| `posY` | float | Normalized screen Y (0–1, Y=0 at bottom) |
| `scale` | float | Panel scale multiplier |
| `widthMult` | float | Panel width multiplier |

---

### `workplace_triggers_settings.xml`

Stores player settings. Written by `WorkplaceSettings`.

```xml
<WorkplaceSettings>
    <wageMultiplier>1.0</wageMultiplier>
    <endShiftOnLeave>true</endShiftOnLeave>
    <showEarningsInHud>true</showEarningsInHud>
    <showHud>true</showHud>
    <hudScale>1.0</hudScale>
    <showNotifications>true</showNotifications>
    <debugMode>false</debugMode>
</WorkplaceSettings>
```

| Key | Default | Clamped range |
|-----|---------|---------------|
| `wageMultiplier` | 1.0 | 0.1 – 5.0 (UI exposes 0.5x – 2.0x) |
| `endShiftOnLeave` | true | bool |
| `showEarningsInHud` | true | bool |
| `showHud` | true | bool |
| `hudScale` | 1.0 | 0.5 – 2.5 (UI exposes 0.75x – 2.0x) |
| `showNotifications` | true | bool |
| `debugMode` | false | bool |

Values are clamped to their valid ranges on load via `WorkplaceSettings:validate()`.

---

## Shift History

Shift history (last 50 entries) is **session-only** — it is not persisted to disk and resets on game reload. Each entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `workplaceName` | string | Workplace name at time of shift |
| `elapsedHours` | float | In-game hours elapsed |
| `earned` | int | Amount deposited ($) |
| `paySchedule` | string | Schedule used for this shift |
| `gameDay` | int | In-game calendar day the shift ended |
