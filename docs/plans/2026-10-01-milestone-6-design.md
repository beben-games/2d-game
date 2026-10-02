# Milestone 6 design: the colosseum grounds

Status: approved 2026-10-01 in the M6 design session (drafted from the colosseum direction's M6 row
(`2026-09-25-colosseum-design.md`), the M5 checklist's three verdict tables, and the user's answers,
recorded at the end). The plan is `2026-10-01-milestone-6.md`.

**Goal.** The grounds become five rooms with people in them, and the game gains a story system in
the manner of Hades: pools of short events per character, gated on each other and on what the
player has done, shown in a text box, at the emperor's verdict, and at the pick. A visual tool of
our own maintains the events and their interconnections. Every line is a placeholder in the world's
voice until M9's writing.

**Two phases, one tag.** Phase 1 is the game side and closes on a playtest of `0.6.0-rc1`. Phase 2
is the writer's kit (the Story tab, the lint, the brief) and closes when the user has written a few
real events with it. `m6` is tagged after both.

**Out of scope.** The turning point and any thumbs down in normal play (M9; `verso` stays the only
way down); the real writing and the character pages' content (the user's, workshopped in their own
session; the pages are due by M6's end); portraits and room art (M8); tiers, classes, and the
armoury's choices (M7); the economy pass on the training prices, coins popping with the wave, and
the hidden favour bar (parked, the user's choice of 2026-10-01); relationship levels, gifts, and
events that fire mid-run (wanted later: the three seams below keep them open); a door sound (the
fade is the transition; M2's `door_open` is still in `assets/sfx` if a playtest asks for one).

## The story system

**The unit is an event**, not a tree. Each character has a pool of events in one plain-text file
(`data/story/<character>.txt`). An event carries:

- `requires` / `unless`: events that must, or must not, have played, from any character's pool.
  This is the cross-character gating.
- `when`: a condition over story flags, the profile's flags and stats (`wins`, `falls`, `deaths`,
  `runs`), and facts about the last run (`last_outcome`, `last_verdict`, `last_band`,
  `last_killer`) or, at the pick, the round (`round_band`, `round_loss`).
- `priority`: `story`, `high`, `normal`, or `filler`. The highest eligible tier wins; within a
  tier, file order. Repeatable events rotate, least recently played first.
- `once` (the default) or `repeat`.
- `trigger`: `talk` (the default: E on the character), `enter <room>` (plays on arrival), or a
  named moment: `verdict_wait`, `verdict_up`, `verdict_down`, `pick`.
- `act` (optional, 1 to 3): for the Story tab's filter, the lint, and the act cheat.
- A body: lines (`SPEAKER: text`), each with an optional condition in brackets before it, and
  optional choices (`? text`, then indented effects and lines). No nested choices.

```text
# data/story/veteran.txt
== the_warning
requires: lanista.after_first_win, doctor.the_wound
when: deaths >= 1
priority: high

VETERAN: PLACEHOLDER {wins} nights, and you still walk.
[last_verdict == down] VETERAN: PLACEHOLDER I saw them carry you out.
? PLACEHOLDER Say nothing.
    set: veteran_distant
? PLACEHOLDER "So did you."
    set: veteran_trust
    VETERAN: PLACEHOLDER Hm.
```

An event's full id is `<file>.<name>`. A placeholder line starts with `PLACEHOLDER`, which the
lint counts and the box never shows.

**One picker, three presenters.** The narrator's windows at the verdict and the crowd's line at
the pick are events in pools of their own (`narrator.txt`, `crowd.txt`), chosen by the same picker
as the lanista's. Only the way they are shown differs.

**Pacing.** Each character offers at most one non-filler `talk` event per return to the grounds.
After it, E gives a `filler` bark (or, for a merchant, the panel). `enter` events and the named
moments do not count against it. The story advances with runs.

**Something new.** `Story.has_new(character)` is true while a non-filler `talk` event is eligible
for that character this return. `story_changed` on the bus fires whenever story state changes, so
whatever shows it stays current.

**Variable text.** `{name}` substitutes any name the conditions can read; a bracketed condition on
a line plays it only when true.

**State.** A new `story` section in the save: the events played (a count and the run number of the
last play), the story flags, and who has spoken this return (cleared when a run ends). An older
save loads with an empty story. `Profile.commit()` gains one call site: the end of an event played
in the grounds.

**Validation at load**, as `UpgradeCatalog` does: a duplicate id, an unknown event in `requires` or
`unless`, an unknown name in a condition or a substitution, an effect on an undeclared flag, a
cycle of `requires`, a nested choice, an unknown trigger, or a timed line longer than its cap is an
error. Story flags are declared in `data/story/flags.txt` (name and default), so a typo never makes
a flag.

**Three seams for later** (relationship levels, gifts, mid-run events), each closed to unknown
values today:

- Conditions and substitutions resolve every name through one context (`StoryContext`), so a later
  `bond.lanista >= 2` is a new namespace in the lookup, not a parser change.
- Effects are a verb list. `set` is the only verb now; `give` or `raise` later are new verbs on the
  same line shape, usable in a choice or at an event's end.
- Triggers are a table of named moments. `round_start`, `boss_spawn`, or `low_health` are new rows,
  shown by the timed presenter the verdict already uses (it never pauses the game).

**Code shape.** Pure classes under test: `StoryScript` (the parser, and in phase 2 the writer back
to text), `StoryCondition` (the expression), `StoryCatalog` (load and validate), `StoryPicker`
(eligibility and choice), `StoryContext` (names to values). A `Story` autoload after `Profile`
holds the catalog and reads and writes `Profile.save`'s story section.

## The grounds

```text
 [Armamentarium] --- [ Ludus Magnus ] --- [Sanitarium]
   armourer, rack     lanista, post         doctor
                      veteran (yard)
                            |
                       [ Hypogeum ] ---> the arena (the lift)
                        attendant
                            :
                      ( Spoliarium )   its door appears once seen
```

**Rooms as data.** `data/grounds/<room>.tres` (`GroundsRoomDef`): the size in tiles (26x15 for
every room, from the user's decision during the build; the size is a parameter because the rooms
may grow when the arena does), the doors
(wall, place, the room behind, an optional condition), the stations, and the characters' spots.
`Grounds` holds one room at a time and takes the camera's limits from it. The rooms are today's
tiles ringed solid, dressed from the tileset.

**One key.** A new `interact` action on E. Doors, the post, the rack, the lift, and characters are
`Interactable`s; the nearest in reach is the focus and carries a small key cap ("E") over it.
Nothing opens on contact any more: M5's walk-in stations, the gate, and their tests change to E.
A panel closes on E, Esc, or walking out of reach.

**Doors.** E on a door: a short fade, the next room, the gladiator at the matching door.

**People.** The lanista stands at the post and the armourer at the rack (merchants); the veteran
in the Ludus's yard, the doctor in the Sanitarium, and the attendant at the Hypogeum's lift only
talk. A wordless mark floats over a character while `Story.has_new` is true. E on a character:

- a new event plays, and a merchant's panel opens after it;
- a merchant with nothing new opens the panel at once;
- anyone else gives their bark.

The cast (`data/story/cast.json`: id, placeholder name, tileset sprite for the body and the
portrait, bleep) is a placeholder until the character pages and M8's portraits.

**A run's flow.** Play (after the first return) and a thumbs up land in the Ludus. The way to the
arena is the door to the Hypogeum and E on its lift: the fade, the arena, round 1. The first-run
rule is unchanged (`flags.returned`). The walk is a few seconds a run and is where the marks are
seen; the user accepts it for now and may shorten it later.

**The first arrival.** An `enter ludus` event of `story` priority plays as the fade lifts on the
first return.

**The Spoliarium wake.** After a thumbs down and the Porta Libitinaria screen the gladiator wakes
lying on the Spoliarium's floor and rises on the first input. (The session's "no weapon in hand
until leaving the room" cannot be drawn: today's gladiator sprite holds no weapon. Being stripped
is carried by the wake, the room, the silence, and the coins already lost, until M8's art.) Its one
door leads to the Hypogeum. `flags.spoliarium_seen` is set, and from then on the
Hypogeum's door to it shows and works. The room plays no music. An `enter spoliarium` event is
there for the narrator (a placeholder).

## The text box and the three voices

**The box.** `DialogueBox` (a CanvasLayer with the menus, the UI sheet's frame, at the bottom of the
view): a portrait at the left, the speaker's name, the line revealed letter by letter in the pixel
font, with the speaker's bleep. E, Enter, or a click completes the line, then advances. Choices are
a short list picked by number key or click, as the cards are. In the grounds it pauses the tree
like the other menus. An event counts as played when it starts, so none is half-skipped.

**The narrator at the verdict.** The same box in a timed mode: no input, no pause, a dark
silhouette for a portrait. The scene stays real time and cannot be skipped.

- `verdict_wait` shows from the start of the camera's drift through the pause on the box
  (`VERDICT_DRIFT` + `VERDICT_PAUSE`, 2.7 s).
- `verdict_up` or `verdict_down` shows under the thumb; `VERDICT_SHOW` goes from 1.2 s to about
  2.5 s so the line can be read.
- A timed line has a length cap the loader enforces.

A win has no thumb and no narrator in M6.

**The crowd at the pick.** One line under "Pick a boon" on the picker, from the crowd's pool on
the `pick` trigger. Its conditions read the round's final band and the main source of favour lost
in the round, which `Favour` tallies as it happens:

| `round_loss` | Tallied from | The crowd's word for it |
|---|---|---|
| `hit` | the hit's penalty | clumsy |
| `fled` | decay while enemies lived and none was near the gladiator | a coward |
| `slow` | decay while enemies were near and none died | slow |
| `none` | nothing lost | |

The bad bands combine with the source, worded more strongly at Boo than at Quiet (the user's
correction): three judgements for Boo, three for Quiet, a plain fallback for each when nothing was
lost (a round can end low without losing anything), and praise for Cheer and for Roar, which do not
read the source. The fled-or-slow split is one distance check per decay tick.

## The decay

Playtest 3's note 2: the grace from 3 s to 2 s (`DECAY_GRACE`) and the drain from 1.5 to 4 a second
(`DECAY_PER_SECOND`), so two idle seconds past the grace cost about eight points on the bar. Judged
on the phase 1 playtest. The same task hardens `test_a_round_starting_past_the_gate_opens_at_it`
(`tests/test_favour_scene.gd`), which waits `ROUND_GAP + 0.1` real seconds and failed once under
load on 2026-10-01.

**The boss, and narrow escapes** (the user's decision of 2026-10-01, on the Task 1 review's
estimate: at 4 a second the boss's first stage, which has nothing to kill, drains the meter to
nothing and puts the perfect run out of reach). Two changes, built as the plan's Task 3b:

- **A hit on the boss holds the decay off.** It pays no points; it restarts the grace, as a
  scoring act does. A status tick (the burn) is not a hit for this: only a shot landing counts. Against the boss there is nothing else to kill, so fighting it counts as
  fighting. M5's rule stands for every other enemy: a hit that does not kill holds nothing off.
- **A narrow escape is a dare.** A dash that passes very close to an enemy's bolt (the shooter's,
  the boss's ring and volley) scores `dare` at once, as a dash past an enemy's body does today
  (the boss's charge is its body, so it counted already), and a kill inside the window after it
  is `daring`. One dare a dash, whatever it passed. The dash has no i-frames, so the risk is real.
  "Very close" is a first cut (`FavourRules.BOLT_RADIUS`), judged on the playtest.

## Phase 2: the writer's kit

**The Story tab.** An editor plugin of our own (`addons/story_graph/`, left out of the exports)
adding a "Story" tab to Godot's main screen, built on `GraphEdit`.

- Layout: a lane per character, a node per event, placed left to right by its depth in the chain
  of prerequisites. Computed, so no positions are saved.
- Edges: solid for `requires`, red dashed for `unless`, dotted for a flag link (one event's effect
  sets a flag another's `when` reads).
- A node shows its id, a colour for its priority, once or repeat, its trigger, and badges for
  placeholder lines and lint findings.
- Editing: drag between nodes to add a `requires`, delete an edge to remove it, add an event in a
  lane, rename one with every reference updated. A side panel edits the selected event: the header
  as controls, the body as text in the file's own format.
- Filters: by character, by act, and a search over ids and text.
- What-if: load the real save or a blank one, toggle events and flags, and see what each character
  would say next, with the failing requirement named on any event that would not fire.

The tab reads and writes the same files through `StoryScript`, so a file written by hand and one
saved from the tab are the same thing.

**The lint.** In the tab, from `tools/story_lint.sh`, and inside the test suite (bad content fails
the build). Errors are the loader's. Warnings: an unreachable event, a flag set and never read or
read and never set, and a line that looks like it explains a mechanic or addresses the player,
matched against an editable word list (`data/story/lint_words.txt`). It prints a flag map (who
sets each flag, who reads it) and the count of placeholder lines left.

**The act cheat.** Code words in the title's seed field (`Cheats.ACTIONS`, as `tabula` is): the
save is backed up and replaced by a preset story state for the start of that act
(`data/story/acts.json`). The presets are placeholders until M9 defines the acts.

**The brief.** `docs/WRITING.md`: the format, the triggers and the names a condition can read, the
writing rule with examples in and out, how to use the tab and the lint, the placeholder events to
replace, and a one-page template for the character pages.

**How it closes.** The user writes a few real events with the tab, at least one gated across two
characters, and sees them play.

## Show, don't tell, in this milestone

Every placeholder line is checked against the rule in the spec-compliance review (in the world's
voice; never explains a mechanic, names a system, or tells the player what to do), and the lint's
word list backs it in phase 2. The key cap names a key (UI may name); the mark over a head is
wordless; no line anywhere mentions E. The crowd's line and the narrator's windows reinforce what
the sound and the thumb already said.

## Data, names, and constants

- `data/story/`: `<character>.txt` (lanista, armourer, veteran, doctor, attendant, narrator,
  crowd), `flags.txt`, `cast.json` (also the pools' index: an exported build reads the pools by
  name, never by listing a directory); in phase 2 `acts.json`, `lint_words.txt`.
- `data/grounds/`: `ludus.tres`, `armamentarium.tres`, `hypogeum.tres`, `sanitarium.tres`,
  `spoliarium.tres`.
- Save: the `story` section; `flags.spoliarium_seen`.
- New bus signals: `room_entered(id)`, `event_started(id)`, `event_ended(id)`, `story_changed()`,
  and one for the box's bleep. `Favour` exposes the round's loss tally.
- `data/audio.json`: one bleep name per cast member. The files are from dmochas' Text/Dialogue
  Bleeps Pack (supplied by the user 2026-10-01 as
  `~/Downloads/dmochas-dialogue_bleeps_pack.zip`: thirty bleeps as wav, ogg, and mp3; CC BY 4.0,
  credit "dmochas_", https://dmochas-assets.itch.io/dmochas-bleeps-pack), so they can be committed
  with a `CREDITS.md` row. Which bleep each character gets is a first cut the user may change.
- Constants next to what they affect: the box's reveal speed and sizes in `ui/dialogue_box.gd`,
  the timed line's cap in the catalog, the reach and the key cap in `interactable.gd`, the
  near-enemy radius for `fled` in `favour_rules.gd`, `VERDICT_SHOW` in `main.gd`.
- The version: `0.6.0-rc1` for phase 1's playtest.

## Tests

Pure suites: `StoryScript` (every construct, every load error, and in phase 2 the round trip to
text and the rename), `StoryCondition`, `StoryPicker` (priority, file order, rotation, `requires`
and `unless` across pools, the one-event-per-return rule, `has_new`), `StoryContext`, the save's
story section (round trip, an older file), the loss tally, the lint, the what-if engine. A suite
loads the shipped `data/story` and fails on any error. Scene suites: the interact focus and the key
cap, each station on E, door travel between all five rooms, the run's flow through the Hypogeum,
the box (reveal, advance, a choice setting a flag, the pause), a merchant's event then panel, the
mark appearing and clearing, the first arrival, the narrator's windows inside the verdict's times,
the crowd's line for each band and source, the wake (lying, rising, no weapon, the door back, the
flag, the Hypogeum's door after). Smoke: `grounds` uses E; new `talk` (E on the lanista) and `wake`
(`verso`, a fall, the Spoliarium). The Story tab's interface is checked by hand against a short
checklist in the plan.

## Build order

The plan's tasks. Phase 1: (1) the decay and the hardened waits; (2) the story core, pure, with the
save's section and the `Story` autoload; (3) the interact key and the stations on it; (4) rooms as
data, doors, the run's flow; (5) the box, the cast in their rooms, the mark; (6) merchants, the
first arrival, the placeholder events; (7) the narrator at the verdict; (8) the crowd at the pick
with the loss tally; (9) the Spoliarium wake; (10) the docs, the feel checklist, `0.6.0-rc1`.

Phase 2: (11) the writer back to text and the edits; (12) the Story tab's view; (13) its editing;
(14) the what-if panel; (15) the lint and the flag map; (16) the act cheat; (17) the brief.

Two rules the plan adds: the story's pure classes never name an autoload or a Node class (the
Story tab runs them in the editor, where no autoload exists), and no test but the shipped-data
check depends on the shipped prose (scene tests run on a fixture story), so the writing can change
freely.

## Answers from the user (2026-10-01)

- A room per area, one-screen rectangles for now ("that might need to change eventually once the
  arena evolves as well").
- All five rooms of the direction's table; the Sanitarium is the doctor and talk only.
- An interact key for everything: nothing opens on contact.
- Our own dialogue system, with no dependency that forces a UI; Hades-like progression with
  per-character pools gated on each other; variable text; a visual tool for the interconnections
  (our own Story tab in Godot, chosen over Yarn Spinner's files and graph view and over
  articy:draft X with an importer); the file format is ours to choose.
- One milestone in two phases.
- The thumbs down stays behind `verso`.
- Of the parked notes, only the first arrival as a scene joins M6.
- Relationship levels, gifts, and mid-run events are wanted later: design so they can be added.
- The player must be able to see when a character has something new to say.
- The walk through the Hypogeum works for now; a key cap over the focus is fine.
- The crowd's three loss sources combine with the two bad bands: six judgements, stronger at Boo.
- The Story tab's first version as designed (the computed layout, the what-if panel) is enough.
- The bleeps pack supplied; the character pages workshopped in a separate session; no door sound.

## Deviations during the build

(Filled as the build finds them, one line each, mirrored in the plan's "## Deviations".)

- Task 3b (the user's decision, 2026-10-01): a shot landing on the boss holds the decay off, and a dash past an enemy's bolt is a dare ("The boss, and narrow escapes" above); a status tick on the boss holds nothing off.
- Task 4 (the user's decision, 2026-10-01): the grounds rooms are 26x15, not 28x15. At 3x the view shows about 427 px of a 448 px room, so a side wall and the door in it sat off screen on arrival; at 26 tiles the whole room is in view with an even black margin at each side. The run's arena stays 28x15.
- Task 4: a door is the arena's gap in the wall (a dark notch), closed by an invisible wall so the ring stays solid; the lift keeps M5's gate art. The tileset has no side-door art; M8's art replaces both.
- Task 5: characters are solid (the gladiator walked over them otherwise), Space does not advance the text box (it is the dash; E, Enter, or a click do), and the mark over a character gives way to the key cap while that character is in reach.
- Task 5 review (the coordinator's decision): the text box takes the side of the view away from the gladiator (the top while the gladiator stands in the lower half, else the bottom), so it covers neither the gladiator nor whoever they talk to, on arrival or at the Spoliarium wake; the verdict's lines alone keep the bottom (the camera frames the emperor's box at the top there).
- Task 6: a merchant stands beside their station (the lanista on the post's right, the armourer on the rack's left) and is one interactable with it; the key cap stands over the station, so the keeper's mark stays up while the station is in reach (a character's gives way to the cap). The first arrival's `enter ludus` beat is not the lanista's first word: that comes on E at the post, before the panel.
