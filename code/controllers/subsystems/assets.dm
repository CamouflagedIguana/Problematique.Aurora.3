/var/datum/controller/subsystem/assets/SSassets

/datum/controller/subsystem/assets
	name = "Assets"
	init_order = SS_INIT_ASSETS
	flags = SS_NO_FIRE
	runlevels = RUNLEVELS_DEFAULT | RUNLEVEL_LOBBY
	var/list/datum/asset_cache_item/cache = list()
	var/list/preload = list()
	var/datum/asset_transport/transport = new()

/datum/controller/subsystem/assets/New()
	NEW_SS_GLOBAL(SSassets)

/datum/controller/subsystem/assets/Initialize()
	var/newtransporttype = /datum/asset_transport
	switch (config.asset_transport)
		if ("webroot")
			newtransporttype = /datum/asset_transport/webroot

	if (newtransporttype == transport.type)
		return

	var/datum/asset_transport/newtransport = new newtransporttype ()
	if (newtransport.validate_config())
		transport = newtransport

	transport.Load()

	for(var/type in typesof(/datum/asset))
		var/datum/asset/A = type
		if (type != initial(A._abstract))
			load_asset_datum(type)

	transport.Initialize(cache)

	. = ..()

/datum/controller/subsystem/assets/Recover()
	cache = SSassets.cache
	preload = SSassets.preload
