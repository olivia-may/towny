-- resident class constructor
function towny.resident.new(player)

	local resident = {}
	setmetatable(resident, towny.resident)
	towny.resident.__index = towny.resident

	towny.resident_count = towny.resident_count + 1
	resident.index = towny.resident_count
	towny.resident_array[resident.index] = resident

	towny.resident_id_count = towny.resident_id_count + 1
	resident.id = towny.resident_id_count

	resident.name = player:get_player_name()
	resident.nickname = resident.name -- can be changed later by player
	
	return resident
end

function towny.get_resident_by_id(resident_id)

	local i
	for i = 1, towny.resident_count do
		if towny.resident_array[i].id == resident_id then
			return towny.resident_array[i]
		end
	end

	return nil
end

