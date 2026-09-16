extends Node
## Global signal bus. Systems emit here and subscribe here instead of holding references to each other.

signal enemy_spawned(enemy: Node2D)
signal enemy_hit(enemy: Node2D, damage: float, hit_position: Vector2)
signal enemy_died(enemy: Node2D, death_position: Vector2)
## weapon_id names the weapon that fired, so a handgun and a crossbow sound different.
signal shot_fired(muzzle_position: Vector2, direction: Vector2, weapon_id: String)
signal shot_bounced(position: Vector2)
## A player shot or an enemy bolt ended on a wall.
signal shot_hit_wall(position: Vector2)
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
signal room_entered(index: int, total: int)
signal door_sealed(position: Vector2)
## The exit opened after the pick (or the clear of a room with nothing to offer).
signal door_opened(position: Vector2)
signal room_exit_requested()
signal wave_started(index: int, total: int)
signal room_cleared()
signal run_won()
## A fresh run: RunState.start_run (the title's Play, R, a test's reset).
signal run_started()
## rank is the rank the build now holds for the card: 0 for Heal and Switch cards, which never enter the build.
signal upgrade_chosen(card: UpgradeDef, rank: int)
signal build_changed()
signal dash_charges_changed(charges: int, max_charges: int)
## name is "upgrade", "build", "title", "summary_won", or "summary_lost".
signal menu_opened(name: String)
signal menu_closed(name: String)
signal card_hovered()
## The boss became active (its fade-in ended).
signal boss_spawned(boss: Node2D)
signal boss_phase_changed(phase: int)
## pattern is "ring", "volley", "charge", "charge_end", "charge_wall", or "summon"; position is the boss's.
signal boss_attacked(pattern: String, position: Vector2)
