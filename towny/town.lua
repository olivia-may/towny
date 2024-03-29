-- town class constructor
function towny.town.new(player, town_name)
	
	local minetest_player_pos = player:get_pos()
	local towny_player_pos = minetest_player_pos:copy() 
	towny_player_pos.y = towny_player_pos.y + 2
	local res = towny.get_resident_by_name(player:get_player_name())

	--[[
	local is_towny_admin = minetest.check_player_privs(player_name, { towny_admin = true })
	
	local tn,__,distance = towny.regions.get_closest_town(pos)
	if tn and distance < 16 * towny.regions.distance and not towny_admin then
		return err_msg(player, "This location is too close to another town!")
	end

	if towny.get_town_by_name(name) and not towny_admin then
		return err_msg(player, "A town by this name already exists!")
	end

	if towny.eco.enabled and towny.eco.get_player_balance(player) < towny.eco.create_cost then
		return err_msg(player, string.format("You don't have enough %s to start a town! You need %s.",
			towny.eco.get_currency(), towny.eco.format_number(towny.eco.create_cost)))
	end
	]]--

	-- 16 is mapblock size, round down player_pos to nearest multiple of 16 and
	-- -0.5 to align to mapblock boundary
        
	local town = {}
	setmetatable(town, towny.town)

	towny.town_count = towny.town_count + 1
	towny.town_array[towny.town_count] = town
	
	towny.town_id_count = towny.town_id_count + 1
	town.id = towny.town_id_count

	local block = towny.block.new(towny_player_pos, town)
	block.is_town_center = true
	
	-- teleport pos
	town.pos = minetest_player_pos:copy()
	town.name = town_name

	town.member_count = town.member_count + 1
	town.member_array[town.member_count] = res
	
	res.town_id = town.id
	res.town = town
	res.is_mayor = true
	
	--[[
	if towny.regions.protection_mod(p1,p2) then
		return err_msg(player, "This area is protected by another protection mod! Please ensure that this is not the case.")
	end

	-- Remove money
	if towny.settings.eco_enabled then
		--towny.eco.charge_player(player, towny.eco.create_cost)
	end
	]]--
	
	towny.visualize_block(block)
	
	return town
end

function towny.get_town_by_id(town_id)

	local i
	for i = 1, towny.town_count do
		if towny.town_array[i].id == town_id then
			return towny.town_array[i]
		end
	end

	return nil
end

function towny.get_resident_by_name(player_name)
	for i, resident in ipairs(towny.resident_array) do
		if resident.name == player_name then
			return resident
		end
	end

	return nil
end

-- use the players head, not their feet.
function towny.get_player_pos(player)
	local pos = player:get_pos()
        pos.y = pos.y + 2
        return pos
end


function towny.visualize_town(res)
	for i = 1, res.town.block_count do
		towny.visualize_block(res.town.block_array[i], res.name)
	end
end

--[[
function towny.extend_town(player_pos, town)
	local data = towny.towns[town]
	if data.flags['mayor'] ~= player and data.members[player]['claim_create'] ~= true then
		return err_msg(player, "You do not have permission to spend claim blocks in your town.")
	end

	if towny.get_claims_available(town) < 1 then
		return err_msg(player, "You do not have enough remaining claim blocks!")
	end

	local p1,closest_town = towny.regions.align_new_claim_block(pos, player)
	if not p1 then
		return err_msg(player, "You cannot claim this area! Town blocks must be aligned side-by-side.")
	end

	if closest_town ~= town then
		return err_msg(player, "Something went wrong!")
	end

	local p1,p2 = towny.regions.ensure_range(p1)
	if towny.regions.protection_mod(p1,p2) then
		return err_msg(player, "This area is protected by another protection mod! Please ensure that this is not the case.")
	end

	towny.regions.visualize_area(p1,p2,pos)
end

function towny.abridge_town(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local data = towny.towns[town]
	if data.flags['mayor'] ~= player and data.members[player]['claim_delete'] ~= true and not towny_admin then
		return err_msg(player, "You do not have permission to delete claim blocks in your town.")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local success,message = towny.regions.remove_claim(c[1],t)
	if not success then
		return err_msg(player, "Failed to abandon claim block: " .. message)
	end

	minetest.chat_send_player(player, ("Successfully abandoned this claim block! You now have %d claim blocks available!")
		:format(towny.get_claims_available(town)))
	towny.mark_dirty(t, true)

	return true
end

function towny.leave_town(player,kick)
	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local data = towny.towns[town]
	if data.flags['mayor'] == player then
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

	local msg = "You successfully left the town."
	if kick then
		msg = "You were kicked form town."
	end

	towny.mark_dirty(town, false)
	minetest.chat_send_player(player, msg)
	return true
end

function towny.kick_member(town,player,member)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	local data = towny.towns[town]

	if data.flags['mayor'] ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to kick people from this town.")
	end

	if not data.members[member] then
		return err_msg(player, ("User %s is not in this town."):format(member))
	end

	if member == data.flags['mayor'] then
		return err_msg(player, "You cannot kick the town mayor.")
	end

	if player == member then
		return err_msg(player, "You cannot kick yourself from town.")
	end

	return towny.leave_town(member,true)
end

function towny.delete_town(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	if data.flags['mayor'] ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to delete this town.")
	end

	local name = towny.get_full_name(town) .. ""

	if towny.nations then
		local nat = towny.nations.get_town_nation(town)
		if nat then
			local ndata = towny.nations.nations[nat]
			if ndata.flags.capital == town then
				return err_msg(player, "You must delete or transfer ownership of your nation first.")
			else
				-- Leave nation
				ndata.members[town] = nil
				ndata.dirty = true
			end
		end
	end

	-- Wipe the town
	towny.towns[t] = nil
	towny.regions.memloaded[t] = nil
	towny.storage.delete_all_meta(t)

	minetest.chat_send_player(player, "Successfully deleted the town!")
	minetest.chat_send_all(("%s has fell into ruin."):format(name))
	return true
end

function towny.delete_plot(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town or not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	local plot_data = data.plots[p]
	if (data.flags['mayor'] ~= player and data.members[player]['plot_delete'] ~= true) and (plot_data.owner ~= player) and not towny_admin then
		return err_msg(player, "You do not have permission to delete this plot.")
	end

	towny.regions.set_plot(c[1],t,nil)
	data.plots[p] = nil
	towny.mark_dirty(t, true)

	minetest.chat_send_player(player, "Successfully removed the plot.")
	return true
end

function towny.create_plot(pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p ~= nil then
		return err_msg(player, "You cannot create a plot here!")
	end

	local data = towny.towns[t]
	if data.flags['mayor'] ~= player and data.members[player]['plot_create'] ~= true and not towny_admin then
		return err_msg(player, "You do not have permission to create plots in this town.")
	end

	local pid = minetest.sha1(minetest.hash_node_position(c[1]))

	local success,message = towny.regions.set_plot(c[1],t,pid)
	if not success then
		minetest.chat_send_player(player, "Failed to create a plot here: " .. message)
		return false
	end

	data.plots[pid] = {
		owner = player,
		members = {[player] = {}},
		flags = {},
	}
	towny.mark_dirty(t, true)

	minetest.chat_send_player(player, "Successfully created a plot!")
	towny.regions.visualize_area(c[1], c[2], pos)
	return true
end

function towny.claim_plot(pos,player)
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or t ~= town then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local tdata = towny.towns[t]
	if p ~= nil then
		local plot_data = tdata.plots[p]
		if plot_data.flags['claimable'] or player == tdata.flags['mayor'] then
			if plot_data.owner == player or plot_data.members[player] then
				return err_msg(player, "You are already a member of this plot.")
			end

			local cost = plot_data.flags["cost"] or 0
			if cost > 0 and towny.eco.enabled and towny.eco.get_player_balance(player) < cost then
				return err_msg(player, string.format("You don't have enough %s to claim this plot! You need %s.",
					towny.eco.get_currency(), towny.eco.format_number(cost)))
			end

			tdata.plots[p] = {
				owner = player,
				members = {[player] = {}},
				flags = {},
			}

			towny.mark_dirty(t, false)

			-- Remove money
			if towny.eco.enabled then
				towny.eco.charge_player(player, cost)
			end

			minetest.chat_send_player(player, "Successfully claimed the plot!")
			towny.regions.visualize_area(c[1], c[2], pos)

			return true
		else
			return err_msg(player, "This plot is not for sale.")
		end
	end

	return towny.create_plot(pos,player)
end

function towny.abandon_plot(pos,player)
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or t ~= town then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p == nil then
		return err_msg(player, "There is no plot here.")
	end

	local tdata = towny.towns[t]
	local pdata = tdata.plots[p]

	if not pdata.members[player] then
		return err_msg(player, "You are not a member of this plot.")
	end

	-- Update plot members
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
	towny.mark_dirty(t, false)
	minetest.chat_send_player(player, "Successfully abandoned the plot!")

	return true
end

function towny.plot_member(pos,player,member,action)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or t ~= town then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p == nil then
		return err_msg(player, "There is no plot here.")
	end

	local tdata = towny.towns[t]
	local pdata = tdata.plots[p]

	if pdata.owner ~= player and player ~= tdata.flags['mayor'] and not towny_admin then
		return err_msg(player, "You do not have permission to modify this plot.")
	end

	if not tdata.members[member] then
		return err_msg(player, ("User '%s' is not part of this town."):format(member))
	end

	-- Update plot members
	local members = {}
	local action_desc = "add yourself to"
	if action == 0 then
		action_desc = "remove yourself from"
	end

	if member == pdata.owner then
		return err_msg(player, ("You cannot %s from this plot."):format(action_desc))
	end

	if action == 0 then
		action_desc = ("removed %s from"):format(member)
		for mem,dat in pairs(pdata.members) do
			if mem ~= member then
				-- Transfer ownership to the first other member
				members[mem] = dat
			end
		end
	else
		action_desc = ("added %s to"):format(member)
		members = pdata.members
		members[member] = {}
	end

	pdata.members = members
	towny.mark_dirty(t, false)
	minetest.chat_send_player(player, ("Successfully %s plot!"):format(action_desc))

	return true
end

-- Set flags

function towny.set_plot_flags(pos,player,flag,value)
	if not flag then return false end
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p == nil then
		return err_msg(player, "There is no plot here! Please stand in the plot you wish to modify.")
	end

	local data = towny.towns[t]
	local plot_data = data.plots[p]
	if data.flags['mayor'] ~= player and plot_data.owner ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this plot.")
	end

	local fs,flag,res = towny.flag_validity(flag, 'plot', value, pos)
	if not fs then
		return err_msg(player, "Invalid flag or flag value.")
	end

	minetest.chat_send_player(player, ("Successfully set the plot flag '%s' to '%s'!"):format(flag, value))
	plot_data.flags[flag] = res
	towny.mark_dirty(t, false)
end

function towny.set_plot_member_flags(pos,player,member,flag,value)
	if not member or not flag then return false end
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	if p == nil then
		return err_msg(player, "There is no plot here! Please stand in the plot you wish to modify.")
	end

	local data = towny.towns[t]
	local plot_data = data.plots[p]
	if data.flags['mayor'] ~= player and plot_data.owner ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this plot.")
	end

	if not plot_data.members[member] then
		return err_msg(player, "There is no such member in this plot.")
	end

	local fs,flag,res = towny.flag_validity(flag, 'plot_member', value, pos)
	if not fs then
		return err_msg(player, "Invalid flag or flag value.")
	end

	minetest.chat_send_player(player, ("Successfully set the plot member %s's flag '%s' to '%s'!")
		:format(member, flag, value))
	plot_data.members[member][flag] = res
	towny.mark_dirty(t, false)
end

function towny.set_town_flags(pos,player,flag,value)
	if not flag then return false end
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data  = towny.towns[t]
	local mayor = data.flags['mayor']
	if mayor ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this town.")
	end

	local fs,flag,res = towny.flag_validity(flag, 'town', value, pos, data.members)
	if not fs then
		return err_msg(player, "Invalid flag or invalid or unchangeable flag value.")
	end

	-- Announce mayor change to all
	if flag == "mayor" and res ~= mayor then
		towny.chat.announce_to_members(town, ("The town mayor rights have been given to %s!"):format(res))
	end

	minetest.chat_send_player(player, ("Successfully set the town flag '%s' to '%s'!"):format(flag,value))
	data.flags[flag] = res
	towny.mark_dirty(t, false)
end

function towny.set_town_member_flags(pos,player,member,flag,value)
	if not member or not flag then return false end
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town and not towny_admin then
		return err_msg(player, "You're not currently in a town!")
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can modify.")
	end

	local data = towny.towns[t]
	if data.flags['mayor'] ~= player and not towny_admin then
		return err_msg(player, "You do not have permission to modify this town.")
	end

	if not data.members[member] then
		return err_msg(player, "There is no such member in this town.")
	end

	local fs,flag,res = towny.flag_validity(flag, 'town_member', value, pos)
	if not fs then
		return err_msg(player, "Invalid flag or flag value.")
	end

	minetest.chat_send_player(player, ("Successfully set the town member %s's flag '%s' to '%s'!")
		:format(member, flag, value))
	data.members[member][flag] = res
	towny.mark_dirty(t, false)
end

-- Getters

function towny.get_flags(town,plot)
	local tdata = towny.towns[town]
	if not tdata then return nil end
	if not plot then return tdata.flags end
	if not tdata.plots[plot] then return nil end
	return tdata.plots[plot].flags
end

function towny.get_plot_flags(town,pos,player)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos and player then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local t,p,c = towny.regions.get_town_at(pos)
	if not t or (t ~= town and not towny_admin) then
		return err_msg(player, "You are not in any town you can access.")
	end

	if not t or not p then return nil end
	return towny.get_flags(t,p)
end

-- Get used claim blocks
function towny.get_claims_used(town)
	if not towny.regions.memloaded[town] then return 0 end
	return #towny.regions.memloaded[town].blocks
end

-- Get maximum available claim blocks, including bonuses
function towny.get_claims_max(town)
	local tdata = towny.towns[town]
	if not tdata then return 0 end
	if not tdata.level then towny.get_town_level(town, true) end
	local bonus = 0

	if tdata.flags['claim_blocks'] and tdata.flags['claim_blocks'] > 0 then
		bonus = tdata.flags['claim_blocks']
	end

	if towny.nations then
		local n = towny.nations.get_town_nation(town)
		local ndata = towny.nations.nations[n]
		if n and ndata and ndata.level then
			bonus = bonus + ndata.level.block_bonus
		end
	end

	return tdata.level.claimblocks + bonus, tdata.level.claimblocks, bonus
end

-- Get available claim blocks
function towny.get_claims_available(town)
	local used = towny.get_claims_used(town)
	local max  = towny.get_claims_max(town)
	return max - used
end

function towny.get_member_count(town)
	local tdata = towny.towns[town]
	if not tdata then return nil end
	return count(tdata.members)
end

function towny.get_full_name(town)
	local tdata = towny.towns[town]
	if not tdata then return nil end
	if not tdata.level then return tdata.name end
	return ("%s (%s)"):format(tdata.name, tdata.level.name_tag)
end

function towny.get_player_name(player)
	local town = towny.get_player_town(player)
	local tdata = towny.towns[town]
	if not tdata then return player end
	if not tdata.level then return player end
	if towny.nations and tdata.flags.mayor == player then
		local n = towny.nations.get_town_nation(town)
		if n then
			local name = towny.nations.get_player_name(n,player)
			if name then
				return name
			end
		end
	end
	return ("%s %s"):format(tdata.level.mayor_tag, player)
end

function towny.get_town_level(town, update)
	local tdata = towny.towns[town]
	if not tdata then return nil end
	if tdata.level and not update then return tdata.level end
	local lvl
	for _,describe in pairs(towny.levels) do
		if count(tdata.members) >= describe.members then
			lvl = describe
		end
	end
	tdata.level = lvl
	return lvl
end

minetest.register_on_joinplayer(function (player)
	local town = towny.get_player_town(player:get_player_name())
	if not town then return end

	local tdata = towny.towns[town]
	if not tdata then return nil end
	if not tdata.flags["greeting"] then return nil end

	minetest.chat_send_player(player:get_player_name(),
		minetest.colorize("#078e36", ("[%s] "):format(towny.get_full_name(town))) ..
		minetest.colorize("#02aacc", tdata.flags["greeting"]))
end)
]]--

minetest.register_on_joinplayer(function(player)
	if not towny.get_resident_by_name(player:get_player_name()) then
		towny.resident.new(player)
	end
end)
