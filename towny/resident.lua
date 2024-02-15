-- resident class constructor
function towny.resident.new(player)

	local resident = {}
	setmetatable(resident, towny.resident)
	towny.resident.__index = towny.resident

	towny.resident_count = towny.resident_count + 1
	resident.index = towny.resident_count
	towny.resident_array[resident.index] = resident

	resident.name = player:get_player_name()
	resident.nickname = resident.name -- can be changed later by player
	
	return resident
end
