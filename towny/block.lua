local modareas = minetest.get_modpath("areas") ~= nil

--local main_is_protected = minetest.is_protected

-- block class constructor
function towny.block.new(pos, town)
	
	local block = {}
	setmetatable(block, towny.block)

	town.block_count = town.block_count + 1
	town.block_array[town.block_count] = block

	town.block_id_count = town.block_id_count + 1
	block.id = town.block_id_count

	block.blockpos = vector.new(math.floor(pos.x / 16),
		math.floor(pos.y / 16),
		math.floor(pos.z / 16))
	block.pos_min = vector.new(block.blockpos.x * 16,
		block.blockpos.y * 16,
		block.blockpos.z * 16)
	block.pos_max = vector.add(block.pos_min, 15)
	
	block.town_id = town.id
	block.town = town

	block.perm_build = towny.NO_PERMS
	block.perm_destroy = towny.NO_PERMS
	block.perm_switch = towny.NO_PERMS
	block.perm_itemuse = towny.NO_PERMS

	return block
end

-- block class constructor for when storage is loaded
function towny.block.new_from_data(data)

	local block = {}
	setmetatable(block, towny.block)
	
	block.id = data.id
	block.name = data.name
	block.town_id = data.town_id
	--block.is_plotted = data.is_plotted
	--block.plot_id = data.plot_id
	block.is_town_center = data.is_town_center
	block.blockpos = towny.convert_to_vector(data.blockpos)
	block.pos_min = towny.convert_to_vector(data.pos_min)
	block.pos_max = towny.convert_to_vector(data.pos_max)
	block.perm_build = data.perm_build
	block.perm_destroy = data.perm_destroy
	block.perm_switch = data.perm_switch
	block.perm_itemuse = data.perm_itemuse

	return block
end

-- block class destructor
function towny.block:delete()

	towny.array_remove(self.town.block_array, self.town.block_count, self.id)
	self.town.block_count = self.town.block_count - 1
	towny.storage:set_string("block " .. self.town_id .. " " .. self.id, "")
	self = nil
end

-- Visualize a block
function towny.visualize_block(block, player_name)
	
	local i
	for i = 0, 15 do
	
		-- sides
		
		minetest.add_particle({
			pos = vector.add(
				block.pos_min,
				vector.new(0, i, 0)
			),
			expirationtime = 10,
			size = 10,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		minetest.add_particle({
			pos = vector.add(
				vector.new(block.pos_max.x, block.pos_min.y, block.pos_min.z),
				vector.new(0, i, 0)
			),
			expirationtime = 10,
			size = 10,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		minetest.add_particle({
			pos = vector.add(
				vector.new(block.pos_max.x, block.pos_min.y, block.pos_max.z),
				vector.new(0, i, 0)
			),
			expirationtime = 10,
			size = 10,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
		minetest.add_particle({
			pos = vector.add(
				vector.new(block.pos_min.x, block.pos_min.y, block.pos_max.z),
				vector.new(0, i, 0)
			),
			expirationtime = 10,
			size = 10,
			texture = "towny_block_visual.png",
			playername = player_name,
		})
	end
end

-- Test to see if a position is in a block, return block
function towny.get_block_by_pos(pos)

	local block
	local town
	
	for i = 1, towny.town_count do
		town = towny.town_array[i]

		for j = 1, town.block_count do
			block = town.block_array[j]
			if pos.x > block.pos_min.x and 
				pos.x < block.pos_max.x and
				pos.y > block.pos_min.y and 
				pos.y < block.pos_max.y and
				pos.z > block.pos_min.z and 
				pos.z < block.pos_max.z then

				return block
			end
		end
	end

	return nil
end

-- Find any conflicts with protection mods
-- Do not allow placement of towns in any areas-protected regions, no matter if the user has
-- build permission there or not.
function towny.is_protected(pos, player_name)
	--if not protprev then return false end
	
	local block = towny.get_block_by_pos(pos)

	if block then return true end

	if modareas then
		if #areas:getAreasIntersectingArea(
			table.copy(block.pos_min), table.copy(block.pos_max)) > 0 then
			
			return true
		end
	end

	if minetest.is_protected(pos, player_name) then return false end


	-- Clear of any other protections
	return false
end

--[[
-- Test to see if there's already a protected node in a region
function towny.regions.already_protected(p1, p2, name)
	local found = false
	for x = p1.x, p2.x do
		if found then break end
		for y = p1.y, p2.y do
			if found then break end
			for z = p1.z, p2.z do
				if main_is_protected({x=x,y=y,z=z}, name) then
					found = true
					break
				end
			end
		end
	end
	return found
end

function towny.regions.build_perms(town, name, plotid)
	if not towny.towns[town] then return true end -- Can build here, this town doesnt even exist
	local towndata = towny.towns[town]

	-- Owner of the town can always build where they want in their town
	if name == towndata.flags['mayor'] then
		return true
	end

	-- Not even a town member, can't build here!
	if not towndata.members[name] then return false end

	-- Plot build rights
	if plotid and towndata.plots[plotid] then
		-- This flag dictates that this member can build in all town plots, no matter if they own it or not
		if towndata.members[name]['plot_build'] == true then return true end

		local plot = towndata.plots[plotid]

		-- This flag dictates that all members can build in unowned town plots
		if not plot.owner and not towndata.flags['plot_build'] == true then return true end

		-- Plot owner can always build in their plot
		if name == plot.owner then return true end
		if plot.members[name] then
			if towndata.flags['plot_member_build'] == false then
				return plot.members[name]['plot_build']
			else
				return plot.members[name]['plot_build'] ~= false
			end
		end
	else
		-- This flag dictates that all members can build in unplotted town claims
		if towndata.flags['town_build'] == true then return true end

		-- If this member has access to building in any town claims, let them
		if towndata.members[name]['town_build'] == true then return true end
	end

	return false
end

-- Ensure double coordinates for a range
function towny.regions.ensure_range(p)
	local p1,p2
	if p.x then
		p1 = p
                -- 16 is mapblock size
		p2 = vector.subtract(p, {x=16,y=16,z=16})
	elseif #p == 2 then
		p1 = p[1]
		p2 = p[2]
	end

	return p1,p2
end

function towny.get_town_by_pos(pos)
	local in_town, in_plot, in_claim
	for town,regions in pairs(towny.regions.memloaded) do
		if in_town ~= nil then break end
                -- 16 is mapblock size
		if vector.distance(pos, regions.origin) <= 16 * 448 then
			for _,tc in pairs(regions.blocks) do
				local p1,p2 = towny.regions.ensure_range(tc)
				if pos_in_region(pos,p1,p2) then
					in_town = town
					in_claim = {p1,p2}
					if tc.plot then
						in_plot = tc.plot
					end
					break
				end
			end
		end
	end
	return in_town,in_plot,in_claim
end

function towny.regions.get_closest_town(pos,name)
	local in_town,block
	local last_distance = 0
	for town,regions in pairs(towny.regions.memloaded) do
		local count = true

		if name then
			count = towny.regions.build_perms(town, name, nil)
		end

                -- 16 is mapblock size
		if count and vector.distance(pos, regions.origin) <= 16 * 448 then
			for _,tc in pairs(regions.blocks) do
				local p1,p2 = towny.regions.ensure_range(tc)
				local center = vector.subtract(p1, {x=8,y=8,z=8})

				local dist = vector.distance(pos, center)
				if dist < last_distance or last_distance == 0 then
					last_distance = dist
					in_town = town
					block = {p1,p2}
				end
			end
		end
	end
	return in_town,block,last_distance
end

function towny.regions.town_claim_exists(town,p1)
	if not towny.regions.memloaded[town] then return false end
	local blocks = towny.regions.memloaded[town].blocks
	for _,pos in pairs(blocks) do
		if region_equal(p1, pos) then return true end
	end
	return false
end

function towny.regions.align_new_claim_block(pos,name)
	local closest_town,closest_block,distance = towny.regions.get_closest_town(pos,name)
	if not closest_town then return nil end
	if distance > (32) then return nil end -- Too far

	local new_pos
	local p1,p2 = closest_block[1],closest_block[2]

	-- 16 is mapblock size
	-- X
	if (pos.z <= p1.z and pos.z >= p2.z) and (p1.y >= pos.y and p2.y <= pos.y) then
		if pos.x > p1.x then
			new_pos = vector.add(p1, {x=16,y=0,z=0})
		else
			new_pos = vector.add(p1, {x=-16,y=0,z=0})
		end
	-- Y
	elseif (pos.x <= p1.x and pos.x >= p2.x) and (pos.z <= p1.z and pos.z >= p2.z) then
		if pos.y > p1.y then
			new_pos = vector.add(p1, {x=0,y=16,z=0})
		elseif pos.y < p2.y then
			new_pos = vector.add(p1, {x=0,y=-16,z=0})
		end
	-- Z
	elseif (pos.x <= p1.x and pos.x >= p2.x) and (p1.y >= pos.y and p2.y <= pos.y) then
		if pos.z > p1.z then
			new_pos = vector.add(p1, {x=0,y=0,z=16})
		else
			new_pos = vector.add(p1, {x=0,y=0,z=-16})
		end
	end

	if new_pos == nil then return nil end -- Impossible position
	return new_pos,closest_town
end

function towny.regions.remove_claim(p1,town)
	local blocks = {}
	if not towny.regions.memloaded[town] then return false, "This town does not exist anymore." end
	for _,pos in pairs(towny.regions.memloaded[town].blocks) do
		if region_equal(p1, pos) and pos['plot'] and towny.towns[town].plots[pos['plot'] ] then
			return false, "This town claim defines a plot. Please remove the plot before removing the claim!"
		elseif region_equal(p1, pos) and pos['origin'] == true then
			return false, "This town claim is the origin of this town!"
		elseif not region_equal(p1, pos) then
			table.insert(blocks, pos)
		end
	end

	towny.regions.memloaded[town].blocks = blocks
	return true
end

function towny.regions.set_plot(pos,town,plot)
	if not towny.regions.memloaded[town] then return false, "This town does not exist anymore." end
	for _,block in pairs(towny.regions.memloaded[town].blocks) do
		if region_equal(block, pos) then
			block['plot'] = plot
			break
		end
	end
	return true
end

function towny.regions.position_protected_from(pos, name)
	local town,plot = towny.regions.get_town_at(pos)
	if not town then return false end

	return not towny.regions.build_perms(town, name, plot)
end

-- Finally, override is_protected
function minetest.is_protected(pos, name)
	local bt = towny.regions.position_protected_from(pos, name)
	if bt ~= false then
		return true
	end

	return main_is_protected(pos, name)
end
]]--
