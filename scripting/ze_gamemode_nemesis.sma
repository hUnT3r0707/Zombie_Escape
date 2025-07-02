#include <amxmodx>
#include <reapi>

#include <ze_core>

// Libraries.
stock const LIBRARY_NEMESIS[] = "ze_class_nemesis"
stock const LIBRARY_RESOURCES[] = "ze_resources"

// Defines.
#define GAMEMODE_NAME "Nemesis"

// Colors
enum any:Colors
{
	Red = 0,
	Green,
	Blue
}

enum _:HUDs
{
	Float:HUD_EVENT_X = 0,
	Float:HUD_EVENT_Y
}

// CVars.
new g_iChance,
	g_iNoticeMode,
	g_iMinPlayers,
	g_iNoticeColors[Colors],
	bool:g_bSounds,
	bool:g_bEnabled,
	bool:g_bBackToSpawn

// Array.
new Float:g_flHUDPosit[HUDs]

// XVar.
new g_xFixSpawn

// Dynamic Array.
new Array:g_aSounds

public plugin_natives()
{
	set_module_filter("module_filter")
	set_native_filter("native_filter")
}

public module_filter(const module[], LibType:libtype)
{
	if (equal(module, LIBRARY_NEMESIS) || equal(module, LIBRARY_RESOURCES))
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public plugin_precache()
{
	new const szNemesisModeSound[][] = {"zm_es/ze_nemesis_1.wav"}

	// Create new dyn Array.
	g_aSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read spread sound from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "NEMESIS_MODE", g_aSounds)

	if (!ArraySize(g_aSounds))
	{
		for (new i = 0; i < sizeof(szNemesisModeSound); i++)
			ArrayPushString(g_aSounds, szNemesisModeSound[i])

		// Write spread sound from INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "NEMESIS_MODE", g_aSounds)
	}

	new szSound[MAX_RESOURCE_PATH_LENGTH]

	// Precache Sounds.
	new iFiles = ArraySize(g_aSounds)
	for (new i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aSounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}


	if (LibraryExists(LIBRARY_RESOURCES, LibType_Library))
	{
		new const szNemesisAmbienceSound[] = "zm_es/ze_amb_nemesis.wav"
		const iNemesisAmbienceSound = 200

		// Registers new Ambience on game.
		ze_res_ambx_register(GAMEMODE_NAME, szNemesisAmbienceSound, iNemesisAmbienceSound)
	}
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Gamemodes: Nemesis", ZE_VERSION, ZE_AUTHORS)

	// CVars.
	bind_pcvar_num(register_cvar("ze_nemesis_enable", "1"), g_bEnabled)
	bind_pcvar_num(register_cvar("ze_nemesis_chance", "20"), g_iChance)
	bind_pcvar_num(register_cvar("ze_nemesis_minplayers", "4"), g_iMinPlayers)
	bind_pcvar_num(register_cvar("ze_nemesis_notice", "3"), g_iNoticeMode)
	bind_pcvar_num(register_cvar("ze_nemesis_notice_red", "200"), g_iNoticeColors[Red])
	bind_pcvar_num(register_cvar("ze_nemesis_notice_green", "0"), g_iNoticeColors[Green])
	bind_pcvar_num(register_cvar("ze_nemesis_notice_blue", "0"), g_iNoticeColors[Blue])
	bind_pcvar_num(register_cvar("ze_nemesis_sound", "1"), g_bSounds)
	bind_pcvar_num(register_cvar("ze_nemesis_spawn", "1"), g_bBackToSpawn)

	// New's Mode.
	ze_gamemode_register(GAMEMODE_NAME)

	// Set Values.
	g_xFixSpawn = get_xvar_id(X_Core_FixSpawn)
}

public plugin_cfg()
{
	g_flHUDPosit[HUD_EVENT_X] = -1.0
	g_flHUDPosit[HUD_EVENT_Y] = 0.4

	if (!ini_read_float(ZE_FILENAME, "HUDs", "HUD_GAMEEVENT_X", g_flHUDPosit[HUD_EVENT_X]))
		ini_write_float(ZE_FILENAME, "HUDs", "HUD_GAMEEVENT_X", g_flHUDPosit[HUD_EVENT_X])
	if (!ini_read_float(ZE_FILENAME, "HUDs", "HUD_GAMEEVENT_Y", g_flHUDPosit[HUD_EVENT_Y]))
		ini_write_float(ZE_FILENAME, "HUDs", "HUD_GAMEEVENT_Y", g_flHUDPosit[HUD_EVENT_Y])
}

public ze_gamemode_chosen_pre(game_id, target, bool:bSkipCheck)
{
	if (!g_bEnabled)
		return ZE_GAME_IGNORE

	if (!bSkipCheck)
	{
		// ze_class_nemesis not Loaded?
		if (!LibraryExists(LIBRARY_NEMESIS, LibType_Library))
			return ZE_GAME_IGNORE

		// This is not round of Nemesis?
		if (random_num(1, g_iChance) != 1)
			return ZE_GAME_IGNORE

		if (get_playersnum_ex(GetPlayers_ExcludeDead) < g_iMinPlayers)
			return ZE_GAME_IGNORE
	}

	// Continue starting game mode: Nemesis
	return ZE_GAME_CONTINUE
}

public ze_gamemode_chosen(game_id, target)
{
	new bool:bAppear

	if (!target)
	{
		new iPlayers[MAX_PLAYERS], iAliveNum, id

		// Get index of all Alive Players.
		get_players(iPlayers, iAliveNum, "a")

		// Fix call the Spawn function when respawn player.
		set_xvar_num(g_xFixSpawn, 1)

		while (!bAppear)
		{
			// Get randomly player.
			id = iPlayers[random_num(0, iAliveNum - 1)]

			// Player already Nemesis!
			if (ze_is_user_nemesis(id))
				continue

			if (g_bBackToSpawn)
			{
				// Respawn the player.
				rg_round_respawn(id)
			}

			// Turn a player into a Nemesis.
			ze_set_user_nemesis(id)

			// New Nemesis.
			bAppear = true
		}

		// Disable it.
		set_xvar_num(g_xFixSpawn)
	}
	else
	{
		// Turn a player into a Nemesis.
		ze_set_user_nemesis(target)

		// New Nemesis.
		bAppear = true
	}

	if (g_bSounds)
	{
		// Play sound for everyone.
		new szSound[MAX_RESOURCE_PATH_LENGTH]
		ArrayGetString(g_aSounds, random_num(0, ArraySize(g_aSounds) - 1), szSound, charsmax(szSound))
		PlaySound(0, szSound)
	}

	switch (g_iNoticeMode)
	{
		case 1: // Text Center.
		{
			client_print(0, print_center, "%L", LANG_PLAYER, "HUD_NEMESIS")
		}
		case 2: // HUD.
		{
			set_hudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], g_flHUDPosit[HUD_EVENT_X], g_flHUDPosit[HUD_EVENT_Y], 1, 3.0, 3.0, 0.1, 1.0)
			show_hudmessage(0, "%L", LANG_PLAYER, "HUD_NEMESIS")
		}
		case 3: // DHUD.
		{
			set_dhudmessage(g_iNoticeColors[Red], g_iNoticeColors[Green], g_iNoticeColors[Blue], g_flHUDPosit[HUD_EVENT_X], g_flHUDPosit[HUD_EVENT_Y], 1, 3.0, 3.0, 0.1, 1.0)
			show_dhudmessage(0, "%L", LANG_PLAYER, "HUD_NEMESIS")
		}
	}

	if (LibraryExists(LIBRARY_RESOURCES, LibType_Library))
	{
		// Plays ambience sound for everyone.
		ze_res_ambx_play(GAMEMODE_NAME)
	}
}