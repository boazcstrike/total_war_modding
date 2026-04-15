extends Node

# SquadManager singleton for handling AI squad coordination
class_name SquadManager

# Dictionary of squad_id -> Array[Node] (agents in squad)
var squads = {}

# Dictionary of agent -> squad_id for quick lookup
var agent_squads = {}

# Squad counter per faction
var squad_counters = {}

func _ready():
    # Ensure this is a singleton
    pass

func get_max_squad_size(faction: String) -> int:
    match faction:
        "Guard":
            return 4
        "Bandit":
            return 6
        "Military":
            return 4
        _:
            return 4

func get_min_squad_size(faction: String) -> int:
    match faction:
        "Guard":
            return 2
        "Bandit":
            return 3
        "Military":
            return 4
        _:
            return 2

# Assign an agent to a squad
func assign_to_squad(agent: Node, faction: String) -> String:
    if agent_squads.has(agent):
        return agent_squads[agent]

    # Find or create a squad for this faction
    var squad_id = _find_available_squad(faction)
    if squad_id == "":
        squad_id = _create_new_squad(faction)
        if squad_id == "":
            # Can't assign to squad
            agent.set_meta("squad_id", "")
            agent.set_meta("squad_leader", false)
            return ""

    # Add agent to squad
    if !squads.has(squad_id):
        squads[squad_id] = []

    squads[squad_id].append(agent)
    agent_squads[agent] = squad_id

    # Assign leader if first in squad
    if squads[squad_id].size() == 1:
        agent.set_meta("squad_leader", true)
    else:
        agent.set_meta("squad_leader", false)

    agent.set_meta("squad_id", squad_id)

    return squad_id

# Find an available squad for the faction (not full)
func _find_available_squad(faction: String) -> String:
    for squad_id in squads.keys():
        if squad_id.begins_with(faction + "_") and squads[squad_id].size() < get_max_squad_size(faction):
            return squad_id
    return ""

# Create a new squad for the faction
func _create_new_squad(faction: String) -> String:
    if faction == "Military" and squad_counters.get(faction, 0) >= 2:
        return ""
    if !squad_counters.has(faction):
        squad_counters[faction] = 0
    squad_counters[faction] += 1
    return faction + "_" + str(squad_counters[faction])

# Get all members of a squad
func get_squad_members(squad_id: String) -> Array:
    return squads.get(squad_id, [])

# Get squad members excluding the sender
func get_squad_allies(agent: Node) -> Array:
    var squad_id = agent_squads.get(agent, "")
    if squad_id == "":
        return []
    var members = squads.get(squad_id, []).duplicate()
    members.erase(agent)
    return members

# Check if two agents are in the same squad
func are_squad_mates(agent1: Node, agent2: Node) -> bool:
    var squad1 = agent_squads.get(agent1, "")
    var squad2 = agent_squads.get(agent2, "")
    return squad1 != "" and squad1 == squad2

# Send a message to squad members
func send_squad_message(agent: Node, message: Dictionary):
    var allies = get_squad_allies(agent)
    for ally in allies:
        if is_instance_valid(ally) and ally.has_method("receive_squad_message"):
            ally.receive_squad_message(message)

# Remove agent from squad (on death)
func remove_from_squad(agent: Node):
    var squad_id = agent_squads.get(agent, "")
    if squad_id != "" and squads.has(squad_id):
        squads[squad_id].erase(agent)
        # If squad is empty, remove it
        if squads[squad_id].is_empty():
            squads.erase(squad_id)
    agent_squads.erase(agent)

# Get squad size
func get_squad_size(agent: Node) -> int:
    var squad_id = agent_squads.get(agent, "")
    if squad_id == "":
        return 0
    return squads.get(squad_id, []).size()

# Check if agent is squad leader
func is_squad_leader(agent: Node) -> bool:
    return agent.get_meta("squad_leader", false)

# Get total number of active squads
func get_total_squads() -> int:
    var count = 0
    for squad_id in squads:
        var has_active = false
        for agent in squads[squad_id]:
            if is_instance_valid(agent) and not agent.is_paused:
                has_active = true
                break
        if has_active:
            count += 1
    return count