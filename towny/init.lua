-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

-- TODO: Economy
-- TODO: Refactor towns, settings, and mapsblocks
-- TODO: `resident` class
-- TODO: storage
-- TODO: merge towny_nations into towny 
-- TODO: plots

-- `towny` namespace
towny = {
	modpath = minetest.get_modpath(minetest.get_current_modname()),
	
	settings = {
		storage_engine = minetest.settings:get("towny_storage_engine") or "modstorage",
                -- min distance in mapblocks from town center (16x16x16 nodes)
		town_distance = tonumber(minetest.settings:get('towny_distance')) or 4,
		vertical_towns = 
			minetest.settings:get_bool('towny_vertical_towns', false),
		eco_enabled = false,
	},
	
	-- (claimed by a town) mapblock class
	block = {
		id = 0,
		name = nil, --string
		town = nil, -- town, town that owns this block
		plot = nil, -- Plot ID if this claim block is plotted
		is_town_center = false,
		blockpos = {}, -- vector, block position
		pos_min = {}, -- vector, min pos
		pos_max = {}, -- vector, max pos
		perms = {
			build = {
				resident = false,
				nation = false,
				ally = false,
				outsider = false,
			},	
			destroy = {
				resident = false,
				nation = false,
				ally = false,
				outsider = false,
			},
			switch = {
				resident = false,
				nation = false,
				ally = false,
				outsider = false,
			},
			itemuse = {
				resident = false,
				nation = false,
				ally = false,
				outsider = false,
			},
		},
	},
	
	-- Town class
	town = {
		id = 0,
		name = nil, -- string
		members = {}, -- resident table
		member_count = 0, 
		mayors = {}, -- resident table
		mayor_count = 0,
		blocks = {},-- block table, owned mapblocks
		block_count = 0,
		flags = nil, -- TODO: remove this
		pos = {} -- vector
	},

	-- resident class
	resident = {
		id = 0,
		nickname = nil, -- string
		name = nil, -- string, minetest name ex. 'singleplayer'
		town = nil, -- town, resident town
		friends = {}, -- other residents
	},
	
	-- Mapblocks loaded into memory cache
	block_array = {},
	block_count = 0,
	
	town_array   = {},
	town_count = 0,

	resident_array = {},
	resident_count = 0,
	
	-- not sure what this does?
	storage = {},
	
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

	-- Set to true if files need to be updated
	dirty = false,
}

-- block class constructor
function towny.block.new(pos, town)
	local block = {}
	setmetatable(block, towny.block)
	towny.block.__index = towny.block
	towny.block_count = towny.block_count + 1
	block.id = towny.block_count

	block.blockpos = vector.new(math.floor(pos.x / 16),
		math.floor(pos.y / 16),
		math.floor(pos.z / 16))
	block.pos_min = vector.new(block.blockpos.x * 16 - 0.5,
		block.blockpos.y * 16 - 0.5,
		block.blockpos.z * 16 - 0.5)
	block.pos_max = vector.add(block.pos_min, 16)
	
	block.town = town
	towny.block_array[towny.block_count] = block

	town.block_count = town.block_count + 1
	town.blocks[town.block_count] = block

	return block
end

-- resident class constructor
function towny.resident.new(player)
	local resident = {}

	setmetatable(resident, towny.resident)
	towny.resident.__index = towny.resident
	towny.resident_count = towny.resident_count + 1
	resident.id = towny.resident_count
	resident.name = player:get_player_name()
	resident.nickname = resident.name -- can be changed later
	towny.resident_array[towny.resident_count] = resident
	
	return resident
end

minetest.register_on_joinplayer(function(player)
	towny.resident.new(player)
end)

dofile(towny.modpath .. "/storage/init.lua")
dofile(towny.modpath .. "/visualize.lua")
--dofile(towny.modpath .. "/regions.lua")
dofile(towny.modpath .. "/town.lua")
dofile(towny.modpath .. "/commands.lua")
