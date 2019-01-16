-- Store all data in ModStorage metadata
-- Recommended

local storage = minetest.get_mod_storage()

local function write_meta(town,scope,data)
	local data = table.copy(data)
	data.dirty = nil
	data.level = nil

	local serialized = minetest.serialize(data)
	storage:set_string(town.."/"..scope, serialized)
	data = nil
end

function towny.storage.save_town_meta(town)
	local tmeta = towny.towns[town]
	if tmeta and tmeta.dirty then
		towny.get_town_level(town, true)
		write_meta(town,"meta",tmeta)
		tmeta.dirty = false
	end

	local rmeta = towny.regions.memloaded[town]
	if rmeta and rmeta.dirty then
		write_meta(town,"region",rmeta)
		rmeta.dirty = false
	end
end

function towny.storage.save_nation_meta(nation)
	if not towny.nations then return end
	local rmeta = towny.nations.nations[nation]
	if rmeta and rmeta.dirty then
		write_meta(nation,"nation",rmeta)
		rmeta.dirty = false
	end
end

-- Ideally only ever called once
function towny.storage.load_all_towns()
	local keys = {}
	local store = storage:to_table()

	if store and store.fields then
		store = store.fields
	end

	for key, data in pairs(store) do
		local town, scope = key:match("^([%a%d_-]+)/([%a%d_-]+)")
		if town and scope then
			local tbl = minetest.deserialize(data)
			if scope == "meta" then
				towny.towns[town] = tbl
				towny.get_town_level(town, true)
			elseif scope == "region" then
				towny.regions.memloaded[town] = tbl
			elseif scope == "nation" and towny.nations then
				towny.nations.nations[town] = tbl
				towny.nations.get_nation_level(town, true)
			end
		end
	end
end

function towny.storage.delete_all_meta(town)
	if storage:get_string(town.."/meta") ~= "" then
		storage:set_string(town.."/meta", "")
	end

	if storage:get_string(town.."/region") ~= "" then
		storage:set_string(town.."/region", "")
	end

	if storage:get_string(town.."/nation") ~= "" then
		storage:set_string(town.."/nation", "")
	end
end
