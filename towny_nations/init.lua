-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())
towny.nations = {
	modpath = modpath,
	levels = {
		{
			king_tag = 'Leader',
			members = 0,
			tag = '(Nation)',
			block_bonus = 10,
			prefix = 'Land of',
		}, {
			king_tag = 'Count',
			members = 10,
			tag = '(Nation)',
			block_bonus = 20,
			prefix = 'Federation of',
		}, {
			king_tag = 'Duke',
			members = 20,
			tag = '(Nation)',
			block_bonus = 40,
			prefix = 'Dominion of',
		}, {
			king_tag = 'King',
			members = 30,
			tag = '(Nation)',
			block_bonus = 60,
			prefix = 'Kingdom of',
		}, {
			king_tag = 'Emperor',
			members = 40,
			tag = 'Empire',
			block_bonus = 100,
			prefix = 'The',
		}, {
			king_tag = 'God Emperor',
			members = 60,
			tag = 'Realm',
			block_bonus = 140,
			prefix = 'The',
		}
	},
}
