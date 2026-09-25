# Milestone 5 design: rounds and the grounds

Status: approved 2026-09-25 (drafted from the colosseum design (`2026-09-25-colosseum-design.md`, its M5 row
and "Open decisions") and the user's answers in the M5 session (stand where you are at a round's
end; a short scene then the gate screen for the fall; a walkable first grounds room; then the
user's three corrections, recorded at the end). The plan is `2026-09-25-milestone-5.md`.

**Goal.** The first playable of the colosseum on today's art: a run is eight rounds in one arena
with the crowd's favour, coins, a fall and a verdict, then a return to a grounds room where money
buys training and the gate starts the next run. Not one word of explanation anywhere.

**Out of scope** (later milestones): the six areas and the characters (M6), the Spoliarium wake
(M6), tiers 2 and 3, the tier select, classes beyond the one gladiator, the emperor's fight (M7),
the art (M8), the turning point and any thumbs down in play (M9).

## The run

**One arena, eight rounds.** `SeriesDef` (`data/series/tier_1.tres`: the arena size, eight
`RoundDef`s) replaces `FloorDef`; `RoundDef` (a `WaveTable`) replaces `RoomDef`, whose size and
exit side go (the size is the series', and there is no exit). One `Room` is built for the run and
stays; a round is its wave runner given the next table. `Door`, the entry seal, the fade between
rooms, `room_exit_requested`, `door_opened`, and `door_sealed` go; `Fade` stays for the fall and
the return. The top wall keeps its opening: it is the emperor's box now, drawn as the door face was,
with the thumb over it at the verdict. The HUD says "Round n/8". The boss is round 8's only wave,
as today.

**The round's end, standing where you are.** On `room_cleared` (renamed `round_cleared`): the
crowd reacts by band (a sound), the band's bonus lands (below), the picker opens after
`PICKER_DELAY` with the granter's name over the cards ("The crowd" for Cheer and Roar, "The
emperor" for Boo and Quiet; four cards on a Roar), and after the pick a beat of `ROUND_GAP` (1.0 s,
the crowd settling) before `round_started` and the next table's first wave fades in. Refund rounds
after a switch work as today. The last round ends in the verdict instead of a picker.

**Favour.** The crowd pays for danger and punishes caution. `FavourRules` (pure) scores named
**acts**, a table of (act, value, detector) so a later milestone adds an act (a melee kill, a
boldness streak, a penalty for repetition) as one row and one detector, and `RunState.favour`
holds the meter, 0 to 100, starting at `START` (30). The acts in M5:

| Act | Detected | Change |
|---|---|---|
| `kill` | an enemy dies | +3 |
| `chain` | a kill within `CHAIN_WINDOW` (1.5 s) of the last | +2 more |
| `daring` | a kill within `DASH_WINDOW` (0.5 s) after a **dash through danger**: a dash whose path passed within `DANGER_RADIUS` (24 px) of a live enemy. A dash in the open scores nothing, so dashing cannot be farmed | +3 more |
| `clean_round` | a round cleared without a hit | +15 |
| `hit` | a hit taken | -20 |
| `cowardice` | every second past `IDLE_GRACE` (4 s) in which enemies live and the player has neither hit nor killed one; running away is the way to be booed | -2 a second |

Reserved for later, with the detectors named so the table stays open: `melee` (a kill at contact
range, once a melee weapon exists), `repetition` (the same card or the same pattern round after
round, a slow penalty), `variety`, and the boss's own acts. `favour_changed(value, band, act)`
names the act so the HUD and the crowd can react to it.

Bands: Boo below 25, Quiet to 50, Cheer to 75, Roar from 75. The band at the round's end is the
round's verdict; a run whose every round ended in Roar with no hit taken is a **perfect run**
(`RunState.perfect`, false at the first hit), recorded in the profile for M7 and M9. The HUD shows
the meter under the hearts: a nine-patch bar filled in the band's colour (grey, white, gold, red),
no label. The crowd's sounds are its only explanation: `crowd_boo`, `crowd_quiet`, `crowd_cheer`,
`crowd_roar` at each round's end, and `crowd_hush` at the fall.

**Coins.** Every `EnemyDef` has `coins` (chaser 1, shielded chaser 2, shooter 2, the boss 60). A
kill's coins fly from the corpse to the HUD counter (`CoinFlight`, a coin sprite from the tileset's
`coin_anim` tweened in screen space to the counter, `coin_get` on arrival) and join
`RunState.coins` and the round's tally. At the round's end the band pays a bonus on the tally:
Cheer half of it, added to the counter with a flourish; Roar all of it, thrown on the floor. The
boss's coins are always thrown. A **pile** (`scenes/coin_pile.tscn`, an `Area2D` on layer 6
masking 65 so a dash collects too) is tossed in an arc to a seeded spot within `PILE_RADIUS`
(64 px) of the player and inside the floor (`RunState.stream("piles:round")`), `PILE_COUNT`
(4 to 8, the sum split evenly), and pays on contact (`coin_pickup`). Piles stay until picked up
or the run ends. The run's coins reach the profile only through the verdict.

These numbers are a first cut to play. The economy proper is designed backwards in M6 from what
money must buy over the game's length (the training lines and their caps across the tiers, the
completionist rewards, how many runs a line should cost a middling player); a short economy doc
then re-prices the enemies, the bands, and the lines together.

## The fall and the verdict

**The fall.** `Player.hurt` at 0 hp emits `player_fell` (was `player_died`) and the gladiator goes
down: `Juice` freeze as today, the sprite laid flat (rotated a quarter turn, no new art), the wave
runner off, `crowd_hush`. A win reaches the same scene after the boss's corpse hold.

**The verdict.** `VerdictRules.decide(band, hits_taken, flags, cheats)` returns UP or DOWN. In M5
it is UP unless the `verso` cheat is on (pollice verso: the thumb turned), so the DOWN path is
built and tested but never seen in play until M9's turning point, when the flags decide. The
scene, real time by design: `VERDICT_HOLD` (1.0 s) after the hush, the thumb appears over the
emperor's box (a `ThumbSign` node: the tileset has no thumb, so a 16x16 placeholder drawn in code,
up or down, until M8's art) with `verdict_up` or `verdict_down`, `VERDICT_SHOW` (1.2 s), then the
fade and the gate screen. UP banks `RunState.coins` into the profile; DOWN loses them and counts a
death. Both count a run and a fall or a win.

**The gate screen** (`GateScreen`, replacing `Summary`, CanvasLayer 30): the title is the gate,
"Porta Triumphalis" or "Porta Libitinaria"; then the run (rounds, kills, time, coins earned, coins
kept, the seed, `cheats=` when any); then all time (runs, wins, falls, deaths, kills, hits taken,
shots fired, the deadliest enemy by hits landed on you, drawn with its idle animation from
`SpriteAtlas`); Enter or a click goes to the grounds. Esc still returns to the title. No line says
what the gate means.

**R and Restart** are a yield: the run's coins are lost, the profile counts a fall, and a new run
starts at once in the arena (no verdict, no grounds), so testing stays fast. The pause screen's
"Quit to title" is a yield too.

## The profile

`Profile` (autoload) holds a `Save` (`scripts/save.gd`, load and save by path like `Settings`,
`user://save.cfg`, a `version` key; a missing or older file loads the defaults). Sections:
`money`; `training` (rank per line); `flags` (`runs`, `wins`, `falls`, `deaths`, `perfect_runs`,
`returned` once the grounds have been seen); `stats`; and `runs`, a run log. Written at the
verdict and at every purchase.

The profile records more than M5 reads, so later achievements, unlocks, and completionist rewards
can be granted from the past. `stats` (all time, counters keyed by name, nested by id where it
says so): `shots_fired` per weapon id, `shots_hit`, `hits_landed` per enemy id, `kills` per enemy
id, `hits_taken` per attacker id, `deaths_by` per attacker id (the killing hit), `dashes`,
`dashes_through_danger`, `cards_taken` per card id, `switches`, `rounds_cleared`, `rounds_by_band`
per band, `clean_rounds`, `perfect_runs`, `boss_kills`, `boss_time_best`, `coins_earned`,
`coins_lost`, `coins_spent`, `piles_collected`, `favour_peak`, `time_played`, `time_in_grounds`,
`best_run` (rounds, kills, time). `runs` keeps one record per run, newest first, capped at
`RUN_LOG_CAP` (500): seed, cheats, the outcome (win, fall, yield), the verdict, rounds, kills, time,
coins earned and kept, hits taken, the band of each round, the build at the end (weapon and ranks),
the training ranks at the start, the date. Adding a counter later means adding its name to
`Save.STAT_KEYS`; an older file loads with the new ones at zero. `Player.hurt`
gains `attacker_id` (the enemy's def id, or the bolt's shooter's; "" unknown) so `player_hit`
carries it and `hits_by` fills. Tests use a scratch path and `Profile.reset()` in
`SceneSuite.after_test`.

## The grounds

`scenes/grounds.tscn`: one rectangle on today's tiles (`ArenaGrid` with no opening), the player
walking, no enemies, `music_grounds`. Three stations, each an `Area2D` with a sprite from the
tileset and nothing written on it; walking into one opens its panel, walking out closes it:

- **The training post** (a `crate` with a `weapon_spear` leaning on it): the training panel, a
  framed column of three lines with their rank pips and price, bought with money, greyed when it
  cannot be paid or is capped; `buy` on a purchase. Lines: **Hearts** (+1 heart a rank, 3 ranks,
  50/100/200), **Breath** (+1 dash charge a rank, 2 ranks, 80/160), **Renown** (+10 starting
  favour a rank, 3 ranks, 40/80/160). `Build.starting(profile)` applies them.
- **The rack** (`weapon_*` sprites on the wall): the armoury panel, showing the gladiator and the
  handgun as equipped and empty slots beside it. Nothing to choose in M5; the empty slots are the
  hint.
- **The gate** (the top wall's opening, as the exit door was drawn): walking through it starts the
  run: the fade, the arena, round 1.

**The flow.** The title's Play starts the first run straight in the arena (`flags.runs == 0`).
After the gate screen the player is in the grounds for the first time (`flags.returned` set) and
every run after starts from its gate. Restart and R behave as above.

## Show, don't tell, in this milestone

No panel has a caption, the HUD's new elements (the meter, the counter) have no label, the gate
screen names the gate and nothing else, the picker's granter line is a name. The spec-compliance
review of every task checks the rule. The tester notes (`docs/TESTERS.md`) explain nothing either:
they ask what the tester understood.

## Data, names, and constants

- `data/series/tier_1.tres` (`SeriesDef`: `arena_width` 28, `arena_height` 15, `rounds`);
  `data/rounds/round_1..8.tres` (`RoundDef`: `waves`). `data/floors` and `data/rooms` go.
- `EnemyDef.coins`. `data/audio.json`: `crowd_boo`, `crowd_quiet`, `crowd_cheer`, `crowd_roar`,
  `crowd_hush`, `coin_get`, `coin_toss`, `coin_pickup`, `verdict_up`, `verdict_down`, `gate`,
  `buy`, and the loop `music_grounds`. The user sources them; each is silence plus
  `AUDIO_MISSING` until it lands.
- New bus signals: `round_started(index, total)`, `round_cleared()` (renamed), `favour_changed
  (value, band)`, `coins_changed(run_coins)`, `coins_thrown(position, count)`, `pile_collected
  (position, value)`, `player_fell(position)` (renamed), `verdict_given(up)`, `grounds_entered()`,
  `training_bought(line, rank)`. `player_hit` gains `attacker_id`.
- Constants next to what they affect: the favour table in `favour_rules.gd`, `ROUND_GAP` in
  `main.gd`, the pile numbers in `coin_pile.gd`, the verdict times in `verdict.gd`, the training
  table in `training_rules.gd`.
- Cheats: `verso` (thumbs down this run), `dives` (start with 1000 coins) for testing the post.

## Tests

Pure suites for `FavourRules` (each act, the dash-through-danger detector on a path and an enemy
position, the cowardice drain and its grace), `VerdictRules`, `TrainingRules`, `Save` (round trip
through a scratch file, defaults on a missing or older file, the run log's cap and order, every
`STAT_KEYS` name surviving a round trip), `SeriesDef` validation. Scene suites: the round
transitions without doors (a cleared round's picker, the gap, the next wave), the Roar's four cards
and piles, the coin flight and the counter, a pile collected by walking and by dashing, the fall
scene's stages on `physics_frame` and the real-time holds, UP banking coins and DOWN losing them
(`verso`), the gate screen's texts and the deadliest sprite, the grounds' stations opening their
panels and a purchase changing the next run's hearts, the first-run flow (straight into the arena,
the grounds after). Smoke: `round` replaces `room` (clear, pick, the next wave), `fall` (hp 1, the
thumb, `SMOKE_VERDICT up`), `grounds` (walk into the post, `smoke_grounds.png`).

## Answers from the user (2026-09-25)

The favour must pay for danger and punish caution and, later, repetition (the acts table above);
coins start as written and the economy is designed backwards later; the profile saves every stat it
can (the list above). The user sources the thirteen sounds (silence until they land); the training
lines' names and prices stay placeholders for the playtest; the code-drawn thumb is fine until M8.

## Deviations during the build

(Filled as the build finds them, one line each, mirrored in the plan's "## Deviations".)

- Task 1: none at the design level; the code-level departures are in the plan.
