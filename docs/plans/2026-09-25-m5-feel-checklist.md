# Milestone 5 feel checklist

Play at least two runs (win or fall; eight rounds in one arena, a card after each of the first seven,
the boss in round 8), and let one end in the grounds with money spent at the training post before the
next gate. `tools/run.sh` or the zips (`0.5.0-rc1` for playtest 1, `0.5.0-rc2` for playtest 2); the seed
is on the gate screen and in the `RUN_END` line; `-- --seed=N` replays it. The cheats in the seed field:
`permawhat?` (no damage), `verso` (the thumb goes down), `dives` (1000 coins). Rate each line good / meh /
bad with a note; the knob for each is named. The milestone closes when the slice is one you would hand a
friend and every row's answer to "where did you feel told" is "nowhere".

The sections up to "Verdict, playtest 1" are playtest 1's questions as asked of `0.5.0-rc1` (their numbers
are rc1's); the verdict table holds the sixteen notes and what each became, and "Questions for playtest 2"
is what `0.5.0-rc2` asks.

## The round flow

- The gap between rounds (a pick, then a second of empty arena, then the next wave): a breath, or dead time? (`Main.ROUND_GAP`, `PICKER_DELAY` in `scripts/main.gd`)
- ~~The granter's name over the cards ("The crowd", "The emperor"): does it read as who is giving, and does it change your sense of the pick? (`FavourRules.GRANTER_CROWD`/`GRANTER_EMPEROR` in `scripts/favour_rules.gd`, `GRANTER_GAP` in `scripts/ui/upgrade_menu.gd`)~~ (the granters went in playtest 2, note 4)
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
| 1 | Need to grab coins from further away (a pull) | Piles inside `PileRules.PULL_RADIUS` (96 px) drift to the player at `PULL_SPEED`, accelerating; a Roar's and the boss's piles land in a ring past the reach (`RING_MIN` 112 to `RING_MAX` 160), so they wait to be walked to; `Reach` ranks widen the pull | `scripts/coin_pile.gd`, `scripts/pile_rules.gd` | Done in 5ecc413; the ring in f6d5f65 |
| 2 | A little more time to grab coins between rounds; maybe wait until the coins are picked up | After the pick, the gap waits until no pile is left on the floor, up to `PILE_WAIT_CAP` (6 s), then the next wave | `scripts/main.gd` `_next_round_later` | Done in e68d02d |
| 3 | Favour is far too easy to accumulate: it maxes naturally while avoiding and killing | Decision: harder to gain and it decays. Shipped: kill +1, chain +2, daring +4, clean round +10, hit -25, start 20; the decay `DECAY_PER_SECOND` 1.5 after `DECAY_GRACE` 3 s without a scoring act (a kill, a chain, a daring, a clean round; a hit on an enemy that does not kill no longer holds it off) while enemies live, replacing the cowardice drain; bands unchanged. Then, on the review's estimate that a hit-free run still maxes it: kills and chains cap at the Roar edge (75; daring and the clean round push past), and the crowd cools between rounds (the decay runs whenever a run is live and unpaused, through the gap and the coin wait, until the fall or the run's end; never in the grounds); after the review: the cap is 74, one under the Roar edge, so kills alone never reach Roar (a clean round or a daring dash does), and the crowd stops cooling at a win | `scripts/favour_rules.gd`, `scripts/favour.gd` | Done in 815cef8, the cap and the cooling in e586b53, the cap at 74 and the cooling's end at a win in 2ec619d |
| 4 | The first boss is still far too weak (two wins in about three minutes each) | `max_hp` 300 to 600, `telegraph_time` 0.6 to 0.5, `recover_time` 0.8 to 0.55, `charge_speed` 320 to 380; stage two keeps its own numbers; tune again on the next run | `data/enemies/boss.tres` | Done in 3eb4cf1 |
| 5 | The emperor's decision comes too fast, without build-up or a scene (an announcer asking the emperor?) | Decision: a longer wordless beat now; the announcer's line in M6 with the dialogue system. Shipped: after the hold (`VERDICT_HOLD` 1.0 s, the hush the only sound) the camera drifts from the fallen gladiator to the emperor's box over `VERDICT_DRIFT` (1.5 s), zooming in by `VERDICT_ZOOM` (1.5) as it goes with its limits kept (never the void: the box framed a tile under the top of the zoomed view, the arena filling the rest, the gladiator out of frame below only when the fall was in the arena's bottom third) under the drum roll (`verdict_roll`, the user's file, cut by the thumb), then a held pause `VERDICT_PAUSE` (1.2 s) on the box, then the thumb: 3.7 s from the fall; the camera snaps back at the next run's start, under the black | `scripts/main.gd` `_build_up`, `VERDICT_ZOOM`; `scripts/camera.gd` `drift_to`, `top_framed` | Done in 1b78651, the zoomed drift in f60e100 |
| 6 | The thumb is ugly and disproportionate | The Raven sheet's drawn thumbs (`thumb_up` (54, 15), `thumb_down` (55, 15)) at 3x, centred over the box; M8's art replaces them | `scripts/thumb_sign.gd` | Done in 067c602 (a code-drawn fist), replaced by the sheet's thumbs in f6d5f65 |
| 7 | No emperor decision when the player wins | Decision: no thumb on a win; the victor goes out by the Porta Triumphalis after the roar and the sweep | `scripts/main.gd` `_verdict` | Done in 82bcc56 |
| 8 | In the hub, stores should show the currencies you hold | The panel shows the money held (a coin icon and the number) at its top | `scripts/ui/training_panel.gd` | Done in bb38986 |
| 9 | Eventually, stores should have merchant NPCs | Recorded for M6: the lanista at the post, the armourer at the rack | design | M6 |
| 10 | A quick text description in the store UI | Decision: the rule refined to "UI may name, never narrate" (colosseum design); each row gets a short line naming what it buys | `scripts/ui/training_panel.gd` | Done in b7fdcff |
| 11 | Passives bought in the hub should differ from the boons of a series | Decision: the lines buy what a run cannot give: Offer (+1 card per offer), Reroll (one per run, a button on the picker), Mercy (the emperor spares you once: the fall becomes a heart), Reach (a wider pull); Hearts, Breath, Renown removed (hearts and dashes stay cards). Shipped: Offer (2 ranks, 120/240: one more card in every offer, `UpgradeMenu.MAX_CARDS` 5, a row too wide for the view drawn at three quarters, key 5 for the fifth, the extra card sliding in with the roar), Reroll (2 ranks, 100/200: the picker's Reroll button with a pip per re-draw left, the same round's offer drawn again from its own seeded stream, the heal slot kept), Mercy (1 rank, 300: the lethal hit leaves one heart with a ring and the roar; the next one falls), Reach (3 ranks, 40/80/160: the pull 32 px wider a rank); each row an icon (scroll, clover, the heal figure, the coin) and its line; an rc1 save's old ranks load and count for nothing | `scripts/training_rules.gd`, `scripts/ui/training_panel.gd`, `scripts/ui/upgrade_menu.gd`, `scripts/main.gd`, `scripts/player.gd` | Done in 6900401 (the lines), 01611a2 (Offer), 871c7d8 (Reroll), bb52a8a (Mercy), the review pass in 418ff0a |
| 12 | Eventually, the first arrival in the hub should be a cutscene, like the first death | Recorded for M6/M9 | design | M6/M9 |
| 13 | The fourth card on a Roar went unnoticed; it should arrive with a delay and an animation | The three cards land, then after `LAST_CARD_DELAY` (0.6 s) the fourth slides in from the right over `LAST_CARD_SLIDE` with the crowd's roar; `pick_4` only once it is in (from Task 11 the same reveal serves any card past the base three: an Offer rank's extra card on a lesser band slides in with `ui_open`) | `scripts/ui/upgrade_menu.gd` | Done in 847e5b1, generalised in 01611a2 and 418ff0a |
| 14 | The bonuses in the top right corner should reset between series | Bug: the HUD build strip and the counter refresh on `run_started` (a run from the gate has no scene reload) | `scripts/ui/hud.gd` | Done in 6d861b1 |
| 15 | The highlighted enemy on the end screen needs text to say what it is | A line under the portrait: the enemy's display name and "hit you N times" (UI may name) | `scripts/ui/gate_screen.gd` | Done in c66e1fe |
| 16 | I don't understand the bars under the life bar | An icon at the left of each: the boot for the dash pips (`dash_charge`), two heads drawn in code for the favour meter (PLACEHOLDER: the Raven sheet has no crowd) until M8 | `scripts/ui/hud.gd` | Done in 224dcab (a mask from the sheet), the placeholder heads in f6d5f65 |

## Questions for playtest 2 (`0.5.0-rc2`)

What rc2 asks, each with its knob; rate good / meh / bad with a note as before, and the one question under
"Show, don't tell" stands.

- The favour retune: kill +1, chain +2, daring +4, clean round +10, hit -25, from 20; kills and chains never lift the meter past 74, so a Roar takes a clean round or a daring kill. Does a Roar feel earned now, and did you reach one? (`FavourRules.ACTS`, `START`, `KILL_CAP`, `CAPPED_ACTS` in `scripts/favour_rules.gd`)
- The decay: after 3 s without a scoring act the meter loses 1.5 a second while the run is live, through the gap between rounds and the coin wait. Does it read (the crowd cooling while you run, idle, or walk to coins), and did it ever feel unfair? (`FavourRules.DECAY_GRACE`, `DECAY_PER_SECOND`)
- The two heads beside the meter and the boot beside the dash pips: do the rows read now, and does the placeholder crowd pass until M8's art? (`Hud.crowd_placeholder`, `ROW_ICON_SCALE`, `ROW_ICON_GAP` in `scripts/ui/hud.gd`)
- The pull: a landed pile within 96 px drifts to you, accelerating; Reach widens it 32 px a rank. The right reach, and did the acceleration read? (`PileRules.PULL_RADIUS` in `scripts/pile_rules.gd`; `CoinPile.PULL_SPEED`, `PULL_ACCEL` in `scripts/coin_pile.gd`; `TrainingRules.REACH_STEP`)
- The ring: a Roar's piles and the boss's land 112 to 160 px out, past the pull, on the open side near a wall. A scatter worth walking, and did any land where you could not see them? (`PileRules.RING_MIN`, `RING_MAX`, `MIN_GAP`)
- The wait: after a pick the next round holds until the floor is clear of piles, up to 6 s. A breath, or dead time; did you ever wait the whole cap? (`Main.PILE_WAIT_CAP`, `ROUND_GAP` in `scripts/main.gd`)
- The build-up: after the fall, a second's hold, then the camera drifts to the emperor's box over 1.5 s zooming in 1.5x under the drum roll, holds 1.2 s on the box, then the hand. 3.7 s from the fall to the hand: right, or too long? Did the zoom frame the box, and did the drift read as looking to the emperor? (`Main.VERDICT_HOLD`, `VERDICT_DRIFT`, `VERDICT_ZOOM`, `VERDICT_PAUSE`; `Camera.TOP_MARGIN` in `scripts/camera.gd`; `data/audio.json` `verdict_roll` at -6 dB)
- The hand: the Raven sheet's thumb at 3x over the box. Does it read as the emperor's, and at the right size? (`ThumbSign.SCALE` in `scripts/thumb_sign.gd`)
- The late card: a Roar's fourth card, and an Offer rank's extra card on any band, arrive 0.6 s after the others, sliding in from the right (the roar, or the picker's open sound). Did you notice it this time, and did the delay read as a gift? (`UpgradeMenu.LAST_CARD_DELAY`, `LAST_CARD_SLIDE` in `scripts/ui/upgrade_menu.gd`)
- The five-card row (two Offer ranks, or one on a Roar): the cards at three quarters with a gap. Readable, or cramped? Should four already shrink? (`UpgradeMenu.MAX_CARDS`, `SCALE_STEP`, `CARD_GAP`, `CARD_SIZE`)
- The Reroll button under the cards with a pip per re-draw left: found, understood, and did the re-drawn offer feel like a new hand or the same one? (`UpgradeMenu.REROLL_SIZE`, `REROLL_GAP`, `REROLL_PIP_GAP`; `TrainingRules.LINES.reroll`)
- Mercy: the lethal hit leaves one heart with a ring and the roar, and the next one falls. Did it trigger, did you see why you were still up, and was 300 the right price? (`Player.MERCY_HP` in `scripts/player.gd`; `TrainingRules.LINES.mercy`)
- The four training lines (Offer 120/240, Reroll 100/200, Mercy 300, Reach 40/80/160) with their icons and their lines: which did you buy first, did the row's line say enough and no more, and did the next run show the purchase? (`TrainingRules.LINES` in `scripts/training_rules.gd`; `LINE_FONT_SIZE`, `ROW_SIZE` in `scripts/ui/training_panel.gd`)
- The money at the panel's top: found, and did it make the prices read? (`TrainingPanel.MONEY_HEIGHT`)
- The boss at 600 hp with the faster telegraph, recover, and charge: how long did it take, where did you fall to it, and is it a fight now? (`data/enemies/boss.tres` `max_hp`, `telegraph_time`, `recover_time`, `charge_speed`)
- No thumb on a win: the fanfare, the sweep, the Porta Triumphalis. Did the win's end feel complete without the emperor? (`Main.WIN_HOLD`, `_verdict`)
- The portrait's line on the gate screen ("<name> hit you N times"): a name, or a narration? (`GateScreen.portrait_line` in `scripts/ui/gate_screen.gd`)
- Show, don't tell: where did you feel told? The row's lines and the portrait's line name; if any of them explained, say which.

## Verdict, playtest 2 (2026-09-26)

The user played `0.5.0-rc2` and returned six notes. One row each, the decision in Change and the commit in
Done; the tasks are 13 to 18 of `docs/plans/2026-09-25-milestone-5.md`.

| # | Note | Change | Where | Done |
|---|---|---|---|---|
| 1 | Training bonuses should have names, and a description when hovered | Each line gets a name (`TrainingRules.LINES[*].name`: Offer, Reroll, Mercy, Reach) shown on its row beside the icon; the row's line moves to a description strip at the panel's foot that shows the hovered row's text and is empty otherwise (UI may name: a name on a thing you buy) | `scripts/training_rules.gd`, `scripts/ui/training_panel.gd` | Done in f725e05, the review pass in 02c0f15 |
| 2 | A debug option to wipe the save, or a proper save manager, to test the game from the start | The code word `tabula` in the title's seed field (the testing-aid pattern of `permawhat?`, `verso`, `dives`): Play then backs the save file up to `<path>.bak`, replaces it with the defaults, commits, and starts as a first run (the arena, the grounds after the gate). A title-time action, not a run flag: the run is uncheated | `scripts/cheats.gd`, `scripts/autoload/profile.gd`, `scripts/ui/title.gd`, `scripts/main.gd` | Done in cd3b11e, the review pass in 795e11b (a failed backup refuses the wipe) |
| 3 | Extra cards from training should load at the same time as the normal cards | Only the crowd's card (a Roar) arrives late; an Offer rank's cards land with the base three on every band | `scripts/ui/upgrade_menu.gd`, `scripts/main.gd` | Done in 9ca545d, the review pass in d5befd8 |
| 4 | "The emperor" over the cards by default and "the crowd" on a roar reads oddly; the roar's extra card should look extra, and the heading should just say "Pick a boon" | The heading is always "Pick a boon" (the user's words; the granters and `FavourRules.granter` go). The crowd's card is drawn apart (its own frame from the UI sheet and the crowd's two heads over its title) and drops in from the top of the view (the stands are above) after the beat, into the last slot without a heal, the one before it with | `scripts/ui/upgrade_menu.gd`, `scripts/ui/ui_theme.gd`, `scripts/favour_rules.gd` | Done in c84ca77 (the heading), 9ca545d (the crowd's card), the review pass in d5befd8 (the gold tint, the heads at 4x, the `roar` smoke) |
| 5 | No boons should be held back in the hub; the pause menu should have tabs to look separately at training, boons, etc. | Bug: `RunState.build` outlived the run into the grounds (the pause screen showed the last run's cards and the gladiator kept its hearts and charges); `enter_grounds` clears the loadout before the revive. The pause screen gets three tabs: Options (Resume, Restart, the volumes, the quits), Boons (the build), Training (the profile's lines with their names and rank pips); Esc opens on Options, Tab on Boons | `scripts/main.gd`, `scripts/autoload/run_state.gd`, `scripts/ui/build_screen.gd`, `scripts/ui/training_panel.gd` | Done in d8a29c0 (the build cleared in the grounds), eeb07f5 (the tabs) |
| 6 | Favour is too hard to obtain in the first few rounds, then too easy; dashing towards enemies does not feel rewarded | Decision: a round's kills pay a fixed budget (`KILL_BUDGET` 40 shared by the round's enemies, so round 1's nine and round 7's fifty-three each bring the meter the same distance); a dash through danger scores at once (`dare` +2, the radius 32) and the kill after it more (`daring` +5, the window 0.75 s); kills, chains, dares, and the clean round all stop at 74 (`ROAR_GATE`): only a daring kill reaches Roar, in every round alike | `scripts/favour_rules.gd`, `scripts/favour.gd`, `scripts/autoload/run_state.gd`, `scripts/main.gd` | |
