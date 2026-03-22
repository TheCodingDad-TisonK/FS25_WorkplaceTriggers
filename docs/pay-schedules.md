# Pay Schedules and Earnings Calculation

## Overview

Each trigger has two wage-related settings configured in the Edit dialog:

- **Hourly Wage** — the base wage value (meaning varies by schedule, see below)
- **Pay Schedule** — one of `hourly`, `flat`, or `daily`

A global **Wage Multiplier** from mod settings is applied on top (default 1.0x; options 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x).

## Time Measurement

Elapsed time is always computed from `g_currentMission.time` (milliseconds since mission start). This is the authoritative game clock shared by server and all clients, so earnings stay in sync across machines without any additional network traffic.

```lua
realElapsedMs = currentTime - shiftStartTime
```

The **Time Multiplier** per trigger controls how real elapsed milliseconds convert to in-game hours:

| Setting | Effect |
|---------|--------|
| Auto (0) | Uses `g_currentMission.environment.timeScale` (default FS25 = 120; 1 real second = 2 in-game minutes) |
| x1 | 1 real second = 1 in-game second (very slow pay) |
| x3 | 3 in-game seconds per real second |
| x5 | 5 in-game seconds per real second |
| x10 | 10 in-game seconds per real second |

```lua
inGameHours = (realElapsedMs * timeScale) / (1000 * 60 * 60)
```

## Hourly Schedule

```
earnings = floor(hourlyWage * inGameHours * wageMultiplier)
```

Classic time-clock pay. Earnings display in the HUD updates live every tick.

## Flat Rate Schedule

```
earnings = floor(hourlyWage * wageMultiplier)
```

The wage field is a fixed payout for the entire shift regardless of time spent. A 5-minute shift and a 5-hour shift both pay the same amount.

## Daily Schedule

```
inGameDays = inGameHours / 24
earnings = floor(hourlyWage * inGameDays * wageMultiplier)
```

The wage field is an amount per in-game day. At FS25 default speed (120x) one real-world minute equals 2 in-game hours, so one in-game day passes in 12 real minutes.

## Zone-Leave Penalty

When the player leaves the trigger zone and the 10-second countdown expires, the shift ends with a 20% penalty:

```
penaltyPay = floor(currentEarnings * 0.20)
```

Only `penaltyPay` is deposited. The full amount is shown in the HUD message alongside the reduced payout so the player knows what they forfeited.

## Earnings Boundary Conditions

- If `realElapsedMs < 0` (clock anomaly) it is clamped to 0 — no negative earnings
- All final values are passed through `math.floor()` — no fractional currency
- A shift ended before any time passes pays $0 (flat rate always pays the full amount)
