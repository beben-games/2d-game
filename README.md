# Arena Roguelike

A small top-down action roguelike made in Godot 4.7, built as an experiment in making an open-source
game with [Claude Code](https://claude.com/claude-code) and free assets.

Fight through eight single-screen rooms. After each cleared room you pick one of three upgrade
cards, and room eight holds the boss. You start with a handgun and can switch to a crossbow. Upgrades
stack into builds: bouncing, homing, and piercing shots, burn, stun, and chill, extra dash charges,
and more hearts. Some enemies carry shields that stop your shots from the front.

Status: an early prototype (Milestone 4 of the plan, version `0.4.0-rc3`). The name "Arena" is a
placeholder.

## Play

Download the Windows or Linux zip from [Releases](https://github.com/beben-games/2d-game/releases),
unzip it, and run it. The README inside the zip covers the details, such as the SmartScreen warning
on Windows.

- Move: WASD. Aim: mouse. Shoot: hold left click. Dash: Space or right click.
- Pick an upgrade card: click it, or press 1, 2, or 3.
- Tab or Esc pauses (your build, the volumes, restart, quit). R restarts the run.
- Type a seed on the title screen to replay a run. The end screen shows each run's seed.

## Run from source

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build, not .NET).

```bash
git clone https://github.com/beben-games/2d-game.git
cd 2d-game
godot --path .                  # or open project.godot in the editor and press F5
godot --path . -- --seed=1234   # skip the title and replay seed 1234
```

The repository leaves out a few third-party files whose licenses forbid reposting them. Without
them the game draws placeholder icons and plays some sounds as silence; `docs/ASSETS.md` explains
where to get them. The release builds include everything.

## Develop

The tool scripts are bash and expect the Godot binary at `/Applications/Godot.app` (macOS); set
`GODOT_BIN` to point elsewhere (see `tools/godot.sh`).

- `tools/test.sh` runs every gdUnit4 suite headless (exit 0 on pass).
- `tools/check_boot.sh` boots the main scene headless and fails on any Godot error or warning.
- `tools/smoke.sh <scenario>` plays a scripted few seconds in a window and saves a screenshot to
  `reports/`.
- `tools/build.sh` exports the Windows and Linux release zips into `builds/` (needs the Godot export
  templates).

Game data (weapons, enemies, upgrades, waves, rooms) lives in `data/` as Godot resources. The design
and the build record of every milestone are in `docs/plans/`, and `docs/STATUS.md` is the current
state. `CLAUDE.md` holds the conventions the Claude Code sessions follow.

## License

The code, scenes, data, tools, and docs are [MIT](LICENSE). The art, fonts, sounds, and music are by
other authors under their own licenses; see [CREDITS.md](CREDITS.md).
