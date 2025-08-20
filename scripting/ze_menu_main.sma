#include <amxmodx>
#include <amxmisc>
#include <reapi>

#include <ze_core>
#include <ze_class_human>
#include <ze_class_zombie>

// Libraries.
stock const LIBRARY_HUMAN[] = "ze_class_human"
stock const LIBRARY_ZOMBIE[] = "ze_class_zombie"
stock const LIBRARY_WEAPONS[] = "ze_weapons_menu"
stock const LIBRARY_ITEMS[] = "ze_items_manager"
stock const LIBRARY_RESOURCES[] = "ze_resources"

// Keys Menu.
const KEYS_MENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0

public plugin_natives()
{
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}

public module_filter(const module[], LibType:libtype)
{
	if (equal(module, LIBRARY_HUMAN) || equal(module, LIBRARY_ZOMBIE) || equal(module, LIBRARY_ITEMS) || equal(module, LIBRARY_WEAPONS) || equal(module, LIBRARY_RESOURCES))
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
	register_plugin("[ZE] Menu Main", ZE_VERSION, ZE_AUTHORS)

	// Commands.
	register_clcmd("jointeam", "cmd_MenuMain")
	register_clcmd("chooseteam", "cmd_MenuMain")
	register_clcmd("say /menu", "cmd_MenuMain")
	register_clcmd("say_team /menu", "cmd_MenuMain")

	// New Menu's.
	register_menu("Menu_Main", KEYS_MENU, "handler_Menu_Main")
}

public cmd_MenuMain(const id)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return PLUGIN_CONTINUE

	show_Menu_Main(id)
	return PLUGIN_HANDLED_MAIN
}

public show_Menu_Main(const id)
{
	static szMenu[MAX_MENU_LENGTH], iLen
	szMenu = NULL_STRING

	// Menu Title.
	iLen = formatex(szMenu, charsmax(szMenu), "\r%L \y%L:^n^n", LANG_PLAYER, "MENU_PREFIX", LANG_PLAYER, "MENU_MAIN_TITLE")

	if (LibraryExists(LIBRARY_WEAPONS, LibType_Library))
	{
		// 1. Weapons Menu.
		if (is_user_alive(id))
		{
			if (ze_auto_buy_enabled(id))
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \d%L^n", LANG_PLAYER, "MENU_RE_WEAPONS")
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%L^n", LANG_PLAYER, "MENU_WEAPONS")
			}
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \d%L^n", LANG_PLAYER, "MENU_WEAPONS")
		}
	}

	if (LibraryExists(LIBRARY_ITEMS, LibType_Library))
	{
		// 2. Extra Items.
		if (is_user_alive(id))
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \y%L^n", LANG_PLAYER, "MENU_EXTRAITEMS")
		}
		else
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \d%L^n", LANG_PLAYER, "MENU_EXTRAITEMS")
		}
	}

	// New Line.
	szMenu[iLen++] = '^n'

	// 3. Human Classes
	if (LibraryExists(LIBRARY_HUMAN, LibType_Library))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. %L^n", LANG_PLAYER, "MENU_HCLASSES")
	}

	// 4. Zombie Classes
	if (LibraryExists(LIBRARY_ZOMBIE, LibType_Library))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. %L^n", LANG_PLAYER, "MENU_ZCLASSES")
	}

	// New Line.
	szMenu[iLen++] = '^n'

	// 5. Leave Spectators
	switch (get_member(id, m_iTeam))
	{
		case TEAM_SPECTATOR, TEAM_UNASSIGNED:
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \y%L^n", LANG_PLAYER, "MENU_LEAVE_SPECS")
		}
	}

	// New Line.
	szMenu[iLen++] = '^n'

	// 0. Exit.
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \w%L", LANG_PLAYER, "MENU_EXIT")

	if (LibraryExists(LIBRARY_RESOURCES, LibType_Library))
		ze_res_menu_sound(id, ZE_MENU_DISPLAY)

	// Show the Menu for player.
	show_menu(id, KEYS_MENU, szMenu, ZE_MENU_TIMEOUT, "Menu_Main")
}

public handler_Menu_Main(const id, iKey)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return PLUGIN_HANDLED

	if (LibraryExists(LIBRARY_RESOURCES, LibType_Library))
		ze_res_menu_sound(id, ZE_MENU_SELECT)

	switch (iKey)
	{
		case 0: // 1. Weapons Menu.
		{
			if (LibraryExists(LIBRARY_WEAPONS, LibType_Library))
			{
				if (ze_auto_buy_enabled(id))
				{
					ze_set_auto_buy(id)
				}
				else
				{
					ze_show_weapons_menu(id)
				}
			}
		}
		case 1: // 2. Extra Items.
		{
			// Show Extra-Items menu for player.
			if (LibraryExists(LIBRARY_ITEMS, LibType_Library))
			{
				ze_item_show_menu(id)
			}
		}
		case 2: // 3. Human Classes.
		{
			if (LibraryExists(LIBRARY_HUMAN, LibType_Library))
			{
				ze_hclass_show_menu(id)
			}
		}
		case 3: // 4. Zombie Classes.
		{
			if (LibraryExists(LIBRARY_ZOMBIE, LibType_Library))
			{
				ze_zclass_show_menu(id)
			}
		}
		case 4: // 5. Leave Spectators.
		{
			switch (get_member(id, m_iTeam))
			{
				case TEAM_SPECTATOR, TEAM_UNASSIGNED:
				{
					rg_set_user_team(id, TEAM_CT, MODEL_UNASSIGNED, true, true)
				}
			}
		}
		case 9: // 0. Exit.
		{
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_HANDLED
}