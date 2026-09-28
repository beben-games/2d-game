# Art status

The art pipeline's living page, the art counterpart of `docs/STATUS.md`: the routine of an art
session, this period's budget, the concepts, what waits on the user, the approved references, the
hand queue, and the log. The design and its reasons are
`docs/plans/2026-09-26-art-pipeline-design.md` ("## The budget loop and the review"). Updated
2026-09-27.

## The rules

- **The user is the only judge of the look**, at every step: bake-offs, bases, and finals. Claude
  never picks a winner. Claude may set a candidate aside only for a fault it can state (the wrong
  canvas or view, a broken limb, off the palette, semi-transparent pixels, cut off), and the
  set-aside ones stay visible in the review with their reason.
- **Cost is not quality.** A custom animation is not assumed better than a template, a Pro call not
  better than v3 or a standard one, a generation not better than code or hand work. Where two
  methods can make the same thing, the user compares them on one direction of one state first
  (the method bake-off), each shown with what its production would cost, and picks.
- **References are the user's.** No image goes into a call to steer it (a reference, style, init,
  or colour image, on any endpoint, Pro or not) unless it is in "## References" below, approved by
  the user or brought by the user. Claude proposes references; the user approves them before the
  first call that uses them.
- **Pro calls carry references** (the user, 2026-09-27: the references are what the twentyfold
  price buys). Every Pro call sends approved references (a style image, reference images, an
  approved character as `style_character_id`, style tiles); a Pro call without them is the
  exception, only for a first look before anything is approved, and its job file says why
  (`no_refs_reason`; `gen.py` refuses one without). So each concept's first gate after its
  approval is usually its references.
- **Concepts, not prompts.** The user approves each concept and its budget range; Claude writes
  every prompt and makes every call inside it.
- **The cheapest rung first** for spending: what code, a two-minute Aseprite job, scripted
  Aseprite, or Claude Design can do confidently is not generated. Where a cheap rung and a
  generation could both serve, the look is a bake-off like any other.

| Rung | Who | For |
|---|---|---|
| Code (Python/Pillow, Godot shaders and particles) | Claude | Mirroring the west directions, palette swaps and recolours, the palette remap, hit flashes, afterimages, dissolves, effects, tile variants by flip |
| Aseprite by hand, 2 minutes or less | the user (the hand queue) | A pose touch-up, a corpse frame, a heart's half and empty states, a stray pixel |
| Aseprite scripted (`aseprite -b`, Lua) | Claude | Sheets, frame timing, batch recolours, exports |
| Claude Design | the user or Claude | Style boards, palette candidates, UI and 1080p layout mock-ups |
| PixelLab standard | Claude | v3 characters (1 or 2 generations), template animations (1 a direction), pixflux images (1) |
| PixelLab Pro | Claude | Custom animations (20 to 40 a direction), Pro images and grids, Pro tiles, objects, portraits (20 to 40) |

## The art session

Art moves when the user calls an art session; there is no scheduled run. Each session, in order:

1. **Relevance check.** Read `docs/STATUS.md`, the latest milestone design and feel checklist it
   points to, and what changed since the last session (`git log --oneline <game commit in the last
   log line>..HEAD -- docs data scripts`). For each concept, does what it serves still hold? A cut
   enemy, a new class, a changed size, or a playtest note on the look is raised with the user
   before anything is spent, and the table updated.
2. **Budget.** `tools/art/budget.py` (the live balance and what this session may spend).
3. **Clear the user's answers** from "## Waiting on the user": approved concepts, approved or
   brought references, bake-off picks, approved bases and finals, send-backs with their notes.
4. **Work** the approved concepts in the table's order, within the allowance, each up to its next
   gate (a bake-off to show, a base to approve, a final), with approved references only.
5. **Gather the review**: every gate reached this session on one page (the review page once
   built; a contact sheet in `reports/` until then), each candidate at 2x and at game scale beside
   today's sprite, the set-aside ones with their reasons, each bake-off option with its production
   cost. Add them to "## Waiting on the user".
6. **Record.** Update the table (status, spent), the references, the hand queue, and add a log
   line naming the game commit read in step 1.

## This period

Tier 2 (Pixel Artisan): 5,000 generations from 2026-09-27, renewing 2026-10-27 (unspent
generations expire). 4,956 left on 2026-09-27 (the bake-off spent 44). The sink opens 2026-10-24:
from then on everything left goes to the sink concepts and to bake-offs for concepts not yet
started. Split: style probe and bake-offs 500, production 3,250, rerolls 750, sink 500.

## Concepts

The user approves each concept and its range. **Bake-off** is what the method comparisons cost
(the methods named are the ones compared; the user picks); **production** runs from "every cheaper
method wins" to "every dearer method wins", in generations, from the API's published formulas
(each call type's real cost is measured on its first use and replaces the estimate). Readiness:
*locked* (the design fixes it), *provisional* (a later milestone may change it: drafts only),
*pending* (not designed yet: nothing spent).

| # | Concept | Serves | Readiness | Methods compared (the user picks) | Local work | Bake-off | Production | Status |
|---|---|---|---|---|---|---|---|---|
| C1 | Style lock: gladiator, imp, sand and wall swatch, coin under five styles | every concept | locked | v3 against Pro for the figures; pixflux against a Pro grid for the swatch and the coin | The master palette (Claude Design, Aseprite), the side-by-side board | 100 to 250 | - | three rounds (257 spent, prompt only: `art/jobs/c1_*.json`); the gladiator (S5, Pro) and three chaser creatures approved; waiting on the wraps' colour, the hound, the references |
| C2 | The gladiator (48 px, 8 directions, 5 generated) | the player | locked | Idle and run: template against custom; the fall: a v3 state against custom against a hand pose; hit and dash: code (flash, afterimage) against generated | West mirrored in code | 100 | 15 to 750 | proposed |
| C3 | Tier 1 mobs: chaser, shielded chaser, shooter (the chaser's skins: the lemur, the masked condemned, the strix, perhaps the hound; a skin per series, maybe) | M4/M5 enemies | locked | Imp and shaman idle and run: template against custom; the shaman's wind-up and cast: template attack against custom; deaths: code dissolve with a hand corpse against custom | The shielded chaser as a recoloured imp with a shield sprite facing its arc | 120 | 30 to 1,200 | proposed |
| C4 | Tier 1 boss (96 px) | M4 boss | locked | Idle and run: template against custom; the charge, ring, and summon: effects over a held pose against custom | - | 60 | 15 to 1,000 | proposed |
| C5 | The arena: sand, sandstone walls, the emperor's box, the gate | the arena, the grounds | locked | Standard tileset against Pro tiles against a pixflux swatch tiled by hand; the box and the gate: pixflux against an object | Variants by flip and recolour, cracks by hand | 80 | 60 to 180 | proposed |
| C6 | Boon and HUD icons (the 18 names in `data/icons.json`) | M5 cards, HUD | provisional (M7 adds boons) | Pixflux candidates against a Pro grid, on three icons | The thumb down as the thumb up turned in code | 80 | 90 to 300 | proposed |
| C7 | Props and pickups: coin (spinning), heart, crate, spear, handgun, crossbow | M5 piles, grounds, weapons | locked | Pixflux against an object, on the coin; the spin: animated against hand frames | Heart states by hand, projectiles by hand or code, weapons rotated in the engine | 25 | 30 to 150 | proposed |
| C8 | Effects: muzzle flash, hits, the boss's ring, coin burst | juice | locked | Nothing generated unless the user asks for a bake-off | Godot particles and shaders, Aseprite | 0 | 0 | proposed |
| C9 | UI frames at 1080p | every panel | provisional (the 1080p move) | Nothing generated yet | DungeonUI remapped to the palette in code, touched up in Aseprite; layouts in Claude Design | 0 | 0 | proposed |
| C10 | The crowd (M8) | the border, the favour | provisional (1080p, M7 tiers) | One body's cheer: template against custom | Recolours for variety, tiling in code | 25 | 30 to 250 | sink |
| C11 | Portrait probe: the gladiator's bust, talking | M6 dialogue | pending (no characters written) | `character_to_portrait` from the approved sprite against a Pro image of the bust with the sprite as an approved reference; then its visemes for one mood | Blink and arm layers by hand | 40 to 100 | - | sink |
| C12 | The emperor in his box: seated, thumb up and down | M8 box, M9 verdict | provisional (M7 fight, M9 story) | v3 against Pro for the figure; the gestures: template against custom | - | 40 | 20 to 120 | sink |
| C13 | Later casts: M6 grounds characters, M7 classes, tier 2 and 3 enemies and bosses | M6, M7 | pending | Nothing until their designs exist | - | 0 | 0 | held |

Totals for C1 to C7: about 800 if every cheaper method wins, about 4,300 if every dearer one does
(the bake-offs are about 565 to 715 of either). The period has 4,956; each bake-off's options are
shown with their production cost, so the user picks knowing what the month can hold.

**Talking portraits are in the API** (checked 2026-09-27): `portrait-character-pro`
(`character_to_portrait`, sizes 16 to 160, or `portrait_to_character` for a bust the user brings),
`characters/{id}/portrait` (free), `vocal-animation` (the paid step, once per mood), then
`lip-sync` (free: the frame plan an engine plays) and `talking-gif` (free: a GIF to review). C11
tries the chain on the gladiator; its cost is measured there.

## Waiting on the user

- **The gladiator's wraps** (`reports/art_C1_wraps.png`): the white forearm wraps recoloured in
  code (`tools/art/wraps.py`, no generation) with the crest's reds or the belt's browns, all eight
  directions on sand at 3x and at 2x (the 1080p size). Pick red, brown, the original, or another
  colour.
- **The hound** (`reports/art_C1_hound.png`, beside the three kept creatures): Pro on the `dog`
  template works on a 48 px canvas (it failed twice at 32): a pink, ribbed hound with a spiked
  collar, 20 wide and 38 tall facing south and about 44 long from the side, so larger than the
  32 px chasers (the gladiator is 46 tall); and v3 on the `dog` template at 32 px: a grey hound
  filling its canvas. Keep either, both, or neither.
- **References** (the rule "Pro calls carry references"): approve the S5 gladiator as the style
  reference for the figures to come (`style_character_id`) and his south frame as the style image
  for tiles, icons, and props, or bring others. Nothing is used until approved.
- **C1 round 1's small images** (`reports/art_C1_grids.png`: pixflux or Pro grids) and the
  swatches (`reports/art_C1_styles.png`) are still open. Round 1's figures were answered: Pro, no
  capes, symmetrical, not bulky, the imps replaced (round 2: `reports/art_C1_round2.png`).
- Approve or change the concepts (C2 to C12) and their ranges.

## References

Approved references (`art/refs/refs.json` holds the files, hashes, sources, and what each may
steer). None yet.

## Approved

Bases and results the user approved (a base is not a reference until approved as one).

- 2026-09-27, the gladiator: C1 round 2's S5 Pro character (`r2_S5_gladiator_pro`, PixelLab
  character `e3f8e681-d12c-49ed-b758-703d40c3ebee`), "better", with colour tweaks to come: the red crest
  kept (it reads on sand), the white forearm wraps to change (low contrast).
- 2026-09-27, the chaser's skins, kept as they are: the lemur (`3ee990a7-1fff-4273-b114-57eda5887d7e`), the masked
  condemned (`9e079c70-35b2-442e-a9d2-2dd57cd3205d`), the strix (`d26e45cc-79cd-4abe-9226-495dff451690`), from C1 round 2.

## Hand queue

Two-minute Aseprite jobs for the user, filled as concepts land. Empty.

## Log

- 2026-09-27: the keychain key in, `pixellab.py balance` and `budget.py` working (Tier 2 active,
  4,956 of 5,000 left). Concepts drafted for the user's review; revised the same day with the
  user's rules (the user judges the look at every step, cost is not quality, references approved
  by the user before use) and the portrait chain found in the API. Game commit read: `573f870`.
- 2026-09-27: `gen.py` (plan and run, refs enforced, the ledger, jobs posted side by side) and
  `sheet.py` built; C1 round 1 on prompts alone: five styles on v3 and pixflux, Pro in S1's words
  (29 calls, 115 generations; measured: v3 figure 2, pixflux 1, Pro character 20, Pro image grid
  20). 4,841 left. Game commit read: `89c79ae`.
- 2026-09-27: C1 round 2 from the user's notes: the gladiator redesigned, four chaser ideas in Pro
  (six calls, 120 generations; the hound failed twice, not charged). The rule "Pro calls carry
  references" added (the user), enforced by `gen.py`. 4,721 left. Game commit read: `66376cd`.
- 2026-09-27: the user picked the S5 gladiator and kept the lemur, the condemned, and the strix as
  the chaser's skins. The hound: Pro on the `dog` template works at 48 px (failed at 32), v3 on
  `dog` at 32 (22 generations). The wraps recoloured in code (`tools/art/wraps.py`). 4,699 left.
  This page rebuilt from `89c79ae` (the edits of `66376cd` and `be68b75` had matched a heading's
  name inside the routine's text and duplicated a block). Game commit read: `be68b75`.
