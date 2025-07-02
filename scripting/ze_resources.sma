#include <amxmodx>
#include <fakemeta>
#include <ze_core>
#include <ze_gamemodes>

// Defines.
#define BEGIN_SOUNDS
#define READY_SOUNDS
#define WINS_SOUNDS
#define AMBIENCE_SOUNDS
#define COUNTDOWN_SOUNDS

// Task ID
#define TASK_COUNTDOWN 100

#if defined AMBIENCE_SOUNDS
#define TASK_AMBIENCE 1565

// Enum.
enum _:AMBIENTX_DATA
{
	AMB_NAME[MAX_NAME_LENGTH] = 0,
	AMB_SOUND[MAX_RESOURCE_PATH_LENGTH],
	AMB_LENGTH
}

// Menu Sounds.
new g_szSelectSound[MAX_RESOURCE_PATH_LENGTH] = "buttons/lightswitch2.wav"
new g_szDisplaySound[MAX_RESOURCE_PATH_LENGTH] = "buttons/lightswitch2.wav"

// Cvars.
new Float:g_flAmbDelay

// Variables.
new bool:g_bMenuSounds
#endif
new g_iFwReturn

#if defined COUNTDOWN_SOUNDS
new g_iCountdown,
	g_iGameDelay,
	g_iCountSounds
#endif

new g_iForward

// Dynamic Arrays.
#if defined BEGIN_SOUNDS
new Array:g_aBeginSounds
#endif

#if defined READY_SOUNDS
new Array:g_aReadySounds
#endif

#if defined WINS_SOUNDS
new Array:g_aEscapeFailSounds,
	Array:g_aEscapeSuccessSounds
#endif

#if defined COUNTDOWN_SOUNDS
new Array:g_aCountdownSounds
#endif

new Array:g_aPainSounds,
	Array:g_aPainHeadSounds,
	Array:g_aMissSlashSounds,
	Array:g_aMissWallSounds,
	Array:g_aAttackSounds,
	Array:g_aDieSounds

#if defined AMBIENCE_SOUNDS
// Trie's.
new Trie:g_tAmbientSndx
#endif

public plugin_natives()
{
	register_library("ze_resources")

	#if defined AMBIENCE_SOUNDS
	register_native("ze_res_ambience_register", "__native_res_ambience_register")
	register_native("ze_res_ambience_play", "__native_res_ambience_play")

	register_native("ze_res_ambx_register", "__native_res_ambx_register")
	register_native("ze_res_ambx_play", "__native_res_ambx_play")

	g_tAmbientSndx = TrieCreate()
	#endif

	register_native("ze_res_menu_sound", "__native_res_menu_sound")
}

public plugin_precache()
{
	new szSound[MAX_RESOURCE_PATH_LENGTH], iFiles, i

#if defined BEGIN_SOUNDS
	// Default Begin sound.
	new const szBeginSounds[][] = {"zm_es/ze_newround.wav"}

	// Create new dyn Arrays.
	g_aBeginSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read all sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "BEGIN", g_aBeginSounds)

	if (!ArraySize(g_aBeginSounds))
	{
		for (i = 0; i < sizeof(szBeginSounds); i++)
			ArrayPushString(g_aBeginSounds, szBeginSounds[i])

		// Write Begin sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "BEGIN", g_aBeginSounds)
	}

	iFiles = ArraySize(g_aBeginSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aBeginSounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}
#endif

#if defined READY_SOUNDS
	// Default Ready sound.
	new const szReadySounds[][] = {"zm_es/ze_ready.mp3"}

	// Create new dyn Arrays.
	g_aReadySounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read Ready sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "READY", g_aReadySounds)

	if (!ArraySize(g_aReadySounds))
	{
		for (i = 0; i < sizeof(g_aReadySounds); i++)
			ArrayPushString(g_aReadySounds, szReadySounds[i])

		// Write Ready sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "READY", g_aReadySounds)
	}

	iFiles = ArraySize(g_aReadySounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aReadySounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}
#endif

#if defined WINS_SOUNDS
	// Default Escape Success/Fail sounds.
	new const szEscapeFailSound[][] = {"zm_es/escape_success.wav"}
	new const szEscapeSucessSound[][] = {"zm_es/escape_fail.wav"}

	// Create new dyn Arrays.
	g_aEscapeFailSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aEscapeSuccessSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read Escape Success and Fail sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "ESCAPE_FAIL", g_aEscapeFailSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "ESCAPE_SUCCESS", g_aEscapeSuccessSounds)

	if (!ArraySize(g_aEscapeFailSounds))
	{
		for (i = 0; i < sizeof(szEscapeFailSound); i++)
			ArrayPushString(g_aEscapeFailSounds, szEscapeFailSound[i])

		// Write Escape Fail sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "ESCAPE_FAIL", g_aEscapeFailSounds)
	}

	if (!ArraySize(g_aEscapeSuccessSounds))
	{
		for (i = 0; i < sizeof(szEscapeSucessSound); i++)
			ArrayPushString(g_aEscapeSuccessSounds, szEscapeSucessSound[i])

		// Write Escape Success sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "ESCAPE_SUCCESS", g_aEscapeSuccessSounds)
	}

	iFiles = ArraySize(g_aEscapeFailSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aEscapeFailSounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}

	iFiles = ArraySize(g_aEscapeSuccessSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aEscapeSuccessSounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}
#endif

#if defined COUNTDOWN_SOUNDS
	// Default Countdown sounds.
	new const szCountdownSounds[][] = {"zm_es/count/1.wav", "zm_es/count/2.wav", "zm_es/count/3.wav", "zm_es/count/4.wav", "zm_es/count/5.wav", "zm_es/count/6.wav","zm_es/count/7.wav", "zm_es/count/8.wav", "zm_es/count/9.wav", "zm_es/count/10.wav"}

	// Create new dyn Array.
	g_aCountdownSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read Countdown sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "COUNTDOWN", g_aCountdownSounds)

	if (!ArraySize(g_aCountdownSounds))
	{
		for (i = 0; i < sizeof(szCountdownSounds); i++)
			ArrayPushString(g_aCountdownSounds, szCountdownSounds[i])

		// Write Countdown sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "COUNTDOWN", g_aCountdownSounds)
	}

	iFiles = ArraySize(g_aCountdownSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetArray(g_aCountdownSounds, i, szSound, charsmax(szSound))
		format(szSound, charsmax(szSound), "sound/%s", szSound)
		precache_generic(szSound)
	}
#endif

	new const szPainSounds[][] = {"zm_es/zombie_pain_1.wav", "zm_es/zombie_pain_2.wav"}
	new const szPainHeadSounds[][] = {"zm_es/zombie_pain_1.wav", "zm_es/zombie_pain_2.wav"}
	new const szMissSlashSounds[][] = {"zm_es/zombie_miss_slash_1.wav", "zm_es/zombie_miss_slash_2.wav", "zm_es/zombie_miss_slash_3.wav"}
	new const szMissWallSounds[][] = {"zm_es/zombie_miss_wall_1.wav", "zm_es/zombie_miss_wall_2.wav", "zm_es/zombie_miss_wall_3.wav"}
	new const szAttackSounds[][] = {"zm_es/zombie_attack_1.wav", "zm_es/zombie_attack_2.wav", "zm_es/zombie_attack_3.wav"}
	new const szDieSounds[][] = {"zm_es/zombie_death.wav", "zm_es/zombie_death_1.wav"}

	// Create new dyn Arrays.
	g_aPainSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aPainHeadSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aMissSlashSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aMissWallSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aAttackSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)
	g_aDieSounds = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1)

	// Read Zombie sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "Sounds", "PAIN", g_aPainSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "PAIN_HEAD", g_aPainHeadSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "MISS_SLASH", g_aMissSlashSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "MISS_WALL", g_aMissWallSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "ATTACK", g_aAttackSounds)
	ini_read_string_array(ZE_FILENAME, "Sounds", "DIE", g_aDieSounds)

	if (!ArraySize(g_aPainSounds))
	{
		for (i = 0; i < sizeof(szPainSounds); i++)
			ArrayPushString(g_aPainSounds, szPainSounds[i])

		// Write Pain sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "PAIN", g_aPainSounds)
	}

	if (!ArraySize(g_aPainHeadSounds))
	{
		for (i = 0; i < sizeof(szPainHeadSounds); i++)
			ArrayPushString(g_aPainHeadSounds, szPainHeadSounds[i])

		// Write Pain headshot sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "PAIN_HEAD", g_aPainHeadSounds)
	}

	if (!ArraySize(g_aMissSlashSounds))
	{
		for (i = 0; i < sizeof(szMissSlashSounds); i++)
			ArrayPushString(g_aMissSlashSounds, szMissSlashSounds[i])

		// Write Miss Slash sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "MISS_SLASH", g_aMissSlashSounds)
	}

	if (!ArraySize(g_aMissWallSounds))
	{
		for (i = 0; i < sizeof(szMissWallSounds); i++)
			ArrayPushString(g_aMissWallSounds, szMissWallSounds[i])

		// Write Miss Wall sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "MISS_WALL", g_aMissWallSounds)
	}

	if (!ArraySize(g_aAttackSounds))
	{
		for (i = 0; i < sizeof(szAttackSounds); i++)
			ArrayPushString(g_aAttackSounds, szAttackSounds[i])

		// Write Attack sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "ATTACK", g_aAttackSounds)
	}

	if (!ArraySize(g_aDieSounds))
	{
		for (i = 0; i < sizeof(szDieSounds); i++)
			ArrayPushString(g_aDieSounds, szDieSounds[i])

		// Write Die sounds on INI file.
		ini_write_string_array(ZE_FILENAME, "Sounds", "DIE", g_aDieSounds)
	}

	// Precache Sounds.
	iFiles = ArraySize(g_aPainSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aPainSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	iFiles = ArraySize(g_aPainHeadSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aPainHeadSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	iFiles = ArraySize(g_aMissSlashSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aMissSlashSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	iFiles = ArraySize(g_aMissWallSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aMissWallSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	iFiles = ArraySize(g_aAttackSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aAttackSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	iFiles = ArraySize(g_aDieSounds)
	for (i = 0; i < iFiles; i++)
	{
		ArrayGetString(g_aDieSounds, i, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	// Read menu sounds from INI file.
	if (!ini_read_string(ZE_FILENAME, "Sounds", "MENU_SELECT", g_szSelectSound, charsmax(g_szSelectSound)))
		ini_write_string(ZE_FILENAME, "Sounds", "MENU_SELECT", g_szSelectSound)
	if (!ini_read_string(ZE_FILENAME, "Sounds", "MENU_DISPLAY", g_szDisplaySound, charsmax(g_szDisplaySound)))
		ini_write_string(ZE_FILENAME, "Sounds", "MENU_DISPLAY", g_szDisplaySound)

	// Precache Sounds.
	precache_generic(fmt("sound/%s", g_szSelectSound))
	precache_generic(fmt("sound/%s", g_szDisplaySound))
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Resources", ZE_VERSION, ZE_AUTHORS)

	// Hook Chain.
	register_forward(FM_EmitSound, "fw_EmitSound_Pre")

#if defined COUNTDOWN_SOUNDS
	bind_pcvar_num(get_cvar_pointer("ze_gamemodes_delay"), g_iGameDelay)
#endif
	bind_pcvar_num(register_cvar("ze_menu_sounds", "1"), g_bMenuSounds)

	// Create Forwards.
	g_iForward = CreateMultiForward("ze_res_fw_zombie_sound", ET_CONTINUE, FP_CELL, FP_CELL, FP_ARRAY)
}

#if defined AMBIENCE_SOUNDS
public plugin_cfg()
{
	g_flAmbDelay = 5.0

	if (!ini_read_float(ZE_FILENAME, "AmbienceX", "DELAY_START", g_flAmbDelay))
		ini_write_float(ZE_FILENAME, "AmbienceX", "DELAY_START", g_flAmbDelay)
}
#endif

public plugin_end()
{
	// Free the Memory.
	DestroyForward(g_iForward)

	#if defined BEGIN_SOUNDS
	ArrayDestroy(g_aBeginSounds)
	#endif
	#if defined READY_SOUNDS
	ArrayDestroy(g_aReadySounds)
	#endif
	#if defined WINS_SOUNDS
	ArrayDestroy(g_aEscapeFailSounds)
	ArrayDestroy(g_aEscapeSuccessSounds)
	#endif
	#if defined COUNTDOWN_SOUNDS
	ArrayDestroy(g_aCountdownSounds)
	#endif

	ArrayDestroy(g_aPainSounds)
	ArrayDestroy(g_aPainHeadSounds)
	ArrayDestroy(g_aMissSlashSounds)
	ArrayDestroy(g_aMissWallSounds)
	ArrayDestroy(g_aAttackSounds)
	ArrayDestroy(g_aDieSounds)

	#if defined AMBIENCE_SOUNDS
	TrieDestroy(g_tAmbientSndx)
	#endif
}

public ze_game_started_pre()
{
#if defined COUNTDOWN_SOUNDS
	remove_task(TASK_COUNTDOWN)
#endif
}

public ze_game_started()
{
	new szSound[MAX_RESOURCE_PATH_LENGTH]

	// Stop all sounds.
	StopSound()

#if defined BEGIN_SOUNDS
	// Play Begin sound for everyone.
	ArrayGetString(g_aBeginSounds, random_num(0, ArraySize(g_aBeginSounds) - 1), szSound, charsmax(szSound))
	PlaySound(0, szSound)
#endif

#if defined READY_SOUNDS
	// Play Ready sound for everyone.
	ArrayGetString(g_aReadySounds, random_num(0, ArraySize(g_aReadySounds) - 1), szSound, charsmax(szSound))
	PlaySound(0, szSound)
#endif

#if defined AMBIENCE_SOUNDS
	remove_task(TASK_AMBIENCE)
#endif

#if defined COUNTDOWN_SOUNDS
	g_iCountdown = g_iGameDelay
	g_iCountSounds = ArraySize(g_aCountdownSounds)
	set_task(1.0, "play_Countdown", TASK_COUNTDOWN, .flags = "b")
#endif
}

public ze_gamemode_chosen(game_id, target)
{
	// Remove Countdown Task.
	remove_task(TASK_COUNTDOWN)
}

public play_Countdown(taskid)
{
	g_iCountdown--

	if (g_iCountdown <= 0)
	{
		remove_task(taskid)
		return
	}

	if (g_iCountdown <= g_iCountSounds)
	{
		if (g_iCountdown - 1 > INVALID_HANDLE)
		{
			static szSound[MAX_RESOURCE_PATH_LENGTH]
			ArrayGetString(g_aCountdownSounds, g_iCountdown - 1, szSound, charsmax(szSound))
			PlaySound(0, szSound)
		}
	}
}

public ze_roundend(iWinTeam)
{
	// Stop all sounds.
	StopSound()

#if defined AMBIENCE_SOUNDS
	remove_task(TASK_AMBIENCE)
#endif

#if defined COUNTDOWN_SOUNDS
	remove_task(TASK_COUNTDOWN)
#endif

#if defined WINS_SOUNDS
	switch (iWinTeam)
	{
		case ZE_TEAM_HUMAN:
		{
			new szSound[MAX_RESOURCE_PATH_LENGTH]
			ArrayGetString(g_aEscapeSuccessSounds, random_num(0, ArraySize(g_aEscapeSuccessSounds) - 1), szSound, charsmax(szSound))
			PlaySound(0, szSound)
		}
		case ZE_TEAM_ZOMBIE:
		{
			new szSound[MAX_RESOURCE_PATH_LENGTH]
			ArrayGetString(g_aEscapeFailSounds, random_num(0, ArraySize(g_aEscapeFailSounds) - 1), szSound, charsmax(szSound))
			PlaySound(0, szSound)
		}
	}
#endif
}

public fw_EmitSound_Pre(const iEnt, iChan, const szSample[], Float:flVol, Float:flAttn, bitsFlags, iPitch)
{
	// Is not Player?
	if (szSample[0] != 'p' && szSample[1] != 'l' && szSample[2] != 'a')
		return FMRES_IGNORED

	// Is not Zombie?
	if (!ze_is_user_zombie(iEnt))
		return FMRES_IGNORED

	static szSound[MAX_RESOURCE_PATH_LENGTH]; szSound = NULL_STRING

	// Pain.
	if (szSample[7] == 'b' && szSample[8] == 'h' && szSample[9] == 'i')
	{
		ArrayGetString(g_aPainSounds, random_num(0, ArraySize(g_aPainSounds) - 1), szSound, charsmax(szSound))

		// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
		ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_PAIN, PrepareArray(szSound, sizeof(szSound), 1))

		if (g_iFwReturn >= ZE_STOP || !szSound[0])
			return FMRES_SUPERCEDE

		emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
		return FMRES_SUPERCEDE
	}

	// Headshot.
	if (szSample[7] == 'h' && szSample[8] == 'e' && szSample[9] == 'a')
	{
		ArrayGetString(g_aPainHeadSounds, random_num(0, ArraySize(g_aPainHeadSounds) - 1), szSound, charsmax(szSound))

		// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
		ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_HDSHOT, PrepareArray(szSound, sizeof(szSound), 1))

		if (g_iFwReturn >= ZE_STOP || !szSound[0])
			return FMRES_SUPERCEDE

		emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
		return FMRES_SUPERCEDE
	}

	if (szSample[8] == 'k' && szSample[9] == 'n' && szSample[10] == 'i')
	{
		// Miss Slash.
		if (szSample[14] == 's' && szSample[15] == 'l' && szSample[16] == 'a')
		{
			ArrayGetString(g_aMissSlashSounds, random_num(0, ArraySize(g_aMissSlashSounds) - 1), szSound, charsmax(szSound))

			// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
			ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_SLASH, PrepareArray(szSound, sizeof(szSound), 1))

			if (g_iFwReturn >= ZE_STOP || !szSound[0])
				return FMRES_SUPERCEDE

			emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
			return FMRES_SUPERCEDE
		}

		if (szSample[14] == 'h' && szSample[15] == 'i' && szSample[16] == 't')
		{
			// Miss Wall.
			if (szSample[17] == 'w')
			{
	 			ArrayGetString(g_aMissWallSounds, random_num(0, ArraySize(g_aMissWallSounds) - 1), szSound, charsmax(szSound))

				// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
				ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_WALL, PrepareArray(szSound, sizeof(szSound), 1))

				if (g_iFwReturn >= ZE_STOP || !szSound[0])
					return FMRES_SUPERCEDE

				emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
				return FMRES_SUPERCEDE
			}
			else // Attack.
			{
				ArrayGetString(g_aAttackSounds, random_num(0, ArraySize(g_aAttackSounds) - 1), szSound, charsmax(szSound))

				// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
				ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_ATTACK, PrepareArray(szSound, sizeof(szSound), 1))

				if (g_iFwReturn >= ZE_STOP || !szSound[0])
					return FMRES_SUPERCEDE

				emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
				return FMRES_SUPERCEDE
			}
		}

		// Attack.
		if (szSample[14] == 's' && szSample[15] == 't' && szSample[16] == 'a')
		{
			ArrayGetString(g_aAttackSounds, random_num(0, ArraySize(g_aAttackSounds) - 1), szSound, charsmax(szSound))

			// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
			ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_ATTACK, PrepareArray(szSound, sizeof(szSound), 1))

			if (g_iFwReturn >= ZE_STOP || !szSound[0])
				return FMRES_SUPERCEDE

			emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
			return FMRES_SUPERCEDE
		}
	}

	// Die | Death.
	if (szSample[7] == 'd' && (szSample[8] == 'i' || szSample[8] == 'e') && (szSample[9] == 'e' || szSample[9] == 'a'))
	{
		ArrayGetString(g_aDieSounds, random_num(0, ArraySize(g_aDieSounds) - 1), szSound, charsmax(szSound))

		// Call forward ze_res_fw_zombie_sound(param1, param2, array[])
		ExecuteForward(g_iForward, g_iFwReturn, iEnt, ZE_SND_DIE, PrepareArray(szSound, sizeof(szSound), 1))

		if (g_iFwReturn >= ZE_STOP || !szSound[0])
			return FMRES_SUPERCEDE

		emit_sound(iEnt, iChan, szSound, flVol, flAttn, bitsFlags, iPitch)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

/**
 * -=| Natives |=-
 */
#if defined AMBIENCE_SOUNDS
public __native_res_ambience_register(plugin_id, num_params)
{
	log_error(AMX_ERR_GENERAL, "[ZE] This native deprecated!, Use ze_res_ambx_register()")
	return -1
}

public __native_res_ambience_play(plugin_id, num_params)
{
	log_error(AMX_ERR_GENERAL, "[ZE] This native deprecated!, Use ze_res_ambx_play()")
	return 0
}

public __native_res_ambx_register(plugin_id, num_params)
{
	new szName[MAX_NAME_LENGTH]
	if (!get_string(1, szName, charsmax(szName)))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Cannot register a new ambient sound without specifying the game mode name.")
		return false
	}

	mb_strtoupper(szName, charsmax(szName))
	if (TrieKeyExists(g_tAmbientSndx, szName))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] The game mode (%s) already has ambient sounds.", szName)
		return false
	}

	new pArray[AMBIENTX_DATA], szTemp[128], bool:bFileLoaded, i

	// Create dyn Arrays.
	new Array:aTempSounds = ArrayCreate(128, 1)
	new Array:aAmbSounds = ArrayCreate(AMBIENTX_DATA, 1)

	// Read ambient sounds from INI file.
	ini_read_string_array(ZE_FILENAME, "AmbienceX", szName, aTempSounds)

	new szSound[MAX_RESOURCE_PATH_LENGTH]
	if (!ArraySize(aTempSounds))
	{
		for (i = 2; i < num_params; i++)
		{
			get_string(i, pArray[AMB_SOUND], charsmax(pArray) - AMB_SOUND)
			pArray[AMB_LENGTH] = get_param(i + 1)
			ArrayPushArray(aAmbSounds, pArray)

			// Pre-load sound file.
			formatex(szSound, charsmax(szSound), "sound/%s", pArray[AMB_SOUND])
			precache_generic(szSound)

			formatex(szTemp, charsmax(szTemp), "%s:%i", pArray[AMB_SOUND], pArray[AMB_LENGTH])
			ArrayPushString(aTempSounds, szTemp)
		}

		// Write default ambience(s) sounds in INI file.
		ini_write_string_array(ZE_FILENAME, "AmbienceX", szName, aTempSounds)
		bFileLoaded = true
	}

	if (!bFileLoaded)
	{
		new const iSounds = ArraySize(aTempSounds)

		new szLength[10]
		for (i = 0; i < iSounds; i++)
		{
			ArrayGetString(aTempSounds, i, szTemp, charsmax(szTemp))

			strtok2(szTemp, pArray[AMB_SOUND], charsmax(pArray) - AMB_SOUND, szLength, charsmax(szLength), ':')
			pArray[AMB_LENGTH] = str_to_num(szLength)

			// Pre-load sound file.
			formatex(szSound, charsmax(szSound), "sound/%s", pArray[AMB_SOUND])
			precache_generic(szSound)

			ArrayPushArray(aAmbSounds, pArray)
		}
	}

	// Free the Memory.
	ArrayDestroy(aTempSounds)

	TrieSetCell(g_tAmbientSndx, szName, aAmbSounds)
	return true
}

public __native_res_ambx_play(plugin_id, num_params)
{
	new szName[MAX_NAME_LENGTH]
	if (!get_string(1, szName, charsmax(szName)))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Cannot play ambient sound without a registered game mode name.")
		return false
	}

	mb_strtoupper(szName, charsmax(szName))
	if (!TrieKeyExists(g_tAmbientSndx, szName))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] This an ambient sound not found (%s)", szName)
		return false
	}

	new Array:aHandle
	TrieGetCell(g_tAmbientSndx, szName, aHandle)

	new pArray[AMBIENTX_DATA]
	ArrayGetArray(aHandle, random_num(0, ArraySize(aHandle) - 1), pArray)

	// Delay before play Ambience sound.
	set_task(g_flAmbDelay, "@play_Sound", TASK_AMBIENCE, pArray[AMB_SOUND], AMB_SOUND, "a", 1)

	if (get_param(2))
	{
		// Task for repeat Ambience sound.
		set_task(float(pArray[AMB_LENGTH]), "@play_Sound", TASK_AMBIENCE, pArray[AMB_SOUND], AMB_SOUND, "b")
	}

	return true
}

@play_Sound(const szSound[], taskid)
{
	new iPlayers[MAX_PLAYERS], iAliveNum
	get_players(iPlayers, iAliveNum, "h")

	for (new id, i = 0; i < iAliveNum; i++)
	{
		id = iPlayers[i]

		// Play sound for player.
		PlaySound(id, szSound)
	}
}
#endif

public __native_res_menu_sound(const plugin_id, const num_params)
{
	if (!g_bMenuSounds)
	{
		return 2
	}

	new const id = get_param(1)

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Player not on game (%d)", id)
		return 0
	}

	switch (get_param(2))
	{
		case ZE_MENU_SELECT:
			client_cmd(id, "spk ^"%s^"", g_szSelectSound)
		case ZE_MENU_DISPLAY:
			client_cmd(id, "spk ^"%s^"", g_szDisplaySound)
	}

	return 1
}