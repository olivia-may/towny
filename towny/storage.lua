local clock = 0

function towny.storage_save()
	
	local i, j
	local table_str
	-- pointers
	local res
	local block
	local town

	-- no duplicate data or clones of classes

	for i = 1, towny.resident_count do

		res = towny.resident_array[i]
		res.town = nil
		table_str = minetest.serialize(res)
		towny.storage:set_string("res " .. tostring(res.name), table_str)
	end
	for i = 1, towny.town_count do

		town = towny.town_array[i]

		for j = 1, town.block_count do

			block = town.block_array[j]
			block.town = nil
			table_str = minetest.serialize(block)
			towny.storage:set_string("block " .. tostring(town.id) .. " " .. block.id,
				table_str)
		end

		town.block_array = nil
		town.block_count = nil
		town.member_array = nil
		town.member_count = nil
		
		table_str = minetest.serialize(town)
		towny.storage:set_string("town " .. tostring(town.id), table_str)
	end
end

-- called just after initialization
function towny.storage_load()
	local i
	local storage_table_fields = towny.storage:to_table().fields
	local res
	local block
	local town
	local table_type

	-- load towns first
	for key, value in pairs(storage_table_fields) do

		table_type = key:match("^[%a]+")

		if table_type == "town" then
			
			town = minetest.deserialize(value)
			
			town.pos = towny.convert_to_vector(town.pos)
			towny.town_count = towny.town_count + 1
			towny.town_array[towny.town_count] = town

			town.block_array = {}
			town.block_count = 0
			town.member_array = {}
			town.member_count = 0
		end
	end

	for key, value in pairs(storage_table_fields) do

		table_type = key:match("^[%a]+")

		-- residents
		if table_type == "res" then

			res = minetest.deserialize(value)
			towny.resident_count = towny.resident_count + 1
			towny.resident_array[towny.resident_count] = res
			
			if res.town_id then

				town = towny.get_town_by_id(res.town_id)
				res.town = town
				town.member_count = town.member_count + 1
				town.member_array[town.member_count] = res
			end
		end

		-- blocks
		if table_type == "block" then

			block = towny.block.new_from_data(minetest.deserialize(value))
			--block = minetest.deserialize(value)
			
			town = towny.get_town_by_id(block.town_id)
			block.town = town
			town.block_count = town.block_count + 1
			town.block_array[town.block_count] = block
		end
	end

end

-- delete all data
function towny.delete_all_data()

	-- storage
	local storage_table_fields = towny.storage:to_table().fields
	local table_type
	
	for key, value in pairs(storage_table_fields) do
		towny.storage:set_string(key, "")
	end

	-- memory
	local i
	for i = 1, towny.resident_count do
		towny.resident_array[i] = nil
	end
	towny.resident_count = 0
	towny.resident_id_count = 0
	
	for i = 1, towny.town_count do
		towny.town_array[i] = nil
	end
	towny.town_count = 0
	towny.town_id_count = 0

	minetest.request_shutdown("All towny data was deleted by towny admin", false, 0)
end

minetest.register_on_mods_loaded(function ()

	print("[towny] Loading towny storage.")
	towny.storage_load()
end)

minetest.register_on_shutdown(function ()

	print("[towny] Saving towny memory to storage.")
	towny.storage_save()
end)

minetest.register_globalstep(function (dtime)
	clock = clock + dtime
	-- Autosave every x seconds
	if clock > towny.setting_autosave_interval then
		print("[towny] Autosaving towny memory to storage.")
		towny.storage_save()
		clock = 0
	end
end)
