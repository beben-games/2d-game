# Milestone 7 design: tiers 2 and 3

Status: approved 2026-10-04 in the M7 design session (drafted from the colosseum direction's M7 row
and its sections "The run", "The arena grows", "The grounds", and "The verdict, and the emperor"
(`2026-09-25-colosseum-design.md`), and the user's answers, recorded at the end). Phase 1 is
designed in full; phases 2 and 3 are outlines, each with a short design pass of its own before its
plan. Phase 1's plan is `2026-10-04-milestone-7.md`.

**Goal.** The ladder: a run can be fought in a bigger arena against new enemies and a new boss, and
winning a tier opens the next. The arena's size becomes a parameter, and three rules keep a big
arena as fair as the one-screen one. Then the classes, the rewards for finishing, and the emperor's
fight.

**Three phases, one tag.** Each phase ends in a release candidate and the user's playtest; `m7` is
tagged after the third.

1. The arena rules, tier 2 (two screens, the charger, the standard-bearer, the beast and its
   handler), the lifts, boss loot.
2. Tier 3 (borderless, two more enemies, the last boss).
3. Classes with their weapons, the mix-and-match unlock, the completionist rewards, the emperor's
   fight.

Milestone 6 is still open while this is written (its phase 2 waits on the user's real events);
nothing here depends on its close.

## The big arena

**A tier is a series.** `data/series/tier_2.tres` sits beside `tier_1.tres`: its own arena size
(56x30 tiles of 16 px, two screens each way at today's 3x zoom), its own eight rounds, its boss in
the eighth. A run's structure does not change: favour, coins, the pick, the fall, and the verdict
work as today. Tier 1 stays exactly as it is, and its suites pass untouched.

**Rectangles now, the oval at M8.** The arena keeps today's tile grid at a bigger size on the
current tileset. The rules below are written against two things only, *the visible rect* (what the
camera shows) and *the arena's bounds*, never against tiles, so the oval painted stage of the art
sessions swaps in at M8 behind the same interface.

**The three fairness rules**, the same at every size, so nothing switches between tiers:

1. **The screen edge is a wall for shots.** A player shot reaching the edge of the visible rect
   bounces if it has a bounce left and dies otherwise; an enemy bolt dies there. In tier 1 the wall
   tiles sit inside the edge, so the raycast hits them first and nothing changes. The camera's aim
   lean stays, so the visible rect moves with the aim; the rule reads the rect at the moment the
   shot reaches it.
2. **Enemies begin an attack only on screen.** A spawn fades in at the edge of the visible rect,
   never beyond it. A shooter, a charger, or a boss begins a wind-up only while visible; off screen,
   an enemy walks toward the player. An attack already wound up when the player scrolls away
   finishes; it does not restart. An aura is not an attack (the standard-bearer's banner reaches
   from off screen, below): the principle is that nothing *damages* the player from where they
   cannot see.
3. **Nothing to be cornered by.** No new obstacles in the big arenas; the walls exist but are
   rarely in view.

**What follows from the rules.**

- Coin piles are thrown inside the visible rect as well as inside the arena.
- The boss's seat at its spawn is the top centre of the visible rect, not of the arena.
- The emperor's box stays at the top wall's centre. In tier 2 it is off screen for most of a fight;
  the verdict's camera drift travels to it over the longer distance.

**Off-screen arrows** (the user's addition). With spawns at the visible edge and a two-screen arena,
an enemy can be left far behind; the arrows are how it is found.

- One small arrow per living enemy outside the visible rect, on the HUD layer at the screen's edge,
  on the line from the player to that enemy. No words, no numbers.
- The boss's arrow is larger; the standard-bearer's carries a small banner; a summon's is any
  enemy's.
- An arrow fades in as its enemy leaves the screen and out as it enters. Arrows that would overlap
  near a corner are nudged apart along the edge.
- It shows whenever an enemy is off screen, in any tier (never, in tier 1). It marks a position
  only: rule 2 means nothing off screen is attacking.

## Tier 2

**The charger** (the lesson: sidestep, don't outrun).

- Walks at the player like a chaser until it is on screen and inside its range.
- Stops and lowers its head: a thin line on the floor shows the path for about 0.7 s. The line is
  fixed when the wind-up starts; it does not track.
- Crosses fast along the line, well past where the player stood; contact hurts.
- Skids to a halt and stands still for about a second, taking extra damage from behind.
- Only a wall or the end of its run stops it. It passes through other enemies without hurting them.
- A dash across its path during the charge is a dare, as a dash past any harmful enemy is today.

**The standard-bearer** (the lesson: kill order).

- Carries a banner and does no damage; its body is solid.
- Enemies inside the banner's radius move and wind up faster (about a quarter). A soft ring on the
  floor shows the radius; buffed enemies carry a tint.
- The buff reaches from off screen (the user's decision: otherwise scrolling it out of view is the
  cheap answer). The tint on the pack and the bearer's own arrow point at the cause.
- It stays behind the pack, on screen or off: it keeps the nearest other enemy between itself and
  the player and backs away when approached, so its radius keeps covering the pack.
- Its death ends the buff at once. As the last enemy alive it stops fleeing and walks at the
  player, so a round never stalls.
- The radius is the number to tune: first guess a third of a screen's width, so a pack spread
  around the player is only partly covered. A playtest question.

**The beast and its handler** (tier 2's boss; it examines both lessons).

- Two bodies, a health bar each on the ledge row.
- The beast charges in telegraphed lines like a charger, chaining two or three, with a ring attack
  between chains.
- The handler keeps far away, throws a slow volley, and while alive drives the beast (shorter
  pauses between charges).
- The handler dead first: the beast goes wild (faster charges, shorter telegraphs, no ring).
- The beast dead first: the handler fights alone (faster volleys, two chargers summoned once).
- The boss round's favour is as built in M6 (the meter opens at 100, gains capped at 20); the
  favour paid by damage is shared across both bodies' health.
- The fight ends when both are dead; the coins are thrown at the second death.

**The rounds.** Eight. Rounds 1 and 2 bring the charger alone, then with chasers; round 3 the
standard-bearer with a small pack; rounds 4 to 7 mix both with tier 1's enemies (shooters, shielded
chasers) in bigger waves than tier 1's; round 8 is the boss. The numbers are the plan's first guess,
tuned on the playtest.

**Sprites.** The current tileset; the plan proposes which sprite is which and asks the user for
anything the tileset lacks, never a quiet substitute.

**Documented, not built in phase 1** (candidates for tier 3, the user's to pick):

- *The lobber* (the ground can be the danger): keeps far away and lobs a slow arcing shot at where
  the player stands; a ring on the floor shows where it lands, and the patch burns for a few seconds.
- *The splitter* (where you kill matters): a big slow body that bursts into three small fast
  chasers when it dies.
- *The chariot* (a boss): never stops, circles the arena's edge, cuts across in charging lines, its
  rider throwing javelins as it passes; it can be hurt only as it goes by. Its movement along the
  edge depends on the arena's shape, which the oval changes.

## The lifts, unlocks, and the record

**Unlocks on the save.** The profile gains an `unlocks` section. Phase 1 holds one thing in it, the
highest tier unlocked (1 on a new save); phase 3 adds classes and weapons. An older save loads at
the default with one correction: a save that already has a win is given tier 2.

**Boss loot as data.** A series names what its first win unlocks (`tier_1.tres`: tier 2). The first
time a tier is won the unlock is written with the run's banking, in the same commit as the money; a
later win of that tier pays coins only. Phase 1's only kind of unlock is a tier; the field is built
to take a class, a weapon, or a grounds area.

**The lifts.** The Hypogeum holds three lift bays side by side, each a station in the room's data
with its tier and its condition.

- Tier 1's lift is as today.
- A locked tier's bay is a shut, dark cage: not interactable, no key cap, no focus.
- An unlocked tier's lift is open and lit; E rides it.
- The first time the Hypogeum is entered after an unlock, the new cage rises open with a sound,
  once. That is the whole announcement.

The title's seed and cheats apply to whichever lift is ridden first, as to the single lift today.

**The record.** The run's record, the gate screen's block, and the `RUN_END` line carry the tier.
The profile counts wins per tier; the best run and the best boss time are kept per tier.

**What the story can read.** Two new names for conditions and substitutions: the highest tier
unlocked, and the last run's tier. The lint and What-if learn both.

**Coins.** Tier 2's enemies and boss are worth more than tier 1's, as data. The training prices
stay; the economy pass is still parked.

**A testing aid.** `scalae` in the title's seed field (an action word, not a run flag) unlocks
every tier on the save.

## Show, don't tell, in this milestone

No caption, hint, or line explains a tier, a lift, an arrow, the banner, or the charge. The lifts
carry no label; a locked bay says nothing. The charger's line and the banner's ring are the world
showing itself, as the shooter's telegraph is. Every spec-compliance review checks this as a spec
item.

## Phases 2 and 3, in outline

**Phase 2: tier 3.**

- The arena is borderless: a size so large the walls are never reached, on the same grid and the
  same three rules.
- Where the verdict happens with no wall for the emperor's box is a question for the phase's design
  pass.
- Two more enemies and the last boss, picked by the user after tier 2's playtest (the lobber, the
  splitter, and the chariot are the documented candidates).
- The third lift opens on tier 2's first win.
- Whether the arrows need a distance cue is a playtest question.

**Phase 3: classes, rewards, the emperor.**

- A class is a starting card and a skin, locked to its own weapon; the first comes from tier 1's
  boss, granted from the profile to anyone who has already won. Three or four for v1; which ones is
  the phase's design pass.
- The rack in the Armamentarium is where a class is chosen. Mix-and-match unlocks once every
  unlocked class has won tier 3. A new class starts at the highest tier unlocked.
- Completionist rewards: money or a cosmetic for finishing a tier with every class or under a
  condition; never a mechanic or a story beat.
- The emperor's fight: a boss far beyond the player's power, at the box, on the third time a
  perfect run overrules the thumb. The flags that lead to it are M9's; phase 3 builds the fight and
  a way to reach it for testing.

**Needed from the user.** Before phase 2's plan: tier 3's two enemies and boss, and where the
verdict happens with no walls. Before phase 3's plan: the class list, and the emperor's line (what
makes the fight hopeless at first, and what turns it).

## Out of this milestone

- Class experience, levels, and challenges: after M7 (they need the classes and the user's
  per-class challenge designs).
- The oval stage and any painted art (M8); the 1080p move.
- The economy pass on training prices, coins popping with the wave, the hidden favour bar.
- The scripted thumbs and the turning point (M9).

## Tests

- One suite named after the three rules, run at the one-screen and the two-screen size.
- Tier 1's existing suites pass untouched.
- Pure rules (the charger's line, the banner's cover, the arrows' placement, the unlock at a first
  win, the save's correction at load) in pure suites; scenes for the charge, the buff, the two-body
  boss and its two kill orders, the lifts, and the cage's rise.
- The reload probe rides the second lift; a tier 2 smoke scenario captures a charger's line, a
  banner's ring, an off-screen arrow, and the two boss bars.

## Build order, phase 1

The arena rules come first, on a two-screen test series with tier 1's enemies, so they are proven
before any new enemy exists. Then the arrows; the charger; the standard-bearer; the boss; tier 2's
rounds; the unlocks, the lifts, and the record; the story's two names; the smoke scenario, the
docs, the checklist, and the release candidate. The same loop as M6: one implementer per task, a
spec-compliance and a code-quality review, a fix pass, a re-review.

## Answers from the user (2026-10-04)

1. The cut: three phases under one tag.
2. The shape: rectangles now, the oval at M8.
3. Tier 2's enemies: the standard-bearer and the charger; the lobber and the splitter kept
   documented.
4. Tier 2's boss: the beast and its handler; the chariot written down for later.
5. The tier select: separate lifts, one a tier.
6. Section 1: "let's try it like this, but we probably need arrows pointing at offscreen enemies".
7. Section 2: the standard-bearer's range works from off screen too.
8. Sections 3 and 4 approved as presented, with class experience and levels left out of M7.

## Deviations during the build

- Plan (2026-10-04, from the code survey; `2026-10-04-milestone-7.md`, "Decided at the plan"): "on screen" is the visible rect grown by a margin of a tile, because tier 1's arena is a little wider than the view and scrolls (without the margin rule 1 would stop a shot short of tier 1's side walls and the arrows would show there); tier 2 for a save with a win is computed when read, not written at load, so an older file, a wiped one, and an act preset agree; the chosen tier is kept across a restart; "the handler drives the beast" is the beast's first stage, and the handler's death is its enrage (no separate driving mechanic); the boss bars sit at the screen's top, side by side for two (in tier 2 that row is not the wall's ledge).
