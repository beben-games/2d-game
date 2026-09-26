# Arena Roguelike, tester build 0.5.0-rc1

Thanks for testing. This is an early, unsigned build of a small action roguelike. It is free and has
no online features. The only thing it writes outside its own folder is Godot's per-user data folder,
`%APPDATA%\Godot\app_userdata\Arena Roguelike\` on Windows or
`~/.local/share/godot/app_userdata/Arena Roguelike/` on Linux, which holds your volume settings
(`settings.cfg`), a log (`logs/`), and your progress (`save.cfg`, with a `save.cfg.bak` if a file
could not be read); deleting that folder resets the volumes and the progress.

## Running it

- Windows: unzip, run `ArenaRoguelike.exe`. SmartScreen will warn because the build is not signed:
  click "More info", then "Run anyway".
- Linux (x86_64): unzip, then `chmod +x ArenaRoguelike.x86_64` and run it. Needs OpenGL 3.3.

The game runs fullscreen at 1280x720 scaled. Quit from the title's Quit button or the pause screen's
"Quit game" (Alt+F4 on Windows or your window manager's close also works).

## Controls

- Move: WASD. Aim: mouse. Shoot: hold left click. Dash: Space or right click.
- Cards: click one, or press 1 to 4.
- Tab or Esc: the pause screen (your build, the volumes, restart, quit to title, quit the game).
  R: restart the run.
- Enter on the title starts; type a seed first to replay a run.
- On the end screen: Enter or a click continues, Esc returns to the title.

## What it is

Eight rounds in one arena, then the boss. Between runs you are in the grounds.

## What we want to know

Play at least two full runs (win or fall), then tell us:

1. The meter under the hearts: what did you make of it, and what moved it?
2. The number at the right of the screen, and the coins on the floor: what are they, and what did
   you do about them?
3. The crowd: what did you hear, and when?
4. The thumb at the end of a run: what did it mean, and did you see it coming?
5. The end screen names a gate. Did you meet two names? What did they tell you?
6. The grounds: three places. What did each do, and did the next run feel different?
7. Where did the game explain something to you (a caption, a label, a hint)? We want that answer
   to be "nowhere"; if it is not, tell us where.
8. The fights: rounds 4 to 7 and the boss, as before. Where did you fall, and did it feel fair?
9. Sound and music: the run's loop, the boss's, the grounds', the crowd, the fanfare: too loud,
   too soft, missing anywhere?
10. Anything ugly, laggy, or broken (say what you were doing).

The end screen shows a seed number. Include it with any bug so we can replay your run.

Send feedback to Benjamin however you got this build.

## For testers only

The seed field on the title takes three code words instead of a number: `permawhat?` (no damage),
`verso` (the thumb goes down), `dives` (1000 coins). A cheated run says so on its end screen.
