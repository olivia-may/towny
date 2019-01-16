
local setting = minetest.settings:get("towny_storage_engine") or "modstorage"
if setting == "modstorage" or setting == "flatfile" then
	if setting == "flatfile" then
		minetest.log("warning", "Using flatfile for towny storage is discouraged!")
	end

	dofile(towny.modpath.."/storage/"..setting..".lua")
else
	error("Invalid storage engine for towny configured.")
end

local clock = 0
local saving = false
local function carrier_tick()
	if not towny.dirty or saving then return end
	saving = true

	for town,data in pairs(towny.towns) do
		if data.dirty then
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

-- Register
minetest.register_globalstep(function (dt)
	clock = clock + (dt + 1)
	if clock >= 60 then
		carrier_tick()
		clock = 0
	end
end)

minetest.after(0.1, function ()
	towny.storage.load_all_towns()
end)
