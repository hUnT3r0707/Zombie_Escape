#include <amxmodx>
#include <reapi>

#include <ze_core>
#include <ze_levels>
#include <ze_class_const>

// Libraries.
stock const LIBRARY_LEVELS[] = "ze_levels"
stock const LIBRARY_HUDINFO[] = "ze_hud_info"
stock const LIBRARY_KNOCKBACK[] = "ze_kb_system"
stock const LIBRARY_NEMESIS[] = "ze_class_nemesis"
stock const LIBRARY_WPNMODELS[] = "ze_weap_models_api"

// Macro.
#define FIsWrongClass(%0) (ZE_CLASS_INVALID>=(%0)>=g_iNumZombies)

// Menu Timeout
const ZE_MENU_TIMEOUT = 30   // -1 = No time.

// Constant.
const MAX_DESC_LENGTH = 64

// Zombie Attributes.
enum _:ZOMBIE_ATTRIB
{
	ZOMBIE_NAME[MAX_NAME_LENGTH] = 0,
	ZOMBIE_DESC[MAX_DESC_LENGTH],
	ZOMBIE_MODEL[MAX_NAME_LENGTH],
	ZOMBIE_MELEE[MAX_RESOURCE_PATH_LENGTH],
	Float:ZOMBIE_HEALTH,
	Float:ZOMBIE_SPEED,
	Float:ZOMBIE_GRAVITY,
	Float:ZOMBIE_KNOCKBACK,
	ZOMBIE_LEVEL
}

// Colors indexes.
enum _:Colors
{
	Red = 0,
	Green,
	Blue
}

enum _:TOTAL_FORWARDS
{
	FORWARD_SELECT_CLASS_PRE = 0,
	FORWARD_SELECT_CLASS_POST
}

// Default Zombie Attributes.
stock const DEFAULT_ZOMBIE_NAME[] = "Regular Zombie"
stock const DEFAULT_ZOMBIE_DESC[] = "-= Balanced =-"
stock const DEFAULT_ZOMBIE_MODEL[] = "terror"
stock const DEFAULT_ZOMBIE_MELEE[] = "models/v_knife.mdl"
stock const Float:DEFAULT_ZOMBIE_HEALTH = 10000.0
stock const Float:DEFAULT_ZOMBIE_SPEED = 320.0
stock const Float:DEFAULT_ZOMBIE_GRAVITY = 640.0
stock const Float:DEFAULT_ZOMBIE_KNOCKBACK = 200.0
stock const DEFAULT_ZOMBIE_LEVEL = 0

// Variable.
new g_iFwResult,
	g_iNumZombies

// Cvars.
new g_iHudColor[Colors]

// Arrays.
new g_iNext[MAX_PLAYERS+1],
	g_iPage[MAX_PLAYERS+1],
	g_iCurrent[MAX_PLAYERS+1],
	g_iForwards[TOTAL_FORWARDS]

// String.
new g_szText[64]

// Dynamic Array.
new Array:g_aZombieClass

public plugin_natives()
{
	register_library("ze_class_zombie")
	register_native("ze_zclass_register", "__native_zclass_register")
	register_native("ze_zclass_get_current", "__native_zclass_get_current")
	register_native("ze_zclass_get_next", "__native_zclass_get_next")
	register_native("ze_zclass_is_valid", "__native_zclass_is_valid")
	register_native("ze_zclass_get_name", "__native_zclass_get_name")
	register_native("ze_zclass_get_desc", "__native_zclass_get_desc")
	register_native("ze_zclass_get_model", "__native_zclass_get_model")
	register_native("ze_zclass_get_melee", "__native_zclass_get_melee")
	register_native("ze_zclass_get_health", "__native_zclass_get_health")
	register_native("ze_zclass_get_speed", "__native_zclass_get_speed")
	register_native("ze_zclass_get_gravity", "__native_zclass_get_gravity")
	register_native("ze_zclass_get_knockback", "__native_zclass_get_knockback")
	register_native("ze_zclass_get_level", "__native_zclass_get_level")
	register_native("ze_zclass_get_index", "__native_zclass_get_index")
	register_native("ze_zclass_set_current", "__native_zclass_set_current")
	register_native("ze_zclass_set_next", "__native_zclass_set_next")
	register_native("ze_zclass_set_name", "__native_zclass_set_name")
	register_native("ze_zclass_set_desc", "__native_zclass_set_desc")
	register_native("ze_zclass_set_health", "__native_zclass_set_health")
	register_native("ze_zclass_set_speed", "__native_zclass_set_speed")
	register_native("ze_zclass_set_gravity", "__native_zclass_set_gravity")
	register_native("ze_zclass_set_knockback", "__native_zclass_set_knockback")
	register_native("ze_zclass_set_level", "__native_zclass_set_level")
	register_native("ze_zclass_add_text", "__native_zclass_add_text")
	register_native("ze_zclass_show_menu", "__native_zclass_show_menu")

	set_module_filter("module_filter")
	set_native_filter("native_filter")

	// Create new dyn Array.
	g_aZombieClass = ArrayCreate(ZOMBIE_ATTRIB, 1)
}

public module_filter(const module[], LibType:libtype)
{
	if (equal(module, LIBRARY_NEMESIS) || equal(module, LIBRARY_HUDINFO) || equal(module, LIBRARY_KNOCKBACK) || equal(module, LIBRARY_WPNMODELS) || equal(module, LIBRARY_LEVELS))
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Class: Zombie", ZE_VERSION, ZE_AUTHORS)

	// Cvars.
	bind_pcvar_num(register_cvar("ze_hud_info_zombie_red", "255"), g_iHudColor[Red])
	bind_pcvar_num(register_cvar("ze_hud_info_zombie_green", "127"), g_iHudColor[Green])
	bind_pcvar_num(register_cvar("ze_hud_info_zombie_blue", "0"), g_iHudColor[Blue])

	// Create Forwards.
	g_iForwards[FORWARD_SELECT_CLASS_PRE] = CreateMultiForward("ze_select_zclass_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING, FP_STRING, FP_STRING, FP_FLOAT, FP_FLOAT, FP_FLOAT, FP_FLOAT, FP_CELL)
	g_iForwards[FORWARD_SELECT_CLASS_POST] = CreateMultiForward("ze_select_zclass_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_STRING, FP_STRING, FP_STRING, FP_FLOAT, FP_FLOAT, FP_FLOAT, FP_FLOAT, FP_CELL)

	// Commands.
	register_clcmd("say /zm", "cmd_ShowClassesMenu")
	register_clcmd("say_team /zm", "cmd_ShowClassesMenu")
	register_clcmd("say /zclass", "cmd_ShowClassesMenu")
	register_clcmd("say_team /zclass", "cmd_ShowClassesMenu")
}

public plugin_end()
{
	// Free the Memory.
	ArrayDestroy(g_aZombieClass)
	DestroyForward(g_iForwards[FORWARD_SELECT_CLASS_PRE])
	DestroyForward(g_iForwards[FORWARD_SELECT_CLASS_POST])
}

public plugin_cfg()
{
	if (!g_iNumZombies)
	{
		new aArray[ZOMBIE_ATTRIB]

		// Default Zombie.
		copy(aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME, DEFAULT_ZOMBIE_NAME)
		copy(aArray[ZOMBIE_DESC], charsmax(aArray) - ZOMBIE_DESC, DEFAULT_ZOMBIE_DESC)
		copy(aArray[ZOMBIE_MODEL], charsmax(aArray) - ZOMBIE_MODEL, DEFAULT_ZOMBIE_MODEL)
		copy(aArray[ZOMBIE_MELEE], charsmax(aArray) - ZOMBIE_MELEE, DEFAULT_ZOMBIE_MELEE)
		aArray[ZOMBIE_HEALTH] = DEFAULT_ZOMBIE_HEALTH
		aArray[ZOMBIE_SPEED] = DEFAULT_ZOMBIE_SPEED
		aArray[ZOMBIE_GRAVITY] = DEFAULT_ZOMBIE_GRAVITY
		aArray[ZOMBIE_KNOCKBACK] = DEFAULT_ZOMBIE_KNOCKBACK
		aArray[ZOMBIE_LEVEL] = DEFAULT_ZOMBIE_LEVEL

		// Copy Array on dyn Array.
		ArrayPushArray(g_aZombieClass, aArray)
		g_iNumZombies = 1
	}
}

public client_putinserver(id)
{
	// HLTV Proxy?
	if (is_user_hltv(id))
		return

	g_iCurrent[id] = ZE_CLASS_INVALID
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	// HLTV Proxy?
	if (is_user_hltv(id))
		return

	g_iPage[id] = 0
	g_iNext[id] = 0
	g_iCurrent[id] = 0
}

public cmd_ShowClassesMenu(const id)
{
	show_Zombies_Menu(id)
	return PLUGIN_CONTINUE
}

public ze_user_infected(iVictim, iInfector)
{
	// Ignore Nemesis!
	if (LibraryExists(LIBRARY_NEMESIS, LibType_Library) && ze_is_user_nemesis(iVictim)) return

	// Player hasn't chosen a class yet?
	if (g_iCurrent[iVictim] == ZE_CLASS_INVALID)
		RequestFrame("show_Zombies_Menu", iVictim)

	new iClassID = g_iNext[iVictim]

	// Get Zombie attributes.
	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, iClassID, aArray)

	// Call forward ze_select_class_pre(param1, param2, param3, param4, string5, string6, string7, string8, fparam9, fparam10, fparam11, fparam12, param13)
	ExecuteForward(g_iForwards[FORWARD_SELECT_CLASS_PRE], g_iFwResult, iVictim, iClassID, true, false, aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MELEE], aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], aArray[ZOMBIE_KNOCKBACK], aArray[ZOMBIE_LEVEL])

	if (g_iFwResult >= ZE_CLASS_UNAVAILABLE)
		return

	set_entvar(iVictim, var_health, aArray[ZOMBIE_HEALTH])
	set_entvar(iVictim, var_max_health, aArray[ZOMBIE_HEALTH])
	set_entvar(iVictim, var_gravity, (aArray[ZOMBIE_GRAVITY] / 800.0))

	ze_set_user_speed(iVictim, aArray[ZOMBIE_SPEED])

	if (LibraryExists(LIBRARY_KNOCKBACK, LibType_Library))
	{
		ze_set_zombie_knockback(iVictim, aArray[ZOMBIE_KNOCKBACK])
	}

	if (LibraryExists(LIBRARY_HUDINFO, LibType_Library))
	{
		ze_hud_info_set(iVictim, aArray[ZOMBIE_NAME], g_iHudColor)
	}

	rg_set_user_model(iVictim, aArray[ZOMBIE_MODEL], true)

	if (LibraryExists(LIBRARY_WPNMODELS, LibType_Library))
	{
		ze_set_user_view_model(iVictim, CSW_KNIFE, aArray[ZOMBIE_MELEE])
		ze_set_user_weap_model(iVictim, CSW_KNIFE)
	}

	// Call forward ze_select_class_post(param1, param2, param3, string4, string5, string6, string7, fparam8, fparam9, fparam10, fparam11, param12)
	ExecuteForward(g_iForwards[FORWARD_SELECT_CLASS_POST], _/* Ignore return value */, iVictim, iClassID, true, aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MELEE], aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], aArray[ZOMBIE_KNOCKBACK], aArray[ZOMBIE_LEVEL])
	g_iCurrent[iVictim] = iClassID
}

public show_Zombies_Menu(const id)
{
	new szLang[MAX_MENU_LENGTH], iLevel

	// Title.
	formatex(szLang, charsmax(szLang), "\r%L \y%L:", LANG_PLAYER, "MENU_PREFIX", LANG_PLAYER, "MENU_ZOMBIES_TITLE")
	new iMenu = menu_create(szLang, "handler_Zombies_Menu")
	new fLevel = LibraryExists(LIBRARY_LEVELS, LibType_Library)

	if (fLevel)
		iLevel = ze_get_user_level(id)

	for (new aArray[ZOMBIE_ATTRIB], iItemData[2], i = 0; i < g_iNumZombies; i++)
	{
		g_szText = NULL_STRING
		ArrayGetArray(g_aZombieClass, i, aArray)

		// Call forward ze_select_class_pre(param1, param2, param3, param4, string5, string6, string7, string8, fparam9, fparam10, fparam11, fparam12, param13)
		ExecuteForward(g_iForwards[FORWARD_SELECT_CLASS_PRE], g_iFwResult, id, i, false, true, aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MELEE], aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], aArray[ZOMBIE_KNOCKBACK], aArray[ZOMBIE_LEVEL])

		if (g_iFwResult >= ZE_CLASS_DONT_SHOW)
			continue

		// ML: Name.
		if (GetLangTransKey(aArray[ZOMBIE_NAME]) != TransKey_Bad)
			formatex(aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME, "%L", LANG_PLAYER, aArray[ZOMBIE_NAME])

		// ML: Description.
		if (GetLangTransKey(aArray[ZOMBIE_DESC]) != TransKey_Bad)
			formatex(aArray[ZOMBIE_DESC], charsmax(aArray) - ZOMBIE_DESC, "%L", LANG_PLAYER, aArray[ZOMBIE_DESC])

		if (g_iFwResult == ZE_ITEM_UNAVAILABLE)
			formatex(szLang, charsmax(szLang), "\d%s • %s%s", aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], g_szText)
		else if (fLevel && iLevel < aArray[ZOMBIE_LEVEL])
			formatex(szLang, charsmax(szLang), "\d%s • %s%s \r[\r%L\d: \y%i\r]", aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], g_szText, LANG_PLAYER, "MENU_LEVEL", aArray[ZOMBIE_LEVEL])
		else if (i == g_iCurrent[id])
			formatex(szLang, charsmax(szLang), "\w%s \d• \y%s%s \d[\r%L\d]", aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], g_szText, LANG_PLAYER, "CURRENT")
		else if (i == g_iNext[id])
			formatex(szLang, charsmax(szLang), "\w%s \d• \y%s%s \d[\r%L\d]", aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], g_szText, LANG_PLAYER, "NEXT")
		else
			formatex(szLang, charsmax(szLang), "\w%s \d• \y%s%s", aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], g_szText)

		iItemData[0] = i
		iItemData[1] = 0

		menu_additem(iMenu, szLang, iItemData)
	}

	// Next, Back, Exit.
	formatex(szLang, charsmax(szLang), "%L", LANG_PLAYER, "NEXT")
	menu_setprop(iMenu, MPROP_NEXTNAME, szLang)
	formatex(szLang, charsmax(szLang), "%L", LANG_PLAYER, "BACK")
	menu_setprop(iMenu, MPROP_BACKNAME, szLang)
	formatex(szLang, charsmax(szLang), "%L", LANG_PLAYER, "EXIT")
	menu_setprop(iMenu, MPROP_EXITNAME, szLang)

	// Show the Menu for player.
	menu_display(id, iMenu, g_iPage[id], ZE_MENU_TIMEOUT)
}

public handler_Zombies_Menu(const id, iMenu, iKey)
{
	switch (iKey)
	{
		case MENU_TIMEOUT, MENU_EXIT:
		{
			goto CloseMenu
		}
		default:
		{
			new iItemData[2]
			menu_item_getinfo(iMenu, iKey, .info = iItemData, .infolen = charsmax(iItemData))
			new i = iItemData[0]

			if (assign_PlayerClassID(id, i))
				g_iPage[id] = iKey / 7
		}
	}

	CloseMenu:
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public assign_PlayerClassID(const id, iClassID)
{
	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, iClassID, aArray)

	// Call forward ze_select_class_pre(param1, param2, param3, param4, string5, string6, string7, string8, fparam9, fparam10, fparam11, fparam12, param13)
	ExecuteForward(g_iForwards[FORWARD_SELECT_CLASS_PRE], g_iFwResult, id, iClassID, false, false, aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MELEE], aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], aArray[ZOMBIE_KNOCKBACK], aArray[ZOMBIE_LEVEL])

	if (g_iFwResult >= ZE_STOP)
		return 0

	if (LibraryExists(LIBRARY_LEVELS, LibType_Library) && ze_get_user_level(id) < aArray[ZOMBIE_LEVEL])
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_LVL_NOT_ENOUGH")
		return 0
	}

	// Call forward ze_select_class_post(param1, param2, param3, string4, string5, string6, string7, fparam8, fparam9, fparam10, fparam11, param12)
	ExecuteForward(g_iForwards[FORWARD_SELECT_CLASS_POST], _/* Ignore return value */, id, iClassID, false, aArray[ZOMBIE_NAME], aArray[ZOMBIE_DESC], aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MELEE], aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], aArray[ZOMBIE_KNOCKBACK], aArray[ZOMBIE_LEVEL])
	g_iNext[id] = iClassID

	// Name.
	if (GetLangTransKey(aArray[ZOMBIE_NAME]) != TransKey_Bad)
		formatex(aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME, "%L", LANG_PLAYER, aArray[ZOMBIE_NAME])

	// Send colored message on chat for player.
	ze_colored_print(id, "%L", LANG_PLAYER, "MSG_ZOMBIE_NAME", aArray[ZOMBIE_NAME])
	ze_colored_print(id, "%L", LANG_PLAYER, "MSG_ZOMBIE_INFO", aArray[ZOMBIE_HEALTH], aArray[ZOMBIE_SPEED], aArray[ZOMBIE_GRAVITY], (aArray[ZOMBIE_KNOCKBACK] / MAX_KNOCKBACK) * 100.0)
	return 1
}

/**
 * -=| Natives |=-
 */
public __native_zclass_register(const plugin_id, const num_params)
{
	new szName[MAX_NAME_LENGTH]
	if (!get_string(1, szName, charsmax(szName)))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Can't register new class without name.")
		return ZE_CLASS_INVALID
	}

	new aArray[ZOMBIE_ATTRIB]
	for (new i = 0; i < g_iNumZombies; i++)
	{
		ArrayGetArray(g_aZombieClass, i, aArray)

		if (equal(szName, aArray[ZOMBIE_NAME]))
		{
			log_error(AMX_ERR_NATIVE, "[ZE] Can't register new class with exist name.")
			return ZE_CLASS_INVALID
		}
	}

	if (!ini_read_string(ZE_FILENAME_ZCLASS, szName, "NAME", aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME))
	{
		copy(aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME, szName)
		ini_write_string(ZE_FILENAME_ZCLASS, szName, "NAME", aArray[ZOMBIE_NAME])
	}

	if (!ini_read_string(ZE_FILENAME_ZCLASS, szName, "DESC", aArray[ZOMBIE_DESC], charsmax(aArray) - ZOMBIE_DESC))
	{
		get_string(2, aArray[ZOMBIE_DESC], charsmax(aArray) - ZOMBIE_DESC)
		ini_write_string(ZE_FILENAME_ZCLASS, szName, "DESC", aArray[ZOMBIE_DESC])
	}

	if (!ini_read_string(ZE_FILENAME_ZCLASS, szName, "MODEL", aArray[ZOMBIE_MODEL], charsmax(aArray) - ZOMBIE_MODEL))
	{
		get_string(3, aArray[ZOMBIE_MODEL], charsmax(aArray) - ZOMBIE_MODEL)
		ini_write_string(ZE_FILENAME_ZCLASS, szName, "MODEL", aArray[ZOMBIE_MODEL])
	}

	if (!ini_read_string(ZE_FILENAME_ZCLASS, szName, "MELEE", aArray[ZOMBIE_MELEE], charsmax(aArray) - ZOMBIE_MELEE))
	{
		get_string(4, aArray[ZOMBIE_MELEE], charsmax(aArray) - ZOMBIE_MELEE)
		ini_write_string(ZE_FILENAME_ZCLASS, szName, "MELEE", aArray[ZOMBIE_MELEE])
	}

	if (!ini_read_float(ZE_FILENAME_ZCLASS, szName, "HEALTH", aArray[ZOMBIE_HEALTH]))
	{
		aArray[ZOMBIE_HEALTH] = get_param_f(5)
		ini_write_float(ZE_FILENAME_ZCLASS, szName, "HEALTH", aArray[ZOMBIE_HEALTH])
	}

	if (!ini_read_float(ZE_FILENAME_ZCLASS, szName, "SPEED", aArray[ZOMBIE_SPEED]))
	{
		aArray[ZOMBIE_SPEED] = get_param_f(6)
		ini_write_float(ZE_FILENAME_ZCLASS, szName, "SPEED", aArray[ZOMBIE_SPEED])
	}

	if (!ini_read_float(ZE_FILENAME_ZCLASS, szName, "GRAVITY", aArray[ZOMBIE_GRAVITY]))
	{
		aArray[ZOMBIE_GRAVITY] = get_param_f(7)
		ini_write_float(ZE_FILENAME_ZCLASS, szName, "GRAVITY", aArray[ZOMBIE_GRAVITY])
	}

	if (!ini_read_float(ZE_FILENAME_ZCLASS, szName, "KNOCKBACK", aArray[ZOMBIE_KNOCKBACK]))
	{
		aArray[ZOMBIE_KNOCKBACK] = get_param_f(8)
		ini_write_float(ZE_FILENAME_ZCLASS, szName, "KNOCKBACK", aArray[ZOMBIE_KNOCKBACK])
	}

	if (!ini_read_int(ZE_FILENAME_ZCLASS, szName, "LEVEL", aArray[ZOMBIE_LEVEL]))
	{
		aArray[ZOMBIE_LEVEL] = get_param(9)
		ini_write_int(ZE_FILENAME_ZCLASS, szName, "LEVEL", aArray[ZOMBIE_LEVEL])
	}

	new szModel[MAX_RESOURCE_PATH_LENGTH]

	// Precache Models.
	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MODEL])
	precache_model(szModel)
	formatex(szModel, charsmax(szModel), "models/player/%s/%sT.mdl", aArray[ZOMBIE_MODEL], aArray[ZOMBIE_MODEL])
	if (file_exists(szModel, true))
		precache_model(szModel) // For FastDL.
	precache_model(aArray[ZOMBIE_MELEE])

	// Copy array on dyn Array.
	ArrayPushArray(g_aZombieClass, aArray)
	return ++g_iNumZombies - 1
}

public __native_zclass_get_current(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return ZE_CLASS_INVALID
	}

	return g_iCurrent[id]
}

public __native_zclass_get_next(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return ZE_CLASS_INVALID
	}

	return g_iNext[id]
}

public __native_zclass_is_valid(const plugin_id, const num_params)
{
	if (FIsWrongClass(get_param(1)))
		return false
	return true
}

public __native_zclass_get_name(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return 0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)

	// Copy Name on new Buffer.
	return set_string(2, aArray[ZOMBIE_NAME], get_param(3))
}

public __native_zclass_get_desc(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return 0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)

	// Copy Name on new Buffer.
	return set_string(2, aArray[ZOMBIE_DESC], get_param(3))
}

public __native_zclass_get_model(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return 0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)

	// Copy Name on new Buffer.
	return set_string(2, aArray[ZOMBIE_MODEL], get_param(3))
}

public __native_zclass_get_melee(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)

	// Copy Name on new Buffer.
	set_string(2, aArray[ZOMBIE_MELEE], get_param(3))
	return true
}

public Float:__native_zclass_get_health(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return -1.0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	return aArray[ZOMBIE_HEALTH]
}

public Float:__native_zclass_get_speed(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return -1.0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	return aArray[ZOMBIE_SPEED]
}

public Float:__native_zclass_get_gravity(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return -1.0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	return aArray[ZOMBIE_GRAVITY]
}

public Float:__native_zclass_get_knockback(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return -1.0
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	return aArray[ZOMBIE_KNOCKBACK]
}

public __native_zclass_get_level(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return ZE_CLASS_INVALID
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	return aArray[ZOMBIE_LEVEL]
}

public __native_zclass_get_index(const plugin_id, const num_params)
{
	new szName[MAX_NAME_LENGTH]
	if (!get_string(1, szName, charsmax(szName)))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Can't search class index without name !")
		return ZE_CLASS_INVALID
	}

	for (new aArray[ZOMBIE_ATTRIB], i = 0; i < g_iNumZombies; i++)
	{
		ArrayGetArray(g_aZombieClass, i, aArray)
		if (equal(szName, aArray[ZOMBIE_NAME]))
			return i
	}

	return ZE_CLASS_INVALID
}

public __native_zclass_set_current(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	new i = get_param(2)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	g_iCurrent[id] = i

	if (get_param(3))
	{
		ze_set_user_zombie(id)
	}

	return true
}

public __native_zclass_set_next(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	new i = get_param(2)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	g_iNext[id] = i
	return true
}

public __native_zclass_set_name(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	get_string(2, aArray[ZOMBIE_NAME], charsmax(aArray) - ZOMBIE_NAME)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_desc(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	get_string(2, aArray[ZOMBIE_DESC], charsmax(aArray) - ZOMBIE_DESC)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_health(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	aArray[ZOMBIE_HEALTH] = get_param_f(2)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_speed(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	aArray[ZOMBIE_SPEED] = get_param_f(2)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_gravity(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	aArray[ZOMBIE_GRAVITY] = get_param_f(2)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_knockback(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	aArray[ZOMBIE_KNOCKBACK] = get_param_f(2)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_set_level(const plugin_id, const num_params)
{
	new i = get_param(1)

	if (FIsWrongClass(i))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Class ID (%d)", i)
		return false
	}

	new aArray[ZOMBIE_ATTRIB]
	ArrayGetArray(g_aZombieClass, i, aArray)
	aArray[ZOMBIE_LEVEL] = get_param(2)
	ArraySetArray(g_aZombieClass, i, aArray)
	return true
}

public __native_zclass_add_text(const plugin_id, const num_params)
{
	get_string(1, g_szText, charsmax(g_szText))
	return vdformat(g_szText, charsmax(g_szText), 1, 2)
}

public __native_zclass_show_menu(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	show_Zombies_Menu(id)
	return true
}