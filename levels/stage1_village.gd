extends HauntedLevel
## =========================================================================
## Stage1Village  -  Level 1: Abandoned Village
## =========================================================================
## Teaches: moving, looking, jumping, crouching, interacting, taking damage,
## AND the core loop of the game - find the roaming ghosts and banish them
## before they kill you.
##
## Difficulty order in this level (easiest first):
##   the two girl soldier ghosts, then the boy soldier ghost.
## No queen, no king. That is deliberate - Stage 1 is the tutorial hunt.
## =========================================================================

func _level_started() -> void:
	expect_min_ghosts = 3
	expect_min_weapons = 2
	expect_locked_katana = false
	GameManager.set_objective("Explore the abandoned village")
	GameManager.clue_found.connect(_on_clue_found)


func on_all_ghosts_banished() -> void:
	GameManager.complete_objective("stage1_clear")
	GameManager.set_objective("The village is quiet again. Find the cursed well")
	GameManager.show_message(
		"Every spirit in the village has been banished.\n\nSTAGE 1 COMPLETE.\nDescending to Stage 2 - the haunted military barracks...\n\n(The Queen and the King are waiting there.)",
		7.0)


func _on_clue_found(clue_id: String) -> void:
	match clue_id:
		"chapel_note":
			GameManager.set_objective("Find the cursed well to the west")
		"tower_note":
			GameManager.set_objective("Clear the village of spirits")
