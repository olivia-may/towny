-- Commands

-- Privileges

minetest.register_privilege("towny", {
	description = "Can create and join towns",
})

minetest.register_privilege("towny_admin", {
	description = "Can administrate other people's towns",
	give_to_singleplayer = false
})

-- API

-- Send message to all town members who are online
function towny.chat.announce_to_members(town,message)
	local tdata = towny.towns[town]
	if not tdata then return end
	for member in pairs(tdata.members) do
		if minetest.get_player_by_name(member) then
			minetest.chat_send_player(member,message)
		end
	end
end

-- Commands

local function invite_player(town,player,target)
	local utown = towny.get_player_town(player)
	if not utown then
		return false, "You are not in a town."
	end

	if target == player then
		return false, "You cannot invite yourself!"
	end

	if not minetest.get_player_by_name(target) then
		return false, "You can only invite online players to your town."
	end

	local target_town = towny.get_player_town(target)
	if target_town then
		return false, "This player is already in a town!"
	end

	if towny.chat.invites[town.."-"..target] then
		return false, "This player has already been invited to join your town!"
	end

	local tdata = towny.towns[town]

	minetest.chat_send_player(target, ("You have been invited to join town '%s' by %s"):format(tdata.name, player))
	minetest.chat_send_player(target, "You can accept this invite by typing '/town invite accept' or deny '/town invite deny'")

	towny.chat.invites[town.."-"..target] = { rejected = false, town = town, player = target, invited = player }
	return true, ("Player %s has been invited to join your town."):format(target)
end

local function join_town(town,player,from_invite)
	local tdata = towny.towns[town]
	if not tdata then return false, "No such town" end
	if (not from_invite and not tdata.flags['joinable']) then return false, "You cannot join this town." end
	towny.chat.announce_to_members(town, minetest.colorize("#02aacc", ("%s has joined the town!"):format(player)))
	minetest.chat_send_player(player, ("You have successfully joined the town '%s'!"):format(tdata.name))
	tdata.members[player] = {}
	towny.mark_dirty(town,false)
	return true
end

local function invite_respond(player,response)
	local utown = towny.get_player_town(player)
	if utown then
		return false, "You are already in a town."
	end

	for id,data in pairs(towny.chat.invites) do
		if data.player == player then
			if not data.rejected then
				if response == true then
					towny.chat.invites[id] = nil
					return join_town(data.town,player,true)
				else
					towny.chat.invites[id] = { rejected = true }
					return true, "You have rejected the join request."
				end
			end
		end
	end

	return false, "You do not have any pending invites."
end

function towny.chat.send_flags (flags,message)
	local shiny = {}
	for flag,value in pairs(flags) do
		if type(value) == "table" then
			if value.x and value.y and value.z then
				value = minetest.pos_to_string(value)
			else
				value = dump(value)
			end
		elseif type(value) == "boolean" then
			local str_value = "true"
			if value == false then str_value = "false" end
			value = str_value
		end
		shiny[#shiny+1] = flag..": "..value
	end

	return true, message ..": "..table.concat( shiny, ", " )
end

local function town_command (name, param)
	local player = minetest.get_player_by_name(name)
	if not player then return false, "Can't run command on behalf of offline player." end

	local pr1, pr2 = string.match(param, "^([%a%d_-]+) (.+)$")
	local town = towny.get_player_town(name)

	-- Pre town requirement
	local town_info = nil

	if (pr1 == "create" or pr1 == "new") and pr2 then
		return towny.create_town(nil, name, pr2)
	elseif (pr1 == "invite" and not minetest.get_player_by_name(pr2)) then
		return invite_respond(name, (pr2:lower() == "accept" or minetest.is_yes(pr2)))
	elseif pr1 == "join" and towny.get_town_by_name(pr2) and not town then
		return join_town(pr2,name,false)
	elseif pr1 == "show" or pr1 == "info" then
		if not towny.get_town_by_name(pr2) then
			return false, "No such town."
		end
		town_info = pr2
	elseif param == "" and town then
		town_info = town
	end

	-- Print town information
	if town_info then
		return false, "Not yet implemented!"
	end

	if not town then
		return false, "You are not currently in a town."
	end

	-- Town management commands
	local tdata = towny.towns[town]

	if param == "extend" or param == "claim" then
		return towny.extend_town(nil, name)
	elseif param == "leave" then
		return towny.leave_town(name)
	elseif param == "teleport" then
		local portal = tdata.flags['teleport']
		if not portal then portal = tdata.flags['origin'] end
		player:set_pos(portal)
		return true, "Teleporting you to town.."
	elseif param == "unclaim" then
		return towny.abridge_town(nil, name)
	elseif param == "visualize" then
		towny.regions.visualize_town(town)
		return true
	elseif param == "flags" then
		local flags = towny.get_flags(town)
		if flags then
			return towny.chat.send_flags(flags,"Flags of your town")
		end
	elseif (param == "delete" or param == "abandon") or (pr1 == "delete" or pr1 == "abandon") then
		if towny.chat['delete_verify_' .. name] and pr2 == "I WANT TO DELETE MY TOWN" then
			towny.chat['delete_verify_' .. name] = nil
			return towny.delete_town(nil, name)
		else
			towny.chat['delete_verify_' .. name] = true
			minetest.chat_send_player(name, minetest.colorize("#f79204",
				"WARNING! Deleting your town will render ALL of the buildings in it without protection!"))
			return false, "Please run the command again with 'I WANT TO DELETE MY TOWN' in all caps written after it."
		end
	elseif param == "greeting" then
		local tdata = towny.towns[town]
		if not tdata.flags["greeting"] then return false, "This town has no greeting message." end

		return true,
			minetest.colorize("#078e36", ("[%s] "):format(towny.get_full_name(town))) ..
			minetest.colorize("#02aacc", tdata.flags["greeting"])
	elseif pr1 == "kick" then
		return towny.kick_member(town,name,pr2)
	elseif pr1 == "set" then
		local flag, value = string.match(pr2, "^([%a%d_-]+) (.+)$")
		return towny.set_town_flags(nil,name,flag,value)
	elseif pr1 == "member" then
		local action, user = string.match(pr2, "^([%a%d_-]+) (.+)$")
		if action == "kick" then
			return towny.kick_member(town,name,pr2)
		elseif action == "set" then
			local target, flag, value = string.match(user, "^([%a%d_-]+) ([%a%d_-]+) (.+)$")
			return towny.set_town_member_flags(nil,name,target,flag,value)
		end
	end

	-- Plot management commands
	if pr1 == "plot" then
		local pl1, pl2 = string.match(pr2, "^([%a%d_-]+) (.+)$")
		if pr2 == "claim" then
			return towny.claim_plot(nil,name)
		elseif pr2 == "abandon" then
			return towny.abandon_plot(nil,name)
		elseif pr2 == "delete" then
			return towny.delete_plot(nil,name)
		elseif pr2 == "flags" then
			local flags = towny.get_plot_flags(town,nil,name)
			if flags then
				return towny.chat.send_flags(flags,"Flags of this plot")
			else
				return false, "There's no plot here."
			end
		elseif pl1 == "set" and pl2 then
			local flag, value = string.match(pl2, "^([%a%d_-]+) (.+)$")
			return towny.set_plot_flags(nil,name,flag,value)
		elseif pl1 == "member" and pl2 then
			local action, user = string.match(pl2, "^([%a%d_-]+) (.+)$")
			if action == "add" then
				return towny.plot_member(nil,name,user,1)
			elseif action == "remove" or action == "del" or action == "kick" then
				return towny.plot_member(nil,name,user,0)
			elseif action == "set" then
				local target, flag, value = string.match(user, "^([%a%d_-]+) ([%a%d_-]+) (.+)$")
				return towny.set_plot_member_flags(nil,name,target,flag,value)
			end
		end
	elseif pr1 == "invite" and minetest.get_player_by_name(pr2) then
		return invite_player(town,name,pr2)
	end

	return false, "Invalid command usage."
end

minetest.register_chatcommand("town", {
	description = "Manage your town",
	privs = {towny = true},
	func = town_command
})

minetest.register_chatcommand("plot", {
	description = "Manage your town plot",
	privs = {towny = true},
	func = function (name, param)
		return town_command(name, "plot " .. param)
	end
})
