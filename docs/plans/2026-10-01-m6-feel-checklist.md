# Milestone 6 feel checklist (phase 1)

Play at least two runs into the grounds and back: walk all five rooms, talk to everyone with a
bubble over their head, buy at the post, take the lift, and let one run fall under `verso` so the
thumb goes down and you wake in the Spoliarium. `tools/run.sh` or the zips of `0.6.0-rc1`; the seed
is on the gate screen and in the `RUN_END` line; `-- --seed=N` replays it. The cheats in the seed
field: `permawhat?` (no damage), `verso` (the thumb goes down), `dives` (1000 coins); beside them
`tabula` wipes the save (kept as `save.cfg.bak`) and plays a first run, which is the way to see the
first arrival in the Ludus again. Every line of text is a placeholder (M9 writes the real ones):
judge where a line sits, how long it stays, and whether it reinforces, not its words. Rate each line
good / meh / bad with a note; the knob for each is named. Phase 1 closes on this playtest's verdict
(the table at the end), and every row's answer to "where did you feel told" should be "nowhere".

## The decay

- The crowd cools sooner and faster: after 2 s without a scoring act the meter loses 4 a second, so two idle seconds past the grace cost about eight points. When you stopped fighting, did the bar visibly drop? Did it drop while you were fighting well? (`FavourRules.DECAY_GRACE`, `DECAY_PER_SECOND` in `scripts/favour_rules.gd`)
- The boss: a shot that lands on it holds the decay off as a kill would (a burn's tick does not), so its first stage, with nothing else to kill, no longer drains the meter. Did the meter hold while you shot it, and drop when you only dodged? (`Favour._on_enemy_hit` in `scripts/favour.gd`)
- Narrow escapes: a dash that passes within 20 px of an enemy's bolt scores a dare, as a dash past an enemy's body does, and a kill just after it is daring. Did you notice the meter tick on a close dash past a bolt, and did you ever dash at a volley for the crowd? (`FavourRules.BOLT_RADIUS`, `dash_past_bolt`)
- Dare-farming: in the shooter rounds, can you hold Cheer on dashes alone (each dare restarts the grace)? The knobs, in order: a dare restarts the grace only when it raises the meter; a once-per-bolt mark (a bolt pays one dare); a smaller `BOLT_RADIUS` (the hurt radius plus the bolt's is 11 px, so 20 px leaves a 9 px band). (`scripts/favour.gd` `_on_player_dashed`; `FavourRules.BOLT_RADIUS`)

## The grounds: five rooms and one key

- The map: the Ludus (the post, the lanista, the veteran), the Armamentarium (the rack, the armourer) to its left, the Sanitarium (the doctor) to its right, the Hypogeum (the lift, the attendant) through its top, the Spoliarium beside the Hypogeum once seen. Did you find every room, and did the layout make sense to walk? (`data/grounds/*.tres` `doors`; `GroundsRooms`)
- A door is a bare gap in the wall (the void showing through, no frame; the lift keeps the M5 gate's art). Did the gaps read as ways through, at the top and at the sides? (`ArenaGrid.door_gap`; `Door.AREA_MARGIN` in `scripts/door.gd`; M8's art replaces both)
- The rooms are 26 tiles wide, so each sits whole in the view with a thin black margin at each side. Did the margin bother you? (`GroundsRoomDef.width` in `scripts/defs/grounds_room_def.gd`)
- The dressing, a first cut from the tileset: banners and a fountain in the Ludus, blue banners in the Armamentarium, columns in the Hypogeum, a fountain and flasks in the Sanitarium, skulls in the Spoliarium. Does each room read as a place of its own? (`dressing` in `data/grounds/*.tres`)
- The walk to the arena (the Ludus, its top door, the lift) is a few seconds a run. Fine, or a chore by the third run? (the map in `data/grounds/`)
- Nothing opens on contact: E acts on whatever is in reach, under the key cap. Did you find the post, the rack, the doors, and the lift, and did E do what you expected each time? (`Interactable`, `Grounds._update_focus`; `Main._on_interacted`)
- The key cap ("E" on a small panel) over the thing in reach; over the rack, the lift, and the side doors it is held inside the view's edge. Readable, in the right place, too big? (`KeyCap.SIZE`, `GAP`, `EDGE` in `scripts/ui/key_cap.gd`)
- A panel closes on E, on Esc, or when you walk off. Did any of the three surprise you? (`Main._on_focus_changed`, `_unhandled_input`)
- Arriving through a door you stand a little into the room, with nothing in reach. Too far in, or about right? (`Grounds.ENTRY_DEPTH` in `scripts/grounds.gd`)

## The talk

- The bleeps (dmochas's pack, one pitch per speaker): the files peak around -16 to -24 dBFS and play at 0 dB, a guess. Too quiet, too loud, the right voice for each? (`bleep_<cast id>` `volume_db`, `pitch_jitter`, `min_gap` in `data/audio.json`)
- The blip cadence: a bleep every three letters revealed, spaces and punctuation counted, at 40 letters a second. Chatter, or a voice? (`DialogueBox.BLIP_EVERY`, `REVEAL_PER_SECOND` in `scripts/ui/dialogue_box.gd`)
- The box: 1152 by 224 at the top or the bottom of the view, whichever side the gladiator is not on, the portrait at 4x at the left. The size, and the portrait's place in it? (`DialogueBox.BOX_SIZE`, `PORTRAIT_SCALE`, `PORTRAIT_SLOT`, `EDGE_GAP`; `Main._box_at_top`)
- Going on: E, Enter, or a click finishes a line, then passes it; Space does not (it is the dash). Did you reach for another key? Replies: 1 to 5 or a click. Did the numbered list read? (`DialogueBox._unhandled_input`, `pick_action`)
- The gold bubble over a head with something new to say: did you see it, did you go to it, and did it go when you expected? Over the ogre and the lizard it floats a tile above the drawn head, and the armourer's sits on the wall's face. (`StoryMark` `BUBBLE`, `FILL`, `BOB_HEIGHT`, `BOB_PERIOD` in `scripts/story_mark.gd`; `CastFigure.MARK_GAP` in `scripts/cast_figure.gd`)
- A character's bubble gives way to the key cap when you are in reach; a merchant's stays up beside the cap over the station. Did the two read together? (`CastFigure.hides_mark_when_focused`)
- The merchants: the lanista at the post and the armourer at the rack say their new word first, then the panel opens; with nothing new, the panel opens at once. Did the word before the panel feel like a person, or a toll? (`Main._on_station`)
- The first return: the lanista's line as the black lifts in the Ludus (once; `tabula` to see it again). Did it land as a welcome? (`lanista.arrival` in `data/story/lanista.txt`; `Main._play_entry`)
- Characters are solid at the lower body, with no depth sorting: walking up from above, the gladiator draws over them. Did it look wrong? (`CastFigure.BODY_HEIGHT`, `BODY_INSET`, `STAND_BELOW`; a y-sort is the fix)

## The narrator at the verdict

- The window at the bottom of the zoomed verdict view, through the drift and the pause (2.7 s), then the thumb's line under the thumb. It covers a gladiator who fell near the floor's middle row (in frame for about 37% of fall positions, 45% before). Did it hide the body you wanted to see? The knobs: a shorter one-line strip, or the window on the bottom side away from the body (a horizontal side for `show_timed`). (`DialogueBox.TIMED_BOX_SIZE`; `Main._narrate`)
- The silhouette: the hatted figure drawn dark at 3x, nameless, silent. Big enough to read as someone? (`DialogueBox.TIMED_PORTRAIT_SCALE`, `TIMED_PORTRAIT_SLOT`, `SILHOUETTE`; the narrator's `sprite` in `data/story/cast.json`)
- The thumb now stays 2.5 s with its line (a win's stay is 1.2 s, with no line). Long enough to read, or too long before the gate? (`Main.VERDICT_SHOW`, `WIN_SHOW` in `scripts/main.gd`)

## The crowd at the pick

- The line over "Pick a boon" judges the round: at Boo and Quiet by what lost the most favour (a hit, running, or stalling), at Cheer and Roar with praise. Did `fled` and `slow` read right in play: hunting the last shooter at range, kiting chasers while shooting, standing still while a wave walks in? (`FavourRules.NEAR_RADIUS` 96 and the engagement window `DECAY_GRACE` in `scripts/favour_rules.gd`; `FavourRules.drain_source`)
- The line's place: at three and four cards it crosses the emperor's box's door in the top wall, and late in a run the HUD's build strip at the right. Legible, and acceptable over the box? The knob: a drop of the picker's column while a line shows (56 px at full scale). (`UpgradeMenu.CROWD_LINE_GAP`, `HEADING_GAP` in `scripts/ui/upgrade_menu.gd`)

## The lock

- A round ended at Boo offers one card greyed under a chain, which neither its key nor a click takes. Did it read as taken by the crowd, with the boos and the crowd's line? (`UpgradeMenu.CHAIN_SCALE`, `CHAIN_STEP`, `CHAIN_CROSS`, `LOCKED_MODULATE`; the `chain` icon)
- Losing a card at Boo: fair, or piling on a round that already went badly? (`FavourRules.LOCKS_AT_BOO`; `UpgradeCatalog.LOCK_MIN_PICKABLE` in `scripts/upgrade_catalog.gd`)
- The heal card is never the one locked (the crowd takes a boon, not the gladiator's life). Should it be lockable? (`UpgradeCatalog.LOCK_SPARES_HEAL`)
- A locked card with a two-line name: the `boo` capture's "Heart Container" reads as "leat / ontaine" under the chain's X, which crosses at the icon and suits a one-line name. Readable enough? (`UpgradeMenu.CHAIN_CROSS`; an art judgement)

## The wake

- After a thumbs down and the Porta Libitinaria screen the gladiator lies on the Spoliarium's floor. Does the lying pose (the fall's quarter turn) read as a wake and not a death? (`Player.lie` in `scripts/player.gd`)
- The rise has no animation: the sprite stands on the first press. Acceptable until M8's art? (`Player.rise`)
- The room plays no music. Is the silence enough to say where you are? (`music` in `data/grounds/spoliarium.tres`)
- The narrator's wake line stays 3 s at the top. Read in time? (`Main.ENTRY_LINE_TIME`)
- Rising on any move, the dash, or E, with a click (the shot) doing nothing: right? (`Player.RISE_ACTIONS`)
- Esc during the wake's line takes it down, and it does not come back after the pause screen closes. Acceptable? (`Main._on_menu_opened`)

## Show, don't tell

- The one question: where did you feel told? A caption, a label, a name, a hint, a line someone said, a sound that explained instead of being. The key cap names a key, the box names its speaker, the post names its lines; the crowd's line and the narrator's should only say what the sound and the thumb already said. We want "nowhere"; anything else is a row below.

## Verdict, playtest 1

(The user's notes on `0.6.0-rc1`, one row each; the Change column holds the decision once taken,
the Done column the commit.)

| # | Note (2026-10-02) | Change | Where | Done |
|---|---|---|---|---|
| 1 | Difficulty is still good. | None. | | n/a |
| 2 | The merchant and upgrade menus (the rack's and the post's panels) should close on a click outside the window, on top of Esc and walking away. | A click outside the panel closes it (Task 10a). | `TrainingPanel`, `ArmouryPanel`, `Main` | `585c31f` |
| 3 | Narrative style and character design are good, a strong start to build on. One nit: the lanista speaks of notches in the post, but none are visible. Fix the visuals, not the writing. | Notches drawn on the post (Task 10b, a placeholder until M8's art). | `grounds.gd` | `24eed83` |
| 4 | The door that leads back to the arena has a wall under it. | The lift's opening cuts the top wall's face like a door gap (Task 10c). | `grounds.gd`, `arena.gd` | `4052cd0` |
| 5 | Until the first heart container (the one that sticks to the right) is taken, it should always be on the right, like healing, and it can never be the extra one the crowd grants. | The container holds the right slot hurt or not until one is owned; the crowd's card sits before it (Task 10d). | `UpgradeCatalog.offers`, `UpgradeMenu.crowd_slot` | |
| 6 | The single shooter on the first wave of round 2 makes little sense on its own. | The wave gets company (Task 10e). | `data/waves/room_2.tres` | |
| 7 | Ricochet should ricochet off shields. | A shot with a bounce left reflects off a blocking shield (Task 10f). | `Projectile`, `ShieldRules` | |
| 8 | The boss is too easy, but earning favour on the boss fight is too hard. | The boss harder; its damage pays the round's kill budget as it is dealt (Task 10g). | `boss.tres`, `boss.gd`, `FavourRules`, `Favour` | |

| # | Note | Change | Where | Done |
|---|---|---|---|---|
| | | | | |
