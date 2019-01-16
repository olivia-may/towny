-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())

-- This code is borrowed from [areas] by ShadowNinja

local function towns_at_pos(pos, areas)
	if not areas then areas = {} end
	local t,p,c = towny.regions.get_town_at(pos)

	if t then
		if towny.nations then
			local n = towny.nations.get_town_nation(t)
			if n then
				table.insert(areas, { name = towny.nations.get_full_name(n) })
			end
		end

		local town = towny.get_full_name(t)
		local tdata = towny.towns[t]
		local greeting = ""
		if tdata.flags.greeting then
			greeting = "- "..tdata.flags.greeting
		end
		table.insert(areas, { name = ("%s %s"):format(town, greeting) })

		if p then
			local plot = tdata.plots[p]
			local greeting = ("%s's Plot"):format(plot.owner)

			if plot.flags['greeting'] then
				greeting = ("%s (%s)"):format(plot.flags['greeting'], plot.owner)
			end

			-- Override unowned plot greeting
			if not plot.owner then
				greeting = "Unowned Plot"
			end

			if plot.flags['claimable'] then
				if plot.flags['cost'] and plot.flags['cost'] > 0 then
					-- TODO: economy
				end
				greeting = greeting .. " (For sale: FREE!)"
			end

			table.insert(areas, { name = ("%s - %s"):format(town, greeting) })
		end
	end
	
	return areas
end

if minetest.get_modpath("areas") ~= nil then
	areas:registerHudHandler(towns_at_pos)
else
	towny.hud = {}
	minetest.register_globalstep(function(dtime)
		for _, player in pairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			local pos = vector.round(player:getpos())
			local areaStrings = {}

			for i,town in pairs(towns_at_pos(pos)) do
				table.insert(areaStrings, town.name)
			end

			local areaString = "Towns:"
			if #areaStrings > 0 then
				areaString = areaString.."\n"..
					table.concat(areaStrings, "\n")
			end
			local hud = towny.hud[name]
			if not hud then
				hud = {}
				towny.hud[name] = hud
				hud.areasId = player:hud_add({
					hud_elem_type = "text",
					name = "Towns",
					number = 0xFFFFFF,
					position = {x=0, y=1},
					offset = {x=8, y=-8},
					text = areaString,
					scale = {x=200, y=60},
					alignment = {x=1, y=-1},
				})
				hud.oldAreas = areaString
				return
			elseif hud.oldAreas ~= areaString then
				player:hud_change(hud.areasId, "text", areaString)
				hud.oldAreas = areaString
			end
		end
	end)

	minetest.register_on_leaveplayer(function(player)
		towny.hud[player:get_player_name()] = nil
	end)
end
