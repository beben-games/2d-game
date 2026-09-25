# The colosseum: the direction after the slice

Status: approved in the design session of 2026-09-25 (after playtest 2 of Milestone 4). This is the
direction for v1; each milestone below gets its own design and plan as before. Supersedes the "After
the slice" paragraph of `2026-09-02-action-roguelike-design.md`.

## The frame

You are a gladiator in a fantasy colosseum drawn from the real one. The arena is one rectangle, the
one we have, and everything the game asks of you happens in it: dodge, shoot, dash, read the enemy.
The decisions moved out of the fight, to the end of each round and to the grounds between nights.

Words used from here on:

- **Run**: one night in the arena. It ends at the series' boss (a win) or at your death.
- **Series**: the run's ladder of rounds and its boss. Series 1 is today's eight rooms and boss.
  Winning series N unlocks series N+1. v1 has three.
- **Round**: what a room is today: two or three waves, then a boon. Eight rounds to a series.
- **Boon**: one of the upgrade cards, granted at a round's end by the crowd or the emperor. Lasts
  the run.
- **Favour**: the crowd's mood, a meter that tracks how well you fight. Decides the boon offer and
  the pay.
- **The grounds**: the hub, the places around the colosseum, visited between runs.

## The run

**Rounds in one arena.** The door walk goes: the arena is one place. A round ends when its waves
are dead; the crowd reacts, coins fly to the counter, the boon is granted at the emperor's box (set
into the top wall where the door is today), and after a beat the next round's waves fade in. The
entry seal, the door, the fade between rooms, and `Door` go away; the room's wave table and the wave
runner stay as the round's.

**Series.** Series 1 keeps today's eight rounds and boss with two or three waves each. Series 2 and
3 each bring one or two new enemy types that teach one thing each (the way chasers teach moving,
shamans reading a wind-up, shields flanking), bigger waves, a bigger arena (below), and a boss.
Difficulty lives in the enemies and their numbers, never in the arena's shape.

**Death** ends the run. You keep the money and the story progress earned so far and lose the boons;
you wake in the grounds. A quit mid-run is a death. There is no mid-run save.

**Boons.** The cards as they are, with the heal-slot rule of playtest 2. The granter is the crowd
or the emperor by favour band, and one thing changes with it: a Roar round offers four cards
instead of three. Nothing else about the picker changes; it gets a face, a name, and a line.

**Favour and style.** One meter per run, 0 to 100, shown on the HUD next to the hearts:

- Rises on kills, more for a kill within a short window of the last (a chain), for a kill made
  during or right after a dash through the crowd, and for a round cleared without a hit.
- Drops by a chunk on every hit taken. It never decays on its own: standing still is not punished,
  getting hit is.
- Four bands, low to high: **Boo, Quiet, Cheer, Roar.** The band at a round's end is the round's
  style verdict, shown with the crowd's reaction (sound, a line from the granter).
- Pay scales with the band (x1, x1, x1.5, x2 on the round's coins); a Roar round throws coin piles
  on the floor; a Roar round offers four boons.

The numbers (the chain window, the drop per hit, the band edges) are the plan's, tuned on playtests.

**Money.** Two forms:

- **The counter.** Every kill pays; the coin flies from the corpse to the HUD counter (a small
  animation, no pickup). The round's total is scaled by the style band.
- **Piles on the floor.** After a boss fight, and after a Roar round, coins are thrown into the
  arena as little piles scattered around the player, picked up by walking over them (physics
  layer 6, the unused `pickups` layer). Piles stay until picked up or the run ends, so collecting
  during the next round's waves is a risk you choose.

Money survives death. It buys the training lines in the grounds and nothing else in v1.

**Boss loot.** A boss pays a lot of coin (thrown on the floor) and, the first time it dies, one
unlock: a weapon, a class, an area of the grounds, or a story beat. Which one is the series' data.

## The arena grows

The arena's size is a parameter of the series, and within series 3 of the story. `ArenaGrid` takes
the size and the camera already follows; the work is in the rules that keep a big arena fair.

- **Series 1: one screen** (28x15 tiles, today). The walls are at the screen's edge and corners are
  a lesson of their own.
- **Series 2: two screens** (about 56x30). The camera follows; the walls are real but rarely in view.
- **Series 3: borderless.** So large the walls are never reached; the crowd is a haze at the edge of
  sight, and at the story's end the arena is the mind, without edges.

Three rules, the same at every size, so nothing switches between stages:

1. **The screen edge is a wall for shots.** A player shot reaching the edge of the visible rect
   bounces if it has Ricochet and dies otherwise; an enemy bolt dies there. In the one-screen arena
   the wall tiles sit inside the edge, so the raycast hits them first and today's behaviour is
   unchanged. Ricochet keeps its meaning at every size: the shot comes back from the edge of what
   you can see.
2. **Enemies act only on screen.** A spawn fades in at the visible edge, never off screen; a shooter
   or the boss winds up only while visible; a chaser off screen walks toward you until it is on it.
   Nothing hurts you from where you cannot see.
3. **Nothing to be cornered by.** With no walls in reach the only pressure is the enemies, which is
   the dodging loop the game is about.

The work: the size parameter per series, the spawner placing in the visible rect instead of the
room, the projectile's edge check, the shooter's on-screen gate, and the crowd drawn at the arena's
edge (a ring for the small stages, a haze for the borderless one). One test suite, its cases named
after the three rules.

## The grounds

The hub, walkable, built with the rectangle-room tech we have (the hub is where the rectangles
belong). Each area is a real place of the Colosseum with one function and one or two characters.
Claude drafted this table from the sources; the human corrects it and picks.

| Area | The real thing | In the game |
|---|---|---|
| Ludus Magnus | the gladiator school beside the Colosseum, with its own practice ring | training: the meta stat lines, bought with money; the lanista (your owner) |
| Armamentarium | the armoury | weapons and classes: equip what boss loot and quests have unlocked |
| Hypogeum | the cellars under the arena: lifts, cages, machinery, the beasts | challenges and quests; the way into the arena; the attendant character |
| Sanitarium | the infirmary for wounded gladiators | the doctor; the body and its cost; story beats about wounds |
| Spoliarium | where the dead were stripped of their armour | locked at first; the discovery that turns the story |
| Porta Libitinaria and Porta Triumphalis | the gate of death and the gate of triumph | the two ways out of the arena; which gate, and in what state, is the ending of a run and of the game |

**Meta progression: training lines.** Capped stat lines bought in the Ludus Magnus, each 2 to 5
ranks: +1 heart, +1 dash charge, start the run with a chosen card, one more card in every boon
offer. Unlocks (weapons, classes, areas) never cost money; they come from boss loot and quests, so
money makes the next run kinder and the ladder stays a skill test.

**Classes and weapons.** The build already keys on `weapon_id`, so a class is a starting build (a
weapon, a starting card or two, a heart count). v1: one new weapon and one new class beyond the
handgun gladiator, both unlocked by series 1's and 2's bosses.

**Characters.** Five or six: the lanista, a veteran, the doctor, an armourer or trainer, an
attendant from the Hypogeum, and the emperor, seen only from the arena. Short exchanges in a text
box with a portrait, unlocked by story flags (run count, wins, deaths, areas entered, choices made).
A few choices, no branching trees.

## The story

Three acts over the three series, told between nights: the arrival and the first taste of the
crowd; the wins that cost more each night, the doctor and the veteran fraying; the descent, opened
by the Spoliarium, ending in the madness the crowd wants. A comment on mortality. The endings
happen at the gates: which one you leave by, and in what state.

The form is fixed by this design (short exchanges, flags, a few choices, text with a portrait). The
content is the human's: the section "Who designs what" lists it. Claude writes placeholder lines
marked as such so every system is testable before the writing lands.

## Persistence

One save file, `user://save.cfg`, written at every return to the grounds: money, training ranks,
unlocks, story flags, and all-time stats (from the notes of 2026-09-21: shots fired, times hit,
deaths, kills by enemy, the deadliest enemy shown with its animated sprite on the end-of-run
screen). Runs are not saved mid-way. The volumes stay in `settings.cfg`. A save is versioned and a
missing or older one loads with defaults, like `Settings`.

## Dropped

Non-rectangular rooms and multiple exits (they add corners and choke points to a game whose skill
is dodging in the open), mid-run hub visits, the door walk between rooms, and the heart pickup
(Heal is a card). Money piles are the one thing on the floor.

## The path

Six milestones after `m4`, each playable, each closing on the user's playtest verdict, each with
its own design session and plan. Systems first on today's art; the writing in parallel from M6; the
art and the story last, on systems that hold.

| Milestone | Delivers | The playable check |
|---|---|---|
| **M5 Rounds and the grounds** | Rooms become rounds in one arena (no door walk; the boon at the emperor's box); favour and the style verdict; money as the counter and as piles; the save file; a first grounds as one rectangle room with three stations (train, arm, enter the arena); the training lines; the end-of-run stats screen | A run, a return, spend money, a stronger next run |
| **M6 The colosseum grounds** | The grounds as the six areas, walkable, with placeholder characters; the dialogue system (data files, conditions on story flags, a text box with a portrait, a few choices); placeholder writing marked as such; the writing brief and the data format handed to the human | Walk the grounds, talk, unlock a line by winning |
| **M7 Series 2 and 3** | The arena size parameter and the three fairness rules; series 2 (two screens, two new enemies, a second boss) and series 3 (borderless, two more enemies, the last boss); boss loot and unlocks; one new weapon and one class in the Armamentarium | Win series 1, play series 2 at two screens, reach series 3 |
| **M8 The look** | The colosseum re-skin: arena tiles, the crowd, the grounds, the six portraits, the title; sound and music for the grounds and the new bosses; the name | The game reads as a colosseum |
| **M9 The story** | The human's dialogues and beats in the data files; the flags wired to the acts; the Spoliarium reveal; the endings at the two gates; a content note on the title | The story plays start to end |
| **M10 v1** | Balance across the three series, the all-time stats, the tester build, an itch.io page | Hand it to strangers |

## Who designs what

**The human** (the user, or a writer they bring in). These need taste, a point of view, and
knowledge of the real place. Claude drafts placeholders, edits, and builds the tooling, but does not
author them:

1. **The name of the game**, and the tone in one paragraph: how dark, how funny, what it says about
   mortality. Needed by M8.
2. **The characters**: for each of the five or six, a name, a background, what they want, what they
   hide, how they speak (a few lines of voice), and how they change over the three acts. One page
   each. Needed by M6's end, so M9 has them.
3. **The story beats**: the three acts as a list of moments, each with its trigger (run count, a win,
   a death, an area entered, a choice) and what changes after it; the Spoliarium discovery; the
   descent; the endings at the gates. Two or three pages. Needed by M9.
4. **The dialogues**: every exchange, in the data format from M6 (a text file per character; Claude
   supplies the format, a lint that catches missing flags and unreachable lines, and a cheat code
   to play from any act). Around 10,000 to 15,000 words for v1. Needed by M9.
5. **The places**: which areas, what each looks like and holds, from the sources. Correct the table
   above and pick. Needed by M6.
6. **Art direction and assets**: the look of the colosseum, the crowd, the portraits; sourcing or
   generating the assets and settling their licences per `CREDITS.md`. Needed by M8.
7. **Music and sound** for the grounds, the crowd, and the new bosses, as today. M8.
8. **One line per new enemy**: the lesson it teaches (Claude designs the behaviour from it). M7.
9. **The playtest verdicts**, as always: feel, fairness, and whether the story lands.

**Claude**: every system above and its tests; the data formats (series, rounds, boons, favour,
money, save, dialogue, story flags) and the validation that rejects bad content at load; the new
enemies' behaviours and the boss patterns; the arena rules; the writers' tooling (the lint, a flag
map, the act cheat code); balance numbers from the user's notes; the tester builds and releases;
the drafts of everything in the human list, marked as drafts, so nothing waits on the writing.

## Open decisions

Taken in M5's design session: the favour numbers; the coin animation and the pile art on today's
tileset; what the first grounds room looks like before M6; whether the round-end beat has the
player walk anywhere or stand where they are.

## Deviations during the build

(Recorded per milestone in its own design doc; this file gets a line when a milestone changes the
direction.)
