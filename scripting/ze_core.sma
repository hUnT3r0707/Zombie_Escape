#include <amxmodx>
#include <amxmisc>
#include <sockets>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <json>
#include <xs>

#include <ze_stocks>
#include <ze_core_const>

// Constants.
const AUTH_CHECK_TIMES = 3
const Float:AUTH_RETRY_DELAY = 0.5  // Delay before try authorized client (Minimum: 0.1)

// Custom Forwards.
enum _:FORWARDS
{
	FORWARD_GAMESTARTED_PRE = 0,
	FORWARD_GAMESTARTED,
	FORWARD_USER_HUMANIZED_PRE,
	FORWARD_USER_HUMANIZED,
	FORWARD_USER_INFECTED_PRE,
	FORWARD_USER_INFECTED,
	FORWARD_USER_INFECTED_EX,
	FORWARD_USER_SPAWN_POST,
	FORWARD_USER_KILLED_POST,
	FORWARD_USER_LAST_HUMAN,
	FORWARD_USER_LAST_ZOMBIE,
	FORWARD_USER_AUTHORIZED,
	FORWARD_USER_DISCONNECTED,
	FORWARD_ROUNDEND
}

// Task IDs.
enum (+=1)
{
	TASK_ROUNDTIME = 100,
	TASK_SVREPONSE,
	TASK_CONNECTFAIL,
	TASK_CHECKUPDATE
}

new const g_szBlockSounds[][] =
{
	"!MRAD_terwin",
	"!MRAD_ctwin",
	"!MRAD_rounddraw"
}

new const g_szBlockTxtMsg[][] =
{
	"#Terrorits_Win",
	"#CTs_Win",
	"#Round_Draw",
	"#Hostages_Not_Rescued",
	"#Target_Saved"
}

new const g_szEntitesClass[][] =
{
	"env_fog",
	"env_rain",
	"env_snow",
	"hostage_entity",
	"info_bomb_target",
	"info_hostage_rescue",
	"func_vip_safetyzone",
	"info_vip_start",
	"item_longjump",
	"func_bomb_target",
	"func_buyzone",
	"func_hostage_rescue",
	"weapon_c4"
}

// Cvars.
new g_iReqPlayers,
	g_iBlockTanks,
	bool:g_bBlockSuicide,
	bool:g_bBlockMoneyHUD,
	bool:g_bBlockHpArRrHUD,
	bool:g_bBlockBloodEffs,
	bool:g_bBlockStartupMOTD,
	bool:g_bBlockHintMessage,
	Float:g_flRoundEndDelay

// Variables.
new g_iFwSpawn,
	g_iFwReturn,
	g_iLastHuman,
	g_iHumanWins,
	g_iZombieWins,
	g_iLastZombie,
	g_iPainShockFree,
	g_bitsIsZombie,
	g_bitsSpeedFactor,
	g_hSocketUpdate,
	g_msgWeapPickup,
	bool:g_bRoundEnd,
	bool:g_bCheckUpdate,
	bool:g_bFreezePeriod,
	bool:g_bLastHumanDied

// Arrays.
new g_iForwards[FORWARDS],
	g_iChecks[MAX_PLAYERS+1],
	bool:g_bMOTD[MAX_PLAYERS+1],
	Float:g_flUserSpeed[MAX_PLAYERS+1],
	Float:g_flAuthPeriod[MAX_PLAYERS+1]

// XVars.
public x_bGameStarted,
		x_bGameChosen,
		x_bFixSpawn,
		x_iRoundTime,
		x_iRoundNum,
		x_bRespawnAsZombie,
		x_bUpdateAvailable

public plugin_natives()
{
	register_native("ze_is_user_zombie", "__native_is_user_zombie")

	register_native("ze_set_user_human", "__native_set_user_human")
	register_native("ze_set_user_zombie", "__native_set_user_zombie")

	register_native("ze_is_last_human", "__native_is_last_human")
	register_native("ze_is_last_zombie", "__native_is_last_zombie")

	register_native("ze_force_set_user_human", "__native_force_set_user_human")
	register_native("ze_force_set_user_zombie", "__native_force_set_user_zombie")

	register_native("ze_set_user_speed", "__native_set_user_speed")
	register_native("ze_reset_user_speed", "__native_reset_user_speed")

	register_native("ze_round_end", "__native_round_end")

	g_iFwSpawn = register_forward(FM_Spawn, "fw_Spawn_Pre")

	set_module_filter("fw_module_filter")
	set_native_filter("fw_native_filter")
}

public fw_module_filter(const module[], LibType:libtype)
{
	if (equal(module, "sockets"))
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public fw_native_filter(const name[], index, trap)
{
	if (!trap)
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Core/Engine", ZE_VERSION, ZE_AUTHORS)

	// Events.
	register_event("HLTV", "fw_NewRound_Event", "a", "1=0", "2=0")
	register_event("TextMsg", "fw_RestartRound_Event", "a", "2=#Game_will_restart_in", "2=#Game_Commecing", "2=#Round_Draw")
	register_logevent("fw_RoundStart_Event", 2, "1=Round_Start")
	register_logevent("fw_RoundEnd_Event", 2, "1=Round_End")

	// Message.
	register_message(SVC_TEMPENTITY, "fw_TempEntity_Msg")
	register_message(get_user_msgid("TextMsg"), "fw_TextMsg_Msg")
	register_message(get_user_msgid("SendAudio"), "fw_SendAudio_Msg")
	register_message(get_user_msgid("HideWeapon"), "fw_HideWeapon_Msg")
	register_message(get_user_msgid("TeamScore"), "fw_TeamScore_Msg")
	register_message(get_user_msgid("MOTD"), "fw_MOTD_Msg")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayer_Spawn, "fw_PlayerSpawn_Post", 1)
	RegisterHookChain(RG_CBasePlayer_Killed, "fw_PlayerKilled_Post", 1)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "fw_TakeDamage_Post", 1)
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "fw_TraceAttack_Pre", 0)
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "fw_ResetMaxSpeed_Post", 1)
	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "fw_HasRestrictItem_Pre", 0)
	RegisterHookChain(RG_CBasePlayer_HintMessageEx, "fw_PlayerHintMessageEx_Pre")
	RegisterHookChain(RG_CSGameRules_CheckWinConditions, "fw_CheckWinConditions_Post", 1)
	RegisterHookChain(RG_RoundEnd, "fw_RoundEnd_Post", 1)

	// Hams.
	RegisterHam(Ham_Use, "func_tank", "fw_CTankUse_Pre")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_CTankUse_Pre")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_CTankUse_Pre")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_CTankUse_Pre")

	// FakeMeta.
	register_forward(FM_ClientKill, "fw_ClientKill_Pre")
	unregister_forward(FM_Spawn, g_iFwSpawn)
	g_iFwSpawn = 0

	// CVars.
	new const pCvarReqPlayers = register_cvar("ze_required_players", "2")

	bind_pcvar_num(pCvarReqPlayers, g_iReqPlayers)
	bind_pcvar_num(register_cvar("ze_painshockfree", "1"), g_iPainShockFree)
	bind_pcvar_num(register_cvar("ze_lasthuman_die", "0"), g_bLastHumanDied)

	bind_pcvar_num(register_cvar("ze_block_kill", "1"), g_bBlockSuicide)
	bind_pcvar_num(register_cvar("ze_block_hp_ar_rdr", "1"), g_bBlockHpArRrHUD)
	bind_pcvar_num(register_cvar("ze_block_money", "1"), g_bBlockMoneyHUD)
	bind_pcvar_num(register_cvar("ze_block_blood", "1"), g_bBlockBloodEffs)
	bind_pcvar_num(register_cvar("ze_block_MOTD", "1"), g_bBlockStartupMOTD)
	bind_pcvar_num(register_cvar("ze_block_hintmsg", "1"), g_bBlockHintMessage)
	bind_pcvar_num(register_cvar("ze_block_tank", "1"), g_iBlockTanks)

	bind_pcvar_num(register_cvar("ze_check_update", "1"), g_bCheckUpdate)

	bind_pcvar_float(get_cvar_pointer("mp_round_restart_delay"), g_flRoundEndDelay)

	hook_cvar_change(pCvarReqPlayers, "cvar_ReqPlayers")

	// Create Forwards.
	g_iForwards[FORWARD_GAMESTARTED_PRE] = CreateMultiForward("ze_game_started_pre", ET_CONTINUE)
	g_iForwards[FORWARD_GAMESTARTED] = CreateMultiForward("ze_game_started", ET_IGNORE)
	g_iForwards[FORWARD_USER_HUMANIZED_PRE] = CreateMultiForward("ze_user_humanized_pre", ET_CONTINUE, FP_CELL)
	g_iForwards[FORWARD_USER_HUMANIZED] = CreateMultiForward("ze_user_humanized", ET_IGNORE, FP_CELL)
	g_iForwards[FORWARD_USER_INFECTED_PRE] = CreateMultiForward("ze_user_infected_pre", ET_CONTINUE, FP_CELL, FP_CELL, FP_FLOAT)
	g_iForwards[FORWARD_USER_INFECTED] = CreateMultiForward("ze_user_infected", ET_IGNORE, FP_CELL, FP_CELL)
	g_iForwards[FORWARD_USER_INFECTED_EX] = CreateMultiForward("ze_user_infected_ex", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_iForwards[FORWARD_USER_SPAWN_POST] = CreateMultiForward("ze_user_spawn_post", ET_IGNORE, FP_CELL)
	g_iForwards[FORWARD_USER_KILLED_POST] = CreateMultiForward("ze_user_killed_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_iForwards[FORWARD_USER_LAST_HUMAN] = CreateMultiForward("ze_user_last_human", ET_IGNORE, FP_CELL)
	g_iForwards[FORWARD_USER_LAST_ZOMBIE] = CreateMultiForward("ze_user_last_zombie", ET_IGNORE, FP_CELL)
	g_iForwards[FORWARD_USER_AUTHORIZED] = CreateMultiForward("ze_user_authorized", ET_IGNORE, FP_CELL, FP_STRING, FP_CELL, FP_CELL, FP_FLOAT)
	g_iForwards[FORWARD_USER_DISCONNECTED] = CreateMultiForward("ze_user_disconnected", ET_CONTINUE, FP_CELL)
	g_iForwards[FORWARD_ROUNDEND] = CreateMultiForward("ze_roundend", ET_IGNORE, FP_CELL)

	// New Localization file (.txt)
	register_dictionary("zombie_escape.txt")

	// Initial Value.
	g_msgWeapPickup = get_user_msgid("WeapPickup")
}

public plugin_cfg()
{
	new szGameDesc[MAX_NAME_LENGTH], szCfgDir[24]

	// Get configs directory.
	get_configsdir(szCfgDir, charsmax(szCfgDir))

	// Execute our configuration (.cfg)
	server_cmd("exec ^"%s/%s.cfg^"", szCfgDir, ZE_FILENAME)
	server_exec()

	// Game Description.
	formatex(szGameDesc, charsmax(szGameDesc), "%L", LANG_PLAYER, "GAME_DESC")
	set_member_game(m_GameDesc, szGameDesc)

	// Block Buyzone.
	set_member_game(m_bTCantBuy, true)
	set_member_game(m_bCTCantBuy, true)
	set_member_game(m_bMapHasBuyZone, false)

	// Block CS Map Gamemodes.
	set_member_game(m_bMapHasBombZone, false)
	set_member_game(m_bMapHasBombTarget, false)
	set_member_game(m_bMapHasRescueZone, false)
	set_member_game(m_bMapHasEscapeZone, false)
	set_member_game(m_bMapHasVIPSafetyZone, false)

	// Mod Version.
	register_cvar("ze_mod_version", ZE_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("ze_mod_version", ZE_VERSION)
	register_cvar("ze_mod_md5hash", ZE_MD5HASH, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("ze_mod_md5hash", ZE_MD5HASH)

	// Check Update.
	if (g_bCheckUpdate)
		set_task(10.0, "check_Update", TASK_CHECKUPDATE)
}

public plugin_end()
{
	// Free the Memory.
	DestroyForward(g_iForwards[FORWARD_GAMESTARTED_PRE])
	DestroyForward(g_iForwards[FORWARD_GAMESTARTED])
	DestroyForward(g_iForwards[FORWARD_USER_HUMANIZED_PRE])
	DestroyForward(g_iForwards[FORWARD_USER_HUMANIZED])
	DestroyForward(g_iForwards[FORWARD_USER_INFECTED_PRE])
	DestroyForward(g_iForwards[FORWARD_USER_INFECTED_EX])
	DestroyForward(g_iForwards[FORWARD_USER_INFECTED])
	DestroyForward(g_iForwards[FORWARD_USER_SPAWN_POST])
	DestroyForward(g_iForwards[FORWARD_USER_KILLED_POST])
	DestroyForward(g_iForwards[FORWARD_USER_LAST_HUMAN])
	DestroyForward(g_iForwards[FORWARD_USER_LAST_ZOMBIE])
	DestroyForward(g_iForwards[FORWARD_USER_AUTHORIZED])
	DestroyForward(g_iForwards[FORWARD_USER_DISCONNECTED])
	DestroyForward(g_iForwards[FORWARD_ROUNDEND])
}

public cvar_ReqPlayers(pCvar)
{
	if (!x_bGameStarted)
	{
		if (get_PlayersNum() >= g_iReqPlayers)
		{
			x_bGameStarted = true
			set_cvar_num("sv_restartround", 2)
		}
	}
	else // Game already started.
	{
		if (get_PlayersNum() < g_iReqPlayers)
		{
			x_bGameStarted = false
			set_cvar_num("sv_restartround", 2)
		}
	}
}

public check_Update(taskid)
{
	new error

	// Open a Socket.
	if ((g_hSocketUpdate = socket_open(ZE_HOME_HOST, ZE_HOME_PORT, SOCKET_TCP, error)))
	{
		switch (error)
		{
			case 1: server_print("[ZE] Check-Update: Unable to create socket.")
			case 2: server_print("[ZE] Check-Update: Unable to connect to hostname.")
			case 3: server_print("[ZE] Check-Update: Unable to connect to HTTP Port.")
			default: // No error?
			{
				// Send request to Server.
				new szRequest[256]
				formatex(szRequest, charsmax(szRequest), "GET /%s HTTP/1.1^r^nHost:%s^r^nAccept:application/json^r^n^r^n", ZE_HOME_TOPIC, ZE_HOME_HOST)
				socket_send2(g_hSocketUpdate, szRequest, strlen(szRequest))

				// Check from reponse.
				set_task(1.0, "check_Reponse", TASK_SVREPONSE, "", 0, "a", 5)
				set_task(6.0, "close_Connection", TASK_CONNECTFAIL)
			}
		}
	}
}

public check_Reponse(taskid)
{
	// Data received?
	if (socket_is_readable(g_hSocketUpdate))
	{
		// Remove Other Tasks.
		remove_task(TASK_SVREPONSE)
		remove_task(TASK_CONNECTFAIL)

		new szBuffer[512], szVersion[8]
		socket_recv(g_hSocketUpdate, szBuffer, charsmax(szBuffer))

		new i
		if ((i = contain(szBuffer, "{")) > -1)
			copy(szBuffer, charsmax(szBuffer), szBuffer[i])

		new JSON:hJson
		if ((hJson = json_parse(szBuffer)) == Invalid_JSON)
		{
			server_print("[Zombie-Escape] Error while parsing JSON string (Bad JSON format) (-1)")
		}
		else
		{
			new szMD5Hash[34]

			if (json_object_get_string(hJson, "fversion", szVersion, charsmax(szVersion)) || json_object_get_string(hJson, "md5hash", szMD5Hash, charsmax(szMD5Hash)))
			{
				if (str_to_float(szVersion) < ZE_VERSION_FL || !equal(szMD5Hash, ZE_MD5HASH))
				{
					x_bUpdateAvailable = 1
				}
			}
		}

		if (x_bUpdateAvailable)
		{
			formatex(szBuffer, charsmax(szBuffer), "\
			^n^n^n\
			| ***--- Zombie Escape Rebuild %s ---***^n\
			| There is a new update!^n\
			| • Official Website: https://escapers-zone.net/^n\
			| • GitHub: https://github.com/z0h1r-LK/Zombie_Escape/releases/latest/ \
			^n^n^n\
			", szVersion)

			server_print(szBuffer)

			new hFile
			if ((hFile = fopen("update", "wt")))
			{
				fputs(hFile, szVersion)
				fclose(hFile)
			}
		}
		else
		{
			server_print("[Zombie-Escape] Your Mod is up to date :)")
		}

		// Frees handle.
		json_free(hJson)
		socket_close(g_hSocketUpdate)
	}
}

public close_Connection(taskid)
{
	server_print("[Zombie-Escape] Failed to connect to the server!")

	// Close socket.
	socket_close(g_hSocketUpdate)
}

public client_putinserver(id)
{
	g_flAuthPeriod[id] = get_gametime()
	clientAuthorized(id)

	if (is_user_hltv(id))
		return

	g_bMOTD[id] = true
	set_task(0.5, "client_Connected")  // Delay before check gamerules.
}

public client_Connected()
{
	if (!x_bGameStarted)
	{
		if (get_PlayersNum() >= g_iReqPlayers)
		{
			x_bGameStarted = true

			// Restart the round After 2s
			set_cvar_num("sv_restartround", 2)
		}
	}

	check_LastPlayer()
}

public clientAuthorized(const id)
{
	// Player disconnected?
	if (!is_user_connected(id))
		return

	new RClientAuth:iClType, bool:bIsAuthorized = false

	if (!is_dedicated_server() && id == 1) // It is ListenServer?
	{
		iClType = ZE_AUTH_CLIENT
		bIsAuthorized = true
	}
	else if (is_user_bot(id))
	{
		iClType = ZE_AUTH_BOT
		bIsAuthorized = true
	}
	else if (is_user_hltv(id))
	{
		iClType = ZE_AUTH_PROXY
		bIsAuthorized = true
	}
	else
	{
		iClType = ZE_AUTH_CLIENT
	}

	new szAuthID[MAX_AUTHID_LENGTH], Float:flDuration
	get_user_authid(id, szAuthID, charsmax(szAuthID))

	if (!bIsAuthorized)
	{
		if (!szAuthID[0] || equali(szAuthID, "STEAM_ID_LAN") || equali(szAuthID, "STEAM_ID_PENDING") || equali(szAuthID, "VALVE_ID_LAN") || equali(szAuthID, "VALVE_ID_PENDING"))
		{
			if (++g_iChecks[id] >= AUTH_CHECK_TIMES)
			{
				flDuration = get_gametime() - g_flAuthPeriod[id]

				// Call forward ze_user_authorized(param1, string2, param3, param4, fparam5)
				ExecuteForward(g_iForwards[FORWARD_USER_AUTHORIZED], _/* Ignore return value */, id, szAuthID, iClType, true, flDuration)
			}
			else
			{
				set_task(AUTH_RETRY_DELAY, "clientAuthorized", id) // Try again! Server does not load Auth ID.
			}
		}
		else
		{
			bIsAuthorized = true
		}
	}

	if (bIsAuthorized)
	{
		flDuration = get_gametime() - g_flAuthPeriod[id]

		// Call forward ze_user_authorized(param1, string2, param3, param4, fparam5)
		ExecuteForward(g_iForwards[FORWARD_USER_AUTHORIZED], _/* Ignore return value */, id, szAuthID, iClType, false, flDuration)
	}
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	// HLTV Proxy?
	if (is_user_hltv(id))
		return

	// Reset Var.
	g_iChecks[id] = 0
	g_flUserSpeed[id] = 0.0
	g_flAuthPeriod[id] = 0.0
	g_bMOTD[id] = false
	flag_unset(g_bitsIsZombie, id)
	flag_unset(g_bitsSpeedFactor, id)

	// Check Last Human or Zombie.
	check_LastPlayer()

	// Call forward ze_user_disconnected(param1)
	ExecuteForward(g_iForwards[FORWARD_USER_DISCONNECTED], g_iFwReturn, id)

	if (g_iFwReturn >= ZE_STOP)
		return

	// Delay before check gamerules.
	set_task(1.0, "client_Disconnected")
}

public client_Disconnected()
{
	if (x_bGameStarted)
	{
		if (get_PlayersNum() < g_iReqPlayers)
		{
			x_bGameStarted = false

			// Restart the round after 2s.
			set_cvar_num("sv_restartround", 2)
		}
		else
		{
			if (x_bGameChosen)
			{
				// Get the number of the Humans and Zombies.
				new const iHumansNum = get_member_game(m_iNumCT)
				new const iZombiesNum = get_member_game(m_iNumTerrorist)

				if (iHumansNum && !iZombiesNum)
				{
					rg_round_end(g_flRoundEndDelay, WINSTATUS_CTS, ROUND_CTS_WIN, "", "", true)
				}
				else if (iZombiesNum && !iHumansNum)
				{
					rg_round_end(g_flRoundEndDelay, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "", "", true)
				}
				else
				{
					// Get number of alive Humans and Zombies.
					new const iAliveHumansNum = get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT")
					new const iAliveZombiesNum = get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "TERRORIST")

					if (iAliveHumansNum && !iAliveZombiesNum)
					{
						rg_round_end(g_flRoundEndDelay, WINSTATUS_CTS, ROUND_CTS_WIN, "", "", true)
					}
					else if (iAliveZombiesNum && !iAliveHumansNum)
					{
						rg_round_end(g_flRoundEndDelay, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "", "", true)
					}
				}
			}
		}
	}
}

public fw_ClientKill_Pre(const id)
{
	if (g_bBlockSuicide)
		return FMRES_SUPERCEDE
	return FMRES_IGNORED
}

public fw_Spawn_Pre(const iEnt)
{
	for (new i = 0; i < sizeof(g_szEntitesClass); i++)
	{
		if (FClassnameIs(iEnt, g_szEntitesClass[i]))
		{
			// Free edict.
			rg_remove_entity(iEnt)
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public check_LastPlayer()
{
	new iPlayers[MAX_PLAYERS], iAliveNum

	// Get number of Alive players in Humans Team.
	get_players(iPlayers, iAliveNum, "ae", "CT")

	// Search on Last Human.
	if (iAliveNum == 1)
	{
		g_iLastHuman = iPlayers[0]

		// Call forward ze_user_last_human(param1).
		ExecuteForward(g_iForwards[FORWARD_USER_LAST_HUMAN], _/* Ignore return value */, g_iLastHuman)
	}
	else
	{
		g_iLastHuman = 0
	}

	// Get number of Alive players in Zombies Team.
	get_players(iPlayers, iAliveNum, "ae", "TERRORIST")

	// Search on Last Zombie.
	if (iAliveNum == 1)
	{
		g_iLastZombie = iPlayers[0]

		// Call forward ze_user_last_zombie(param1).
		ExecuteForward(g_iForwards[FORWARD_USER_LAST_ZOMBIE], _/* Ignore return value */, g_iLastZombie)
	}
	else
	{
		g_iLastZombie = 0
	}
}

public fw_NewRound_Event()
{
	x_iRoundNum++

	// Freeze Time.
	g_bFreezePeriod = true

	// New Round.
	g_bRoundEnd = false

	// Remove all Tasks.
	remove_task(TASK_ROUNDTIME)

	// Call forward ze_game_started_pre() and get return value.
	ExecuteForward(g_iForwards[FORWARD_GAMESTARTED_PRE], g_iFwReturn)

	if (g_iFwReturn >= ZE_STOP)
		return

	new const iPlayersNum = get_PlayersNum()
	if (iPlayersNum < g_iReqPlayers)
	{
		ze_colored_print(0, "%L", LANG_PLAYER, "NO_ENOUGH_PLAYERS", iPlayersNum, g_iReqPlayers)
		return
	}

	// Call forward ze_game_started()
	ExecuteForward(g_iForwards[FORWARD_GAMESTARTED])

	// Send colored message on chat for all clients.
	ze_colored_print(0, "%L", LANG_PLAYER, "MSG_READY")
}

public fw_RestartRound_Event()
{
	x_iRoundNum = 0
	g_iHumanWins = 0
	g_iZombieWins = 0

	// Update Score on SERVER.
	rg_update_teamscores(0, 0, false)

	// Round End!
	g_bRoundEnd = true

	// Remove tasks.
	remove_task(TASK_ROUNDTIME)

	// Call forward ze_roundend(param1)
	ExecuteForward(g_iForwards[FORWARD_ROUNDEND], _/* Ignore return value */, ZE_TEAM_UNA)
}

public fw_RoundStart_Event()
{
	x_iRoundTime = get_member_game(m_iRoundTime)

	// Task for check round time left.
	set_task(1.0, "check_RoundTime", TASK_ROUNDTIME, .flags = "b")

	g_bFreezePeriod = false
}

public check_RoundTime(const taskid)
{
	if (--x_iRoundTime <= 1)
	{
		rg_round_end(g_flRoundEndDelay, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "", "", true)

		// Remove task.
		remove_task(taskid)
	}
}

public fw_RoundEnd_Event()
{
	g_bRoundEnd = true
}

public fw_TempEntity_Msg(const msg_id, const dest, const player)
{
	if (!g_bBlockBloodEffs)
		return PLUGIN_CONTINUE

	switch (get_msg_arg_int(1))
	{
		case TE_BLOOD, TE_BLOODSTREAM, TE_BLOODSPRITE:
		{
			return PLUGIN_HANDLED
		}
		case TE_DECAL, TE_BSPDECAL, TE_WORLDDECAL, TE_DECALHIGH, TE_WORLDDECALHIGH:
		{
			switch (get_msg_arg_int(5))
			{
				case 192..197:
				{
					return PLUGIN_HANDLED
				}
			}
		}
	}

	return PLUGIN_CONTINUE
}

public fw_TextMsg_Msg(const msg_id, const dest, const player)
{
	static szMsg[32], i
	get_msg_arg_string(2, szMsg, charsmax(szMsg))

	for (i = 0; i < sizeof(g_szBlockTxtMsg); i++)
	{
		if (equali(szMsg, g_szBlockTxtMsg[i]))
		{
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public fw_SendAudio_Msg(const msg_id, const dest, const player)
{
	static szAudio[24], i
	get_msg_arg_string(2, szAudio, charsmax(szAudio))

	for (i = 0; i < sizeof(g_szBlockSounds); i++)
	{
		if (equali(szAudio, g_szBlockSounds[i]))
		{
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public fw_HideWeapon_Msg(const msg_id, const dest, const player)
{
	static iFlags; iFlags = 0

	if (g_bBlockMoneyHUD)
		iFlags |= HIDEHUD_MONEY

	if (g_bBlockHpArRrHUD)
		iFlags |= HIDEHUD_HEALTH

	// Change message arguments.
	set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | iFlags)
	return PLUGIN_CONTINUE
}

public fw_TeamScore_Msg(const msg_id, const dest, const player)
{
	new szTeamName[2]
	get_msg_arg_string(1, szTeamName, charsmax(szTeamName))

	switch (szTeamName[0])
	{
		case 'C': // Humans.
			set_msg_arg_int(2, ARG_BYTE, g_iHumanWins)
		case 'T': // Zombies.
			set_msg_arg_int(2, ARG_BYTE, g_iZombieWins)
	}
}

public fw_MOTD_Msg(const msg_id, const dest, const player)
{
	if (g_bMOTD[player] && g_bBlockStartupMOTD)
	{
		if (get_msg_arg_int(1) == 1)
		{
			g_bMOTD[player] = false
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public fw_PlayerSpawn_Post(const id)
{
	// Block execute rest of Codes.
	if (x_bFixSpawn)
		return

	// Is not Alive?
	if (!is_user_alive(id))
		return

	if (!x_bGameStarted)
	{
		rg_set_user_team(id, TEAM_CT, MODEL_UNASSIGNED)
	}
	else
	{
		if (!x_bGameChosen)
		{
			set_user_Human(id)
		}
		else
		{
			if (x_bRespawnAsZombie)
			{
				set_user_Zombie(id)
			}
			else
			{
				set_user_Human(id)
			}
		}
	}

	check_LastPlayer()

	// Call forward ze_user_spawn_post(id).
	ExecuteForward(g_iForwards[FORWARD_USER_SPAWN_POST], _/* Ignore return value */, id)
}

public fw_PlayerKilled_Post(const iVictim, const iAttacker, const iGibs)
{
	// Is Alive!
	if (is_user_alive(iVictim))
		return

	if (!x_bGameChosen)
	{
		if (get_playersnum_ex(GetPlayers_ExcludeDead) < g_iReqPlayers)
		{
			// No One Won!
			rg_round_end(g_flRoundEndDelay, WINSTATUS_NONE, ROUND_END_DRAW, "", "rounddraw")
		}
		else if (!get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "TERRORIST") && !get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT"))
		{
			// No One Won!
			rg_round_end(g_flRoundEndDelay, WINSTATUS_NONE, ROUND_END_DRAW, "", "rounddraw")
		}
	}

	check_LastPlayer()

	// Call forward ze_user_killed_post(param1, param2, param3)
	ExecuteForward(g_iForwards[FORWARD_USER_KILLED_POST], _/* Ignore return value */, iVictim, iAttacker, iGibs)
}

public fw_TakeDamage_Post(const iVictim, const iInflector, const iAttacker, const Float:flDamage, const bitsDamageType)
{
	// Damage himself?
	if (iVictim == iAttacker || !is_user_connected(iVictim))
		return

	// Pain Shock Free.
	switch (g_iPainShockFree)
	{
		case 1: // Human.
		{
			if (!flag_get_boolean(g_bitsIsZombie, iVictim))
				set_member(iVictim, m_flVelocityModifier, 1.0)
		}
		case 2: // Zombie.
		{
			if (flag_get_boolean(g_bitsIsZombie, iVictim))
				set_member(iVictim, m_flVelocityModifier, 1.0)
		}
		case 3: // Both.
		{
			set_member(iVictim, m_flVelocityModifier, 1.0)
		}
	}
}

public fw_TraceAttack_Pre(const iVictim, const iAttacker, const Float:flDamage, const Float:vDirecton[3], const pTrace, bitsDamageType)
{
	// Damage himself or player not on game?
	if (iVictim == iAttacker || !is_user_connected(iVictim) || !is_user_connected(iAttacker))
		return HC_CONTINUE

	// Round Ended!
	if (g_bRoundEnd)
		return HC_SUPERCEDE

	// Teammate?
	if (flag_get_boolean(g_bitsIsZombie, iVictim) == flag_get_boolean(g_bitsIsZombie, iAttacker))
		return HC_CONTINUE

	// Attacker is Zombie?
	if (flag_get_boolean(g_bitsIsZombie, iAttacker))
	{
		if (get_user_weapon(iAttacker) != CSW_KNIFE)
			return HC_SUPERCEDE

		static iHeadshot; iHeadshot = (get_pmtrace(pTrace, pmt_hitgroup) == HITGROUP_HEAD)

		// Last Human?
		if (get_playersnum_ex(GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT") == 1)
		{
			if (g_bLastHumanDied)
				return HC_CONTINUE

			switch (set_user_Zombie(iVictim, iAttacker, flDamage, iHeadshot))
			{
				case 1: rg_round_end(g_flRoundEndDelay, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "", "", true)
				case 2: return HC_CONTINUE
			}

			return HC_SUPERCEDE
		}

		switch (set_user_Zombie(iVictim, iAttacker, flDamage, iHeadshot))
		{
			case 0..1: return HC_SUPERCEDE
			case 2: return HC_CONTINUE
		}
	}

	return HC_CONTINUE
}

public fw_ResetMaxSpeed_Post(const id)
{
	// Is not Alive!
	if (!is_user_alive(id) || g_bFreezePeriod)
		return

	static Float:flMaxSpeed
	get_entvar(id, var_maxspeed, flMaxSpeed)

	// Player Frozen?
	if (flMaxSpeed <= 1.0)
		return

	// Speed Factor ON!
	if (flag_get_boolean(g_bitsSpeedFactor, id))
	{
		set_entvar(id, var_maxspeed, (flMaxSpeed + g_flUserSpeed[id]))
	}
	else
	{
		set_entvar(id, var_maxspeed, g_flUserSpeed[id])
	}
}

public fw_HasRestrictItem_Pre(const id, const ItemID:iItem)
{
	// Is not Alive?
	if (!is_user_alive(id))
		return HC_CONTINUE

	// Player is Zombie
	if (iItem != ITEM_KNIFE && flag_get_boolean(g_bitsIsZombie, id))
	{
		// Block pick up weapon.
		SetHookChainReturn(ATYPE_BOOL, true)
	}

	return HC_CONTINUE
}

public fw_PlayerHintMessageEx_Pre(id, const message[], Float:duration, bool:bDisplayIfPlayerDead, bool:bOverride)
{
	if (g_bBlockHintMessage)
	{
		SetHookChainReturn(ATYPE_BOOL, true)
		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public fw_CheckWinConditions_Post()
{
	// Block Game Commecing.
	set_member_game(m_bGameStarted, true)
}

public fw_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	switch (event)
	{
		case ROUND_CTS_WIN:
		{
			g_iHumanWins++
			ExecuteForward(g_iForwards[FORWARD_ROUNDEND], _/* Ignore return value */, ZE_TEAM_HUMAN)
		}
		case ROUND_TERRORISTS_WIN:
		{
			g_iZombieWins++
			ExecuteForward(g_iForwards[FORWARD_ROUNDEND], _/* Ignore return value */, ZE_TEAM_ZOMBIE)
		}
	}

	// Update Team Score.
	rg_update_teamscores(g_iHumanWins, g_iZombieWins, false)
}

public fw_CTankUse_Pre(const entity, idCaller, iActivator, iUseType)
{
	if (g_iBlockTanks != 0 && iUseType == USE_SET)
	{
		if (is_user_alive(idCaller))
		{
			switch (g_iBlockTanks)
			{
				case 1: // Zombie Only.
				{
					if (flag_get_boolean(g_bitsIsZombie, idCaller))
						return HAM_SUPERCEDE
				}
				case 2: // Human Only.
				{
					if (!flag_get_boolean(g_bitsIsZombie, idCaller))
						return HAM_SUPERCEDE
				}
				case 3: // Both
				{
					return HAM_SUPERCEDE
				}
			}
		}
	}

	return HAM_IGNORED
}

/**
 * -=| Function(s) |=-
 */
set_user_Human(const id)
{
	// Call forward ze_user_humanized_pre(param1) and get return value.
	ExecuteForward(g_iForwards[FORWARD_USER_HUMANIZED_PRE], g_iFwReturn, id)

	if (g_iFwReturn >= ZE_STOP)
		return 0

	flag_unset(g_bitsIsZombie, id)

	// Give player Knife.
	rg_give_item(id, "weapon_knife", GT_REPLACE)

	// Call forward ze_user_humanized(param1)
	ExecuteForward(g_iForwards[FORWARD_USER_HUMANIZED], _/* Ignore return value */, id)

	// Switch player to CT team.
	rg_set_user_team(id, TEAM_CT, MODEL_UNASSIGNED)

	// Check Last Human and Zombie.
	check_LastPlayer()
	return 1
}

set_user_Zombie(const iVictim, const iAttacker = 0, Float:flDamage = 0.0, bHead = false)
{
	// Call forward ze_user_infected_pre(param1, param2, fparam3)
	ExecuteForward(g_iForwards[FORWARD_USER_INFECTED_PRE], g_iFwReturn, iVictim, iAttacker, flDamage)

	if (g_iFwReturn == ZE_STOP)
		return 2
	else if (g_iFwReturn >= ZE_BREAK)
		return 0

	flag_set(g_bitsIsZombie, iVictim)

	// Remove player all weapons and items.
	rg_remove_all_items(iVictim)

	// Give player Knife only.
	set_msg_block(g_msgWeapPickup, BLOCK_ONCE)
	rg_give_item(iVictim, "weapon_knife", GT_APPEND)

	// Call forward ze_user_infected(param1, param2).
	ExecuteForward(g_iForwards[FORWARD_USER_INFECTED], _/* Ignore return value */, iVictim, iAttacker)

	// Call forward ze_user_infected_ex(param1, param2, param3)
	ExecuteForward(g_iForwards[FORWARD_USER_INFECTED_EX], _/* Ignore return value */, iVictim, iAttacker, bHead)

	// Switch player TERRORIST team.
	rg_set_user_team(iVictim, TEAM_TERRORIST, MODEL_UNASSIGNED)

	// Check Last Human and Zombie.
	check_LastPlayer()
	return 1
}

force_set_user_Human(const id)
{
	flag_unset(g_bitsIsZombie, id)

	// Give player Knife.
	rg_give_item(id, "weapon_knife", GT_APPEND)

	// Call forward ze_user_humanized(param1).
	ExecuteForward(g_iForwards[FORWARD_USER_HUMANIZED], _/* Ignore return value */, id)

	// Switch player CT team.
	rg_set_user_team(id, TEAM_CT, MODEL_UNASSIGNED)

	// Check Last Human and Zombie.
	check_LastPlayer()
}

force_set_user_Zombie(const iVictim, iAttacker = 0, bool:bHead = false)
{
	flag_set(g_bitsIsZombie, iVictim)

	// Remove player all weapons and items.
	rg_remove_all_items(iVictim)

	// Give player Knife only.
	set_msg_block(g_msgWeapPickup, BLOCK_ONCE)
	rg_give_item(iVictim, "weapon_knife", GT_APPEND)

	// Call forward ze_user_infected(param1, param2).
	ExecuteForward(g_iForwards[FORWARD_USER_INFECTED], _/* Ignore return value */, iVictim, iAttacker)
	ExecuteForward(g_iForwards[FORWARD_USER_INFECTED_EX], _/* Ignore return value */, iVictim, iAttacker, bHead)

	// Switch player TERRORIST team.
	rg_set_user_team(iVictim, TEAM_TERRORIST, MODEL_UNASSIGNED)

	// Check Last Human and Zombie.
	check_LastPlayer()
}

/**
 * -=| Natives |=-
 */
public __native_is_user_zombie(const plugin_id, const num_params)
{
	static id; id = get_param(1)

	if (!is_user_connected(id))
	{
		return false
	}

	return flag_get_boolean(g_bitsIsZombie, id)
}

public __native_set_user_human(const plugin_id, const num_params)
{
	new id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	return set_user_Human(id)
}

public __native_set_user_zombie(const plugin_id, const num_params)
{
	new const victim = get_param(1)

	if (!is_user_connected(victim))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Victim not on game (%d)", victim)
		return false
	}

	new const attacker = get_param(2)

	if (attacker > 0)
	{
		if (!is_user_connected(attacker))
		{
			log_error(AMX_ERR_NATIVE, "[ZE] Attacker not on game (%d)", attacker)
			return false
		}
	}

	return (set_user_Zombie(victim, attacker) == 1)
}

public __native_is_last_human(const plugin_id, const num_params)
{
	return g_iLastHuman
}

public __native_is_last_zombie(const plugin_id, const num_params)
{
	return g_iLastZombie
}

public __native_force_set_user_human(const plugin_id, const num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	force_set_user_Human(id)
	return true
}

public __native_force_set_user_zombie(const plugin_id, const num_params)
{
	new const victim = get_param(1)

	if (!is_user_connected(victim))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Victim not on game (%d)", victim)
		return false
	}

	new const attacker = get_param(2)

	if (attacker > 0)
	{
		if (!is_user_connected(attacker))
		{
			log_error(AMX_ERR_NATIVE, "[ZE] Attacker not on game (%d)", attacker)
			return false
		}
	}

	force_set_user_Zombie(victim, attacker)
	return true
}

public __native_set_user_speed(const plugin_id, const num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	if (get_param(3))
		flag_set(g_bitsSpeedFactor, id)
	else
		flag_unset(g_bitsSpeedFactor, id)

	g_flUserSpeed[id] = get_param_f(2)

	// Change speed of the player.
	rg_reset_maxspeed(id)
	return true
}

public __native_reset_user_speed(const plugin_id, const num_params)
{
	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return false
	}

	g_flUserSpeed[id] = 0.0
	flag_unset(g_bitsSpeedFactor, id)

	// Change speed of the player.
	rg_reset_maxspeed(id)
	return true
}

public __native_round_end(const plugin_id, const num_params)
{
	new const team = get_param(1)

	switch (team)
	{
		case ZE_TEAM_HUMAN:
			return rg_round_end(g_flRoundEndDelay, WINSTATUS_CTS, ROUND_CTS_WIN, "", "", true)
		case ZE_TEAM_ZOMBIE:
			return rg_round_end(g_flRoundEndDelay, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, "", "", true)
		case ZE_TEAM_UNA, ZE_TEAM_SPECTATOR:
			return rg_round_end(g_flRoundEndDelay, WINSTATUS_DRAW, ROUND_NONE, "", "", true)
	}

	log_error(AMX_ERR_NATIVE, "[ZE] Invalid Team ID (%d)", team)
	return -1
}