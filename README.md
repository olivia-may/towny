# Towny

This is a [minetest](https://minetest.net/) mod based on the popular [Minecraft server mod](http://towny.palmergames.com/) of the same name.

At it's current state, it's a glorified semi-fixed-grid protection system based on claims and plots.

**Forum Post:** https://forum.minetest.net/viewtopic.php?f=9&t=21912

### Town Claim Blocks
A claim block is 16x64x16 nodes in size. By default, nobody in town except for the mayor can build in an unplotted claim block. The number of available claim blocks depends on the number of town residents. A claim block can be turned into a plot with the */plot claim* command.

### Plots
Plots are town claim blocks that can be owned by a town resident. Plots can have multiple members.

### Simple usage
* */town new <town name>* - Create a town right where you're standing
* */town claim* - Claim more land for your town. Must be called right outside of an existing town claim.
* */town invite <user>* - Invite a player to your town
* */plot claim* - Create/claim a plot
* */plot set claimable true* - Set the plot as claimable by other town members
* */plot member add/del <resident>* - Add/remove a person from a plot. Adding people to your plot will let them build on it.
* */town kick <user>* - Remove user from your town.
* */town visualize* - Highlight the bounds of your town's claim blocks.
