
if towny.settings.storage_engine == "modstorage" then
	-- TODO: update modstorage.lua
	dofile(towny.modpath.."/storage/modstorage.lua")
-- TODO: remove support for flatfile
elseif towny.settings.storage_engine == "flatfile" then
	minetest.log("warning", "Using flatfile for towny storage is discouraged!")
	--dofile(towny.modpath.."/storage/flatfile.lua")

else
	error("Invalid storage engine for towny configured.")
end

minetest.register_on_mods_loaded(function ()

	print("[towny] Loading towny storage.")
	--print("[towny] Deleting storage.") towny.storage_delete()
	towny.storage_load()
end)

minetest.register_on_shutdown(function ()

	print("[towny] Saving towny memory to storage.")
	towny.storage_save()
end)

--[[ TODO:
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
