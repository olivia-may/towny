-- Visualize an area
-- TODO: Use particles

local r1 = towny.regions.size
local r2 = towny.regions.height
local c_obj_props = {
	hp 			= 1,
	glow 		= 1,
	physical 	= false,
	pointable 	= true,
	visual 		= "cube",
	visual_size = {x = r1, y = r2},
	textures 	= {"towny_visualize.png","towny_visualize.png","towny_visualize.png",
				   "towny_visualize.png","towny_visualize.png","towny_visualize.png"},
	static_save = false,
	use_texture_alpha = true,
}

minetest.register_entity("towny:region_visual", {
	initial_properties = c_obj_props,
	on_punch = function(self)
		self.object:remove()
	end,
	timer0 = 0,
	on_step = function (self,dt)
		self.timer0 = self.timer0 + 1
		if self.timer0 > 600 then
			self.object:remove()
		end
	end
})

local function fl(x)
	return math.floor(x)
end

function towny.regions.visualize_area(p1,p2,pos)
	local center = {x=fl(p2.x + r1/2)+0.5,y=fl(p2.y + r2/2)+0.5,z=fl(p2.z + r1/2)+0.5}

	if towny.regions.vertical.static then
		center.y = pos.y
	end

	local e = minetest.add_entity(center, "towny:region_visual")
end
