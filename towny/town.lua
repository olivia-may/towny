local tr = towny.regions.size
local th = towny.regions.height

local function err_msg(player, msg)
	minetest.chat_send_player(player, minetest.colorize("#ff1111", msg))
	return false
end

local function count(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

local function flag_typeify(value,pos)
	if type(value) == "string" then
		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif value == "here" and pos then
			value = pos
		elseif value == "none" or value == "null" or value == "nil" then
			value = nil
		elseif tonumber(value) ~= nil then
			value = tonumber(value)
		elseif minetest.string_to_pos(value) ~= nil then
			value = minetest.string_to_pos(value)
		end
	end
	return value
end

local function flag_validity(flag,scope,value,pos,members)
	value = flag_typeify(value,pos)
	local spd = towny.flags[scope]
	if type(spd[flag]) == "string" then
		flag = spd[flag]
	end

	if not spd[flag] then return false end
	if spd[flag][3] == false then return false end
	local flgtype = spd[flag][1]

	if flgtype == "member" and (members and not members[tostring(value)]) then
		return false
	elseif flgtype == "member" and value == nil then
		return false
	elseif flgtype == "vector" and (value and (not value.x or not value.y or not value.z)) then
		return false
	elseif (flgtype == "string" or flgtype == "number") and type(value) ~= flgtype then
		return false
	end

	return true, flag, value
end

function towny.get_player_town(name)
	for town,data in pairs(towny.towns) do
		if data.flags['mayor'] == name then
			return town
		elseif data.members[name] then
			return town
		end
	end
	return nil
end

function towny.get_town_by_name(name)
	if not name then return nil end
	for town,data in pairs(towny.towns) do
		if data.name:lower() == name:lower() then
			return town
		end
	end
	return nil
end

function towny.mark_dirty(town, areas)
	towny.dirty = true
	towny.towns[town].dirty = true
	if areas and towny.regions.memloaded[town] then
		towny.regions.memloaded[town].dirty = true
	end
end

function towny.create_town(pos, player, name)
	local towny_admin = minetest.check_player_privs(player, { towny_admin = true })
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	if towny.get_player_town(player) then
		return err_msg(player, "You're already in a town! Please leave your current town before founding a new one!")
	end

	local _,__,distance = towny.regions.get_closest_town(pos)
	if distance > towny.regions.distance * towny.regions.size and not towny_admin then
		return err_msg(player, "This location is too close to another town!")
	end

	if towny.get_town_by_name(name) and not towny_admin then
		return err_msg(player, "A town by this name already exists!")
	end

	-- TODO: Economy

	-- New town information
	local p1 = vector.add(pos, {x=tr / 2,y=th - 1,z=tr / 2})
	local p2 = vector.subtract(pos, {x=tr / 2,y=1,z=tr / 2})
	local id = minetest.sha1(minetest.hash_node_position(pos))
	local data = {
		name = name,
		members = {
			[player] = {}
		},
		plots = {},
		flags = {
			mayor = player,
			origin = pos,
			claim_blocks = towny.claimbonus,
			plot_member_build = true
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
	towny.mark_dirty(id, true)

	minetest.chat_send_player(player, "Your town has successfully been founded!")
	minetest.chat_send_all(("%s has started a new town called '%s'!"):format(player,name))

	towny.regions.visualize_area(p1,p2)

	return true
end

function towny.extend_town(pos,player)
	if not pos then
		pos = minetest.get_player_by_name(player):get_pos()
	end

	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

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

	if towny.regions.town_claim_exists(town,p1) then
		return err_msg(player, "This area is already claimed.")
	end

	if closest_town ~= town then
		return err_msg(player, "Something went wrong!")
	end

	table.insert(towny.regions.memloaded[town].blocks, p1)
	minetest.chat_send_player(player, ("Successfully claimed this block! You have %d claim blocks left!"):format(towny.get_claims_available(town)))
	towny.mark_dirty(town, true)

	local p1,p2 = towny.regions.ensure_range(p1)
	towny.regions.visualize_area(p1,p2)
	return true
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

	local name = data.name .. ""

	-- Wipe the town
	towny.towns[t] = nil
	towny.regions.memloaded[t] = nil
	towny.storage.delete_all_meta(t)

	minetest.chat_send_player(player, "Successfully deleted the town!")
	minetest.chat_send_all(("The town '%s' has fell into ruin."):format(name))
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
	towny.regions.visualize_area(c[1], c[2])
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

			-- TODO: enconomy
			tdata.plots[p] = {
				owner = player,
				members = {[player] = {}},
				flags = {},
			}

			towny.mark_dirty(t, false)

			minetest.chat_send_player(player, "Successfully claimed the plot!")
			towny.regions.visualize_area(c[1], c[2])

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

	local fs,flag,res = flag_validity(flag, 'plot', value, pos)
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

	local fs,flag,res = flag_validity(flag, 'plot_member', value, pos)
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

	local fs,flag,res = flag_validity(flag, 'town', value, pos, data.members)
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

	local fs,flag,res = flag_validity(flag, 'town_member', value, pos)
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
