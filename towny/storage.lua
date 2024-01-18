minetest.register_on_mods_loaded(function ()

	print("[towny] Loading towny storage.")
	towny.storage_load()
end)

minetest.register_on_shutdown(function ()

	print("[towny] Saving towny memory to storage.")
	towny.storage_save()
end)

--[[ TODO: autosave
local clock = 0

local saving = false
local function carrier_tick()
	if not towny.dirty or saving then return end
	saving = true

	for i, town in ipairs(towny.towns) do
		if town.dirty then
			towny.storage.save_town_meta(town)
		end
	end

	if towny.nations then
		for nation,data in pairs(towny.nations.nations) do
			if data.dirty then
				towny.storage.save_nation_meta(nation)
			end
		end
	end

	towny.dirty = false
	saving = false
end

-- Autosave every 60 seconds
minetest.register_globalstep(function (dt)
	clock = clock + (dt + 1)
	if clock >= 600 then
		carrier_tick()
		clock = 0
	end
end)

minetest.after(0.1, function ()
	towny.storage.load_all_towns()
end)
]]--

local storage = minetest.get_mod_storage()

-- deleted towns, blocks, etc. keep their ids
local function reorder_indexes(array, index)
	
	local new_array = {}
	local new_array_index = 0

	for i = 1, index do
		if array[i] then
			new_array_index = new_array_index + 1
			array[i].index = new_array_index
			new_array[new_array_index] = array[i]
		end
	end

	array = nil
	index = nil

	return new_array, new_array_index
end

function towny.storage_save()
	
	local i
	local table_str
	-- pointers
	local res
	local block
	local town

	towny.town_array, towny.town_index =
		reorder_indexes(towny.town_array, towny.town_index)
	towny.block_array, towny.block_index =
		reorder_indexes(towny.block_array, towny.block_index)
	towny.resident_array, towny.resident_index =
		reorder_indexes(towny.resident_array, towny.resident_index)

	for i = 1, towny.resident_index do
		res = towny.resident_array[i]
		-- no data duplication
		res.town = nil
		table_str = minetest.serialize(res)
		storage:set_string("resident/" .. tostring(res.index), table_str)
	end
	for i = 1, towny.block_index do
		block = towny.block_array[i]
		block.town = nil
		table_str = minetest.serialize(towny.block_array[i])
		storage:set_string("block/" .. tostring(towny.block_array[i].index),
			table_str)
	end
	for i = 1, towny.town_index do

		town = towny.town_array[i]
		town.block_index = nil
		town.member_index = nil
		town.mayor_index = nil
		table_str = minetest.serialize(towny.town_array[i])
		storage:set_string("town/" .. tostring(towny.town_array[i].index),
			table_str)
	end
end

local function convert_to_vector(xyz_table)
	return vector.new(xyz_table.x, xyz_table.y, xyz_table.z)
end

-- called just after initialization
function towny.storage_load()
	local i
	local storage_table_fields = storage:to_table().fields
	local res
	local block
	local town
	local is_storage_data = false

	for key, value in pairs(storage_table_fields) do

		local table_type, index = key:match("^([%a%d_-]+)/([%a%d_-]+)")
		if table_type and index then
			if table_type == "town" then
				is_storage_data = true
				town = minetest.deserialize(value)
				town.pos = convert_to_vector(town.pos)
				towny.town_index = towny.town_index + 1
				towny.town_array[town.index] = town

			elseif table_type == "block" then
				is_storage_data = true
				block = minetest.deserialize(value)
				block.blockpos = convert_to_vector(block.blockpos)
				block.pos_min = convert_to_vector(block.pos_min)
				block.pos_max = convert_to_vector(block.pos_max)
				towny.block_index = towny.block_index + 1
				towny.block_array[block.index] = block

			elseif table_type == "resident" then
				is_storage_data = true
				res = minetest.deserialize(value)
				towny.resident_index = towny.resident_index + 1
				towny.resident_array[res.index] = res
			end
		end
	end

	-- put everything that couldn't be stored together

	if is_storage_data then
		for i = 1, towny.town_index do
			town = towny.town_array[i]

			town.blocks = {}
			town.block_index = 0
			town.members = {}
			town.member_index = 0
			town.mayors = {}
			town.mayor_index = 0
		end
		-- residents
		for i = 1, towny.resident_index do
			
			res = towny.resident_array[i]
			town = towny.get_town_by_id(res.town_id)
			
			if town then
				res.town = town
				town.member_index = town.member_index + 1
				town.members[town.member_index] = res
				if res.is_mayor then
					town.mayor_index = town.mayor_index + 1
					town.mayors[town.mayor_index] = res
				end
			end
		end
		for i = 1, towny.block_index do
			
			block = towny.block_array[i]
			town = towny.get_town_by_id(block.town_id)

			if town then
				block.town = town
				town.block_index = town.block_index + 1
				town.blocks[town.block_index] = block
			end
		end
		for i = 1, towny.town_index do
			town = towny.town_array[i]

			town.block_count = town.block_index
			town.member_count = town.member_index
			town.mayor_count = town.mayor_index
		end
	end
end

-- delete all data
function towny.delete_all_data()

	-- storage
	local storage_table_fields = storage:to_table().fields
	
	for key, value in pairs(storage_table_fields) do
		local table_type, index = key:match("^([%a%d_-]+)/([%a%d_-]+)")
		if table_type and index then
			storage:set_string(table_type .. "/" .. index, "")
		end
	end

	-- memory
	local i
	for i = 1, towny.resident_index do
		towny.resident_array[i] = nil
	end
	towny.resident_index = 0
	towny.resident_id_count = 0
	
	for i = 1, towny.block_index do
		towny.block_array[i] = nil
	end
	towny.block_index = 0
	towny.block_id_count = 0
	
	for i = 1, towny.town_index do
		towny.town_array[i] = nil
	end
	towny.town_index = 0
	towny.town_id_count = 0

	minetest.request_shutdown("All towny data was deleted by towny admin", false, 0)
end
