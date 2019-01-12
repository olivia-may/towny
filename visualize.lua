-- Visualize an area

local r1 = towny.regions.size + 1
local r2 = towny.regions.height + 1
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

function towny.regions:visualize_radius(pos)
	local e = minetest.add_entity(pos, "towny:region_visual")
end

function towny.regions:visualize_area(p1,p2)
	local center = {x=p2.x + r1/2,y=p2.y + r2/2,z=p2.z + r1/2}
	local e = minetest.add_entity(center, "towny:region_visual")
end
