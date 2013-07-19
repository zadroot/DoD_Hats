/**
* DoD:S Hats by Root
*
* Description:
*   Attaches specified models to players above their head.
*
* Version 0.9.9
* Changelog & more info at http://goo.gl/4nKhJ
*/

// ====[ SEMICOLON ]======================================================
#pragma semicolon 1

// ====[ STOCK INCLUDES ]=================================================
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

// ====[ CUSTOM INCLUDES ]================================================
#include <colors>
#undef REQUIRE_PLUGIN
#include <updater>

// ====[ CONSTANTS ]======================================================
#define PLUGIN_NAME    "DoD:S Hats"
#define PLUGIN_VERSION "0.9.9"

#define PREFIX         "{green}[Hats]{olive} "
#define UPDATE_URL     "https://raw.github.com/zadroot/DoD_Hats/master/updater.txt"
#define DOD_MAXPLAYERS 33
#define	MAX_HATS       64

// ====[ VARIABLES ]======================================================
new	Handle:dodhats_enable      = INVALID_HANDLE,
	Handle:dodhats_access      = INVALID_HANDLE,
	Handle:dodhats_random      = INVALID_HANDLE,
	Handle:dodhats_clientprefs = INVALID_HANDLE,
	Handle:dodhats_cookie      = INVALID_HANDLE,
	Handle:dodhats_menu        = INVALID_HANDLE;

new	hats_count,                       // Amount of avalible hats
	hat_flag,                         // Used to convert AdmFlag convar string
	hat_index[DOD_MAXPLAYERS + 1],    // Player hat entity reference
	hat_selected[DOD_MAXPLAYERS + 1], // The selected hat index
	hat_target[DOD_MAXPLAYERS + 1],   // For admins to change clients hats
	hat_save[DOD_MAXPLAYERS + 1];     // Stores selected hat to give players

new	bool:hat_drawn[DOD_MAXPLAYERS + 1],      // Player view of hat on/off
	bool:hats_disabled[DOD_MAXPLAYERS + 1],  // Lets players turn their hats on/off
	bool:hats_adminmenu[DOD_MAXPLAYERS + 1]; // Admin var for menu

new	String:Models[MAX_HATS][64],
	String:Names[MAX_HATS][64],
	Float:hatangles[MAX_HATS][3],
	Float:hatposition[MAX_HATS][3],
	Float:hatsize[MAX_HATS];

// ====[ PLUGIN ]=========================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Attaches specified models to players above their head",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/**
 * -----------------------------------------------------------------------
 *     ____           ______                  __  _
 *    / __ \____     / ____/__  ______  _____/ /_(_)____  ____  _____
 *   / / / / __ \   / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
 *  / /_/ / / / /  / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  )
 *  \____/_/ /_/  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/
 *
 * -----------------------------------------------------------------------
*/

/* OnPluginStart()
 *
 * When the plugin starts up.
 * ----------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create ConVars
	CreateConVar("dod_hats_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	dodhats_enable      = CreateConVar("dod_hats_enable",  "1",   "Whether or not enable Hats plugin",                                                          FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodhats_access      = CreateConVar("dod_hats_admflag", "",    "Add specified admin flag name or blank to allow all players access to the hats menu",        FCVAR_PLUGIN);
	dodhats_random      = CreateConVar("dod_hats_random",  "1",   "Whether or not attach a random hat when player is respawning (saved hats will be ignored)",  FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodhats_clientprefs = CreateConVar("dod_hats_save",    "1",   "Whether or not save players selected hats and attach when they spawn or rejoin the server",  FCVAR_PLUGIN, true, 0.0, true, 1.0);

	// Hook only one convar changing - on enable toggle
	HookConVarChange(dodhats_enable, OnConVarChange);

	// Create/register client and admin commands
	RegConsoleCmd("sm_hat",       Command_Hat,                       "Displays a menu of hats allowing players to change what they are wearing");
	RegConsoleCmd("sm_hats",      Command_Hat,                       "Alias for \"sm_hat\"");
	RegConsoleCmd("sm_hatoff",    Command_DisableHat,                "Toggle to turn on or off the ability of wearing hats");
	RegConsoleCmd("sm_hatshow",   Command_ShowHat,                   "Toggle to see or hide your own hat");
	RegConsoleCmd("sm_hatview",   Command_ShowHat,                   "Alias for \"sm_hatview\"");
	RegAdminCmd  ("sm_hatreload",  Admin_ReloadConfig,  ADMFLAG_ROOT, "Reload hats configuration file");
	RegAdminCmd  ("sm_hatrefresh", Admin_ReloadConfig,  ADMFLAG_ROOT, "Alias for \"sm_hatreload\"");
	RegAdminCmd  ("sm_hatc",       Admin_ShowHatMenu,   ADMFLAG_ROOT, "Displays a menu listing players, select one to change their hat");
	RegAdminCmd  ("sm_hatclient",  Admin_ShowHatMenu,   ADMFLAG_ROOT, "Alias for \"sm_hatc\"");
	RegAdminCmd  ("sm_hatchange",  Admin_ShowHatMenu,   ADMFLAG_ROOT, "Alias for \"sm_hatc\"");
	RegAdminCmd  ("sm_hatrandom",  Admin_RandomizeHats, ADMFLAG_ROOT, "Randomizes all players hats");
	RegAdminCmd  ("sm_hatrand",    Admin_RandomizeHats, ADMFLAG_ROOT, "Alias for \"sm_hatrandom\"");
	RegAdminCmd  ("sm_hatadd",     Admin_AddHat,        ADMFLAG_ROOT, "Adds specified model to the config (must be the full model path)");
	RegAdminCmd  ("sm_hatdel",     Admin_DeleteHat,     ADMFLAG_ROOT, "Removes a model from the config (either by index or partial name matching)");
	RegAdminCmd  ("sm_hatdelete",  Admin_DeleteHat,     ADMFLAG_ROOT, "Alias for \"sm_hatdel\"");
	RegAdminCmd  ("sm_hatlist",    Admin_ShowHatList,   ADMFLAG_ROOT, "Displays a list of all the hat models (for use with sm_hatdel)");
	RegAdminCmd  ("sm_hatsave",    Admin_SaveHat,       ADMFLAG_ROOT, "Saves the hat position and angels to the hat config");
	RegAdminCmd  ("sm_hatload",    Admin_ForceHat,      ADMFLAG_ROOT, "Changes all players hats to the one you have");
	RegAdminCmd  ("sm_hatforce",   Admin_ForceHat,      ADMFLAG_ROOT, "Alias for \"sm_hatload\"");
	RegAdminCmd  ("sm_hatang",     Admin_ChangeAngles,  ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat angles (affects all hats/players)");
	RegAdminCmd  ("sm_hatangles",  Admin_ChangeAngles,  ADMFLAG_ROOT, "Alias for \"sm_hatang\"");
	RegAdminCmd  ("sm_hatpos",     Admin_ChangeOrigin,  ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat position (affects all hats/players)");
	RegAdminCmd  ("sm_hatorigin",  Admin_ChangeOrigin,  ADMFLAG_ROOT, "Alias for \"sm_hatpos\"");
	RegAdminCmd  ("sm_hatsize",    Admin_ChangeSize,    ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat size (affects all hats/players)");

	// Load translations
	LoadTranslations("common.phrases");
	LoadTranslations("dod_hats.phrases");

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "dod_hats");

	// Load events by manual cvar change
	OnConVarChange(dodhats_enable, "0", "1");

	// Adds plugin to the updater if selftitled library is avalible
	if (LibraryExists("updater")) Updater_AddPlugin(UPDATE_URL);

	// Creates a new Client preference cookies
	dodhats_cookie = RegClientCookie("dod_hats", "Hat Model", CookieAccess_Protected);
}

/* OnPluginEnd()
 *
 * When the plugin is about to be unloaded.
 * ----------------------------------------------------------------------- */
public OnPluginEnd()
{
	// Remove all previous hats when plugin is un/reloading
	for (new i = 1; i <= MaxClients; i++)
	if (IsValidClient(i)) RemoveHat(i);
}

/* OnMapStart()
 *
 * When the map starts.
 * ----------------------------------------------------------------------- */
public OnMapStart()
{
	// Precache all available hats
	// ToDo: add downloader support ?
	LoadConfig();

	for (new i = 0; i < hats_count; i++)
	{
		PrecacheModel(Models[i]);
	}
}

/* OnLibraryAdded()
 *
 * Called after a library is added that the current plugin references optionally.
 * ----------------------------------------------------------------------- */
public OnLibraryAdded(const String:name[])
{
	// Update plugin
	if (StrEqual(name, "updater")) Updater_AddPlugin(UPDATE_URL);
}

/* OnClientCookiesCached()
 *
 * Called once a client's saved cookies have been loaded from the database.
 * -------------------------------------------------------------------------- */
public OnClientCookiesCached(client)
{
	// If cookies was not ready until connection, wait until OnClientCookiesCached()
	if (IsValidClient(client)) LoadCookies(client);
}

/* OnConVarChange()
 *
 * Called when a convar's value is changed.
 * ----------------------------------------------------------------------- */
public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Converts a string to an integer
	switch (StringToInt(newValue))
	{
		case false: UnhookEvents();
		case true:  HookEvents();
	}
}


/**
 * -----------------------------------------------------------------------
 *      ______                  __
 *     / ____/_   _____  ____  / /______
 *    / __/  | | / / _ \/ __ \/ __/ ___/
 *   / /___  | |/ /  __/ / / / /_(__  )
 *  /_____/  |___/\___/_/ /_/\__/____/
 *
 * -----------------------------------------------------------------------
*/

/* HookEvents()
 *
 * Hooks plugin-needed events on start.
 * ----------------------------------------------------------------------- */
HookEvents()
{
	HookEvent("player_hurt",  Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

/* UnhookEvents()
 *
 * Unhooks plugin-needed events when convar value changed.
 * ----------------------------------------------------------------------- */
UnhookEvents()
{
	UnhookEvent("player_hurt",  Event_PlayerHurt);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
}

/* Event_player_hurt()
 *
 * Called when a player gets hurt.
 * ----------------------------------------------------------------------- */
public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	// On death event hats wont disappear, but this one is working fine
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientHealth(client) < 1) RemoveHat(client);
}

/* Event_player_spawn()
 *
 * Called when a player spawns.
 * ----------------------------------------------------------------------- */
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(dodhats_enable))
	{
		new clientID = GetEventInt(event, "userid");
		new client   = GetClientOfUserId(clientID);

		// Client may re-spawn. I wont give any chance so lets remove previous hat
		RemoveHat(client);

		// Randomize hat if enabled. Otherwise create client's selected hat
		if (GetConVarBool(dodhats_random))
		{
			RandomHat();
		}
		else CreateTimer(0.1, Timer_CreateHat, clientID, TIMER_FLAG_NO_MAPCHANGE);
	}
}


/**
 * -----------------------------------------------------------------------
 *     ______                                          __
 *    / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
 *   / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
 *  / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  )
 *  \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/
 *
 * -----------------------------------------------------------------------
*/

/* Command_Hat()
 *
 * Displays a menu of hats allowing players to change what they are wearing.
 * ----------------------------------------------------------------------- */
public Action:Command_Hat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		decl String:text[64];

		// Get the flag name from 'hat access' convar
		GetConVarString(dodhats_access, text, sizeof(text));
		hat_flag = ReadFlagString(text);

		// Check if client is having admin flags
		new flagc = GetUserFlagBits(client);

		if (hat_flag != 0 && !(flagc & ADMFLAG_ROOT))
		{
			// If flag is specified and client dont have any admin rights, dont change his hat
			if (IsValidClient(client) || !(flagc & hat_flag))
			{
				CPrintToChat(client, "%s%t", PREFIX, "No Access");
				return Plugin_Handled;
			}
		}

		ShowMenu(client);
	}

	else CPrintToChat(client, "%s%t", PREFIX, "No Access");
	return Plugin_Handled;
}

/* Command_DisableHat()
 *
 * Toggle to turn on or off the ability of wearing hats.
 * ----------------------------------------------------------------------- */
public Action:Command_DisableHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// If hats was disabled before, enable it
		if (!hats_disabled[client])
		{
			hats_disabled[client] = true;
			RemoveHat(client);
		}

		// Otherwise enable it again
		else hats_disabled[client] = false;

		// Notify client about enabling or disabling hat
		decl String:text[32];
		Format(text, sizeof(text), "%T", hats_disabled[client] ? "Off" : "On", client);
		CPrintToChat(client, "%s%t", PREFIX, "Hat_Ability", text);
	}

	// Hats is disabled or client is invalid (spectator/dead)
	else CPrintToChat(client, "%s%t", PREFIX, "No Access");
	return Plugin_Handled;
}

/* Command_ShowHat()
 *
 * Toggle to see or hide own hat.
 * ----------------------------------------------------------------------- */
public Action:Command_ShowHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// Get entity by hat index
		new entity = hat_index[client];

		// And make sure hat is valid
		if (entity == 0 || (entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE)
		{
			CPrintToChat(client, "%s%t", PREFIX, "Hat_Missing");
			return Plugin_Handled;
		}

		// Check if hat is hidden or not
		if (hat_drawn[client])
		{
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
			ThirdPerson(client, false);
			hat_drawn[client] = false;
		}
		else
		{
			// Make hat viewable for client
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

			// And show thirdperson view
			ThirdPerson(client, true);
			hat_drawn[client] = true;
		}

		decl String:text[32];
		Format(text, sizeof(text), "%T", hat_drawn[client] ? "On" : "Off", client);
		CPrintToChat(client, "%s%t", PREFIX, "Hat_View", text);
	}
	else CPrintToChat(client, "%s%t", PREFIX, "No Access");

	// Prevents 'unknown command' reply in client console
	return Plugin_Handled;
}

/* Admin_ReloadConfig()
 *
 * Reload hats configuration file.
 * ----------------------------------------------------------------------- */
public Action:Admin_ReloadConfig(client, args)
{
	// Just load config once again
	OnMapStart();

	// Its a separate command which requires notices
	CPrintToChat(client, "%s%t", PREFIX, "Reloaded Config");
	return Plugin_Handled;
}

/* Admin_AddHat()
 *
 * Adds specified model to the config (must be the full model path).
 * ----------------------------------------------------------------------- */
public Action:Admin_AddHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		if (args == 1)
		{
			// Add hat if overall amount of hats not exceed 64
			if (hats_count <= MAX_HATS)
			{
				decl String:text[64], String:key[16];
				GetCmdArg(1, text, sizeof(text));

				// Checks if added model is exists
				if (FileExists(Models[hats_count], true))
				{
					// Create default 'angles/origin/size' config sections
					strcopy(Models[hats_count], sizeof(text), text);
					hatangles[hats_count]   = Float:{ 0.0, 0.0, 0.0 };
					hatposition[hats_count] = Float:{ 0.0, 0.0, 0.0 };
					hatsize[hats_count]     = 1.0;

					// Then open config and write information within
					new Handle:config = OpenConfig();

					// Write a new number and model
					IntToString(hats_count + 1, key, sizeof(text));
					KvJumpToKey(config, key, true);
					KvSetString(config, "model", text);

					// Save config
					SaveConfig(config);

					// CloseHandle to prevent memory leak
					CloseHandle(config);

					hats_count++;
					CPrintToChat (client, "%s%t", PREFIX, "Added Hat", text, hats_count, MAX_HATS);
				}
				else CPrintToChat(client, "%s%t", PREFIX, "Cant Add", text);
			}
			else CPrintToChat(client, "%s%t", PREFIX, "Reached Max", MAX_HATS);
		}
		else CPrintToChat(client, "%s%t", PREFIX, "Usage AddHat");
	}

	return Plugin_Handled;
}

/* Admin_SaveHat()
 *
 * Saves the hat position and angels to the hat config.
 * ----------------------------------------------------------------------- */
public Action:Admin_SaveHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// We will deal with entity. And that entity should be hat model
		new entity = hat_index[client];
		if (IsValidEntRef(entity))
		{
			// Open a config and save 'selected' hat
			new Handle:config = OpenConfig();
			new index = hat_selected[client];

			decl String:text[4];
			IntToString(index + 1, text, sizeof(text));

			// Sets the current position in the KeyValues to the given key
			if (KvJumpToKey(config, text))
			{
				// Getting temporary angles, origin and size for selected hat
				decl Float:ang[3], Float:ori[3], Float:siz;

				// Origin & angles stuff
				GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ori);
				KvSetVector(config, "angles", ang);
				KvSetVector(config, "origin", ori);
				hatangles[index]   = ang;
				hatposition[index] = ori;

				// Resizing
				siz = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

				// Delete older size section if size wasnt actually changed
				if (siz == 1.0000000)
				{
					KvDeleteKey(config, "size");
				}

				// Otherwise add size value
				else KvSetFloat(config, "size", siz);

				hatsize[index] = siz;

				// Save config
				SaveConfig(config);
				CPrintToChat(client, "%s%t", PREFIX, "Saved Hat", Models[index]);
			}

			// Something went wrong
			else CPrintToChat(client, "%s%t", PREFIX, "Cant Save", Models[index]);
			CloseHandle(config);
		}
	}

	return Plugin_Handled;
}

/* Admin_DeleteHat()
 *
 * Removes a model from the config (either by index or partial name matching).
 * ----------------------------------------------------------------------- */
public Action:Admin_DeleteHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		if (args == 1)
		{
			// I've got some issues previously when bool was declared
			decl String:text[64], String:model[64], String:key[16], index;
			new bool:isDeleted;

			// Retrieves a command argument given its index
			GetCmdArg(1, text, sizeof(text));

			if (strlen(text) < 3)
			{
				// Convert index
				index = StringToInt(text);
				if (index < 1 || index >= (hats_count + 1))
				{
					CPrintToChat(client, "%s%t", PREFIX, "Index Invalid", index, hats_count);
					return Plugin_Handled;
				}

				// Hat was successfully deleted. Reduce amount of all available hats
				index--;
				strcopy(text, sizeof(text), Models[index]);
			}

			// That wasnt an index. So lets continue by argument
			else index = 0;

			new Handle:config = OpenConfig();

			// Make sure we are not exceed amount of MAX_HATS
			for (new i = index; i <= MAX_HATS; i++)
			{
				// Retrieve the hat index
				FormatEx(key, sizeof(key), "%d", i + 1);
				if (KvJumpToKey(config, key))
				{
					// Check if hat was deleted before
					if (isDeleted)
					{
						FormatEx(key, sizeof(key), "%d", i);

						// Sets the current section name
						KvSetSectionName(config, key);
						strcopy(Models[i - 1], sizeof(text), Models[i]);
						strcopy(Names[i - 1],  sizeof(text), Names[i]);

						// Clear hat config
						hatangles[i - 1]   = hatangles[i];
						hatposition[i - 1] = hatposition[i];
						hatsize[i - 1]     = hatsize[i];
					}

					// Hat wasnt deleted before
					else
					{
						// Retrieves a string value from a KeyValues key
						KvGetString(config, "model", model, sizeof(model));

						// Check if argument close to model name
						if (StrContains(model, text) != -1)
						{
							CPrintToChat(client, "%s%t", PREFIX, "Deleted Hat", model);
							KvDeleteKey(config, text);

							// Accept changes
							hats_count--;
							isDeleted = true;

							// Remove the invalid hat from menu
							RemoveMenuItem(dodhats_menu, i);
						}
					}
				}

				// Sets the position back to the top node, emptying the entire node traversal history
				KvRewind(config);
				if (i == MAX_HATS)
				{
					// Resave config on success
					if (isDeleted) SaveConfig(config);
					else CPrintToChat(client, "%s%t", PREFIX, "Cant Delete", text);
				}
			}
			CloseHandle(config);
		}

		// If there was no argument, dont delete hat but notify admin about it
		else
		{
			new index = hat_selected[client];
			CPrintToChat(client, "%s%t", PREFIX, "Hat_Wearing", Names[index]);
		}
	}

	return Plugin_Handled;
}

/* Admin_RandomizeHats()
 *
 * Randomizes all players hats.
 * ----------------------------------------------------------------------- */
public Action:Admin_RandomizeHats(client, args)
{
	// Check if plugin is enabled
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// Remove all hats right now, and check only valid clients
		for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i)) RemoveHat(i);

		// Then give random hats to everybody
		RandomHat();
	}

	return Plugin_Handled;
}

/* Admin_ForceHat()
 *
 * Changes all players hats to the one you have.
 * ----------------------------------------------------------------------- */
public Action:Admin_ForceHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// Return admin's selected hat
		new selected = hat_selected[client];
		CPrintToChat(client, "%s%t", PREFIX, "Forced Hat", Models[selected]);

		// Force hat for all...
		for (new i = 1; i <= MaxClients; i++)
		{
			// ...valid clients
			if (IsValidClient(i))
			{
				// Perform hat equip
				RemoveHat(i);
				CreateHat(i, selected);
			}
		}
	}

	return Plugin_Handled;
}

/* Admin_ShowHatMenu()
 *
 * Displays a menu listing players, select one to change their hat.
 * ----------------------------------------------------------------------- */
public Action:Admin_ShowHatMenu(client, args)
{
	// Are plugin is enabled?
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		ShowPlayerList(client);
	}

	return Plugin_Handled;
}

/* Admin_ShowHatList()
 *
 * Displays a list of all the hat models (for use with sm_hatdel).
 * ----------------------------------------------------------------------- */
public Action:Admin_ShowHatList(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		// Reply to admin a index of hat and full path to model
		for (new i = 0; i < hats_count; i++)
		{
			ReplyToCommand(client, "\x04%d) \x05%s", i + 1, Models[i]);
		}
	}
	return Plugin_Handled;
}

/* Admin_ChangeAngles()
 *
 * Shows a menu allowing you to adjust the hat angles.
 * ----------------------------------------------------------------------- */
public Action:Admin_ChangeAngles(client, args)
{
	// Show 'hat angles' menu
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		ShowAnglesMenu(client);
	}

	return Plugin_Handled;
}

/* Admin_ChangeOrigin()
 *
 * Shows a menu allowing you to adjust the hat position.
 * ----------------------------------------------------------------------- */
public Action:Admin_ChangeOrigin(client, args)
{
	// Same here, but about origin
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		ShowOriginMenu(client);
	}

	return Plugin_Handled;
}

/* Admin_ChangeSize()
 *
 * Shows a menu allowing you to adjust the hat size.
 * ----------------------------------------------------------------------- */
public Action:Admin_ChangeSize(client, args)
{
	// Resize menu
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		ShowSizeMenu(client);
	}

	return Plugin_Handled;
}


/**
 * -----------------------------------------------------------------------
 *      __  ___
 *     /  |/  /___  ___  __  ________
 *    / /|_/ / _ \/ __ \/ / / // ___/
 *   / /  / /  __/ / / / /_/ /(__  )
 *  /_/  /_/\___/_/ /_/\__,_/_____/
 *
 * -----------------------------------------------------------------------
*/

/* HatMenu()
 *
 * Provides a menu of allowed hats.
 * ----------------------------------------------------------------------- */
public HatMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			// Retrieve target's hat
			new target = hat_target[client];

			// Target found
			if (target)
			{
				// Reset hat index and use target's userid
				hat_target[client] = 0;
				target = GetClientOfUserId(target);
				if (IsValidClient(target))
				{
					// Notify admin about changing hat on target
					CPrintToChat(client, "%s%t", PREFIX, "Hat_Changed", target);
					RemoveHat(target);

					// Actually this way fixes many issues...
					if (CreateHat(target, index))
					{
						CPrintToChat(target, "%s%t", PREFIX, "Hat_Wearing", Names[index]);
					}
				}

				// Target is invalid
				else
				{
					// Notify admin about it
					CPrintToChat(client, "%s%t", PREFIX, "Hat_Invalid");
				}

				return;
			}

			// That wasnt a target, then admin changed hat for himself
			else
			{
				// Remove old hat
				RemoveHat(client);
				if (CreateHat(client, index))
				{
					// And notify about hat changing
					CPrintToChat(client, "%s%t", PREFIX, "Hat_Wearing", Names[index]);
				}
			}

			// Returns the first item on the page of a currently selected menu
			new menupos = GetMenuSelectionPosition();
			DisplayMenuAtItem(menu, client, menupos, MENU_TIME_FOREVER);
		}
	}
}

/* PlayersMenu()
 *
 * Provides a menu of all valid clients on a server.
 * ----------------------------------------------------------------------- */
public PlayersMenu(Handle:menu, MenuAction:action, client, index)
{
	// I like switch statements for menus
	switch (action)
	{
		case MenuAction_Select:
		{
			decl String:text[32];
			GetMenuItem(menu, index, text, sizeof(text));

			// Finding a target by client index
			new target = StringToInt(text);
			target = GetClientOfUserId(target);

			// Show list of valid clients
			if (IsValidClient(target))
			{
				hat_target[client] = GetClientUserId(target);

				// Show hats menu
				ShowMenu(client);
			}
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

/* AnglesMenu()
 *
 * Provides a menu of hat angles to change.
 * ----------------------------------------------------------------------- */
public AnglesMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		// No need to do 'valid client check' here
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				// Show angles menu on select
				ShowAnglesMenu(client);
				decl Float:ang[3], entity;

				// We are going to change hat angles on all players. That makes modifying hat easier
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						// Get hat index of all players
						entity = hat_index[i];

						// And check if hat is valid
						if (IsValidEntRef(entity))
						{
							// Retrieves a vector of floats from an entity
							GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
							switch (index)
							{
								case 0: ang[0] += 5.0;
								case 1: ang[1] += 5.0;
								case 2: ang[2] += 5.0;
								case 4: ang[0] -= 5.0;
								case 5: ang[1] -= 5.0;
								case 6: ang[2] -= 5.0;
							}
							TeleportEntity(entity, NULL_VECTOR, ang, NULL_VECTOR);
						}
					}
				}
				CPrintToChat(client, "%s%t", PREFIX, "New Angles", ang[0], ang[1], ang[2]);
			}
		}
		case MenuAction_Cancel:
		{
			// Return to Angles menu on cancel or exit
			if (index == MenuCancel_ExitBack) ShowAnglesMenu(client);
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

/* Admin_OriginMenu()
 *
 * Provides a menu of hat position to change.
 * ----------------------------------------------------------------------- */
public OriginMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		// When we select something, show origin menu
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				ShowOriginMenu(client);

				// When storing make sure you don't include the index
				decl Float:ori[3], entity;
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						entity = hat_index[i];
						if (IsValidEntRef(entity))
						{
							// Move hat by origin
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ori);

							// ShowOriginMenu shows an items
							switch (index)
							{
								case 0: ori[0] += 0.5;
								case 1: ori[1] += 0.5;
								case 2: ori[2] += 0.5;
								case 4: ori[0] -= 0.5;
								case 5: ori[1] -= 0.5;
								case 6: ori[2] -= 0.5;
							}

							// Move hat depends on pressed value
							TeleportEntity(entity, ori, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}

				CPrintToChat(client, "%s%t", PREFIX, "New Origin", ori[0], ori[1], ori[2]);
			}
		}
		case MenuAction_Cancel:
		{
			if (index == MenuCancel_ExitBack) ShowOriginMenu(client);
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

/* SizeMenu()
 *
 * Provides a menu of hat size to change.
 * ----------------------------------------------------------------------- */
public SizeMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			// Check if admin is valid. Still not sure needed that or not
			if (IsValidClient(client))
			{
				ShowSizeMenu(client);

				decl Float:siz, entity;
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						// entity always should be a hat
						entity = hat_index[i];
						if (IsValidEntRef(entity))
						{
							// Retrieve a float value from an entity's property
							siz = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
							switch (index)
							{
								// Index is equal to selected item. See 1331/1357/1382 if you want to know why I do that
								case 0: siz += 0.1;
								case 1: siz -= 0.1;
								case 2: siz += 0.5;
								case 3: siz -= 0.5;
								case 4: siz += 1.0;
								case 5: siz -= 1.0;
							}
							SetEntPropFloat(entity, Prop_Send, "m_flModelScale", siz);
						}
					}
				}

				// Notify admin about changing size
				CPrintToChat(client, "%s%t", PREFIX, "New Size", siz);
			}
		}
		case MenuAction_Cancel:
		{
			if (index == MenuCancel_ExitBack) ShowSizeMenu(client);
		}
		case MenuAction_End: CloseHandle(menu);
	}
}


/**
 * -----------------------------------------------------------------------
 *      ______                  __  _
 *     / ____/__  ______  _____/ /_(_)____  ____  _____
 *    / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
 *   / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  )
 *  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/
 *
 * -----------------------------------------------------------------------
*/

/* LoadConfig()
 *
 * Loads "sourcemod/configs/dod_hats.cfg" configuration file.
 * ----------------------------------------------------------------------- */
LoadConfig()
{
	// Open hats configuration file (models, angles, origin...)
	new i, Handle:config = OpenConfig(), String:text[64];
	hats_count = 0;

	for (i = 0; i <= MAX_HATS; i++)
	{
		// Needed to prevent some bugs. Ex. it fixes an issue with 'zero' hat, which are not allowed
		IntToString(i + 1, text, sizeof(text));
		if (KvJumpToKey(config, text))
		{
			KvGetString(config, "model", text, sizeof(text));

			// Remove a whitespace characters from the beginning and end of a string
			TrimString(text);
			if (strlen(text) == 0)
				break;

			// Check if config is exists
			if (FileExists(text, true))
			{
				// Retrieve a vector values from 'angles' and 'origin'
				KvGetVector(config, "angles", hatangles[i]);
				KvGetVector(config, "origin", hatposition[i]);

				// 'size' section too
				hatsize[i] = KvGetFloat(config, "size", 1.0);
				hats_count++;

				// Copy hat names and save it as globals
				strcopy(Models[i], sizeof(text), text);

				KvGetString(config, "name", Names[i], sizeof(text));

				// If length of a string is invalid, rename hat by model name
				if (strlen(Names[i]) == 0) GetHatName(Names[i], i);
			}

			// Oops
			else LogError("Cannot find the model '%s'", text);
			KvRewind(config);
		}
	}

	CloseHandle(config);

	// If config is exists but there is no hats, disable plugin
	if (hats_count == 0) SetFailState("No models wtf?!");

	if (dodhats_menu != INVALID_HANDLE)
	{
		CloseHandle(dodhats_menu);
		dodhats_menu = INVALID_HANDLE;
	}

	// Create hats menu
	dodhats_menu = CreateMenu(HatMenu);

	// Add hats in menu as items (and check how many hats are available)
	for (i = 0; i < hats_count; i++)
	{
		AddMenuItem(dodhats_menu, Models[i], Names[i]);
	}

	// Create a title (for normal and clientprefs menus)
	decl String:title[32];
	Format(title, sizeof(title), "%t", "Hat_Menu_Title");

	SetMenuTitle(dodhats_menu, title);
	SetMenuExitButton(dodhats_menu, true);
}

/* OpenConfig()
 *
 * Opens a configuration file to read/write.
 * ----------------------------------------------------------------------- */
Handle:OpenConfig()
{
	// Open a path relative to the SourceMod folder
	decl String:Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dod_hats.cfg");
	if (!FileExists(Path)) SetFailState("Cannot find the file configs/dod_hats.cfg");

	// Creates a new KeyValues structur
	new Handle:config = CreateKeyValues("Hats");

	if (!FileToKeyValues(config, Path))
	{
		CloseHandle(config);
		SetFailState("Cannot load the file 'configs/dod_hats.cfg'");
	}
	return config;
}

/* SaveConfig()
 *
 * Saves a hat configuration file.
 * ----------------------------------------------------------------------- */
SaveConfig(Handle:config)
{
	// Re-open a file and set the position back to the top node
	decl String:Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dod_hats.cfg");
	KvRewind(config);

	// Converts a KeyValues tree to a file
	KeyValuesToFile(config, Path);
}

/* ShowMenu()
 *
 * Provides a menu of allowed hats.
 * ----------------------------------------------------------------------- */
ShowMenu(client)
{
	if (IsValidClient(client)) DisplayMenu(dodhats_menu, client, MENU_TIME_FOREVER);
}

/* ShowPlayerList()
 *
 * Provides a menu of allowed players on a server.
 * ----------------------------------------------------------------------- */
ShowPlayerList(client)
{
	// Declare strings of userids and names of all players
	decl String:text[16], String:names[MAX_NAME_LENGTH];
	new Handle:menu = CreateMenu(PlayersMenu);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (client > 0 && IsClientInGame(i) && !IsClientObserver(i))
		{
			IntToString(GetClientUserId(i), text, sizeof(text));
			GetClientName(i, names, sizeof(names));

			// Add every client in a menu as item (sorted by userid)
			AddMenuItem(menu, text, names);
		}
	}

	// Needed to translate menu titles
	decl String:title1[32], String:title2[32];
	Format(title1, sizeof(title1), "%t", "Toggle on player");
	Format(title2, sizeof(title2), "%t", "Change on player");

	// If that was a 'hat disabling' menu, show first title, otherwise show menu to change hat
	if (hats_adminmenu[client]) SetMenuTitle(menu, title1);
	else                        SetMenuTitle(menu, title2);

	// Add exit button and display hats menu to a player
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/* ShowAnglesMenu()
 *
 * Actual angles menu.
 * ----------------------------------------------------------------------- */
ShowAnglesMenu(client)
{
	new Handle:menu = CreateMenu(AnglesMenu);

	// I've added this to define what exactly admin should change
	AddMenuItem(menu, NULL_STRING, "X + 5.0");
	AddMenuItem(menu, NULL_STRING, "Y + 5.0");
	AddMenuItem(menu, NULL_STRING, "Z + 5.0");
	AddMenuItem(menu, NULL_STRING, "-------");
	AddMenuItem(menu, NULL_STRING, "X - 5.0");
	AddMenuItem(menu, NULL_STRING, "Y - 5.0");
	AddMenuItem(menu, NULL_STRING, "Z - 5.0");

	decl String:title[32];
	Format(title, sizeof(title), "%t", "Set Angles");

	SetMenuTitle(menu, title);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/* ShowOriginMenu()
 *
 * Actual origin menu.
 * ----------------------------------------------------------------------- */
ShowOriginMenu(client)
{
	// Create a 2nd menu
	new Handle:menu = CreateMenu(OriginMenu);

	AddMenuItem(menu, NULL_STRING, "X + 0.5");
	AddMenuItem(menu, NULL_STRING, "Y + 0.5");
	AddMenuItem(menu, NULL_STRING, "Z + 0.5");
	AddMenuItem(menu, NULL_STRING, "-------");
	AddMenuItem(menu, NULL_STRING, "X - 0.5");
	AddMenuItem(menu, NULL_STRING, "Y - 0.5");
	AddMenuItem(menu, NULL_STRING, "Z - 0.5");

	// Angles & Origin menu is almost the same. Title should be different
	decl String:title[32];
	Format(title, sizeof(title), "%t", "Set Origin");

	SetMenuTitle(menu, title);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/* ShowSizeMenu()
 *
 * Actual size menu.
 * ----------------------------------------------------------------------- */
ShowSizeMenu(client)
{
	new Handle:menu = CreateMenu(SizeMenu);

	AddMenuItem(menu, NULL_STRING, "+ 0.1");
	AddMenuItem(menu, NULL_STRING, "-  0.1");
	AddMenuItem(menu, NULL_STRING, "+ 0.5");
	AddMenuItem(menu, NULL_STRING, "-  0.5");
	AddMenuItem(menu, NULL_STRING, "+ 1.0");
	AddMenuItem(menu, NULL_STRING, "-  1.0");

	decl String:title[32];
	Format(title, sizeof(title), "%t", "Set Size");

	// Set title, add exit button and show menu forever until client close it
	SetMenuTitle(menu, title);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/* GetHatName()
 *
 * Retrieves hat name from config.
 * ----------------------------------------------------------------------- */
GetHatName(String:text[64], i)
{
	// Copy full path name of hat model
	strcopy(text, sizeof(text), Models[i]);

	// Remove useless chars from path/model name like '_' or '/'
	ReplaceString(text, sizeof(text), "_", " ");
	new ori = FindCharInString(text, '/', true) + 1;

	// Remove latest three letters (mdl)
	new len = strlen(text) - ori - 3;
	strcopy(text, len, text[ori]);
}

/* CreateHat()
 *
 * Attaches a hat on a player.
 * ----------------------------------------------------------------------- */
CreateHat(client, index = -1)
{
	if (IsValidClient(client) && !hats_disabled[client] && !IsValidEntRef(hat_index[client]))
	{
		// No multiple cases will run at same time
		switch (index)
		{
			case -1: // Random hat
			{
				// Getting the flag name (a b c d e ... )
				decl String:text[32];
				GetConVarString(dodhats_access, text, sizeof(text));
				hat_flag = ReadFlagString(text);

				// Check if flag is specified
				if (hat_flag != 0)
				{
					// Get client access flag
					new flagc = GetUserFlagBits(client);

					if (!(flagc & ADMFLAG_ROOT) && !(flagc & hat_flag))
						return false;
				}

				// Randomize hats
				index = GetRandomInt(0, hats_count-1);
			}
			case -2: // Saved hats
			{
				// Retrieve hat index from clientprefs
				index = hat_save[client];
				if (index == 0)
				{
					index = GetRandomInt(1, hats_count);
				}
				index--;
			}
			default: hat_save[client] = index + 1; // Specified hat
		}

		// Retrieve a number
		decl String:number[8];
		IntToString(index + 1, number, sizeof(number));

		// If hats should NOT be randomized - save selected hat
		if (GetConVarBool(dodhats_clientprefs) && !GetConVarBool(dodhats_random))
		{
			// Save a hat number in a clientprefs database
			SetClientCookie(client, dodhats_cookie, number);
		}

		// Creates an entity by string name, but does not spawn it
		new entity = CreateEntityByName("prop_dynamic_override");

		// Continue if entity is valid
		if (entity != -1)
		{
			// Set a entity model to hat index
			SetEntityModel(entity, Models[index]);

			// And now spawn it
			DispatchSpawn(entity);

			// Resize hat depends on config value
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", hatsize[index]);

			// Some code that I copied and dont understand how it works
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", client);

			// DoD:S have an attachment 'head' instead of generic 'forward' or 'eyes'
			SetVariantString("head");
			AcceptEntityInput(entity, "SetParentAttachment");

			// Spawn it in a specified position
			TeleportEntity(entity, hatposition[index], hatangles[index], NULL_VECTOR);

			// Return and save hat index for next spawn
			hat_selected[client] = index;
			hat_index[client]    = EntIndexToEntRef(entity);

			// If hat can be seen, make it unseen!
			if (!hat_drawn[client]) SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

			return true;
		}
	}

	return false;
}

/* RemoveHat()
 *
 * Removes an attached model (hat) from player.
 * ----------------------------------------------------------------------- */
RemoveHat(client)
{
	// Checks if entity is hat
	new entity = hat_index[client];
	hat_index[client] = 0;

	// Remove it via AcceptEntityInput
	if (IsValidEntRef(entity)) AcceptEntityInput(entity, "KillHierarchy");
}

/* RandomHat()
 *
 * Randomizes a hat on all clients.
 * ----------------------------------------------------------------------- */
RandomHat()
{
	// Creates a hat with random index (ie -1) on all players
	for (new i = 1; i <= MaxClients; i++)
	if (IsValidClient(i)) CreateHat(i, -1);
}

/* ThirdPerson()
 *
 * Toggles thirdperson mode on a player that called show hat command.
 * ----------------------------------------------------------------------- */
ThirdPerson(client, bool:status)
{
	// Thirdperson enabled
	if (status)
	{
		// Set fov, hide gun, set observe mode and stick camera to a player
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client,    Prop_Send, "m_iObserverMode",   1);
		SetEntProp(client,    Prop_Send, "m_bDrawViewmodel",  0);
		SetEntProp(client,    Prop_Send, "m_iFOV", 100);
	}

	// Thirdperson disabled - set all to defaults
	else
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 1);
		SetEntProp(client,    Prop_Send, "m_iObserverMode",   0);
		SetEntProp(client,    Prop_Send, "m_bDrawViewmodel",  1);
		SetEntProp(client,    Prop_Send, "m_iFOV", 90);
	}
}


/**
 * -----------------------------------------------------------------------
 *      __  ___
 *     /  |/  (_)__________
 *    / /|_/ / // ___/ ___/
 *   / /  / / /(__  ) /__
 *  /_/  /_/_//____/\___/
 *
 * -----------------------------------------------------------------------
*/

/* IsValidClient()
 *
 * Checks if client is valid.
 * ----------------------------------------------------------------------- */
bool:IsValidClient(client)
{
	// Default 'valid client' check
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)) ? true : false;
}

/* IsVakidEntRef()
 *
 * Checks if entity (hat) is valid.
 * ----------------------------------------------------------------------- */
bool:IsValidEntRef(entity)
{
	// Converts an entity index into a serial encoded entity reference
	return (entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE) ? true : false;
}

/* Hook_SetTransmit()
 *
 * Hides a hat model from a client that wearing it.
 * ----------------------------------------------------------------------- */
public Action:Hook_SetTransmit(entity, client)
{
	// Make sure to hide only hat entity (model)
	return (EntIndexToEntRef(entity) == hat_index[client]) ? Plugin_Handled : Plugin_Continue;
}

/* LoadCookies()
 *
 * Loads a client preferences (which hat was chosen before).
 * ----------------------------------------------------------------------- */
LoadCookies(client)
{
	// Get client cookies, set type if available or default
	decl String:cookie[3];
	GetClientCookie(client, dodhats_cookie, cookie, sizeof(cookie));

	// If cookie is not present, set random hat on a client until he save it
	if (StrEqual(cookie, NULL_STRING))
	{
		hat_save[client] = 0;
	}
	else /* Otherwise load client's preferenced hat */
	{
		new type = StringToInt(cookie);
		hat_save[client] = type;
	}
}

/* Timer_CreateHat()
 *
 * Creates a hat with a delay.
 * ----------------------------------------------------------------------- */
public Action:Timer_CreateHat(Handle:timer, any:client)
{
	// Convert userid
	client = GetClientOfUserId(client);

	// Be careful with timers
	if (IsValidClient(client))
	{
		if (GetConVarBool(dodhats_random))      CreateHat(client, -1);
		if (GetConVarBool(dodhats_clientprefs)) CreateHat(client, -2);
	}
}