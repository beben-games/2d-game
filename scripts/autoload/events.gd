extends Node
## Global signal bus. Systems emit here and subscribe here instead of holding references to each other.

signal enemy_spawned(enemy: Node2D)
signal enemy_hit(enemy: Node2D, damage: float, hit_position: Vector2)
signal enemy_died(enemy: Node2D, death_position: Vector2)
signal shot_fired(muzzle_position: Vector2, direction: Vector2)
signal player_hit(damage: int)
signal player_died()
