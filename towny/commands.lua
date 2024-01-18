-- Commands

-- Privileges

minetest.register_privilege("towny", {
	description = "Can create and join towns",
})

minetest.register_privilege("towny_admin", {
	description = "Can administrate other people's towns",
	give_to_singleplayer = false
})

-- Color short-hands

local function fc(f,c)
	return minetest.colorize(f,c)
end

local function b(c)
	return fc("#04a5ea", c)
end

local function b1(c)
	return fc("#35bbf4", c)
end

local function b2(c)
	return fc("#5bc3ef", c)
end

local function g(c)
	return fc("#1a9b25", c)
end

-- API

--[[
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
]]--
local function create_town_info_str(town)

	local str = ""
	local i

	str = str .. town.name .. "\nMayor(s): ["
	for i = 1, town.mayor_count do
		if town.mayors[i] then
			str = str .. town.mayors[i].nickname .. " "
		end
	end
	str = str .. "]\nLocation: " .. town.pos:to_string() .. "\nMembers: ["
	for i = 1, town.member_count do
		if town.members[i] then
			str = str .. town.members[i].nickname .. " "
		end
	end
	str = str .. "]\nOwned blocks: " .. town.block_count

	return str
end
--[[
function towny.chat.print_flag_info(pad, tbl)
	local flags = {}
	for i,v in pairs(tbl) do
		if type(v) == "table" and v[3] ~= false then
			table.insert(flags, pad .. i .. " (" .. v[1] ..") " .. v[2])
		end
	end
	return flags
end

local function print_help(category)
	if not category then
		category = ""
	end

	local str = ""
	local tmp = b(" /town")

	if category == "" or category == "all" then
		str = str .. g("Basic Towny commands") .. "\n"
		str = str .. tmp .. " - Show information about your town" .. "\n"
		str = str .. tmp .. b1(" help") .. " [<category>|all] - " .. "Help on commands" .. "\n"
		str = str .. "   Help categories: members,claim,plot,flags" .. "\n"
		str = str .. tmp .. b1(" new") .. " <town name> - " .. "Create a new town at your current position" .. "\n"
		str = str .. tmp .. b1(" info") .. " <town name> - " .. "Show information about another town" .. "\n"
		str = str .. tmp .. b1(" teleport") .. " - " .. "Teleport to the center of your town" .. "\n"
		str = str .. tmp .. b1(" abandon") .. " - " .. "Abandon your town (deleting it)" .. "\n"
	end

	if category == "members" or category == "all" then
		str = str .. g("Help for Towny member management") .. "\n"
		str = str .. tmp .. b1(" invite") .. " <player> - " .. "Invite someone to your town" .. "\n"
		str = str .. tmp .. b1(" kick") .. " <kick> - " .. "Kick someone from your town" .. "\n"
		str = str .. tmp .. b1(" join") .. " <town name> - " .. "Join a town" .. "\n"
		str = str .. tmp .. b1(" leave") .. " - " .. "Leave your current town" .. "\n"		
	end

	if category == "claim" or category == "all" then
		str = str .. g("Help for Towny claims") .. "\n"
		str = str .. tmp .. b1(" claim") .. " - " .. "Claim land for your town at your current position" .. "\n"
		str = str .. tmp .. b1(" unclaim") .. " - " .. "Unclaim the currently stood in block" .. "\n"
		str = str .. tmp .. b1(" visualize") .. " - " .. "Display your currently claimed blocks" .. "\n"
	end

	if category == "plot" or category == "all" then
		str = str .. g("Help for Towny plots") .. "\n"
		str = str .. tmp .. b1(" plot ") .. "- " .. "Manage plots" .. "\n"
		str = str .. tmp .. b1(" plot ") .. b2("claim") .. " - " .. "Claim this plot" .. "\n"
		str = str .. tmp .. b1(" plot ") .. b2("abandon") .. " - " .. "Abandon this plot" .. "\n"
		str = str .. tmp .. b1(" plot ") .. b2("delete") .. " - " .. "Delete this plot" .. "\n"
		str = str .. tmp .. b1(" plot ") .. b2("flags") .. " - " .. "Display plot flags" .. "\n"
		str = str .. tmp .. b1(" plot ") .. b2("member") .. " add|remove|flags|set <member> [<flag> <value>] - " 
			.. "Plot member management" .. "\n"
	end

	if category == "flags" or category == "all" then
		str = str .. g("Help for Towny town flags") .. "\n"
		str = str .. tmp .. b1(" flags") .. " - " .. "Display current town flags" .. "\n"
		str = str .. tmp .. b1(" set") .. " <flag> <value> - " .. "Modify town flags" .. "\n"

		str = str .. g("Available flags for towns:") .. "\n"
		str = str .. table.concat(towny.chat.print_flag_info("    ", towny.flags.town), "\n") .. "\n"
		str = str .. g("Available flags for town members:") .. "\n"
		str = str .. table.concat(towny.chat.print_flag_info("    ", towny.flags.town_member), "\n") .. "\n"
		str = str .. g("Available flags for town plots:") .. "\n"
		str = str .. table.concat(towny.chat.print_flag_info("    ", towny.flags.plot), "\n") .. "\n"
		str = str .. g("Available flags for town plot members:") .. "\n"
		str = str .. table.concat(towny.chat.print_flag_info("    ", towny.flags.plot_member), "\n") .. "\n"
		if towny.nations then
			str = str .. g("Available flags for nations:") .. "\n"
			str = str .. table.concat(towny.chat.print_flag_info("    ", towny.flags.nation), "\n") .. "\n"
		end
	end

	return str
end
]]--

-- get parameter count (paramc), and array of parameter strings (paramv)
local function get_paramc_and_paramv(params)
	local paramc = 0
	local paramv = {}
	local index
	local i = 1

	while true do
		-- find index of ' ' space character, stop when no match
		index = string.find(params, ' ', i, true)
		paramc = paramc + 1
		if index then
			paramv[paramc] = string.sub(params, i, index - 1)
			i = index + 1
		else 
			paramv[paramc] = string.sub(params, i)
			break
		end
	end

	return paramc, paramv
end

local function towny_command(player_name, params)
	
	local player = minetest.get_player_by_name(player_name)
	if not player then return false, "Can't run command on behalf of offline player." end
	
	local paramc, paramv = get_paramc_and_paramv(params)

	if paramv[1]:len() == 0 then
		-- TODO: towny info
		return true, "towny"
	end

	if paramv[1] == "delete" then

		-- 'delete I WANT TO DELETE ALL TOWNY DATA' is 8 words
		if paramc > 7 then
			if paramv[2] == "I" and 
				paramv[3] == "WANT" and
				paramv[4] == "TO" and
				paramv[5] == "DELETE" and
				paramv[6] == "ALL" and
				paramv[7] == "TOWNY" and
				paramv[8] == "DATA" then
				
				towny.delete_all_data()
				return true, "Deleted all towny data..."
			end
		end
		
		return false, "WARNING: This will PERMANENTLY DELETE ALL TOWNY DATA for this server! The data would be wiped and the server would shut down. Please run this command again with 'I WANT TO DELETE ALL TOWNY DATA' without the ' quotes in all caps typed after it."
	end
end

local function town_command(player_name, params)

	local player = minetest.get_player_by_name(player_name)
	if not player then return false, "Can't run command on behalf of offline player." end
	
	local paramc, paramv = get_paramc_and_paramv(params)
	local resident = towny.get_resident_by_name(player_name)

	if paramv[1]:len() == 0 then 
		if not resident.town then
			return false, "You are not currently in a town."
		end
		return true, create_town_info_str(resident.town)
	end


	if paramv[1] == "help" then
		-- TODO: help
		return true, "help" --print_help(pr2)
	end

	if paramv[1] == "visualize" then
		if not resident.town then
			return false, "You have no town to visualize."
		end
		towny.visualize_town(resident.town)
		return true
	end

	if paramv[1] == "extend" or paramv[1] == "claim" then
		if not resident.town then
			return false, "You don't have a town!"
		end
	
		local player_pos = towny.get_player_pos(player)
		local i
		for i = 1, towny.block_count do
			local block = towny.block_array[i]
			if player_pos.x > block.pos_min.x and 
				player_pos.x < block.pos_max.x and
				player_pos.y > block.pos_min.y and 
				player_pos.y < block.pos_max.y and
				player_pos.z > block.pos_min.z and 
				player_pos.z < block.pos_max.z then
				
				return false, "This area is already claimed!"
			end
		end


		towny.extend_town(towny.get_player_pos(player), resident.town)
		return true, "Successfully claimed block " .. resident.town.blocks[resident.town.block_count].blockpos:to_string() .. "."
	end

	if (paramc > 1) then
		if (paramv[1] == "create" or paramv[1] == "new") then
			
			if resident.town then
				return false, "You're already in a town!" 
			end

			local town = towny.town.new(player, paramv[2])

			minetest.chat_send_all(("%s has started a new town called '%s'!"):format(player_name,
				town.name))

			return true, "Your town has successfully been founded!"
		end
	end
	--[[
	elseif (pr1 == "invite" and not minetest.get_player_by_name(pr2)) then
		return invite_respond(name, (pr2:lower() == "accept" or minetest.is_yes(pr2)))
	elseif pr1 == "join" and not town then
		return join_town(towny.get_town_by_name(pr2), name, false)
	elseif pr1 == "show" or pr1 == "info" then
		if not towny.get_town_by_name(pr2) then
			return false, "No such town."
		end
		town_info = pr2

	-- Town management commands
	local tdata = towny.towns[town]

	elseif param == "leave" then
		return towny.leave_town(name)
	elseif param == "teleport" then
		local portal = tdata.flags['teleport']
		if not portal then portal = tdata.flags['origin'] end
		player:set_pos(portal)
		return true, "Teleporting you to town.."
	elseif param == "unclaim" then
		return towny.abridge_town(nil, name)
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
			return towny.kick_member(town,name,user)
		elseif action == "flags" then
			local mem = tdata.members[user]
			if not mem then
				return false, "No such member of town."
			end
			return towny.chat.send_flags(mem,string.format("Flags of member \"%s\" in town \"%s\"", user, tdata.name))
		elseif action == "set" then
			local target, flag, value = string.match(user, "^([%a%d_-]+) ([%a%d_-]+) (.+)$")
			return towny.set_town_member_flags(nil,name,target,flag,value)
		end
	end

	-- Plot management commands
	if pr1 == "plot" or pr1 == "plots" then
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
	]]--

	return false, "towny: Invalid command usage."
end

local function plot_command()
end

minetest.register_chatcommand("town", {
	description = "Manage your town. Run /town help for more information.",
	privs = {towny = true},
	func = town_command
})

minetest.register_chatcommand("towny", {
	description = "View and manage your towny settings Run /towny help for more information.",
	privs = {towny = true},
	func = towny_command
})

minetest.register_chatcommand("plot", {
	description = "Manage your town plot. Run /town help plot for more information.",
	privs = {towny = true},
	func = plot_command
})
