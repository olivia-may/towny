
local tr = towny.regions.size
local function in_table(tbl, str)
	for _,s in pairs(tbl) do
		if s == str then
			return true
		end
	end
	return false
end

local function err_msg(player, msg)
	minetest.chat_send_player(player, minetest.colorize("#ff1111", msg))
	return false
end

function towny:get_player_town(name)
	for town,data in pairs(towny.towns) do
		if data.mayor == name then
			return town
		elseif in_table(data.members, name) then
			return town
		end
	end
	return nil
end

function towny:get_town_by_name(name)
	for town,data in pairs(towny.towns) do
		if data.name.lower() == name.lower() then
			return town
		end
	end
	return nil
end

function towny:create_town(pos, player, name)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	if towny:get_player_town(player) then
		return err_msg(player, "You're already in a town! Please leave your current town before founding a new one!")
	end

	local _,__,distance = towny.regions:get_closest_town(pos)
	if distance > towny.regions.distance * towny.regions.size and not towny_admin then
		return err_msg(player, "This location is too close to another town!")
	end

	if towny:get_town_by_name(name) and not towny_admin then
		return err_msg(player, "A town by this name already exists!")
	end

	-- TODO: Economy

	-- New town information
	local p1 = vector.add(pos, {x=tr / 2,y=tr - 1,z=tr / 2})
	local p2 = vector.subtract(pos, {x=tr / 2,y=1,z=tr / 2})
	local id = minetest.hash_node_position(pos)
	local data = {
		name = name,
		mayor = player,
		members = {
			[player] = {["town_build"] = true, ["plot_build"] = true}
		},
		plots = {},
		flags = {
			origin = pos,
			claim_blocks = towny.claimbonus,
			plot_member_build = true,
		}
	}

	local regions = {
		origin = pos,
		blocks = {
			{ x=p1.x, y=p1.y, z=p1.z, origin = true }
		}
	}

	towny.towns[id] = data
	towny.regions.memloaded[id] = regions
	towny.dirty = true

	minetest.chat_send_player(player, "Your town has successfully been founded!")
	minetest.chat_send_all(player .. " has started a new town called '" .. name .. "'!")

	towny.regions:visualize_area(p1,p2)

	return true
end

function towny:extend_town(pos,player)
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local data = towny.towns[town]
	if data.mayor ~= player and data.members[player]['claim_create'] ~= true then
		return err_msg(player, "You do not have permission to spend claim blocks in your town.")
	end

	if data.flags["claim_blocks"] < 1 then
		return err_msg(player, "You do not have enough remaining claim blocks!")
	end

	local p1,closest_town = towny.regions:align_new_claim_block(pos, player)
	if not p1 then
		return err_msg(player, "You cannot claim this area! Town blocks must be aligned side-by-side.")
	end

	if towny.regions:town_claim_exists(town,p1) then
		return err_msg(player, "This area is already claimed.")
	end

	if closest_town ~= town then
		return err_msg(player, "Something went wrong!")
	end

	table.insert(towny.regions.memloaded[town].blocks, p1)
	data.flags["claim_blocks"] = data.flags["claim_blocks"] - 1
	minetest.chat_send_player(player, "Successfully claimed this block!")
	towny.dirty = true

	towny.regions:visualize_radius(vector.subtract(p1, {x=tr/2,y=tr/2,z=tr/2}))
	return true
end

function towny:abridge_town(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local data = towny.towns[town]
	if data.mayor ~= player and data.members[player]['claim_delete'] ~= true and not towny_admin then
		return err_msg(player, "You do not have permission to delete claim blocks in your town.")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local success,message = towny.regions:remove_claim(c,t)
	if not success then
		return err_msg(player, "Failed to abandon claim block: " .. message)
	end

	table.insert(towny.regions.memloaded[t].blocks, p1)
	data.flags["claim_blocks"] = data.flags["claim_blocks"] + 1
	minetest.chat_send_player(player, "Successfully abandoned this claim block!")
	towny.dirty = true

	return true
end

function towny:leave_town(player)
	local town = towny:get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local data = towny.towns[town]
	if data.mayor == player then
		return err_msg(player, "You cannot abandon a town that you own! Either delete the town or transfer mayorship.")
	end

	-- Update town members
	local members = {}
	for member,mdata in pairs(data.members) do
		if member ~= player then
			members[member] = mdata
		end
	end
	data.members = members

	-- Update plot members
	for plotid,pdata in pairs(data.plots) do
		local members = {}
		if pdata.owner == player then
			pdata.owner = nil
			if pdata.flags["greeting"] ~= nil then
				pdata.flags["greeting"] = nil
			end
		end

		for mem,dat in pairs(pdata.members) do
			if mem ~= player then
				-- Transfer ownership to the first other member
				if pdata.owner == nil then
					pdata.owner = mem
				end
				members[mem] = dat
			end
		end
		pdata.members = members
	end

	towny.dirty = true
	minetest.chat_send_player(player, "You successfully left the town.")
	return true
end

function towny:delete_town(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	if data.mayor ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to delete this town.")
	end

	local name = data.name .. ""

	-- Wipe the town
	towny.towns[t] = nil
	towny.regions.memloaded[t] = nil
	towny.dirty = true

	minetest.chat_send_player(player, "Successfully deleted the town!")
	minetest.chat_send_all("The town '" .. name .. "' has fell into ruin.")
	return true
end

function towny:delete_plot(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town or not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	local plot_data = data.plots[p]
	if (data.mayor ~= player and data.members[player]['plot_delete'] ~= true) and (plot_data.owner ~= player) and not towny_admin then
		return err_msg(player, "You do not have permission to delete this plot.")
	end

	towny.regions:set_plot(c,t,nil)
	data.plots[p] = nil
	towny.dirty = true

	minetest.chat_send_player(player, "Successfully removed the plot.")
	return true
end

function towny:create_plot(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p ~= nil then
		return err_msg(player, "You cannot create a plot here!")
	end

	local data = towny.towns[t]
	if data.mayor ~= player and data.members[player]['plot_create'] ~= true and not towny_admin then
		return err_msg(player, "You do not have permission to create plots in this town.")
	end

	local pid = minetest.hash_node_position(c)

	local success,message = towny.regions:set_plot(c,t,pid)
	if not success then
		minetest.chat_send_player(player, "Failed to create a plot here: " .. message)
		return false
	end

	data.plots[pid] = {
		owner = player,
		members = {[player] = {}},
		flags = {},
	}
	towny.dirty = true

	minetest.chat_send_player(player, "Successfully created a plot!")
	towny.regions:visualize_radius(vector.subtract(c, {x=tr/2,y=tr/2,z=tr/2}))
	return true
end

function towny:set_plot_flags(pos,player,flag,value)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p ~= nil then
		return err_msg(player, "There is no plot here! Please stand in the plot you wish to modify.")
	end

	local data = towny.towns[t]
	local plot_data = data.plots[p]
	if data.mayor ~= player and plot_data.owner ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this plot.")
	end

	minetest.chat_send_player(player, "Successfully set the plot flag '" .. flag .."' to '" .. value .. "'!")
	if type(value) == "string" and minetest.string_to_pos(value) then
		value = minetest.string_to_pos(value)
	end
	plot_data.flags[flag] = value
end

function towny:set_town_flags(pos,player,flag,value)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny:get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions:get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	if data.mayor ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this town.")
	end

	if (flag == 'bank' or flag == 'claim_blocks' or flag == 'origin') and not towny_admin then
		return err_msg(player, "You cannot change this flag.")
	end

	minetest.chat_send_player(player, "Successfully set the town flag '" .. flag .."' to '" .. value .. "'!")
	if type(value) == "string" and minetest.string_to_pos(value) then
		value = minetest.string_to_pos(value)
	end
	data.flags[flag] = value
end

function towny:get_claims_total(town)
	if not towny.regions.memloaded[town] then return 0 end
	return #towny.regions.memloaded[town].blocks
end
