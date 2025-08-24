#include <amxmodx>
#include <amxmisc>
#include <reapi>

#include <ze_core>
#include <ze_levels>

// Libraries.
stock const LIBRARY_LEVEL[] = "ze_levels"

// Defines.
#define MN_AUTO_SELECT 7
#define MN_NEXT_BACK 8
#define MN_EXIT 9

#define CS_MENU_DELAY 0.5  // float.

// Keys Menu.
const KEYS_MENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

// Weapon Data.
enum _:WPN_DATA
{
	WPN_CUSTOM = 0,
	WPN_NAME[MAX_NAME_LENGTH],
	WPN_CLASS[MAX_NAME_LENGTH],
	WPN_AMMO,
	WPN_LEVEL
}

// Weapon Section.
enum (+=1)
{
	SECTION_NONE = 0,
	SECTION_PRIMARY,
	SECTION_SECONDARY,
	SECTION_ADDITIONAL
}

// Grenades.
enum _:GRENADES
{
	FB = 0,
	HE,
	SG
}

enum _:MENU_DATA
{
	MD_PRI_PAGE = 0,
	MD_SEC_PAGE,
	MD_PREV_PRIMARY,
	MD_PREV_SECONDARY,
	bool:MD_AUTO_SELECT,
	bool:MD_PRIMARY_CHOSEN,
	bool:MD_SECONDARY_CHOSEN,
	Float:MD_BUY_TIME
}

// Primary Weapons Name.
new const g_szDefPrimaryWpn[][WPN_DATA] =
{
	{0, "Famas", "weapon_famas"},
	{0, "Galil", "weapon_galil"},
	{0, "AK-47 Kalashnikov", "weapon_ak47"},
	{0, "M4A1 Carbine", "weapon_m4a1"},
	{0, "SG-552 Commando", "weapon_sg552"},
	{0, "Aug", "weapon_aug"},
	{0, "M3 Shotgun", "weapon_m3"},
	{0, "XM1014 Auto", "weapon_xm1014"},
	{0, "TMP 9mm", "weapon_tmp"},
	{0, "Mac-10", "weapon_mac10"},
	{0, "MP5 Navy 9mm", "weapon_mp5navy"},
	{0, "P90", "weapon_p90"},
	{0, "SG-550 Auto", "weapon_sg550"},
	{0, "G3SG1 Auto", "weapon_g3sg1"},
	{0, "Scout Sniper", "weapon_scout"},
	{0, "AWP Heavy Sniper", "weapon_awp"},
	{0, "M249 Machine Gun", "weapon_m249"}
}

// Secondary Weapons Name.
new const g_szDefSecondaryWpn[][WPN_DATA] =
{
	{0, "Glock-18", "weapon_glock18"},
	{0, "USP", "weapon_usp"},
	{0, "P-228", "weapon_p228"},
	{0, "Desert Eagle", "weapon_deagle"},
	{0, "Five-SeveN", "weapon_fiveseven"},
	{0, "Dual Elite", "weapon_elite"}
}

// Cvars.
new g_iBuyTime,
	bool:g_bGiveItems,
	g_iGiveNades[GRENADES]

// Variables.
new g_iPrimaryNum,
	g_iSecondaryNum,
	g_iAdditionalNum

// Array.
new g_iMenuData[MAX_PLAYERS+1][MENU_DATA]

// Dynamic Array.
new Array:g_aPrimaryWeapons,
	Array:g_aSecondaryWeapons,
	Array:g_aAdditionalWeapons

// XVar (Public Variables).
public x_bWeaponsDisabled = 0;

public plugin_natives()
{
	register_library("ze_weapons_menu")
	register_native("ze_auto_buy_enabled", "__native_auto_buy_enabled")
	register_native("ze_set_auto_buy", "__native_set_auto_buy")
	register_native("ze_show_weapons_menu", "__native_show_weapons_menu")

	set_module_filter("fw_module_filter")
	set_native_filter("fw_native_filter")
}

public fw_module_filter(const module[], LibType:type)
	return equal(module, LIBRARY_LEVEL) ? PLUGIN_HANDLED : PLUGIN_CONTINUE

public fw_native_filter(const name[], index, trap)
	return !trap ? PLUGIN_HANDLED : PLUGIN_CONTINUE

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Weapons Menu", ZE_VERSION, ZE_AUTHORS)

	// Cvars.
	bind_pcvar_num(register_cvar("ze_buy_time", "60"), g_iBuyTime)
	bind_pcvar_num(register_cvar("ze_additional_items", "1"), g_bGiveItems)
	bind_pcvar_num(register_cvar("ze_give_FB_amount", "1"), g_iGiveNades[FB])
	bind_pcvar_num(register_cvar("ze_give_HE_amount", "1"), g_iGiveNades[HE])
	bind_pcvar_num(register_cvar("ze_give_SG_amount", "1"), g_iGiveNades[SG])

	// Commands.
	register_clcmd("say /guns", "cmd_WeaponsMenu")
	register_clcmd("say_team /guns", "cmd_WeaponsMenu")

	// Create new dyn Array.
	g_aPrimaryWeapons = ArrayCreate(WPN_DATA, 20)
	g_aSecondaryWeapons = ArrayCreate(WPN_DATA, 10)
	g_aAdditionalWeapons = ArrayCreate(WPN_DATA, 5)

	// New Menu's.
	register_menu("Primary_Weapons_Menu", KEYS_MENU, "handler_Primary_Weapons")
	register_menu("Secondary_Weapons_Menu", KEYS_MENU, "handler_Secondary_Weapons")
}

public plugin_cfg()
{
	new szFile[MAX_RESOURCE_PATH_LENGTH]

	// Get configs directory.
	new iLen = get_configsdir(szFile, charsmax(szFile))

	// Get full file path.
	formatex(szFile[iLen], charsmax(szFile) - iLen, "/%s.ini", ZE_FILENAME)

	// Read Weapons.
	read_Weapons(szFile)
}

public plugin_end()
{
	// Free the Memory.
	ArrayDestroy(g_aPrimaryWeapons)
	ArrayDestroy(g_aSecondaryWeapons)
	ArrayDestroy(g_aAdditionalWeapons)
}

public client_putinserver(id)
{
	if (is_user_hltv(id))
		return

	g_iMenuData[id][MD_PREV_PRIMARY] = INVALID_HANDLE
	g_iMenuData[id][MD_PREV_SECONDARY] = INVALID_HANDLE
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return

	// Reset cell in Array.
	for (new i = 0; i < MENU_DATA; i++)
	{
		g_iMenuData[id][i] = 0
	}
}

/*
public cmd_Rebuy(id)
{
	// Player not Alive?
	if (!is_user_alive(id))
		return PLUGIN_HANDLED

	// Zombie?
	if (ze_is_user_zombie(id))
		return PLUGIN_HANDLED

	new i

	if ((i = g_iMenuData[id][MD_PREV_PRIMARY]) != INVALID_HANDLE)
		choose_Weapon(id, i, SECTION_PRIMARY)

	if ((i = g_iMenuData[id][MD_PREV_SECONDARY]) != INVALID_HANDLE)
		choose_Weapon(id, i, SECTION_SECONDARY)

	// Hide Menu.
	show_menu(id, 0, "\n", 0)
	return PLUGIN_CONTINUE
}
*/

public cmd_WeaponsMenu(id)
{
	if (x_bWeaponsDisabled)
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_WEAPONS_DISABLED")
		return PLUGIN_HANDLED
	}

	// Player not Alive?
	if (!is_user_alive(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT_ALIVE")
		return PLUGIN_HANDLED
	}

	// Player is Zombie?
	if (ze_is_user_zombie(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_CANT_BUY_WEAPON")
		return PLUGIN_HANDLED
	}

	// Buy time over?
	if (g_iBuyTime > 0)
	{
		if (g_iMenuData[id][MD_BUY_TIME] <= get_gametime())
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "MSG_BUYTIME_OVER")
			return PLUGIN_HANDLED
		}
	}

	show_Available_Menu(id)
	return PLUGIN_CONTINUE
}

public ze_user_humanized(id)
{
	g_iMenuData[id][MD_PRIMARY_CHOSEN] = false
	g_iMenuData[id][MD_SECONDARY_CHOSEN] = false

	if (g_iMenuData[id][MD_AUTO_SELECT])
	{
		new i

		if ((i = g_iMenuData[id][MD_PREV_PRIMARY]) != INVALID_HANDLE)
			choose_Weapon(id, i, SECTION_PRIMARY)

		if ((i = g_iMenuData[id][MD_PREV_SECONDARY]) != INVALID_HANDLE)
			choose_Weapon(id, i, SECTION_SECONDARY)
	}
	else
	{
		set_task(CS_MENU_DELAY, "show_Available_Menu", id) // Delay before display Menu for Human.
		g_iMenuData[id][MD_BUY_TIME] = get_gametime() + g_iBuyTime
	}

	if (g_iGiveNades[FB] > 0)
	{
		rg_give_item(id, "weapon_flashbang", GT_APPEND)
		if (g_iGiveNades[FB] > 1)
			rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_iGiveNades[FB])
	}

	if (g_iGiveNades[HE] > 0)
	{
		rg_give_item(id, "weapon_hegrenade", GT_APPEND)
		if (g_iGiveNades[HE] > 1)
			rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_iGiveNades[HE])
	}

	if (g_iGiveNades[SG] > 0)
	{
		rg_give_item(id, "weapon_smokegrenade", GT_APPEND)
		if (g_iGiveNades[SG] > 1)
			rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_iGiveNades[SG])
	}

	if (g_bGiveItems)
	{
		new iLevel
		new const fLevels = LibraryExists(LIBRARY_LEVEL, LibType_Library)

		if (fLevels)  // Player level.
			iLevel = ze_get_user_level(id)

		for (new pArray[WPN_DATA], pItem, i = 0; i < g_iAdditionalNum; i++)
		{
			ArrayGetArray(g_aAdditionalWeapons, i, pArray)

			if (fLevels && iLevel < pArray[WPN_LEVEL])
				continue

			if ((pItem = rg_give_custom_item(id, pArray[WPN_CLASS], GT_APPEND, pArray[WPN_CUSTOM])) == NULLENT)
			{
				log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ClassName ^'%s^'", pArray[WPN_CLASS])
			}
			else
			{
				if (pArray[WPN_AMMO] > NULLENT)
				{
					rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, pArray[WPN_AMMO])
					rg_set_user_bpammo(id, WeaponIdType:get_weaponid(pArray[WPN_CLASS]), pArray[WPN_AMMO])
				}
			}
		}
	}
}

public show_Available_Menu(id)
{
	if (!is_user_alive(id) || ze_is_user_zombie(id)) // For safe and avoid bugs.
		return

	if (!g_iMenuData[id][MD_PRIMARY_CHOSEN])
		show_Primary_Weapons(id)
	else if (!g_iMenuData[id][MD_SECONDARY_CHOSEN])
		show_Secondary_Weapons(id)
	else
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_ALREADY_BOUGHT")
}

public show_Primary_Weapons(id)
{
	new szMenu[MAX_MENU_LENGTH], pArray[WPN_DATA], iLevel, iLen

	// Menu Title.
	iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L \y%L\d:^n^n", LANG_PLAYER, "MENU_PREFIX", LANG_PLAYER, "MENU_PRIMARY_TITLE")

	// Get number of weapons on page.
	new const iWpn = g_iMenuData[id][MD_PRI_PAGE]
	new const iMaxLoops = min(iWpn + 7, g_iPrimaryNum)
	new const fLevels = LibraryExists(LIBRARY_LEVEL, LibType_Library)

	if (fLevels)
		iLevel = ze_get_user_level(id)

	// Add guns name to Menu.
	new iNum = 1
	for (new i = iWpn; i < iMaxLoops; i++)
	{
		ArrayGetArray(g_aPrimaryWeapons, i, pArray)

		if (fLevels)
		{
			if (iLevel < pArray[WPN_LEVEL])
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \d%s \r[%L\d: \y%i\r]^n", iNum++, pArray[WPN_NAME], LANG_PLAYER, "MENU_LEVEL", pArray[WPN_LEVEL])
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iNum++, pArray[WPN_NAME])
			}
		}
		else // #. Weapon Name
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iNum++, pArray[WPN_NAME])
		}
	}

	szMenu[iLen++] = '^n'

	// 8. Remember?
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%L \d[\r%L\d]^n", LANG_PLAYER, "MENU_AUTOSELECT", LANG_PLAYER, g_iMenuData[id][MD_AUTO_SELECT] ? "ON" : "OFF")

	// 9. Next/Back.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%L\d/\w%L^n", LANG_PLAYER, "MENU_NEXT", LANG_PLAYER, "MENU_BACK")

	// 0. Exit.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%L^n^n", LANG_PLAYER, "MENU_EXIT")

	// Show Menu for player.
	show_menu(id, KEYS_MENU, szMenu, -1, "Primary_Weapons_Menu")
}

public handler_Primary_Weapons(id, iKey)
{
	if (x_bWeaponsDisabled)
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_WEAPONS_DISABLED")
		return PLUGIN_HANDLED
	}

	if (g_iBuyTime > 0)
	{
		if (g_iMenuData[id][MD_BUY_TIME] <= get_gametime())
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "MSG_BUYTIME_OVER")
			return PLUGIN_HANDLED
		}
	}

	if (!is_user_alive(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT_ALIVE")
		return PLUGIN_HANDLED
	}

	if (ze_is_user_zombie(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT")
		return PLUGIN_HANDLED
	}

	switch (iKey)
	{
		case MN_AUTO_SELECT:
		{
			g_iMenuData[id][MD_AUTO_SELECT] = ~g_iMenuData[id][MD_AUTO_SELECT]
			show_Primary_Weapons(id)
		}
		case MN_NEXT_BACK:
		{
			if (g_iMenuData[id][MD_PRI_PAGE]+7 >= g_iPrimaryNum)
				g_iMenuData[id][MD_PRI_PAGE] = 0
			else
				g_iMenuData[id][MD_PRI_PAGE] += 7

			show_Primary_Weapons(id)
		}
		case MN_EXIT:
		{
			return PLUGIN_HANDLED
		}
		default:
		{
			new const iWpn = g_iMenuData[id][MD_PRI_PAGE] + iKey

			if (iWpn < g_iPrimaryNum)
			{
				if (!choose_Weapon(id, iWpn, SECTION_PRIMARY))
				{
					show_Primary_Weapons(id)
				}
				else
				{
					show_Secondary_Weapons(id)
				}
			}
			else
			{
				show_Primary_Weapons(id)
			}
		}
	}

	return PLUGIN_HANDLED
}

public show_Secondary_Weapons(id)
{
	new szMenu[MAX_MENU_LENGTH], pArray[WPN_DATA], iLevel, iLen

	// Menu Title.
	iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L \y%L\d:^n^n", LANG_PLAYER, "MENU_PREFIX", LANG_PLAYER, "MENU_SECONDARY_TITLE")

	// Get number of weapons on page.
	new const iWpn = g_iMenuData[id][MD_SEC_PAGE]
	new const iMaxLoops = min(iWpn + 7, g_iSecondaryNum)
	new const fLevels = LibraryExists(LIBRARY_LEVEL, LibType_Library)

	if (fLevels)
		iLevel = ze_get_user_level(id)

	// Add guns name to Menu.
	new iNum = 1
	for (new i = iWpn; i < iMaxLoops; i++)
	{
		ArrayGetArray(g_aSecondaryWeapons, i, pArray)

		if (fLevels)
		{
			if (iLevel < pArray[WPN_LEVEL])
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \d%s \r[%L\d: \y%i\r]^n", iNum++, pArray[WPN_NAME], LANG_PLAYER, "MENU_LEVEL", pArray[WPN_LEVEL])
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iNum++, pArray[WPN_NAME])
			}
		}
		else // #. Weapon Name
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iNum++, pArray[WPN_NAME])
		}
	}

	szMenu[iLen++] = '^n'

	// 8. Remember?
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \w%L \d[\r%L\d]^n", LANG_PLAYER, "MENU_AUTOSELECT", LANG_PLAYER, g_iMenuData[id][MD_AUTO_SELECT] ? "ON" : "OFF")

	// 9. Next/Back.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \w%L\d/\w%L^n", LANG_PLAYER, "MENU_NEXT", LANG_PLAYER, "MENU_BACK")

	// 0. Exit.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%L^n^n", LANG_PLAYER, "MENU_EXIT")

	// Show Menu for player.
	show_menu(id, KEYS_MENU, szMenu, -1, "Secondary_Weapons_Menu")
}

public handler_Secondary_Weapons(id, iKey)
{
	if (x_bWeaponsDisabled)
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "MSG_WEAPONS_DISABLED")
		return PLUGIN_HANDLED
	}

	if (g_iBuyTime > 0)
	{
		if (g_iMenuData[id][MD_BUY_TIME] <= get_gametime())
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "MSG_BUYTIME_OVER")
			return PLUGIN_HANDLED
		}
	}

	if (!is_user_alive(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT_ALIVE")
		return PLUGIN_HANDLED
	}

	if (ze_is_user_zombie(id))
	{
		ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT")
		return PLUGIN_HANDLED
	}

	switch (iKey)
	{
		case MN_AUTO_SELECT:
		{
			g_iMenuData[id][MD_AUTO_SELECT] = ~g_iMenuData[id][MD_AUTO_SELECT]
			show_Secondary_Weapons(id)
		}
		case MN_NEXT_BACK:
		{
			if (g_iMenuData[id][MD_SEC_PAGE]+7 >= g_iSecondaryNum)
				g_iMenuData[id][MD_SEC_PAGE] = 0
			else
				g_iMenuData[id][MD_SEC_PAGE] += 7

			show_Secondary_Weapons(id)
		}
		case MN_EXIT:
		{
			return PLUGIN_HANDLED
		}
		default:
		{
			new iWpn = g_iMenuData[id][MD_SEC_PAGE] + iKey

			if (iWpn < g_iSecondaryNum)
			{
				if (!choose_Weapon(id, iWpn, SECTION_SECONDARY))
				{
					show_Secondary_Weapons(id)
				}
			}
			else
			{
				show_Secondary_Weapons(id)
			}
		}
	}

	return PLUGIN_HANDLED
}

public choose_Weapon(id, iIndex, iSection)
{
	new pArray[WPN_DATA]

	switch (iSection)
	{
		case SECTION_PRIMARY:
		{
			ArrayGetArray(g_aPrimaryWeapons, iIndex, pArray)

			if (LibraryExists(LIBRARY_LEVEL, LibType_Library))
			{
				if (ze_get_user_level(id) < pArray[WPN_LEVEL])
				{
					ze_colored_print(id, "%L", LANG_PLAYER, "MSG_LVL_NOT_ENOUGH")
					return 0
				}
			}

			new pItem
			if (pArray[WPN_CUSTOM])
			{
				if ((pItem = rg_give_custom_item(id, pArray[WPN_CLASS], GT_REPLACE, pArray[WPN_CUSTOM])) == NULLENT)
				{
					log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ClassName ^'%s^'", pArray[WPN_CLASS])
					return 0
				}
			}
			else
			{
				if ((pItem = rg_give_item(id, pArray[WPN_CLASS], GT_REPLACE)) == NULLENT)
				{
					log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ClassName ^'%s^'", pArray[WPN_CLASS])
					return 0
				}
			}

			// Set player Ammo.
			rg_set_user_bpammo(id, WeaponIdType:get_weaponid(pArray[WPN_CLASS]), pArray[WPN_AMMO])
			rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, pArray[WPN_AMMO])

			g_iMenuData[id][MD_PREV_PRIMARY] = iIndex
			g_iMenuData[id][MD_PRIMARY_CHOSEN] = true
		}
		case SECTION_SECONDARY:
		{
			ArrayGetArray(g_aSecondaryWeapons, iIndex, pArray)

			if (LibraryExists(LIBRARY_LEVEL, LibType_Library))
			{
				if (ze_get_user_level(id) < pArray[WPN_LEVEL])
				{
					ze_colored_print(id, "%L", LANG_PLAYER, "MSG_LVL_NOT_ENOUGH")
					return 0
				}
			}

			new pItem
			if (pArray[WPN_CUSTOM])
			{
				if ((pItem = rg_give_custom_item(id, pArray[WPN_CLASS], GT_REPLACE, pArray[WPN_CUSTOM])) == NULLENT)
				{
					log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ClassName ^'%s^'", pArray[WPN_CLASS])
					return 0
				}
			}
			else
			{
				if ((pItem = rg_give_item(id, pArray[WPN_CLASS], GT_REPLACE)) == NULLENT)
				{
					log_error(AMX_ERR_GENERAL, "[ZE] Invalid Weapon ClassName ^'%s^'", pArray[WPN_CLASS])
					return 0
				}
			}

			// Set player Ammo.
			rg_set_user_bpammo(id, WeaponIdType:get_weaponid(pArray[WPN_CLASS]), pArray[WPN_AMMO])
			rg_set_iteminfo(pItem, ItemInfo_iMaxAmmo1, pArray[WPN_AMMO])

			g_iMenuData[id][MD_PREV_SECONDARY] = iIndex
			g_iMenuData[id][MD_SECONDARY_CHOSEN] = true
		}
	}

	return 1
}

/**
 * -=| Function |=-
 */
read_Weapons(const szFile[])
{
	new hFile

	// Open the file.
	if ((hFile = fopen(szFile, "a+t")))
	{
		new szRead[256], szSection[64], bExist, iLine

		while (!feof(hFile))
		{
			iLine++

			if (!fgets(hFile, szRead, charsmax(szRead)))
				break

			// Remove blanks from Text.
			trim(szRead)

			switch (szRead[0])
			{
				case '#', ';', 0:
				{
					continue
				}
				case '[':
				{
					// Copy name on new Buffer.
					copyc(szSection, charsmax(szSection), szRead[1], ']')

					if (equal(szSection, "Weapons Menu"))
					{
						bExist = 1
						break
					}
				}
			}
		}

		if (!bExist)
		{
			new i

			fputs(hFile, "[Weapons Menu]^n")

			// Create new Section with default Weapons.
			for (i = 0; i < sizeof(g_szDefPrimaryWpn); i++)
				fprintf(hFile, "^"p^" ^"%s^" ^"%s^"^n", g_szDefPrimaryWpn[i][WPN_NAME], g_szDefPrimaryWpn[i][WPN_CLASS])

			for (i = 0; i < sizeof(g_szDefSecondaryWpn); i++)
				fprintf(hFile, "^"s^" ^"%s^" ^"%s^"^n", g_szDefSecondaryWpn[i][WPN_NAME], g_szDefSecondaryWpn[i][WPN_CLASS])

			// Close the file.
			fclose(hFile)
			return 0
		}

		new pArray[WPN_DATA], szWpnName[64], szWpnClass[64], szWpnCustom[64], szWpnAmmo[32], szWpnLevel[32]

		while (!feof(hFile))
		{
			iLine++

			szRead = NULL_STRING

			if (!fgets(hFile, szRead, charsmax(szRead)))
				break

			// Remove blanks from Text.
			trim(szRead)

			switch (szRead[0])
			{
				case '#', ';', 0:
				{
					continue
				}
				case '[':
				{
					break
				}
			}

			szSection = NULL_STRING
			szWpnName = NULL_STRING
			szWpnClass = NULL_STRING
			szWpnAmmo = NULL_STRING
			szWpnLevel = NULL_STRING

			// Parse the text.
			if (parse(szRead, szSection, charsmax(szSection), szWpnName, charsmax(szWpnName), szWpnClass, charsmax(szWpnClass), szWpnAmmo, charsmax(szWpnAmmo), szWpnCustom, charsmax(szWpnCustom), szWpnLevel, charsmax(szWpnLevel)) < 4)
			{
				server_print("[ZE] Line #%i: Some arguments are not found !", iLine)
				continue
			}

			// Remove double quotes.
			remove_quotes(szSection)
			remove_quotes(szWpnName)
			remove_quotes(szWpnClass)
			remove_quotes(szWpnCustom)
			remove_quotes(szWpnAmmo)
			remove_quotes(szWpnLevel)

			switch (szSection[0])
			{
				case 'P', 'p':
				{
					pArray[WPN_CUSTOM] = str_to_num(szWpnCustom)
					copy(pArray[WPN_NAME], charsmax(pArray) - WPN_NAME, szWpnName)
					copy(pArray[WPN_CLASS], charsmax(pArray) - WPN_CLASS, szWpnClass)
					pArray[WPN_AMMO] = str_to_num(szWpnAmmo)
					pArray[WPN_LEVEL] = str_to_num(szWpnLevel)

					ArrayPushArray(g_aPrimaryWeapons, pArray)
					g_iPrimaryNum++
				}
				case 'S', 's':
				{
					pArray[WPN_CUSTOM] = str_to_num(szWpnCustom)
					copy(pArray[WPN_NAME], charsmax(pArray) - WPN_NAME, szWpnName)
					copy(pArray[WPN_CLASS], charsmax(pArray) - WPN_CLASS, szWpnClass)
					pArray[WPN_AMMO] = str_to_num(szWpnAmmo)
					pArray[WPN_LEVEL] = str_to_num(szWpnLevel)

					ArrayPushArray(g_aSecondaryWeapons, pArray)
					g_iSecondaryNum++
				}
				case 'A', 'a':
				{
					pArray[WPN_CUSTOM] = str_to_num(szWpnCustom)
					copy(pArray[WPN_NAME], charsmax(pArray) - WPN_NAME, szWpnName)
					copy(pArray[WPN_CLASS], charsmax(pArray) - WPN_CLASS, szWpnClass)
					pArray[WPN_AMMO] = str_to_num(szWpnAmmo)
					pArray[WPN_LEVEL] = str_to_num(szWpnLevel)

					ArrayPushArray(g_aAdditionalWeapons, pArray)
					g_iAdditionalNum++
				}
			}
		}

		// Close the file.
		fclose(hFile)
		return 1
	}

	return 0
}

/**
 * -=| Natives |=-
 */
public __native_auto_buy_enabled(plugin_id, num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	return g_iMenuData[id][MD_AUTO_SELECT]
}

public __native_set_auto_buy(plugin_id, num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	g_iMenuData[id][MD_AUTO_SELECT] = bool:get_param(2)
	return true
}

public __native_show_weapons_menu(plugin_id, num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	if (!get_param(2))
	{
		if (x_bWeaponsDisabled)
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "MSG_WEAPONS_DISABLED")
			return false
		}

		// Player not Alive?
		if (!is_user_alive(id))
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "CMD_NOT_ALIVE")
			return false
		}

		// Player is Zombie?
		if (ze_is_user_zombie(id))
		{
			ze_colored_print(id, "%L", LANG_PLAYER, "MSG_CANT_BUY_WEAPON")
			return false
		}

		// Buy time over?
		if (g_iBuyTime > 0)
		{
			if (g_iMenuData[id][MD_BUY_TIME] <= get_gametime())
			{
				ze_colored_print(id, "%L", LANG_PLAYER, "MSG_BUYTIME_OVER")
				return false
			}
		}
	}

	show_Available_Menu(id)
	return true
}