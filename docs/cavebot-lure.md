# Cavebot Distance movement

Choose **Distance** under Hunt Style and set its distance to 1–4 SQM. The setting
is saved per character and exported with the JSON script. There is no monster
quantity threshold. Existing scripts using `huntStyle: lure` still load as
Distance, and their old `lureCount` setting is ignored and no longer exported.
The current attack target defines the preferred distance.
Auto Target and the Shooter retain their own targeting, spell and cooldown rules.

Any living, same-floor, non-summoned monster within five SQM of the player,
including the diagonal corners, suspends waypoint movement and starts moving
combat. Visit Stand only once that pack is cleared; never switch to a stationary
fight just because fewer monsters remain. Other monsters entering the area join it. An
engaged monster that remains visible does not leave the pack just because an
escape step briefly increases its distance. Dead or no-longer-visible monsters
are removed; new monsters outside five SQM do not hold the route.

After the pack clears, the character resumes its recorded waypoint, reaches
Stand and continues the route or executes the recorded Stair/Hur action. It does
not skip Stand merely because combat ended away from that SQM. The other hunt
styles retain their existing Node, Stand and Stair behavior.

When combat starts, Distance freezes the last 60 actually travelled route positions
on the current floor, including its entry position. It can backtrack along that
path and seeks positions toward its two ends, while keeping the target range.
Escape steps normally stay within four SQM of this path. If all normal exits
are blocked, a known safe detour may use up to two extra SQM, then return to the
normal corridor. It never enlarges the frozen path. Future waypoints are not
considered travelled terrain. A displaced player
outside the corridor seeks a way back. Floor changes reset the history, and
starting the bot starts a new history at the current position.

**Open Helper**, or the normal Helper button while detached/compact, restores
the Cavebot panel to its full Helper tab, without stopping the bot. Closing the
Helper while Cavebot runs moves it into its floating mini window. Minimize/Expand
switch the floating window size; Stop remains the control that stops the bot.
The Party Hunt tab and script loading are disabled for this client release; its
implementation is preserved for future work.

Escape planning searches reachable positions up to eight steps ahead, capped
at 400 nodes. It favors the selected target range, multiple available exits,
clearance from solid walls and fewer nearby attackers. It penalizes dead ends,
repeated steps and reversing direction, and strongly prefers cardinal steps.
The first step has its own safety/range score, independently of the eventual
destination. If a free exit stays at least two SQM from all monsters (one SQM
when distance is set to one), the planner excludes first steps closer than that.
Intermediate positions also account for the whole pack, not only the target.
Diagonals remain available when they offer a safer escape or an obstacle detour. It can
temporarily use another range to get around a wall or through a narrow corridor.
Unknown terrain, occupied tiles and unintended floor transitions are excluded.

Distance uses native pre-walking when the client supports it, without treating
the predicted position as server confirmation or adding it to travelled history.
Native `onCancelWalk` immediately clears a rejected escape and replans at the
next available step, respecting the client's walk lock. Missing confirmations
use step duration and ping instead of a fixed 900-ms pause. Rejected escape SQMs
are excluded briefly (at least 250 ms), separately from actual route walls.
If all alternatives are temporarily excluded, the map is checked again and a
walkable exit retried. Slow animations/locked walks are never marked as walls.

If every permitted exit is blocked, movement waits while configured attacks and healing
continue. Wall spacing and the chosen range are preferences, not guarantees in
a fully occupied or narrow cave. Manual movement does not disable the bot.

Regression tests, from the client root:

```sh
luajit tests/lua/lure_movement_spec.lua
luajit tests/lua/cavebot_lure_spec.lua
luajit tests/lua/party_hunt_spec.lua
luajit tests/lua/helper_v2_detach_spec.lua
```

These cover single-monster combat, old script compatibility, frozen route bounds,
backtracking, reconnect settings, target distances, wall detours, narrow corridors,
occupied tiles, holes, failed steps, diagonal detection, combat before Node/Stand,
Stair after combat, Echo spawns, window restoration and disabled Party Hunt lifecycle.
They also exercise a pursuing pack over 120 movement steps, cancelled server
steps, delayed acknowledgements, low-ping recovery, predicted-step rollback and
removal of event listeners, plus a blocked virtual boundary with bounded detour
and recovery. The old `auto_explorer_v2_spec.lua` fixture predates
server-authoritative time and asynchronous file dialogs and is not part of this
Distance suite; it must be migrated before use.
