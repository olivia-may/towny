
local function err_msg(player, msg)
	minetest.chat_send_player(player, minetest.colorize("#ff1111", msg))
	return false
end

local function count(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

local function mark_dirty(nation)
	towny.dirty = true
	towny.nations.nations[nation].dirty = true
end

function towny.nations.get_nation_by_name(name)
	if not name then return nil end
	for town,data in pairs(towny.nations.nations) do
		if data.name:lower() == name:lower() then
			return town
		end
	end
	return nil
end

function towny.nations.get_town_nation(town)
	if not town or not towny.towns[town] then return nil end
	for tid,data in pairs(towny.nations.nations) do
		if data.flags.capital == town or data.members[town] then
			return tid
		end
	end
	return nil
end

function towny.nations.create_nation(name,player)
	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local tdata = towny.towns[town]
	if tdata.flags['mayor'] ~= player then
		return err_msg(player, "Only the town mayor can create a nation!")
	end

	if towny.nations.get_town_nation(town) then
		return err_msg(player, "You're already part of a nation!")
	end

	if towny.nations.get_nation_by_name(name) then
		return err_msg(player, "A nation by that name already exists!")
	end

	-- TODO: economy

	local vertpos = {x = math.random(-999,999), y = math.random(-999,999), z = math.random(-999,999)}
	local nid = minetest.sha1(minetest.hash_node_position(vertpos))

	towny.nations.nations[nid] = {
		name    = name,
		members = {[town] = {}},
		flags   = {capital = town},
		allies  = {},
		enemies = {},
	}

	mark_dirty(nid)

	minetest.chat_send_player(player, "Your nation has successfully been founded!")
	minetest.chat_send_all(("%s has started a new nation called '%s'!"):format(player,name))

	return true
end

function towny.nations.leave_nation(player)
	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local tdata = towny.towns[town]
	if tdata.flags['mayor'] ~= player then
		return err_msg(player, "Only the town mayor can leave the nation!")
	end

	local nation = towny.nations.get_town_nation(town)
	local ndata  = towny.nations.nations[nation]
	if not nation or not ndata then
		return err_msg(player, "Your town is currently not part of any nation!")
	end

	if ndata.flags['capital'] == town and count(ndata.members) > 1 then
		return err_msg(player, "Your nation contains more than one member towns! Please remove the towns or change the capital before deleting your nation.")
	end

	if ndata.flags['capital'] == town and count(ndata.members) <= 1 then
		-- Single member town, delete nation
		local name = towny.nations.get_full_name(nation)
		towny.storage.delete_all_meta(nation)
		towny.nations.nations[nation] = nil
		minetest.chat_send_player(player, "Successfully deleted the nation!")
		minetest.chat_send_all(("%s has fallen."):format(name))
	else
		-- Simply leave
		minetest.chat_send_player(player, "Successfully left the nation!")
		towny.nations.nations[nation].members[town] = nil
		towny.nations.announce_to_members(nation, ("%s has left the nation."):format(towny.get_full_name(town)))
		mark_dirty(nation)
	end

	return true
end

function towny.nations.set_nation_flags(player,flag,value)
	if not flag then return false end

	local town = towny.get_player_town(player)
	if not town then
		return err_msg(player, "You're not currently in a town!")
	end

	local nation = towny.nations.get_town_nation(town)
	local ndata  = towny.nations.nations[nation]
	local tdata  = towny.towns[town]
	if not nation or not ndata then
		return err_msg(player, "Your town is currently not part of any nation!")
	end
	
	if ndata.flags.capital ~= town or tdata.flags.mayor ~= player then
		return err_msg(player, "You do not have permission to modify this nation.")
	end

	local val_pass = value
	if flag == "capital" then
		val_pass = towny.get_town_by_name(value)
	end

	local fs,flag,res = towny.flag_validity(flag, 'nation', val_pass, nil, ndata.members)
	if not fs then
		return err_msg(player, "Invalid flag or invalid or unchangeable flag value.")
	end

	-- Announce capital change to all
	if flag == "capital" and res ~= town then
		towny.nations.announce_to_members(nation, ("The nation's capital has been changed to %s!"):format(towny.get_full_name(res)))
	end

	minetest.chat_send_player(player, ("Successfully set the nation flag '%s' to '%s'!"):format(flag,value))
	ndata.flags[flag] = res
	mark_dirty(nation)
end

function towny.nations.kick_town(town,player)
	local mytown = towny.get_player_town(player)
	if not mytown then
		return err_msg(player, "You're not currently in a town!")
	end

	local nation = towny.nations.get_town_nation(mytown)
	local ndata  = towny.nations.nations[nation]
	local tdata  = towny.towns[mytown]
	if not nation or not ndata then
		return err_msg(player, "Your town is currently not part of any nation!")
	end
	
	if ndata.flags.capital ~= mytown or tdata.flags.mayor ~= player then
		return err_msg(player, "You do not have permission to modify this nation.")
	end

	if not ndata.members[town] then
		return err_msg(player, "There is no such town in your nation.")
	end

	if town == ndata.flags['capital'] then
		return err_msg(player, "You cannot kick your own town from your own nation.")
	end

	ndata.members[town] = nil

	minetest.chat_send_player(player, "Successfully kicked the town from the nation!")
	towny.nations.announce_to_members(nation, ("%s has been kicked from the nation."):format(towny.get_full_name(town)))
	towny.chat.announce_to_members(town, "Your town was kicked from the nation.")

	mark_dirty(nation)

	return true
end

function towny.nations.get_nation_level(nation, update)
	local ndata = towny.nations.nations[nation]
	if not ndata then return nil end
	if ndata.level and not update then return ndata.level end
	local lvl
	for _,describe in pairs(towny.nations.levels) do
		if count(ndata.members) >= describe.members then
			lvl = describe
		end
	end
	ndata.level = lvl
	return lvl
end

function towny.nations.get_full_name(nation)
	local ndata = towny.nations.nations[nation]
	if not ndata then return nil end
	if not ndata.level then return ndata.name end
	return ("%s %s %s"):format(ndata.level.prefix, ndata.name, ndata.level.tag)
end

function towny.nations.get_player_name(nation,player)
	local ndata = towny.nations.nations[nation]
	if not ndata then return nil end
	if not ndata.level then return nil end
	local cap = towny.towns[ndata.flags.capital]
	if not cap or not cap.members[player] then return nil end
	if cap.flags.mayor ~= player then return nil end
	return ("%s %s"):format(ndata.level.king_tag, player)
end

function towny.nations.get_member_count(nation)
	local ndata = towny.nations.nations[nation]
	if not ndata then return nil end
	return count(ndata.members)
end

function towny.nations.get_flags(nation)
	local ndata = towny.nations.nations[nation]
	if not ndata then return nil end
	ndata.flags.capital = towny.towns[ndata.flags.capital].name
	return ndata.flags
end
