-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

-- TODO: Economy
-- TODO: Refactor towns, settings, and mapsblocks
-- TODO: plots

-- `towny` namespace
towny = {
	modpath = minetest.get_modpath(minetest.get_current_modname()),

	-- settings

	-- min distance in mapblocks from town center (16x16x16 nodes)
	setting_town_distance =
		tonumber(minetest.settings:get('towny_distance')) or 4,
	-- prevent protectors from other mods being placed in a town
	setting_prevent_protector = minetest.settings:get_bool(
		'towny_prevent_protector', true),
	-- must be invited to towns / nations
	setting_invite = minetest.settings:get_bool('towny_invite', true),
	setting_vertical_towns = 
		minetest.settings:get_bool('towny_vertical_towns', false),
	setting_autosave_interval = 
		tonumber(minetest.settings:get(
		'towny_autosave_interval')) or 900,
	setting_economy = false,

	--[[
	--	rnao
	--	0000 no perms
	--	0001 outsider
	--	0010 ally
	--	0100 nation
	--	1000 resident
	--]]
	-- perm enum
	NO_PERMS = 0,
	OUTSIDER = 1,
	ALLY = 2,
	NATION = 4,
	RESIDENT = 8,

	-- (claimed by a town) mapblock class / struct
	block = {
		id = 0, -- unique id
		index = 0, -- index where this block lives in `block_array`
		name = "",
		town_id = 0, -- int, id of town that owns this block
		town = nil, -- town, pointer to owner town
		is_plotted = false,
		plot_id = 0, -- int , Plot ID if this claim block is plotted
		is_town_center = false,
		blockpos = {}, -- vector, block position
		pos_min = {}, -- vector, min pos
		pos_max = {}, -- vector, max pos
		perm_build = 0,
		perm_destroy = 0,
		perm_switch = 0,
		perm_itemuse = 0,
	},

	-- TODO: plots
	
	-- Town class / struct
	town = {
		blocks = {}, -- block table
		block_count = 0,
		center_block = nil, -- block, town center block
		id = 0,
		index = 0,
		name = "",
		members = {}, -- resident table
		member_count = 0,
		mayors = {}, -- resident table
		mayor_count = 0,
		pos = {}, -- vector
	},

	-- resident class / struct
	resident = {
		-- TODO: implement friends
		-- int, resident[1] [2] [3] etc. are resident's friend's ids
		friends = {}, -- resident table
		-- greatest index of resident friend ids and `friends`
		friend_count = 0, 
		id = 0,
		index = 0,
		nickname = "", -- changeable name
		name = "", -- minetest name ex. 'singleplayer'
		town_id = 0, -- resident town id
		town = nil, -- town, resident town
		is_mayor = false,
	},

	-- Mapblocks loaded into memory cache, when a block is deleted, the
	-- array will be rearranged
	block_array = {},
	block_count = 0, -- Greatest index in block_array
	block_id_count = 0, -- Greatest current id for blocks, an id for a
				-- class always stays the same
	
	town_array = {},
	town_count = 0,
	town_id_count = 0,

	resident_array = {},
	resident_count = 0,
	resident_id_count = 0,
	
	-- economy
	eco     = {},
	
	chat    = {
		chatmod = minetest.settings:get_bool('towny_chat', true),
		invite  = minetest.settings:get_bool('towny_invite', true),
		invites = {},
	},
	
	town_levels = {
		{
			members = 0,
			name_tag = 'Ruins',
			mayor_tag = 'Spirit',
			claimblocks = 1,
		}, {
			members = 1,
			name_tag = 'Settlement',
			mayor_tag = 'Hermit',
			claimblocks = 16,
		}, {
			members = 2,
			name_tag = 'Hamlet',
			mayor_tag = 'Chief',
			claimblocks = 32,
		}, {
			members = 6,
			name_tag = 'Village',
			mayor_tag = 'Baron Von',
			claimblocks = 96,
		}, {
			members = 10,
			name_tag = 'Town',
			mayor_tag = 'Viscount',
			claimblocks = 160,
		}, {
			members = 14,
			name_tag = 'Large Town',
			mayor_tag = 'Count Von',
			claimblocks = 224,
		}, {
			members = 20,
			name_tag = 'City',
			mayor_tag = 'Earl',
			claimblocks = 320,
		}, {
			members = 24,
			name_tag = 'Large City',
			mayor_tag = 'Duke',
			claimblocks = 384,
		}, {
			members = 28,
			name_tag = 'Metropolis',
			mayor_tag = 'Lord',
			claimblocks = 448,
		}
	},

	-- TODO: refactor or remove flags
	--[[
	flags = {
		town = {
			['town_build'] =        {"boolean", "lets everyone build in unplotted town claims"},
			['plot_build'] =        {"boolean", "lets everyone build in unowned town plots"},
			['plot_member_build'] = {"boolean", "if false, plot members don't have build rights to plots by default"},
			['teleport'] =          {"vector",  "town teleport point"},
			['pvp'] =               {"boolean", "players can fight in the town if true, ignores server pvp settings"},
			['plot_pvp'] =          {"boolean", "default plot pvp setting. defaults to false"},
			['joinable'] =          {"boolean", "if true, anyone can join this town. defaults to false"},
			['greeting'] =          {"string",  "town's greeting message"},
			['tax'] =               {"number",  "how much each member has to pay each day to stay in town"},
			['mayor'] =             {"member",  "town's mayor"},
			['bank'] =              {"number",  "town's treasury", false},
			['claim_blocks'] =      {"number",  "town's bonus claim blocks", false},
			['origin'] =            {"vector",  "town's center position, set at town creation", false},
		},
		town_member = {
			['town_build'] =   {"boolean", "member can build in unplotted town claims"},
			['claim_create'] = {"boolean", "member can claim land for the town"},
			['claim_delete'] = {"boolean", "member can abandon claim blocks"},
			['plot_create'] =  {"boolean", "member can create plots"},
			['plot_delete'] =  {"boolean", "member can delete plots"},
		},
		plot = {
			['teleport'] =  {"vector",   "plot's teleport point"},
			['pvp'] =       {"boolean",  "players can fight here if true, ignores server pvp settings"},
			['cost'] =      {"number",   "plot cost (only with economy)"},
			['claimable'] = {"boolean",  "is this plot available for claiming. if cost is more than 0, require payment"},
			['greeting'] =  {"string",   "plot's greeting message (defaults to \"{owner}'s Plot\"/\"Unclaimed Plot\")"},
		},
		plot_member = {
			['plot_build'] = {"boolean", "member can build on plot. defaults to 'plot_member_build' town flag"},
			['build']      = "plot_build",
		},
	},
	]]--
}

dofile(towny.modpath .. "/storage.lua")
dofile(towny.modpath .. "/resident.lua")
dofile(towny.modpath .. "/block.lua")
dofile(towny.modpath .. "/town.lua")
dofile(towny.modpath .. "/commands.lua")
