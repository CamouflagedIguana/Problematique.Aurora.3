/obj/item/tank
	name = "tank"
	icon = 'icons/obj/tank.dmi'
	contained_sprite = TRUE
	drop_sound = 'sound/items/drop/gascan.ogg'
	pickup_sound = 'sound/items/pickup/gascan.ogg'

	var/gauge_icon = "indicator_tank"
	var/last_gauge_pressure
	var/gauge_cap = 6

	flags = CONDUCT
	slot_flags = SLOT_BACK
	w_class = ITEMSIZE_NORMAL

	force = 5.0
	throwforce = 10.0
	throw_speed = 1
	throw_range = 4

	var/datum/gas_mixture/air_contents = null
	var/distribute_pressure = ONE_ATMOSPHERE
	var/integrity = 3
	var/volume = 70
	var/manipulated_by = null		//Used by _onclick/hud/screen_objects.dm internals to determine if someone has messed with our tank or not.
						//If they have and we haven't scanned it with a computer or handheld gas analyzer then we might just breath whatever they put in it.

/obj/item/tank/Initialize()
	. = ..()

	air_contents = new /datum/gas_mixture()
	air_contents.volume = volume //liters
	air_contents.temperature = T20C

	START_PROCESSING(SSprocessing, src)
	adjust_initial_gas()
	update_gauge()

/obj/item/tank/Destroy()
	QDEL_NULL(air_contents)

	STOP_PROCESSING(SSprocessing, src)

	if(istype(loc, /obj/item/device/transfer_valve))
		var/obj/item/device/transfer_valve/TTV = loc
		TTV.remove_tank(src)

	return ..()

/obj/item/tank/examine(mob/user, distance, is_adjacent)
	. = ..()
	if(distance <= 0)
		var/celsius_temperature = air_contents.temperature - T0C
		var/descriptive
		switch(celsius_temperature)
			if(300 to INFINITY)
				descriptive = "furiously hot"
			if(100 to 300)
				descriptive = "hot"
			if(80 to 100)
				descriptive = "warm"
			if(40 to 80)
				descriptive = "lukewarm"
			if(20 to 40)
				descriptive = "room temperature"
			else
				descriptive = "cold"
		to_chat(user, "<span class='notice'>\The [src] feels [descriptive].</span>")

/obj/item/tank/attackby(obj/item/W as obj, mob/user as mob)
	..()
	if ((istype(W, /obj/item/device/analyzer)) && get_dist(user, src) <= 1)
		var/obj/item/device/analyzer/A = W
		A.analyze_gases(src, user)

	if (istype(W, /obj/item/toy/balloon))
		var/obj/item/toy/balloon/B = W
		B.blow(src)
		src.add_fingerprint(user)

	if(istype(W, /obj/item/device/assembly_holder))
		bomb_assemble(W,user)

/obj/item/tank/attack_self(mob/user as mob)
	if (!(src.air_contents))
		return

	ui_interact(user)

/obj/item/tank/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Tank", ui_x=400, ui_y=180)
		ui.open()

/obj/item/tank/ui_host(mob/user)
	. = ..()
	if(istype(loc,/obj/item/device/transfer_valve))
		return loc

/obj/item/tank/ui_data(mob/user)
	var/mob/living/carbon/location = null

	if(istype(loc, /obj/item/rig))
		if(istype(loc.loc, /mob/living/carbon))
			location = loc.loc
	else if(istype(loc, /mob/living/carbon))
		location = loc

	var/using_internal
	if(istype(location))
		if(location.internal==src)
			using_internal = 1

	var/list/data = list()

	data["tankPressure"] = round(air_contents.return_pressure() ? air_contents.return_pressure() : 0)
	data["releasePressure"] = round(distribute_pressure ? distribute_pressure : 0)
	data["defaultReleasePressure"] = round(TANK_DEFAULT_RELEASE_PRESSURE)
	data["maxReleasePressure"] = round(TANK_MAX_RELEASE_PRESSURE)
	data["valveOpen"] = using_internal ? 1 : 0

	data["maskConnected"] = 0

	if(istype(location))
		var/mask_check = 0

		if(location.internal == src)	// if tank is current internal
			mask_check = 1
		else if(src in location)		// or if tank is in the mobs possession
			if(!location.internal)		// and they do not have any active internals
				mask_check = 1
		else if(istype(src.loc, /obj/item/rig) && (src.loc in location))	// or the rig is in the mobs possession
			if(!location.internal)		// and they do not have any active internals
				mask_check = 1

		if(mask_check)
			if(location.wear_mask && (location.wear_mask.item_flags & AIRTIGHT))
				data["maskConnected"] = 1
			else if(istype(location, /mob/living/carbon/human))
				var/mob/living/carbon/human/H = location
				if(H.head && (H.head.item_flags & AIRTIGHT))
					data["maskConnected"] = 1

	return data

/obj/item/tank/ui_act(action,params)
	. = ..()
	if(.)
		return
	if(action=="toggleReleaseValve")
		if(istype(loc,/mob/living/carbon))
			var/mob/living/carbon/location = loc
			if(location.internal == src)
				location.internal = null
				location.internals.icon_state = "internal0"
				to_chat(usr, "<span class='notice'>You close the tank release valve.</span>")
				if (location.internals)
					location.internals.icon_state = "internal0"
			else
				var/can_open_valve
				if(location.wear_mask && (location.wear_mask.item_flags & AIRTIGHT))
					can_open_valve = 1
				else if(istype(location,/mob/living/carbon/human))
					var/mob/living/carbon/human/H = location
					if(H.head && (H.head.item_flags & AIRTIGHT))
						can_open_valve = 1

				if(can_open_valve)
					location.internal = src
					to_chat(usr, "<span class='notice'>You open \the [src] valve.</span>")
					if (location.internals)
						location.internals.icon_state = "internal1"
				else
					to_chat(usr, "<span class='warning'>You need something to connect to \the [src].</span>")
			. = TRUE
			update_icon()
	if(action=="setReleasePressure")
		distribute_pressure = min(max(round(text2num(params["release_pressure"])), 0), TANK_MAX_RELEASE_PRESSURE)
		. = TRUE

/obj/item/tank/remove_air(amount)
	return air_contents.remove(amount)

/obj/item/tank/return_air()
	return air_contents

/obj/item/tank/assume_air(datum/gas_mixture/giver)
	air_contents.merge(giver)

	check_status()
	return 1

/obj/item/tank/proc/remove_air_volume(volume_to_return)
	if(!air_contents)
		return null

	var/tank_pressure = air_contents.return_pressure()
	if(tank_pressure < distribute_pressure)
		distribute_pressure = tank_pressure

	var/moles_needed = distribute_pressure*volume_to_return/(R_IDEAL_GAS_EQUATION*air_contents.temperature)

	return remove_air(moles_needed)

/obj/item/tank/process()
	//Allow for reactions
	air_contents.react() //cooking up air tanks - add phoron and oxygen, then heat above PHORON_MINIMUM_BURN_TEMPERATURE
	if(gauge_icon)
		update_gauge()
	check_status()

/obj/item/tank/proc/adjust_initial_gas()
	return

/obj/item/tank/proc/update_gauge()
	var/gauge_pressure = 0
	if(air_contents)
		gauge_pressure = air_contents.return_pressure()
		if(gauge_pressure > TANK_IDEAL_PRESSURE)
			gauge_pressure = -1
		else
			gauge_pressure = round((gauge_pressure/TANK_IDEAL_PRESSURE)*gauge_cap)

	if(gauge_pressure == last_gauge_pressure)
		return

	last_gauge_pressure = gauge_pressure
	cut_overlays()
	// SSoverlay will handle icon caching.
	add_overlay("[gauge_icon][(gauge_pressure == -1) ? "overload" : gauge_pressure]")

/obj/item/tank/proc/percent()
	var/gauge_pressure = 0
	if(air_contents)
		gauge_pressure = air_contents.return_pressure()
	return 100.0*gauge_pressure/TANK_IDEAL_PRESSURE

/obj/item/tank/proc/check_status()
	//Handle exploding, leaking, and rupturing of the tank

	if(!air_contents)
		return 0

	var/pressure = air_contents.return_pressure()
	if(pressure > TANK_FRAGMENT_PRESSURE)
		if(!istype(src.loc,/obj/item/device/transfer_valve))
			message_admins("Explosive tank rupture! last key to touch the tank was [src.fingerprintslast].")
			log_game("Explosive tank rupture! last key to touch the tank was [src.fingerprintslast].")

		//Give the gas a chance to build up more pressure through reacting
		air_contents.react()
		air_contents.react()
		air_contents.react()

		pressure = air_contents.return_pressure()
		var/range = (pressure-TANK_FRAGMENT_PRESSURE)/TANK_FRAGMENT_SCALE

		explosion(
			get_turf(loc),
			round(min(BOMBCAP_DVSTN_RADIUS, range*0.25)),
			round(min(BOMBCAP_HEAVY_RADIUS, range*0.50)),
			round(min(BOMBCAP_LIGHT_RADIUS, range*1.00)),
			round(min(BOMBCAP_FLASH_RADIUS, range*1.50))
			)
		qdel(src)

	else if(pressure > TANK_RUPTURE_PRESSURE)
		#ifdef FIREDBG
		LOG_DEBUG("<span class='warning'>[x],[y] tank is rupturing: [pressure] kPa, integrity [integrity]</span>")
		#endif

		if(integrity <= 0)
			var/turf/simulated/T = get_turf(src)
			if(!T)
				return
			T.assume_air(air_contents)
			playsound(src.loc, 'sound/effects/spray.ogg', 10, 1, -3)
			qdel(src)
		else
			integrity--

	else if(pressure > TANK_LEAK_PRESSURE)
		#ifdef FIREDBG
		LOG_DEBUG("<span class='warning'>[x],[y] tank is leaking: [pressure] kPa, integrity [integrity]</span>")
		#endif

		if(integrity <= 0)
			var/turf/simulated/T = get_turf(src)
			if(!T)
				return
			var/datum/gas_mixture/leaked_gas = air_contents.remove_ratio(0.25)
			T.assume_air(leaked_gas)
		else
			integrity--

	else if(integrity < 3)
		integrity++

/obj/item/tank/proc/remove_air_by_flag(flag, amount)
	. = air_contents.remove_by_flag(flag, amount)
	update_icon()
