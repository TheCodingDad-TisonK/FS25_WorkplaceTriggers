# Multiplayer

## Design Principle

All shift and trigger state is **server-authoritative**. Clients send requests and receive confirmations; they never apply shift state based on their own outbound events. This prevents desync between a client that gets rejected by the server and the client's local HUD.

## Event Types

All network events share the single `WorkplaceMultiplayerEvent` class serialized over `streamWriteUInt8` event-type dispatch.

| Type constant | Direction | Purpose |
|--------------|-----------|---------|
| `TYPE_SHIFT_START` | Client -> Server | Player pressed E to start a shift |
| `TYPE_SHIFT_END` | Client -> Server | Player pressed E to end, or zone-leave penalty fired |
| `TYPE_SHIFT_CONFIRM` | Server -> All clients | Authoritative shift start or end (with final earnings) |
| `TYPE_CREATE_TRIGGER` | Client -> Server | Dedicated-server client requests trigger creation |
| `TYPE_TRIGGER_CREATED` | Server -> All clients | Stable trigger data broadcast after creation |
| `TYPE_UPDATE_TRIGGER` | Client -> Server (and back) | Edit an existing trigger's name/wage/radius |
| `TYPE_DELETE_TRIGGER` | Any -> All | Delete a trigger by ID |
| `TYPE_REQUEST_SYNC` | Client -> Server | New/rejoining client requests all current triggers |

## Shift Flow

```
Client presses E
  -> sendShiftStart(triggerId)
    SP / listen-server: applied locally, then SHIFT_CONFIRM broadcast
    Dedicated server client: TYPE_SHIFT_START sent to server
      -> server validates trigger exists, calls startShift()
      -> server broadcasts TYPE_SHIFT_CONFIRM to all clients
        -> handleShiftConfirm() on every client updates HUD and mirrors
           just enough state to run zone-leave checks client-side

Client presses E again (or zone-leave timer expires)
  -> sendShiftEnd(isPenalty)
    Similar path; server calls endShift() or endShiftPenalty()
    -> broadcasts TYPE_SHIFT_CONFIRM with triggerId="" (signals end)
    -> clients clear their mirrored shift state
```

`SHIFT_CONFIRM` is the **only** place client HUDs update. The `triggerId == ""` sentinel distinguishes a shift-end confirm from a shift-start confirm; using `earnings == 0` as the sentinel was a historical bug (a shift stopped in under a second pays $0 and would be misread as a start).

## Farm ID Routing

When a dedicated-server client sends `TYPE_SHIFT_START` it includes its `farmId` (from `g_currentMission:getFarmId()`). The server stores this in `shiftTracker.activeFarmId` so that payout targets the right farm when the shift ends. In SP/listen-server the host's farm ID is used directly.

## Trigger Creation Flow

```
SP / listen-server:
  sendCreateTrigger() generates a stableId locally,
  registers the trigger via triggerManager:registerTrigger(),
  then broadcasts TYPE_TRIGGER_CREATED to any connected clients.

Dedicated server client:
  Registers optimistically with a client-local ID (visible immediately in the dialog),
  sends TYPE_CREATE_TRIGGER to the server.
  Server generates its own stableId, registers, broadcasts TYPE_TRIGGER_CREATED to all.
  handleTriggerCreated() has a duplicate check — if the trigger is already registered
  it skips silently, so the optimistic local copy is not doubled.
```

Trigger IDs are stable cross-machine strings in the format `wt_<time>_<counter>`. Node handles (`tostring(node)`) are never used as IDs because they differ between server and client.

## Client Join / Rejoin Sync

On `onMissionLoaded()` clients set `syncPending = true`. The `update()` loop:

1. Waits 2 seconds (warm-up, allows the server stream to fully open)
2. Sends `TYPE_REQUEST_SYNC`
3. Server broadcasts `TYPE_TRIGGER_CREATED` for every known trigger
4. If no triggers arrive within 8 seconds the client retries, up to 5 attempts
5. Once `triggerManager:getAllTriggers()` returns at least one trigger the sync is considered complete and retrying stops

## Zone-Leave Penalty in MP

Zone checks run **client-side only** on the machine whose shift it is. The `shiftOwnerIsLocal` flag prevents the host machine from doing zone checks for a remote client's shift (which would use the wrong player position).

When the countdown expires the client:
1. Clears `activeTriggerId` locally to stop further zone checks
2. Calls `sendShiftEnd(isPenalty = true)`
3. The server calls `endShiftPenalty()`, calculates 20% of accrued earnings, deposits them, and broadcasts `TYPE_SHIFT_CONFIRM` with `triggerId = ""`

## Dedicated Server Notes

On a headless dedicated server `g_i18n` is nil and rendering functions are unavailable. Any call into `hud:onShiftStarted()` or `hud:onShiftEnded()` that reaches the server is wrapped in `pcall` so a rendering error does not block the `SHIFT_CONFIRM` broadcast.
