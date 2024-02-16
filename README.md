# Towny

This is a [minetest](https://minetest.net/) mod based on the popular 
[Minecraft server mod](http://towny.palmergames.com/) of the same name.

At it's current state, it's a glorified fixed-grid protection system
based on claims and plots. This mod is a work in progress, There are a lot of
missing features and possibly some bugs. There will be a lot of changes until
a stable release is made. Much of the code is commented out because it hasn't
been refactored yet.

**Forum Post:** https://forum.minetest.net/viewtopic.php?f=9&t=21912

### Town Claim Blocks
A claim block is 16x16x16 nodes (or one mapblock) in size. By default, nobody
in town except for the mayor can build in an unplotted claim block. The number
of available claim blocks depends on the number of town residents. A claim
block can be turned into a plot with the */plot claim* command.

### Residents
A resident is a player in a towny server. They can join or make a town.
They can own plots, and befriend other residents to allow them to build
in the resident's owned plots.

### Towns
A town is made up of residents and claim blocks. Towns can collect taxes,
invite residents, and expand their territory. Towns have a mayor (or mayors).

### Nations
A nation is made up of towns. Nations can collect taxes from towns and invite
other towns. Nations have a leader (or leaders).

### Plots
Plots are town claim blocks that can be owned by a town resident. Plots can have multiple members.

### Command checklist
#### /towny
* [ ] help - Towny help
#### /town
* [x] new {town name} - Create a town right where you're standing
* [x] claim - Claim more land for your town. Must be called right outside of an existing town claim.
* [x] unclaim - Remove a claimed block from your town.
* [ ] delete - Delete your town, careful!
* [ ] invite {resident} - Invite a player to your town
* [ ] kick {resident} - Remove user from your town.
* [x] show - Highlight the bounds of your town's claim blocks.
#### /plot
* [ ] /plot claim - Create/claim a plot
* [ ] /plot set claimable true - Set the plot as claimable by other town members
* [ ] /plot member add/del {resident} - Add/remove a person from a plot. Adding people to your plot will let them build on it.
* [ ] /plot show - Highlight the bounds of your nearest owned plot.
