_G.Cry3menu = {}

Cry3menu._path = ModPath
Cry3menu._save_path = SavePath .. "Cry3menuSettings.txt"
Cry3menu._current_weapon_default_blueprint_set = {}

Hooks:Add("LocalizationManagerPostInit", "F_"..Idstring("Cry3menu:Loc"):key(), function( loc )
	local langFile = "english.txt"
	loc:load_localization_file(Cry3menu._path .. "loc/" .. langFile)
end)

function Cry3menu:Load()
	local file = io.open(self._save_path, "r")
	if (file) then
		for k, v in pairs(json.decode(file:read("*all"))) do
			self.settings[k] = v
		end
	else
		self:Save()
	end
end

function Cry3menu:Save()
	local file = io.open(self._save_path,"w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function Cry3menu:OpenMenu()
	if self.radial_menu then
		self.radial_menu:Toggle()
	end
end

function Cry3menu:changeWeaponPart(info)
	local category = info.category
	local mod_name = info.mod_name
	local player = managers.player:local_player()
	local player_inv = player:inventory()
	local weapon_base = player_inv:equipped_unit():base()
	local blueprint = deep_clone(weapon_base._blueprint)
	local remove_part = false
	for _,v in pairs(blueprint) do
		if v == mod_name and not Cry3menu._current_weapon_default_blueprint_set[mod_name] then
			remove_part = true
			break
		end
	end
	local ammo_total = weapon_base:ammo_base():get_ammo_total()
	local ammo_remaining_in_clip = weapon_base:ammo_base():get_ammo_remaining_in_clip()
	managers.weapon_factory:change_part_blueprint_only(weapon_base._factory_id, mod_name, blueprint, remove_part)
	player_inv:add_unit_by_factory_name(weapon_base._factory_id, true, false, blueprint, weapon_base._cosmetics_data, weapon_base._textures)

	local new_weapon_base = self.get_player_weapon_base()
	local has_less_ammo = new_weapon_base:ammo_base():get_ammo_remaining_in_clip() > weapon_base:ammo_base():get_ammo_max_per_clip()
	local is_new_mag_size = new_weapon_base:ammo_base():get_ammo_max_per_clip() ~= weapon_base:ammo_base():get_ammo_max_per_clip()
	local is_new_max_ammo = new_weapon_base:ammo_base():get_ammo_max() ~= weapon_base:ammo_base():get_ammo_max()
	local is_new_bullet_class = new_weapon_base._bullet_class ~= weapon_base._bullet_class
	local is_magazine_or_ammo = category == "ammo" or category == "magazine"

	-- Set ammo, if started with less then new version then use that ammo count
	new_weapon_base:ammo_base():set_ammo_total(math.min(ammo_total, new_weapon_base:ammo_base():get_ammo_total()))

	if is_magazine_or_ammo or is_new_mag_size or is_new_max_ammo or is_new_bullet_class or has_less_ammo then
		log("reload because of category"..tostring(category))
		new_weapon_base:set_ammo_remaining_in_clip(0)
	else 
		new_weapon_base:set_ammo_remaining_in_clip(ammo_remaining_in_clip)
	end

	managers.hud:set_ammo_amount(new_weapon_base:selection_index(), new_weapon_base:ammo_info())
end

function Cry3menu:SetMyRadialMenu(menu)
	if not managers.hud then 
		return
	end
	self.radial_menu = menu or self.radial_menu
end

function Cry3menu:SetMyRadialSubMenu(menu, category)
	if not managers.hud then 
		return
	end
	self.radial_sub_menus = self.radial_sub_menus or {}
	self.radial_sub_menus[menu._name] = menu
end

function Cry3menu:openCategoryMenu(key)
	if self.radial_sub_menus and self.radial_sub_menus[key] then
		self.radial_sub_menus[key]:Toggle()
	end
end

function Cry3menu:get_player_weapon_base()
	local player = managers.player:local_player()
	if not player then
		return
	end
	local player_inv = player:inventory()
	if not player_inv:equipped_unit() or not player_inv:equipped_unit():base() then
		return false
	end
	local name_id = player_inv:equipped_unit():base():get_name_id()
	if not name_id then
		return false
	end
	local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name_id)
	if not factory_id then
		return false
	end
	local factory_data = tweak_data.weapon.factory[factory_id]
	if not factory_id or not factory_data.uses_parts then
		return false
	end
	return player_inv:equipped_unit():base()
end

if PlayerInventory then
	Hooks:PostHook(PlayerInventory, '_call_listeners', "F_"..Idstring("RRModTest001:RadialMouseMenu:Init"):key(), function(self, event)
		if tostring(event) == "equip" then
			local player = managers.player:local_player()
			if not player then
				return
			end
			local player_inv = player:inventory()
			if not player_inv:equipped_unit() or not player_inv:equipped_unit():base() then
				return false
			end
			local name_id = player_inv:equipped_unit():base():get_name_id()
			if not name_id then
				return false
			end
			local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name_id)
			if not factory_id then
				return false
			end
			local factory_data = tweak_data.weapon.factory[factory_id]
			if not factory_id or not factory_data.uses_parts then
				return false
			end
			local weapon_base = player_inv:equipped_unit():base()

			Cry3menu._current_weapon_default_blueprint_set = {}
			for _, v in ipairs(factory_data.default_blueprint) do
				Cry3menu._current_weapon_default_blueprint_set[v] = true 
			end
			-- mx_print_table(Cry3menu._current_weapon_default_blueprint_set)
			local categories = {}
			local submenus = {}
			for category, mod_ids in pairs(managers.weapon_factory:get_parts_from_weapon_id(name_id)) do
				log(tostring(mod_ids[1]))
				local is_only_default_stuff = #mod_ids == 1 and mod_ids[1] and Cry3menu._current_weapon_default_blueprint_set[mod_ids[1]] and true
				if not is_only_default_stuff then
					table.insert(categories, {
						-- Change color if it is part of current blueprint?
						text = managers.localization:text("bm_menu_"..category), 
						icon = {  
							texture = managers.menu_component:get_texture_from_mod_type(category, category),
							layer = 3,
							w = 16,
							h = 16,
							alpha = 1,
							color = Color(1,1,1)
						},
						stay_open = false,
						callback = callback(Cry3menu, Cry3menu, "openCategoryMenu", category)
					})
					local mods = {}
					for k, mod_name in ipairs(mod_ids) do
						local guis_catalog = "guis/"
						local bundle_folder = tweak_data.blackmarket.weapon_mods[mod_name] and tweak_data.blackmarket.weapon_mods[mod_name].texture_bundle_folder
						if bundle_folder then
							guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
						end
						local bitmap_texture = guis_catalog .. "textures/pd2/blackmarket/icons/mods/" .. mod_name
						local mod = tweak_data.blackmarket.weapon_mods[mod_name]
						if not mod.unatainable and not mod.dlc or managers.dlc:is_dlc_unlocked(mod.dlc) then
							-- if category == "ammo" then
							-- 	log(managers.localization:text(mod.name_id)..bitmap_texture)
							-- end
							table.insert(mods, {
								-- Change color if it is part of current blueprint?
								text = managers.localization:text(mod.name_id), 
								icon = { 
									texture = bitmap_texture, 
									layer = 3,
									w = 60,
									h = 32,
									alpha = 1,
									color = Color(1,1,1)
								},
								stay_open = true,
								callback = callback(Cry3menu,Cry3menu,"changeWeaponPart", { mod_name = mod_name, category = category })
							})
						end
					end
	
					local params = {
						name = category,
						items = mods,
						radius = 300
					}
					submenus[category] = RadialMouseMenu:new(params, callback(Cry3menu,Cry3menu, "SetMyRadialSubMenu"))
				end
			end
			
			local params = {
				name = "RadialAttachmentsMenu",
				-- radius = #categories > 6 and 50 * #categories or 300,
				items = categories --we'll use the items we created in Step 1 here
			}
		
			local my_radial_menu = RadialMouseMenu:new(params, callback(Cry3menu,Cry3menu,"SetMyRadialMenu"))
		end
	end)
end
