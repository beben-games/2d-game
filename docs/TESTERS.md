# Arena Roguelike, tester build 0.4.0-rc2

Thanks for testing. This is an early, unsigned build of a small action roguelike. It is free and has
no online features. The only thing it writes outside its own folder is Godot's per-user data folder,
`%APPDATA%\Godot\app_userdata\Arena Roguelike\` on Windows or
`~/.local/share/godot/app_userdata/Arena Roguelike/` on Linux, which holds your volume settings
(`settings.cfg`) and a log (`logs/`); deleting that folder resets the volumes.

## Running it

- Windows: unzip, run `ArenaRoguelike.exe`. SmartScreen will warn because the build is not signed:
  click "More info", then "Run anyway".
- Linux (x86_64): unzip, then `chmod +x ArenaRoguelike.x86_64` and run it. Needs OpenGL 3.3.

The game runs fullscreen at 1280x720 scaled. Quit from the title's Quit button or the pause screen's
"Quit game" (Alt+F4 on Windows or your window manager's close also works).

## Controls

- Move: WASD. Aim: mouse. Shoot: hold left click. Dash: Space or right click.
- After a room is cleared, a menu offers three upgrade cards: click one, or press 1, 2, or 3.
- Tab or Esc: the pause screen (your build, the volumes, restart, quit to title, quit the game).
  R: restart the run at any time.
- Enter on the title starts; type a seed first to replay a run.
- On the end screen: R restarts, Esc returns to the title.

## What it is

Eight rooms of enemies. Clear a room, pick an upgrade, walk through the top door. Two weapons:
you start with the handgun; a Crossbow card swaps to it (and you re-pick as many upgrades as you
had). A swap is one-way: a weapon you have used this run is never offered again. Some cards only
appear for one weapon. From room 4 some enemies carry a shield (the pale
arc on their front) that stops your shots: shoot them from the side or behind, or pierce
through. Clear room eight's boss to win.

## What we want to know

Play at least two full runs (win or die), then tell us:

1. Did you find an upgrade combination you liked? Which one?
2. Which cards did you never pick, and why?
3. Handgun or crossbow: which felt better, and was the swap worth its cost?
4. Where did you die, and did it feel fair?
5. Was anything confusing (the menu, the HUD, a card's text)?
6. Anything ugly, laggy, or broken (say what you were doing).
7. The boss: did its attacks read before they landed, and how long did it take?
8. Sound and music: too loud, too soft, missing anywhere?

The run summary shows a seed number. Include it with any bug so we can replay your run.

Send feedback to Benjamin however you got this build.
