
towny.chat.invites.nation = {}

-- Send message to all town members who are online
function towny.nations.announce_to_members(nation,message)
	local ndata = towny.nations.nations[nation]
	if ndata then return end
	for town in pairs(ndata.members) do
		towny.chat.announce_to_members(town,message)
	end
end

local function join_nation(nation,player,from_invite)
	local town = towny.get_player_town(player)
	local tdata = towny.towns[town]
	local ndata = towny.nations.nations[nation]
	if not ndata then return false, "The nation specified does not exist." end
	if not tdata then return false, "You are not in a town that could join a nation." end
	if towny.nations.get_town_nation(town) then return false, "Your town is already part of a nation." end
	if tdata.flags.mayor ~= player then return false, "Only the mayor can join their town into a nation." end
	if (not from_invite and not ndata.flags['joinable']) then return false, "You cannot join this nation." end
	towny.nations.announce_to_members(town, minetest.colorize("#02aacc", ("%s has joined the nation!"):format(towny.get_full_name(town))))
	minetest.chat_send_player(player, ("Your town has successfully joined %s!"):format(towny.nations.get_full_name(nation)))
	ndata.members[town] = {}
	ndata.dirty = true
	towny.dirty = true
	return true
end

local function invite_respond(player,response)
	local utown = towny.get_player_town(player)
	if not utown then
		return false, "You are not in a town."
	end

	local unation = towny.nations.get_town_nation(utown)
	if unation then
		return false, "Your town is already part of a nation."
	end

	for id,data in pairs(towny.chat.invites.nation) do
		if data.player == player then
			if not data.rejected then
				if response == true then
					towny.chat.invites.nation[id] = nil
					return join_nation(data.nation,player,true)
				else
					towny.chat.invites.nation[id] = { rejected = true }
					return true, "You have rejected the join request."
				end
			end
		end
	end

	return false, "You do not have any pending invites."

end

local function invite_town(player,town)
	local utown = towny.get_player_town(player)
	if not utown then
		return false, "You are not in a town."
	end

	if town == utown then
		return false, "You cannot invite yourself!"
	end

	local nation = towny.nations.get_town_nation(utown)
	if not nation then
		return false, "Your town is not part of any nation."
	end

	local utdata = towny.towns[utown]
	local ndata = towny.nations.nations[nation]
	if utdata.flags.mayor ~= player or ndata.flags.capital ~= utown then
		return false, "You can only invite towns to your nation if you own said nation!"
	end

	if not towny.get_town_by_name(town) then
		return false, "Invalid town name."
	end

	local target_town = towny.nations.get_town_nation(town)
	if target_town then
		return false, "This town is already part of a nation!"
	end

	if towny.chat.invites.nation[town.."-"..nation] then
		return false, "This town has already been invited to join your nation!"
	end

	local tdata = towny.towns[town]
	local target = tdata.flags['mayor']
	if not minetest.get_player_by_name(target) then
		return false, "The mayor of the targeted town is offline, thus you cannot invite this town to your nation!"
	end

	minetest.chat_send_player(target, ("Your town has been invited to join %s by %s"):format(towny.nations.get_full_name(nation), player))
	minetest.chat_send_player(target, "You can accept this invite by typing '/nation invite accept' or deny '/nation invite deny'")

	towny.chat.invites[town.."-"..nation] = { rejected = false, nation = nation, town = town, invited = player }
	return true, ("Town %s has been invited to join your nation."):format(town)
end

local function nation_command(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then return false, "Can't run command on behalf of offline player." end

	local pr1, pr2 = string.match(param, "^([%a%d_-]+) (.+)$")
	local town = towny.get_player_town(name)

	if not town then
		return false, "You are not currently in any town."
	end

	local nation = towny.nations.get_town_nation(town)
	local tdata = towny.towns[town]

	-- Pre nation requirement
	local nation_info = nil

	if (pr1 == "create" or pr1 == "new") and pr2 then
		return towny.nations.create_nation(pr2,name)
	elseif (pr1 == "invite" and not towny.get_town_by_name(pr2)) then
		return invite_respond(name, (pr2:lower() == "accept" or minetest.is_yes(pr2)))
	elseif pr1 == "join" and towny.nations.get_nation_by_name(pr2) and not nation then
		return join_nation(pr2,name,false)
	elseif pr1 == "show" or pr1 == "info" then
		if not towny.get_town_by_name(pr2) then
			return false, "No such nation."
		end
		nation_info = pr2
	elseif param == "" and nation then
		nation_info = nation
	end

	-- Print nation information
	if nation_info then
		return false, "Not yet implemented!"
	end

	if not nation then
		return false, "You are not currently in a nation."
	end

	local ndata = towny.nations.nations[nation]
	local capital = towny.towns[ndata.flags.capital]

	if param == "leave" or param == "delete" then
		return towny.nations.leave_nation(name)
	elseif param == "teleport" and capital then
		local portal = capital.flags['teleport']
		if not portal then portal = capital.flags['origin'] end
		player:set_pos(portal)
		return true, "Teleporting you to the nation's capital town.."
	elseif param == "flags" then
		local flags = towny.nations.get_flags(nation)
		if flags then
			return towny.chat.send_flags(flags,"Flags of your nation")
		end
	elseif pl1 == "set" and pl2 then
		local flag, value = string.match(pl2, "^([%a%d_-]+) (.+)$")
		return towny.nations.set_nation_flags(name,flag,value)
	elseif pr1 == "invite" and towny.get_town_by_name(pr2) then
		return invite_town(name,towny.get_town_by_name(pr2))
	end

	return false, "Invalid command usage."
end

minetest.register_chatcommand("nation", {
	description = "Manage your nation",
	privs = {towny = true},
	func = nation_command
})
