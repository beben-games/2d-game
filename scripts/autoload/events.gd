extends Node
## Global signal bus. Systems emit here and subscribe here instead of holding references to each other.

## Emitted by the Spawner and the boss's summons; only tests consume it today.
signal enemy_spawned(enemy: Node2D)
signal enemy_hit(enemy: Node2D, damage: float, hit_position: Vector2)
signal enemy_died(enemy: Node2D, death_position: Vector2)
## weapon_id names the weapon that fired, so a handgun and a crossbow sound different.
signal shot_fired(muzzle_position: Vector2, direction: Vector2, weapon_id: String)
signal shot_bounced(position: Vector2)
## A player shot or an enemy bolt ended on a wall.
signal shot_hit_wall(position: Vector2)
## A player shot ended on an enemy's shield (Enemy.blocks_shot): no damage, sparks and a clink.
signal shot_blocked(position: Vector2)
## A shooter or the boss started its wind-up.
signal enemy_telegraphed(enemy: Node2D)
## A bolt left an enemy (the boss's rings and volleys report through boss_attacked instead).
signal enemy_fired(enemy: Node2D, position: Vector2)
## kind is "burn", "stun", or "chill"; emitted when the status starts, not on a refresh.
signal status_applied(enemy: Node2D, kind: String)
signal player_hit(damage: int, hp: int, max_hp: int)
signal player_healed(hp: int, max_hp: int)
signal player_died(death_position: Vector2)
signal player_dashed(position: Vector2, direction: Vector2)
## A round begins in the arena: index is 0-based, total the series' rounds.
signal round_started(index: int, total: int)
signal wave_started(index: int, total: int)
## The round's last wave died. Arrives from inside a physics callback (a shot's body_entered).
signal round_cleared()
## The round's verdict, emitted by Main right after round_cleared (inside the same physics
## callback): band is FavourRules.band of the favour at the round's end, the crowd's sound follows.
signal round_ended(band: int)
## The crowd's favour moved: value is the meter after the change, band its FavourRules band, act
## the FavourRules.ACTS row that moved it (or FavourRules.COWARDICE_ACT for the idle drain).
signal favour_changed(value: float, band: int, act: String)
## The last round's clear: emitted from Main's round_cleared handler, so it arrives inside the same
## physics callback, and a handler that adds or frees physics nodes or pauses must defer.
signal run_won()
## A fresh run: RunState.start_run (the title's Play, R, a test's reset).
signal run_started()
## rank is the rank the build now holds for the card: 0 for Heal and Switch cards, which never enter the build.
signal upgrade_chosen(card: UpgradeDef, rank: int)
signal build_changed()
signal dash_charges_changed(charges: int, max_charges: int)
## name is "upgrade", "build", "title", "summary_won", or "summary_lost". The summary names have
## no menu_closed twin: a restart reloads the scene.
signal menu_opened(name: String)
signal menu_closed(name: String)
signal card_hovered()
## The boss became active (its fade-in ended).
signal boss_spawned(boss: Node2D)
signal boss_phase_changed(phase: int)
## pattern is "ring", "volley", "charge", "charge_end", "charge_wall", or "summon"; position is the boss's.
signal boss_attacked(pattern: String, position: Vector2)
