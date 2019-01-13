local tr = towny.regions.size
local th = towny.regions.height
local main_is_protected = minetest.is_protected

-- Test to see if a position is in a region
local function pos_in_region(pos, p1, p2)
	return (pos.x <= p1.x and pos.y <= p1.y and pos.z <= p1.z) and
		(pos.x >= p2.x and pos.y >= p2.y and pos.z >= p2.z)
end

local function region_equal(v1, v2)
	return (math.floor(v1.x) == math.floor(v2.x)) and 
		(math.floor(v1.y) == math.floor(v2.y)) and
		(math.floor(v1.z) == math.floor(v2.z))
end

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
	if name == towndata.mayor then
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

local function single_range(p)
	local p1,p2
	if p.x then
		p1 = p
		p2 = vector.subtract(p, {x=tr,y=th,z=tr})
	elseif #p == 2 then
		p1 = p[1]
		p2 = p[2]
	end
	return p1,p2
end

function towny.regions.get_town_at(pos)
	local in_town, in_plot, in_claim
	for town,regions in pairs(towny.regions.memloaded) do
		if in_town ~= nil then break end
		if vector.distance(pos, regions.origin) <= towny.regions.size * towny.regions.maxclaims then
			for _,tc in pairs(regions.blocks) do
				local p1,p2 = single_range(tc)
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

		if count and vector.distance(pos, regions.origin) <= towny.regions.size * towny.regions.maxclaims then
			for _,tc in pairs(regions.blocks) do
				local p1,p2 = single_range(tc)
				local center = vector.subtract(p1, {x=tr/2,y=th/2,z=tr/2})
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
	if distance > (tr + th) then return nil end -- Too far

	local new_pos
	local p1,p2 = closest_block[1],closest_block[2]

	-- X
	if (pos.z <= p1.z and pos.z >= p2.z) and (p1.y >= pos.y and p2.y <= pos.y) then
		if pos.x > p1.x then
			new_pos = vector.add(p1, {x=tr,y=0,z=0})
		else
			new_pos = vector.add(p1, {x=-tr,y=0,z=0})
		end
	-- Y
	elseif (pos.x <= p1.x and pos.x >= p2.x) and (pos.z <= p1.z and pos.z >= p2.z) then
		if pos.y > p1.y then
			new_pos = vector.add(p1, {x=0,y=th,z=0})
		else
			new_pos = vector.add(p1, {x=0,y=-th,z=0})
		end
	-- Z
	elseif (pos.x <= p1.x and pos.x >= p2.x) and (p1.y >= pos.y and p2.y <= pos.y) then
		if pos.z > p1.z then
			new_pos = vector.add(p1, {x=0,y=0,z=tr})
		else
			new_pos = vector.add(p1, {x=0,y=0,z=-tr})
		end
	end

	if new_pos == nil then return nil end -- Impossible position
	return new_pos,closest_town
end

function towny.regions.remove_claim(p1,town)
	local blocks = {}
	if not towny.regions.memloaded[town] then return false, "This town does not exist anymore." end
	for _,pos in pairs(towny.regions.memloaded[town].blocks) do
		if region_equal(p1, pos) and pos['plot'] and towny.towns[town].plots[pos['plot']] then
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

function towny.regions.visualize_town(town)
	if not towny.regions.memloaded[town] then return end
	for _,pos in pairs(towny.regions.memloaded[town].blocks) do
		local p1,p2 = single_range(pos)
		towny.regions.visualize_area(p1,p2)
	end
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

--[[if minetest.settings:get('towny_prevent_protector') == 'true' then
	minetest.register_on_placenode(function (pos, newnode, placer, oldnode, itemstack, pointed_thing)
		local town = towny.regions.get_town_at(pos)
		if not town return end
	end)
end]]
