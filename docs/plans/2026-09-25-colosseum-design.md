# The colosseum: the direction after the slice

Status: approved in the design session of 2026-09-25 (after playtest 2 of Milestone 4), extended
the same day with the emperor, the verdict, the story's reveal, and the "show, don't tell" rule.
This is the direction for v1; each milestone below gets its own design and plan as before.
Supersedes the "After the slice" paragraph of `2026-09-02-action-roguelike-design.md`.

## The frame

You are a gladiator in a fantasy colosseum drawn from the real one. The arena is one rectangle, the
one we have, and everything the game asks of you happens in it: dodge, shoot, dash, read the enemy.
The decisions moved out of the fight, to the end of each round and to the grounds between nights.
Over the emperor's box sits the emperor, who grants, judges, and, late, comes down.

Words used from here on:

- **Run**: one night in the arena. It ends in front of the emperor's box, after the series' boss (a
  win) or after your final hit (a fall).
- **Series**: the run's ladder of rounds and its boss. Series 1 is today's eight rooms and boss.
  Winning series N unlocks series N+1. v1 has three.
- **Round**: what a room is today: two or three waves, then a boon. Eight rounds to a series.
- **Boon**: one of the upgrade cards, granted at a round's end by the crowd or the emperor. Lasts
  the run.
- **Favour**: the crowd's mood, a meter that tracks how well you fight. Decides the boon offer, the
  pay, and, once it matters, whether you live.
- **The verdict**: the emperor's thumb at the run's end.
- **The grounds**: the hub, the places around the colosseum, visited between runs.

### Show, don't tell

A hard rule for every milestone from M5 on. No tutorial, no explaining, no character stating the
obvious or speaking to the player. The player learns the world's rules by playing them, and the
story is the moments where a learned rule breaks. In practice:

- The first run starts in the arena. The grounds appear only after the first run ends.
- A mechanic appears when the story reaches it and is never announced: the favour meter is on the
  HUD from run 1, unexplained; the crowd's sound is its explanation.
- Every character line is checked against the rule in review: if it explains a mechanic, names a
  system, or addresses the player, it goes.
- Tests pin the order: a save at act N has exactly the mechanics of act N and no line from act N+1.

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

**The fall.** At the final hit the gladiator goes down, not dead. The run ends there, in front of
the box, and the verdict follows (below). A quit mid-run is a fall. There is no mid-run save.

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
- A **perfect run** is a run with no hit taken and Roar at its end. It has a place in the verdict.

The numbers (the chain window, the drop per hit, the band edges) are the plan's, tuned on playtests.

**Money.** Two forms:

- **The counter.** Every kill pays; the coin flies from the corpse to the HUD counter (a small
  animation, no pickup). The round's total is scaled by the style band.
- **Piles on the floor.** After a boss fight, and after a Roar round, coins are thrown into the
  arena as little piles scattered around the player, picked up by walking over them (physics
  layer 6, the unused `pickups` layer). Piles stay until picked up or the run ends, so collecting
  during the next round's waves is a risk you choose.

Money buys the training lines in the grounds and nothing else in v1. Whether a run's money is kept
is the verdict's.

**Boss loot.** A boss pays a lot of coin (thrown on the floor) and, the first time it dies, one
unlock: a weapon, a class, an area of the grounds, or a story beat. Which one is the series' data.

## The verdict, and the emperor

Every run ends in front of the emperor's box, after a win or a fall. The thumb decides how you leave:

- **Thumbs up**: out by the Porta Triumphalis, alive, with the run's money and loot. You wake in
  the grounds.
- **Thumbs down**: out by the Porta Libitinaria, dead. You wake in the Spoliarium among the dead,
  stripped: the run's money and loot are gone (story progress and unlocks are kept), and you find
  your own way back to the grounds. It counts as a death for the story.

**The turning point.** At first the emperor always saves you: every fall ends in a thumbs up, and
the player learns the rule *the emperor keeps me alive*, without a word said. As the runs go on and
the gladiator grows too popular (a threshold on wins, favour, and run count, set by the story's
flags), the thumb goes down for the first time. In one moment three things are unveiled: death and
the loss of coin are now real, the Spoliarium exists, and the gladiator is immortal for a reason no
one explains (you woke up). From then on the thumb follows the rule below.

**How the thumb is decided.** By the favour band as the rule (Roar and Cheer up, Boo down, Quiet a
weighted coin flip on the run's hits taken), overridden by the story at set beats: a thumbs down on
a good run when act 2 needs it, a thumbs up on a bad one when he wants you back. The first thumbs
down after a *win* is a broken rule of its own (the player learned that winning means living). The
player only ever sees the thumb and the crowd; the reasons are the writer's.

**The counter.** A perfect run cannot be thumbed down: the crowd overrules the emperor, and the
player discovers this by doing it. Every third time it happens, the emperor comes down into the
arena himself ("I'll just do it myself"): a fight at the box, on his terms, far beyond the player's
power at first, so the first ones are lost and the loss is the point. He becomes beatable only
late, through the ladder (series 3, the training, the class he fears), and beating him opens the
reveal.

**The reveal.** The emperor is a self-sacrificing keeper: the colosseum runs to keep the cosmic
horrors sated and the entropy out, and he has been doing it for longer than anyone. Act 3 asks
whether endless suffering to keep things from ending is worth it; grief underneath. The rules the
player learned (the emperor keeps me alive; winning means living; the perfect run overrules; the
emperor is the tyrant) each break once, in order, and the breaks are the story.

**Unlocked with the story.** The order for v1, pinned by tests on the save's act:

| Appears | Mechanic |
|---|---|
| Run 1 | the arena, coins, the favour meter (unexplained), the verdict (always up) |
| The first return | the grounds |
| The turning point (end of act 1) | the thumb down, death, the loss of coin, the Spoliarium, immortality |
| Act 2 | the thumb by favour with scripted overrides; the counter, discoverable; the emperor's fight |
| Act 3 | the emperor beatable; the reveal; the endings at the gates |

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
| Spoliarium | where the dead were stripped of their armour | unveiled at the turning point: where a thumbs down wakes you, stripped |
| Porta Libitinaria and Porta Triumphalis | the gate of death and the gate of triumph | the two ways out of the arena, chosen by the thumb; the endings of the game happen at them |

**Meta progression: training lines.** Capped stat lines bought in the Ludus Magnus, each 2 to 5
ranks: +1 heart, +1 dash charge, start the run with a chosen card, one more card in every boon
offer. Unlocks (weapons, classes, areas) never cost money; they come from boss loot and quests, so
money makes the next run kinder and the ladder stays a skill test.

**One gladiator, classes, weapons.** There is one player character. A **class** is a base boon (a
card held from the start) and a skin; a **starting weapon** is a weapon. At first each class comes
with its own weapon, locked together; later an unlock in the Armamentarium lets the player mix any
class with any weapon. The build already keys on `weapon_id`, so a class is a starting build. v1:
one new weapon and one new class beyond the handgun gladiator, from series 1's and 2's bosses, and
the mix-and-match unlock from a quest or series 3.

**Characters.** Five or six: the lanista, a veteran, the doctor, an armourer or trainer, an
attendant from the Hypogeum, and the emperor, seen from the arena and, late, met in it. Short
exchanges in a text box with a portrait, unlocked by story flags (run count, wins, deaths, areas
entered, choices made, the turning point, the counters, the fights). A few choices, no branching
trees. Every line obeys "show, don't tell".

## The story

Three acts over the three series, told between nights and by the rules that break:

- **Act 1**: the arrival and the taste of the crowd; the emperor's thumb always up; the grounds
  and their people. Ends at the turning point: the first thumb down, the Spoliarium, the waking.
- **Act 2**: the wins that cost more each night; the doctor and the veteran fraying; the thumb now
  a judgement; the perfect run that overrules it; the emperor coming down and winning.
- **Act 3**: the descent into the madness the crowd wants; the emperor beaten; the reveal; the
  question of whether the suffering has a purpose; the endings at the two gates, which one and in
  what state.

A comment on mortality, with grief underneath. The form is fixed by this design (short exchanges,
flags, a few choices, text with a portrait, the rule breaks as beats). The content is the human's:
"Who designs what" lists it. Claude writes placeholder lines marked as such so every system is
testable before the writing lands.

## Persistence

One save file, `user://save.cfg`, written at every return to the grounds: money, training ranks,
unlocks (classes, weapons, the mix-and-match, areas), story flags (run count, wins, falls, deaths,
the turning point, perfect runs, counters, emperor fights, choices), and all-time stats (from the
notes of 2026-09-21: shots fired, times hit, deaths, kills by enemy, the deadliest enemy shown with
its animated sprite on the end-of-run screen). Runs are not saved mid-way. The volumes stay in
`settings.cfg`. A save is versioned and a missing or older one loads with defaults, like `Settings`.

## Dropped

Non-rectangular rooms and multiple exits (they add corners and choke points to a game whose skill
is dodging in the open), mid-run hub visits, the door walk between rooms, and the heart pickup
(Heal is a card). Money piles are the one thing on the floor. Death as an outright end: the fall
and the verdict replace it.

## The path

Six milestones after `m4`, each playable, each closing on the user's playtest verdict, each with
its own design session and plan. Systems first on today's art; the writing in parallel from M6; the
art and the story last, on systems that hold.

| Milestone | Delivers | The playable check |
|---|---|---|
| **M5 Rounds and the grounds** | Rooms become rounds in one arena (no door walk; the boon at the emperor's box); favour and the style verdict; money as the counter and as piles; the fall and the verdict, data-driven (the favour rule plus a story override hook; always thumbs up until the flags exist); the two gates as the run's end screen; the save file; a first grounds as one rectangle room with three stations (train, arm, enter the arena), shown only after the first run; the training lines; the end-of-run stats screen; the "show, don't tell" rule in review | A run, a return, spend money, a stronger next run, and not one word of explanation |
| **M6 The colosseum grounds** | The grounds as the six areas, walkable, with placeholder characters; the dialogue system (data files, conditions on story flags, a text box with a portrait, a few choices); the Spoliarium wake after a thumbs down; placeholder writing marked as such; the writing brief and the data format handed to the human | Walk the grounds, talk, unlock a line by winning, wake stripped after a thumb down |
| **M7 Series 2 and 3** | The arena size parameter and the three fairness rules; series 2 (two screens, two new enemies, a second boss) and series 3 (borderless, two more enemies, the last boss); boss loot and unlocks; one new weapon, one class, the mix-and-match unlock; the emperor's fight as a boss far above the player's power, on the counter's third | Win series 1, play series 2 at two screens, reach series 3, lose to the emperor |
| **M8 The look** | The colosseum re-skin: arena tiles, the crowd, the grounds, the portraits, the emperor's box and the thumb, the title; sound and music for the grounds and the new bosses; the name | The game reads as a colosseum |
| **M9 The story** | The human's dialogues and beats in the data files; the flags wired to the acts and the unlock order; the turning point; the scripted thumbs; the emperor beatable and the reveal; the endings at the two gates; a content note on the title | The story plays start to end, and the rules break in order |
| **M10 v1** | Balance across the three series, the all-time stats, the tester build, an itch.io page | Hand it to strangers |

## Who designs what

**The human** (the user, or a writer they bring in). These need taste, a point of view, and
knowledge of the real place. Claude drafts placeholders, edits, and builds the tooling, but does not
author them:

1. **The name of the game**, and the tone in one paragraph: how dark, how funny, what it says about
   mortality and grief; how much of the cosmic horror is ever shown. Needed by M8.
2. **The characters**: for each of the five or six, a name, a background, what they want, what they
   hide, how they speak (a few lines of voice), and how they change over the three acts. One page
   each. **The emperor** gets two: his public face and his true nature, and what he knows about the
   gladiator's immortality. Needed by M6's end, so M9 has them.
3. **The story beats and the rule breaks**: the three acts as a list of moments, each with its
   trigger (run count, a win, a fall, an area entered, a choice, a perfect run, a counter) and what
   changes after it; the turning point's threshold; the exact order in which the learned rules
   break; the Spoliarium waking; the endings at the gates. Two or three pages. Needed by M9.
4. **The dialogues**: every exchange, in the data format from M6 (a text file per character; Claude
   supplies the format, a lint that catches missing flags, unreachable lines, and lines that explain
   a mechanic or address the player, and a cheat code to play from any act). Around 10,000 to
   15,000 words for v1. Needed by M9.
5. **The places**: which areas, what each looks like and holds, from the sources. Correct the table
   above and pick. Needed by M6.
6. **Art direction and assets**: the look of the colosseum, the crowd, the emperor's box and the
   thumb, the portraits, the class skins; sourcing or generating the assets and settling their
   licences per `CREDITS.md`. Needed by M8.
7. **Music and sound** for the grounds, the crowd, the verdict, and the new bosses, as today. M8.
8. **One line per new enemy**: the lesson it teaches (Claude designs the behaviour from it), and
   one for the emperor's fight: what makes it hopeless at first and what turns it. M7.
9. **The playtest verdicts**, as always: feel, fairness, whether the story lands, and whether
   anything ever felt explained.

**Claude**: every system above and its tests; the data formats (series, rounds, boons, favour,
money, the verdict and its story hook, save, dialogue, story flags, the unlock order) and the
validation that rejects bad content at load; the new enemies' behaviours and the boss patterns,
the emperor's included; the arena rules; the writers' tooling (the lint, a flag map, the act cheat
code); balance numbers from the user's notes; the tester builds and releases; the drafts of
everything in the human list, marked as drafts, so nothing waits on the writing.

## Open decisions

Taken in M5's design session: the favour numbers; the coin animation and the pile art on today's
tileset; what the fall looks like (the gladiator down, the crowd, the thumb, the gate) on today's
art; what the first grounds room looks like before M6; whether the round-end beat has the player
walk anywhere or stand where they are. Taken in M9's: the turning point's threshold.

## Deviations during the build

(Recorded per milestone in its own design doc; this file gets a line when a milestone changes the
direction.)
