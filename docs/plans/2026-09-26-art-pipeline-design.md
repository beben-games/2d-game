# Art pipeline design: generated pixel art for the colosseum

Status: draft, 2026-09-26, updated 2026-09-27 (PixelLab Tier 2 bought; the key storage and the budget
and review loop added), from the user's answers in the art session (drafted while M5 awaits
playtest 2; no game file changes until the swap-in phase). Feeds M8 ("The look") of the colosseum
design (`2026-09-25-colosseum-design.md`, "## The path" and "## Who designs what" item 6) and the
1080p note under its "## Later, from the user's notes".

**Goal.** Replace every third-party visual (the 0x72 tileset and UI, the Raven icons, the pistol
sheet) with custom art generated with PixelLab and Retro Diffusion, curated by the user and
produced through a scripted, reproducible pipeline in the repo: a manifest of what to make, a
generator that calls the tools' APIs, a cleanup pass that enforces the palette and the grid, an
Aseprite hand-off for touch-ups, and a packer that writes the same atlas data the game already
reads.

**Out of scope here:** the game-side swap (directional animation, the 1080p move, the UI rescale),
which gets its own plan when the art is ready (Phase 4); sound and music; fonts (the pixel fonts
stay); the story's writing.

## Decisions taken (the user, 2026-09-26)

- **Scale: 32 px tiles and a 1080p native view.** The 28x15 arena at 32 px is 896x480, an integer
  2x on 1920x1080 (1792x960), the footprint the 1080p note already planned; the border around it
  holds the crowd and the balcony.
- **Release: a free game for now.** Assets that ship are still generated on a paid plan (below), so
  a paid release stays possible without regenerating.
- **Budget: $15 to $40 a month.**
- **Workflow:** the user sets the artistic direction first in the tools' web UIs; then Claude drives
  generation through the API and MCP most of the time; the user touches up in Aseprite (owned).
- **The look:** a sunlit fantasy Rome at first, changing through the story (see "The palette").
- **Animation:** 8 directions for every character, mobs included (the user's gut: consistency
  looks better; checked by feel in the bake-off, open to being wrong); hit, death, and attack
  states; dash frames and weapon swings; an animated crowd; talking portraits (mouth and arm
  movement) for the dialogues.
- **UI:** DungeonUI's frames repainted in the new palette hold for a while; new frames before 1.0.
- **Portraits:** the recommended size for a 1080p native game (see "Portraits").
- **Bought (2026-09-27):** PixelLab Tier 2 ("Pixel Artisan", about $24 a month, a monthly
  allowance of generations that resets with the billing period; 5,000 by third-party reviews, the
  real figure is `total` in `GET /balance`). Retro Diffusion is not bought yet (see "The budget
  loop").
- **Timing:** start now, in parallel with M5 and M6; the art enters the game at M8 or with the
  1080p move, whichever comes first.

## The tools and their jobs

Both tools, split by what each does best. Prices as read on 2026-09-26 from third-party
comparisons and the API pages; check the official pricing before paying.

| Job | Tool | Why |
|---|---|---|
| Characters: the gladiator, class skins, mobs, bosses, the emperor (directions, every state) | PixelLab (primary), Retro Diffusion in the bake-off | Character creator with consistent 4/8 rotations, skeleton animation (pose control, 3 to 15 frames), text-to-animation up to 16 frames, inpainting, style reference |
| The crowd | PixelLab, compared in the bake-off | A few spectator bodies with cheer, boo, and roar loops, tiled over the stands |
| Icons (the ~128 Raven cells, the boon cards), props, coins, the thumb, weapons | Retro Diffusion | `input_palette`, `rd_pro__skill_icon` and `inventory_items`, pay per image (a 128-icon batch is a few dollars) |
| Effects (muzzle flash, hit, the boss's ring, status trails, coin burst) | Retro Diffusion | `rd_animation__vfx` |
| Arena and grounds tiles | the bake-off decides | Both make Wang tilesets (RD `rd_tile__tileset` 16 to 32 px; PixelLab top-down tilesets with two terrain levels) |
| UI frames and panels | first by hand, later the bake-off's winner | First DungeonUI (CC0) remapped to the master palette by `clean.py` and touched up in Aseprite; new frames before 1.0 (RD `rd_pro__ui_panel`, 256x256 only, or PixelLab) |
| Portraits and their talking layers | PixelLab | Style reference for one look across the cast; inpainting for the mouth, eye, and arm layers on a fixed base |

**Costs.** PixelLab: subscription tiers about $12, $24, $50 a month (Apprentice 320x320, Artisan
400x400, Architect with team features); the free trial (40 fast generations, then about 5 slow a
day at 200x200) carries **no commercial licence**. Its API page lists per-call USD prices ($0.002 to
$0.185); whether API calls draw on the subscription or bill apart is to be confirmed. Retro
Diffusion: a prepaid USD balance, RD Fast from $0.015, RD Plus from $0.025, RD Pro $0.18 an image,
advanced animations $0.10 to $0.25, tilesets $0.10; `check_cost: true` prices a request for free;
a free trial of 50 credits. **Plan:** PixelLab Apprentice ($12) after the bake-off, Artisan ($24)
if the cap or the queue slows the character work; RD topped up by about $10 per batch. Inside the
budget.

## The look

**Style bible** (`art/style/`, the user's first job, in the web UIs): two or three reference images
the user likes (a gladiator, a patch of sand and sandstone, one icon), the master palette, and the
prompt conventions every manifest entry shares (the view: top-down three-quarter as today; the
light: warm sun from the top left; the outline: dark, one pixel, selective or not, to decide).
Rules for every asset:

- **One master palette** (`art/style/palette.hex`, 32 to 48 colours, sunlit Rome: sandstone,
  ochre sand, terracotta, bronze, imperial red and gold, sky shadows). Every asset is quantized to
  it; RD takes it as `input_palette`, PixelLab takes the style references.
- **The story's shifts are remaps, not new art.** Each act (and the madness of act 3) gets a
  variant palette with the same number of colours in the same order (`palette_act2.hex`, ...); the
  game swaps them with a palette-remap shader on the arena and the crowd. Generated art never bakes
  in a mood the story will change.
- **No lettering in generated art** (banners, signs, the box): show, don't tell, and text in a
  sprite can never be changed or translated.
- **Hard pixels only:** no semi-transparent pixels, no anti-aliasing, no half-pixels from an
  upscale. The cleanup enforces it; the bake-off scores it.

## Scale in the engine

The art is 32 px a tile. Two ways to put it in the game, decided in the swap-in plan:

- **A. World in 16 px units, art drawn at half scale** (recommended to evaluate first): sprites
  and tiles are drawn at scale 0.5 in the 16-unit world, the camera zooms 4x at 1080p, so one art
  pixel is exactly 2 screen pixels, the same picture as B. Every tuning number in world pixels
  (speeds, `DANGER_RADIUS`, `PULL_RADIUS`, the pile ring, the colliders, `ArenaGrid.TILE`) and
  the tests over them stay as they are.
- **B. World in 32 px units:** `ArenaGrid.TILE` 32, and every world-pixel constant, collider, and
  test doubled. A large retune for the same picture.

Either way the UI moves to 1080p: its constants are 720p pixels on a 16 px font grid today, and
the move needs a UI scale or a retune (the colosseum design's 1080p note).

## Animation

Facing: the player faces the aim (today a horizontal flip; the gun keeps its own rotation), an
enemy faces its movement. **Mirror the west half:** eight directions are five unique (S, SE, E, NE,
N) with SW, W, NW flipped, which saves three eighths of every character's cost; asymmetric
characters (a shield on one arm) are generated in full.

Every character has 8 directions (the user's call for consistency). The bake-off generates the imp
at 8, and the mock-up plays it once with all 8 and once with only the four cardinals (a subset of
the same frames, so no second generation), so the choice is made by eye in the game's view before
the mobs are produced; a switch to 4 for small mobs would be recorded here.

**Sizes on the 32 px grid:** the gladiator about 48 px tall (1.5 tiles, today's knight's
proportion), an imp about 28 to 32 px, a boss about 72 to 96 px. The figure's height is what
counts, and PixelLab's size setting is ambiguous: its MCP docs say the character fills about 60%
of the canvas, while the web Characters tool (default 48x48, width and height sliders, "stored at
exactly this size, non-square padded to a square") reads as the character's own size. Calibrated
2026-09-26 on the first standard-mode gladiator at 48x48: the figure is 46 px tall with its crest
(17 to 24 px wide by direction), so in the web tool the size is the figure's own. Settings: the
gladiator 48x48, an imp 32x32, a boss 96x96. Animations get a larger canvas when the motion needs room, so
the packer anchors every frame at the feet (bottom centre), not at the canvas. The view is PixelLab's "low top-down" (the three-quarter view of today's
tileset). Characters are drawn with empty hands: the weapon is its own sprite, rotated to the aim.
A design with one-sided details (a manica on one arm, a shield) cannot be mirrored, so it costs
all eight directions per animation.

| Who | Directions | States (frames to tune) |
|---|---|---|
| The gladiator, each class skin | 8 | idle, run, hit, fall (the verdict's gladiator down), dash, a weapon swing per class that has one (the handgun and crossbow keep their own sprite and rotation) |
| Chaser, shielded chaser | 8 | idle, run, hit, death |
| Shooter | 8 | idle, run, wind-up (the telegraph), cast, hit, death |
| Bosses | 8 | idle, run, each attack's wind-up and strike (the charge, the ring, the summon), phase change, death |
| The emperor | 1 in the box, 8 in the arena | seated, the thumb up and down, rise; in the fight as a boss |
| The crowd | 1 (facing the arena) | idle, cheer, boo, roar; a few bodies and colours recombined |

**Cost of 8 everywhere.** With the mirror, a character is five generated directions per state: a
mob at four states is twenty animations, the gladiator at six about thirty. At RD's advanced
animation prices ($0.10 to $0.25) or PixelLab's per-animation prices that is a few dollars a
character, spread over Phase 3's batches; still inside the budget.

## Portraits

For the dialogue text box (M6), at 1080p with one art pixel as 2 screen pixels (scale A or B):

- **A 128x128 bust** (head and shoulders, one arm in frame), drawn at 2x: 256x256 on screen, about
  a quarter of the view's height, beside a text box across the bottom third. Big enough to read an
  expression at a glance, small enough for PixelLab's portrait sizes (up to 160) and RD's limits (RD Pro caps at 256) and
  for hand-editing a whole cast in Aseprite. 96x96 (192 on screen) is the fallback if 128 reads
  too heavy beside the arena's 32 px sprites.
- **Talking through PixelLab's portrait chain** (in the API, checked 2026-09-27; it replaces the
  plan of hand-made mouth overlays): `POST /portrait-character-pro` with `character_to_portrait`
  turns an approved sprite into a bust (sizes 16, 32, 48, 64, 128, 160; 128 matches the size
  above; `portrait_to_character` goes the other way, for a portrait the user brings or draws);
  `POST /characters/{id}/portrait` attaches it (free); `POST /vocal-animation` makes the mouth
  positions (visemes) once per expression (`mood`, the same `viseme_count` across a character's
  moods), the only paid step; `POST /lip-sync` (free) gives the frame plan for a line (which mouth,
  for how long, and the grid cell), and `POST /talking-gif` (free) a GIF for review. The game
  keeps the viseme grid per mood and M6's text box plays the plan, fetched at build time per line
  or mapped from the letters in the engine (the dialogue plan decides). Costs of the portrait and
  the visemes are measured in C0. A blink and an arm gesture stay layers (inpainting or by hand).
  Each step is a gate: the bust is a base the user approves before its visemes are made.
- The emperor gets two sets (his public face and his true nature), per the colosseum design.

## The pipeline

Everything under `art/` (sources and data) and `tools/art/` (Python 3 with Pillow, the same
language as `gen_atlas.py` and `gen_icons.py`). No game file changes until Phase 4.

1. **Manifest** (`art/manifest.json`): one entry per asset, named as the atlas will name it:
   `name`, `tool`, `style` (the RD `prompt_style` or the PixelLab endpoint), `prompt`, `size`,
   `directions`, `states` with their frame counts, `palette`, `references`, `seed`, and a `status`
   (`draft`, `approved`, `edited`). An `edited` entry is never regenerated over.
2. **Generate** (`tools/art/gen.py <name|batch> [--dry-run]`): calls the API, prints the cost first
   (RD `check_cost`), sends an `Idempotency-Key` so a retried request is never charged twice, polls
   the job, and writes the outputs to `art/raw/<name>/<n>/` with a sidecar JSON (tool, model, every
   parameter, seed, date, cost). The keys come from the macOS login keychain (`tools/art/keys.py`,
   below), never the repo. The MCP servers stay for interactive exploration from
   Claude Code; anything that ships goes through the manifest so it can be regenerated.
3. **Clean** (`tools/art/clean.py`): alpha to 0 or 255, background removal checked, a detected
   upscale reduced by nearest neighbour, colours quantized to the palette (nearest in OKLab), the
   frame trimmed or padded to its cell, stray single pixels reported. Output to `art/clean/`.
4. **Review:** a contact sheet per batch (`reports/art_<batch>.png`, every frame and direction on a
   checker, at 2x) for the user's eye, like `tools/icon_sheet.gd` today. Approve, reject with a
   note in the manifest, or hand-edit.
5. **Hand-edit:** the clean frames open in Aseprite; the `.aseprite` file is kept in `art/edit/`
   and exported with the Aseprite CLI (`aseprite -b ... --sheet`) back into `art/clean/`; the entry
   becomes `edited`.
6. **Pack** (`tools/art/pack.py`): approved frames into sheets under `assets/art/` and entries in
   the schema `SpriteAtlas` already reads (`x`, `y`, `w`, `h`, `frames`, `stride`), plus
   `data/icons.json` entries on a new sheet. Directional names add the facing
   (`gladiator_run_se_anim`); the game-side lookup by facing is Phase 4's work.
7. **Credits:** a `CREDITS.md` row per tool once its terms are read ("generated with PixelLab /
   Retro Diffusion on a paid plan, made for this project", the "In the repo" verdict).

**What is committed:** the manifest, the style bible, the clean and packed art, the `.aseprite`
sources, the sidecars. The raw outputs (every reject) are gitignored and backed up privately with
the restricted packs (`docs/ASSETS.md`'s note). Subject to the terms (open question 5).

**Checks:** each tool has a `--check` mode run on the committed data (every manifest name packed,
every packed frame inside its sheet, every pixel on the palette, no semi-transparent pixel); in
Phase 4 a gdUnit4 suite asserts every sprite and icon name the game uses exists in the new atlas.

## The keys

In place 2026-09-27. Each key lives in the macOS login keychain (service `pixellab-api-key`, later
`retrodiffusion-api-key`; account `$USER`), stored once by the user at a prompt so it never reaches
a file, the shell history, or the chat. `tools/art/keys.py` reads it at call time (an environment
variable `PIXELLAB_API_KEY` overrides it); `tools/art/pixellab.py` is the REST client (`balance`
today) and puts it only in the `Authorization` header; no tool prints, logs, or writes a key, and
the sidecars and the ledger record parameters, never headers. `tools/hooks/pre-commit` (enabled
per checkout with `git config core.hooksPath tools/hooks`) fetches each key from the keychain and
refuses a commit whose staged diff contains it, or a staged `.env`. `.gitignore` covers `.env*` and
`art/raw/`. The PixelLab MCP server is not configured: its key would sit in plain text in
`~/.claude.json`, and its calls would spend the allowance outside the ledger. If wanted for
exploration, it takes a `headersHelper` that reads the keychain.

## The budget loop and the review

Proposed 2026-09-27, revised the same day with the user's rules on judgement and references. The
allowance is PixelLab generations, reset monthly and lost if unspent. The loop turns it into art the
user approved, at the pace the user reviews, and spends it all before the reset.

**What things cost.** Every response carries its `usage` (`generations` charged); `GET /balance`
gives `generations` left and `total`. From the API's descriptions: `create-character-v3` is
`ceil(w*h*8/65536)` generations (1 at 48 px, 2 at 96 px) plus 1 when it drafts the figure from
text; a template animation is 1 a direction, a custom one 20 to 40 a direction; objects, Pro
images, Pro tiles, and edits 20 to 40 a call, and at sprite sizes a Pro image returns a grid of
candidates (64 frames for 20 at 32 px or under; 16 for 20 at 43 to 64 px). The ledger (below)
replaces these with measured figures per endpoint and size (concept C0).

**Cost is not quality** (the user, 2026-09-27). A custom animation is not assumed better than a
template, a Pro call not better than v3 or a standard one, a generation not better than code or
hand work: in the user's experience the dearer method has not always won. Where two methods can
make the same thing, the concept's first step is a **method bake-off**: the same subject by each
method, cheaply (one direction, the south, of one state), shown side by side to the user, who
picks; production then uses the winner. A concept's budget is a range: the bake-off, plus
production if the cheaper method wins, up to production if the dearer one wins.

**The user is the only judge of the look** (the user, 2026-09-27). Claude never picks a winner, at
any step. Claude may set aside a candidate only for a fault it can state (the wrong canvas or
view, a broken limb, off the palette, semi-transparent pixels, the figure cut off), and the
set-aside candidates stay one click away in the review with their reason. The gates of a concept,
each the user's:

1. *The concept and its budget* (free): what it serves, its readiness, the methods to compare, and
   the range. Claude writes every prompt and makes every call inside an approved concept; the user
   never reviews prompts or calls.
2. *The references*, before the first call that uses them (below).
3. *The method bake-off*, where the concept has one.
4. *The base* before anything is built on it: the figure before its animations, states, and
   portrait; the tile swatch before the tileset; the palette before the recolours.
5. *The final result*, next to today's sprite at game scale.

The reviews of a session are gathered on one page (the review page once built; a contact sheet in
`reports/` until then), so the user answers them in one sitting.

**References are the user's** (the user, 2026-09-27). Any image sent to steer a generation is a
reference: `reference_image(s)`, `style_image(s)`, `init_image(s)`, `color_image`, and the
tileset's `*_reference_image` fields (today's API takes them on the Pro image and style calls, v3
and Pro characters, objects, tiles and tilesets, the animation and edit calls, pixflux, bitforge,
and rotate). Each one is in `art/refs/refs.json` before it is used: the file, its source (brought by
the user, or a generation or crop the user approved as a reference), what it may steer (style,
colour, a character's identity), and the date the user approved it. The user may bring their own
at any gate. `queue.py` refuses a call carrying an image not in the file, matched by hash. The
subject of an edit or an animation (the approved figure being animated) is not a reference: it
passed its own gate as a base.

**Styles first.** A style is a named bundle in `art/style/styles.json`: view, outline, shading,
detail, the palette, the approved references, a prompt prefix. Before production, the style probe
(C1): the same four subjects (the gladiator, an imp, sand and a sandstone wall, the coin icon)
under five or six candidate styles, side by side, extending the bake-off already in
`art/bakeoff/`. The user picks; a picked result becomes a reference only when the user approves it
as one. Concepts name a style, never repeat it, so a style change requeues cleanly.

**The manifest's statuses** (per asset, inside a concept): `planned` → `generated` (candidates in
`art/raw/`) → `approved` by the user, or `reroll` with the user's note → `cleaned` → `edited` (never
regenerated over) → `packed`. PixelLab keeps characters on its side: the asset stores the
`character_id`, so every animation, state, and portrait reuses the same figure.

**The monthly split** (of `total`, read from the balance, not assumed):

| Share | For | Rule |
|---|---|---|
| 10% | Style probe and method bake-offs | The first month; later months give what is unspent to production |
| 65% | Production | Approved concepts in the table's order, paced (below) |
| 15% | Rerolls | Held for the user's send-backs; released to production in the last week |
| 10% | The sink | See below |

**Pacing, by session.** No scheduled run (the user, 2026-09-27): art moves when the user calls an
art session, following the routine at the top of `docs/ART.md`. `tools/art/budget.py` reads the
balance and gives what the session may spend: up to the even-pace line a week ahead (`lead_days`
in `art/budget.json`), so a gap between sessions is caught up but a month is never spent on the
first draft; it warns when the spending is more than a week behind the line. A run never starts a
job the balance cannot pay for.

**Relevance, every session.** The first step of every art session reads `docs/STATUS.md`, the
latest milestone design and feel checklist, and the commits since the last art session's log line,
and checks each concept's "serves" against them; a change is raised with the user before anything
is spent. Only *locked* concepts go to production; *provisional* ones get drafts in the sink;
*pending* ones get nothing until their design exists.

**The cheapest rung first** (the user, 2026-09-27): what code (mirroring, palette swaps, flashes,
afterimages, effects), a two-minute Aseprite job by the user (the hand queue in `docs/ART.md`),
scripted Aseprite, or Claude Design (style boards, palettes, UI layouts) can do confidently is not
generated. This is about spending, not about the look: where a cheap rung and a generation both
could serve, which looks better is a bake-off for the user, like any other.

**The sink ("make it count").** Three days before the reset, whatever is left is spent on a
standing backlog of useful extras, lowest risk first: more candidates where the user's pick was a
close call, palette and colour variants, the later cast's first drafts (portraits, class skins,
the crowd's bodies), spare props for the grounds, method bake-offs for concepts not yet started.
Nothing expires unspent; nothing in the sink is needed on time.

**The tools** (Phase 2, Python with Pillow and the standard library):

- `tools/art/budget.py` (in place 2026-09-27): the balance, the period, the session's allowance, the
  split.
- `tools/art/queue.py` (Phase 2): `plan` prints what a session would make and cost, no API call;
  `run` spends inside the allowance (each job's id recorded before it is polled so a timeout is
  never re-sent blind, the outputs to `art/raw/<name>/<n>/` with a sidecar); both refuse an image
  input not in `art/refs/refs.json`.
- `art/ledger.jsonl` (committed): one line per call: time, concept, endpoint, a hash of the
  parameters, the reference ids, the job id, the generations charged, the balance after.
- `tools/art/review.py` (Phase 2): a local page (`http://localhost:8765`, opened in the app's
  browser pane) with the session's pending gates: references to approve (or the user's own to
  add), bake-offs side by side, bases, and finals, each candidate on a checker at 2x and at game
  scale beside today's sprite; the set-aside candidates with their reasons; approve, pick, or send
  back with a note; the budget bar. It writes the manifest and `refs.json`.

**Retro Diffusion** stays out until a gap shows, and enters through a method bake-off like any
other method. The bake-off table under "The tools and their jobs" is kept for that decision.

## Phases

| Phase | Who | Delivers |
|---|---|---|
| 0. Terms and style | the user | Read both tools' terms (ownership of output, free vs paid, redistribution); explore in the web UIs; pick the references; a first palette |
| 1. Bake-off | the user and Claude, free tiers | The same five assets in both tools: the gladiator at 32 px (8 directions, walk), an imp (run, hit; at 4 and at 8 directions), sand and sandstone wall tiles, three icons, one effect. Scored by the user (the look is the user's call); Claude records the measurable: palette discipline, clean edges, minutes of Aseprite cleanup, cost |
| 2. Tooling | Claude | Buy per the bake-off; `gen.py`, `clean.py`, the contact sheet, `pack.py`, the checks, proven on the bake-off's winners; nothing wired into the game |
| 3. Production | Claude batches, the user curates | By order of need: the gladiator, the tier 1 mobs and boss, the arena tiles and the emperor's box, the icons, the UI, the effects, the crowd, the grounds, the portraits (M6's characters) |
| 4. Swap-in | a game plan (M8 or the 1080p move) | Scale A or B, the directional animation, the palette-remap shader, the UI at 1080p, the 0x72 and Raven art removed, `CREDITS.md` and `docs/ASSETS.md` updated |

Working beside the milestones: Phases 0 to 3 touch only `art/`, `tools/art/`, and this doc, so they
can run while another session builds the game; the one-agent-per-checkout rule still holds (a
worktree, or commits by explicit path).

## Open questions

Answered 2026-09-26: the extra animation (dash frames, weapon swings, talking portraits), 8
directions for all (checked by feel in the bake-off), the UI frames (DungeonUI repainted for now,
new before 1.0), the portrait size (recommended above: 128x128 at 2x). Still open:

1. Scale A or B (decided in Phase 4, after a prototype of A).
2. The terms: who owns free-tier and paid output of each tool, and may the generated files be
   committed to a public repo? (Purely generated images may carry no copyright of their own in some
   jurisdictions; that does not stop their use, and hand edits add authorship.)
3. The portraits' 128 against 96, by eye once the first bust exists beside the arena's sprites.

Found 2026-09-26: Aseprite 1.3.17.2 (Steam build) at
`/Applications/Aseprite.app/Contents/MacOS/aseprite`; the tools take it from `ASEPRITE_BIN`,
defaulting to that path.

## User actions

- Phase 0: read the terms, explore, pick the references and the palette.
- Store each API key in the login keychain (`security add-generic-password -a "$USER" -s
  pixellab-api-key -w`, typed at the prompt; never in chat, a file, or the repo).
- Give the billing period's reset day, for the pacing.
- Buy the plans the bake-off picks.
- Answer the open questions.
