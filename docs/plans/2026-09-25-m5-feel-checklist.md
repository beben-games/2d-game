# Milestone 5 feel checklist

Play at least two runs (win or fall; eight rounds in one arena, a card after each of the first seven,
the boss in round 8), and let one end in the grounds with money spent at the training post before the
next gate. `tools/run.sh` or the `0.5.0-rc1` zips; the seed is on the gate screen and in the `RUN_END`
line; `-- --seed=N` replays it. The cheats in the seed field: `permawhat?` (no damage), `verso` (the
thumb goes down), `dives` (1000 coins). Rate each line good / meh / bad with a note; the knob for each is
named. The milestone closes when the slice is one you would hand a friend and every row's answer to
"where did you feel told" is "nowhere".

## The round flow

- The gap between rounds (a pick, then a second of empty arena, then the next wave): a breath, or dead time? (`Main.ROUND_GAP`, `PICKER_DELAY` in `scripts/main.gd`)
- The granter's name over the cards ("The crowd", "The emperor"): does it read as who is giving, and does it change your sense of the pick? (`FavourRules.GRANTER_CROWD`/`GRANTER_EMPEROR` in `scripts/favour_rules.gd`, `GRANTER_GAP` in `scripts/ui/upgrade_menu.gd`)
- Four cards on a Roar, edge to edge at 1280 wide: does the row read as a reward, or as a crowded menu? Should the cards shrink instead of the gaps? (`UpgradeMenu.card_gap`, `CARD_GAP`, `CARD_SIZE` in `scripts/ui/upgrade_menu.gd`; `FavourRules.OFFER_COUNT_ROAR`)
- "Round n/8" on the HUD, the round's fanfare on a clear (`room_clear`) and the wave sting: still right with one arena? (`data/audio.json` `room_enter`, `room_clear`, `wave_start`)

## Favour

- The meter under the hearts, with no label: did you work out what it is, and what moved it? (`FAVOUR_BAR_*` in `scripts/ui/hud.gd`; the band colours `FAVOUR_FILL`)
- The acts' numbers: a kill 3, a chain 2, a daring kill 3, a clean round 15, a hit -20, from 30 of 100; did the meter move at the pace of the fight? (`FavourRules.ACTS`, `START`, `MAX`, `CHAIN_WINDOW` in `scripts/favour_rules.gd`)
- The cowardice drain (after 4 s without landing a shot while an enemy lives, 2 a second): did it ever feel unfair, for instance while dodging a volley or waiting out a shield? (`FavourRules.IDLE_GRACE`, `COWARDICE_PER_SECOND`)
- Daring: every kill within half a second of a dash through danger scores it (the dash is not spent by the first kill). Did a dash past an enemy feel rewarded, and did you ever dash for the crowd rather than for the escape? (`FavourRules.DASH_WINDOW`, `DANGER_RADIUS`)
- The crowd at a round's end: the boo, the quiet, the cheer, the roar. Do the four read apart, and are their levels right against the effects? (`data/audio.json` `crowd_boo`, `crowd_quiet`, `crowd_cheer`, `crowd_roar` at -6 dB, `min_gap` 0.5; `Audio.CROWD_SOUNDS`)
- The band edges (25 / 50 / 75): did you reach a Roar, and how often did a round end in a boo? (`FavourRules.BAND_EDGES`)

## Coins

- The counter at the right under the build strip, the number at 32 px with the coin beside it: found without looking for it, and readable mid-fight? (`COIN_COUNTER_GAP`, `COIN_FONT_SIZE`, `COIN_ICON_SCALE` in `scripts/ui/hud.gd`)
- The flight from a corpse to the counter (0.45 s) and its chime: does it read as "that was money", or as noise under a volley? (`CoinFlight.FLIGHT_TIME` in `scripts/ui/coin_flight.gd`; `data/audio.json` `coin_get` at -12 dB, `min_gap` 0.03)
- The Cheer bonus (half the round's tally, one flight from the emperor's box) versus the Roar's piles (the whole tally thrown around you): did you notice the difference, and which felt better? (`Main._pay_bonus` in `scripts/main.gd`)
- The pile count and spread (one pile per 8 coins, 4 to 8 piles, within 64 px, 12 px apart): a scatter worth walking, or a carpet? (`PileRules.COINS_PER_PILE`, `MIN_COUNT`, `MAX_COUNT`, `PILE_RADIUS`, `MIN_GAP` in `scripts/pile_rules.gd`; the toss `TOSS_TIME`, `ARC_HEIGHT` in `scripts/coin_pile.gd`)
- Piles thrown on the last clear (or by the boss) sit under the picker and are still there in the next round: did you pick them up, or forget them? (`Room/Piles`; `Main.throw_piles`)
- The sweep at a thumb up (every pile left on the floor flies to the counter before the banking): did it read, or did money appear from nowhere? (`Main._sweep_piles`)

## The fall and the verdict

- The gladiator laid flat and the hush: does the arena go quiet in the right way? (`Player._fall` in `scripts/player.gd`; `data/audio.json` `crowd_hush`, `player_die`)
- The thumb over the box, a second after the fall, held 1.2 s: a placeholder drawn in code; does its placement over the box read as the emperor's, and is the hold long enough to take in? (`Main.VERDICT_HOLD`, `VERDICT_SHOW`; `ThumbSign.SIZE`, `SCALE`, `FILL`, `EDGE` in `scripts/thumb_sign.gd`)
- The gate screen: the gate's name, the run's block and the all-time block side by side, the deadliest enemy's portrait under them. Did the two gate names ("Porta Triumphalis", "Porta Libitinaria", the second only with `verso` in M5) tell you anything? Is the portrait the right size? (`VerdictRules.GATE_UP`/`GATE_DOWN` in `scripts/verdict_rules.gd`; `BLOCK_GAP`, `PORTRAIT_SCALE`, `PORTRAIT_SIZE`, `FONT_GATE` in `scripts/ui/gate_screen.gd`)
- The fanfare at a thumb up and the horn at a thumb down, then the gate's sound on Enter: do they land, and at the right level? (`data/audio.json` `verdict_up`, `verdict_down` at -4 dB, `gate` at -8 dB)
- A win: the boss's corpse hold, then a second's beat, then the thumb: too long? (`Main.WIN_HOLD`; `Boss.CORPSE_FLASH_HOLD`)
- R, Restart, and Quit to title do nothing between the fall and the gate screen (the verdict cannot be skipped), and R mid-run counts as a fall with the coins lost: did that ever bite you? (`Main._verdict_pending`, `_yield`)

## The grounds

- Walking onto the crate's art to open the training panel, and off it to close: did you find the post, and does the crate with the spear read as a place? (`Grounds.AREA_MARGIN`, `SPEAR_LEAN` in `scripts/grounds.gd`)
- The rack's tallest weapon overhanging the ledge, the three weapons on the top wall's face: does it read as a rack, and did you find it? (`Grounds.RACK_WEAPONS`, `RACK_GAP`)
- R does nothing in the grounds and the pause screen there hides Restart: did you try, and did it bother you? (`Main.restart`; `BuildScreen.set_restart_visible`)
- The training rows without words: an icon, the rank pips, the price with a coin. Did the prices and the pips read? Did a greyed row (capped, or too poor) read as such, and did the refusal's sound help? (`TrainingRules.LINES` prices in `scripts/training_rules.gd`; `ROW_SIZE`, `PRICE_FONT_SIZE`, `GREY_MODULATE` in `scripts/ui/training_panel.gd`; `data/audio.json` `buy`, `buy_denied`)
- What each line does (hearts: two hp a rank; breath: a dash charge; renown: 10 favour at the start): did the next run show it? The names are placeholders and never appear on screen. (`TrainingRules.HP_PER_HEART`, `FAVOUR_PER_RENOWN`; `Build.starting`)
- The armoury's lit handgun slot and two empty ones, the gladiator's idle beside them: does it promise the right thing, or ask for a click it cannot answer? (`SLOT_COUNT`, `EMPTY_MODULATE`, `GLADIATOR_SCALE` in `scripts/ui/armoury_panel.gd`)
- The gate: walking into the open door starts the run behind a fade. Does the door read as the way in, and is the fade the right length? (`Grounds.GATE_SPRITES`; `Main.FADE_TIME`)
- The grounds' loop (`music_grounds`, "Ambient - Agricola" at -2 dB): the right mood for a place between runs, and the right level? (`data/audio.json`)

## The music swap

- Land of the Ancients: "War - Legions" for the run (0 dB) and "War - Sons of Mars" for the boss (+2 dB), against the effects: right level, and does the swap at the boss's spawn land? (`data/audio.json` `music_run`, `music_boss`; `Audio.MUSIC_FADE`)

## Show, don't tell

- The one question: where did you feel told? A caption, a label, a name, a hint, a sound that explained instead of being. We want "nowhere"; anything else is a row for the next milestone.

## Verdict, playtest 1 (2026-09-25)

The user played `0.5.0-rc1` three times: two wins (192 kills in 178 s, seed 583160756; 194 kills in 190 s, seed 1158544060) and a fall in round 7 (189 kills, 148 s, seed 1228492380). Sixteen notes. Each maps to one change, one commit each; the Change column holds the decision once taken, the Done column the commit.

| # | Note | Change | Where | Done |
|---|---|---|---|---|
| 1 | Need to grab coins from further away (a pull) | Piles inside `PULL_RADIUS` (96 px) drift to the player at `PULL_SPEED`, accelerating; `Reach` ranks widen it | `scripts/coin_pile.gd` | |
| 2 | A little more time to grab coins between rounds; maybe wait until the coins are picked up | After the pick, the gap waits until no pile is left on the floor, up to `PILE_WAIT_CAP` (6 s), then the next wave | `scripts/main.gd` `_next_round_later` | |
| 3 | Favour is far too easy to accumulate: it maxes naturally while avoiding and killing | Decision: harder to gain and it decays: kill +1, chain +2, daring +4, clean round +10, hit -25; `DECAY_PER_SECOND` 1.5 after `DECAY_GRACE` 3 s without a scoring act while enemies live (the cowardice drain folds into it); start 20 | `scripts/favour_rules.gd` | |
| 4 | The first boss is still far too weak (two wins in about three minutes each) | `max_hp` 300 to 600, `telegraph_time` 0.6 to 0.5, `recover_time` 0.8 to 0.55, `charge_speed` 320 to 380; stage two keeps its own numbers; tune again on the next run | `data/enemies/boss.tres` | Done in 3eb4cf1 (a stray commit "x" from another session swept the data, the pinned test, and the docs in) and 3eb4cf1 (the charge test) |
| 5 | The emperor's decision comes too fast, without build-up or a scene (an announcer asking the emperor?) | Decision: a longer wordless beat now (the crowd quiets, the camera drifts to the box, a drum roll, a held pause of about four seconds, then the thumb); the announcer's line in M6 with the dialogue system | `scripts/main.gd` verdict scene | |
| 6 | The thumb is ugly and disproportionate | A 24x24 placeholder drawn with a proper fist (thumb, knuckles, a cuff) at 2x, centred over the box; M8's art replaces it | `scripts/thumb_sign.gd` | |
| 7 | No emperor decision when the player wins | Decision: no thumb on a win; the victor goes out by the Porta Triumphalis after the roar and the sweep | `scripts/main.gd` `_verdict` | |
| 8 | In the hub, stores should show the currencies you hold | The panel shows the money held (a coin icon and the number) at its top | `scripts/ui/training_panel.gd` | |
| 9 | Eventually, stores should have merchant NPCs | Recorded for M6: the lanista at the post, the armourer at the rack | design | |
| 10 | A quick text description in the store UI | Decision: the rule refined to "UI may name, never narrate" (colosseum design); each row gets a short line naming what it buys | `scripts/ui/training_panel.gd` | |
| 11 | Passives bought in the hub should differ from the boons of a series | Decision: the lines buy what a run cannot give: Offer (+1 card per offer), Reroll (one per run, a button on the picker), Mercy (the emperor spares you once: the fall becomes a heart), Reach (a wider pull); Hearts, Breath, Renown removed (hearts and dashes stay cards) | design | |
| 12 | Eventually, the first arrival in the hub should be a cutscene, like the first death | Recorded for M6/M9 | design | |
| 13 | The fourth card on a Roar went unnoticed; it should arrive with a delay and an animation | The three cards land, then after `FOURTH_CARD_DELAY` (0.6 s) the fourth slides in from the right with the crowd's roar; `pick_4` only once it is in | `scripts/ui/upgrade_menu.gd` | |
| 14 | The bonuses in the top right corner should reset between series | Bug: the HUD build strip and the counter refresh on `run_started` (a run from the gate has no scene reload) | `scripts/ui/hud.gd` | Done in 6d861b1 |
| 15 | The highlighted enemy on the end screen needs text to say what it is | A line under the portrait: the enemy's display name and "hit you N times" (UI may name) | `scripts/ui/gate_screen.gd` | |
| 16 | I don't understand the bars under the life bar | An icon at the left of each: a boot for the dash pips, a small crowd for the favour meter, from the Raven sheet or drawn in code until M8 | `scripts/ui/hud.gd` | |
