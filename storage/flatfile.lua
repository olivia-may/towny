-- Flatfile storage engine
-- Not recommended

local extension = "lua"
local serialize = true

local function write_meta(town,dir,data)
	local world     = minetest.get_worldpath()
	local directory = world.."/towny/"..dir
	local filepath  = town.."."..extension
	minetest.mkdir(directory)

	data.dirty = nil
	data.level = nil

	local serialized
	if serialize then
		serialized = minetest.serialize(data)
	else
		serialized = minetest.write_json(data)
	end

	if not serialized then return end

	minetest.safe_file_write(directory.."/"..filepath, serialized)
end

local function load_meta(filepath)
	local file = io.open(filepath)
	
	if not file then
		return nil
	end

	local str = ""
	for line in file:lines() do
		str = str..line
	end

	file:close()

	local data
	if serialize then
		data = minetest.deserialize(str)
	else
		data = minetest.parse_json(str)
	end

	return data
end

function towny.storage.save_town_meta(town)
	local tmeta = towny.towns[town]
	if tmeta and tmeta.dirty then
		towny.get_town_level(town, true)
		minetest.after(0.1, function ()
			write_meta(town,"meta",tmeta)
			tmeta.dirty = false
		end)
	end

	local rmeta = towny.regions.memloaded[town]
	if rmeta and rmeta.dirty then
		minetest.after(0.2, function ()
			write_meta(town,"region",rmeta)
			rmeta.dirty = false
		end)
	end
end

local ldirs = { "meta", "region" }
function towny.storage.load_all_towns()
	local world   = minetest.get_worldpath()
	local metadir = world.."/towny/"..ldirs[1]
	minetest.mkdir(metadir)

	local metas = minetest.get_dir_list(metadir, false)
	for _,file in pairs(metas) do
		if file:match("."..extension.."$") then
			local town = file:gsub("."..extension,"")
			minetest.after(0.1, function ()
				local towndata = load_meta(metadir.."/"..file)
				if not towndata then return end
				towny.towns[town] = towndata
				towny.get_town_level(town, true)
			end)
		end
	end

	local regiondir = world.."/towny/"..ldirs[2]
	minetest.mkdir(regiondir)

	local regions = minetest.get_dir_list(regiondir, false)
	for _,file in pairs(regions) do
		if file:match("."..extension.."$") then
			local town = file:gsub("."..extension,"")
			minetest.after(0.1, function ()
				local regiondata = load_meta(regiondir.."/"..file)
				if not regiondata then return end
				towny.regions.memloaded[town] = regiondata
			end)
		end
	end
end

function towny.storage.delete_all_meta(town)
	local world = minetest.get_worldpath()
	local file  = town.."."..extension

	for _,d in pairs(ldirs) do
		local dir = world.."/towny/"..d
		local path = dir.."/"..file
		minetest.after(0.1, os.remove, path)
	end
end
