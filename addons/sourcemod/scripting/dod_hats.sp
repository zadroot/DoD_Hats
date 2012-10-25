#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <sdkhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_NAME    "DoD:S Hats"
#define PLUGIN_VERSION "0.9.2"

#define CHAT_TAG       "\x04[DoD:S Hats]\x05 "
#define UPDATE_URL     "https://raw.github.com/zadroot/DoD_Hats/master/updater.txt"
#define DOD_MAXPLAYERS 33
#define	MAX_HATS       64

new Handle:dodhats_enable      = INVALID_HANDLE,
	Handle:dodhats_access      = INVALID_HANDLE,
	Handle:dodhats_opacity     = INVALID_HANDLE,
	Handle:dodhats_random      = INVALID_HANDLE,
	Handle:dodhats_clientprefs = INVALID_HANDLE,
	Handle:dodhats_cookie      = INVALID_HANDLE,
	Handle:dodhats_menu        = INVALID_HANDLE;

new hats_count,
	hat_flag,
	hat_index[DOD_MAXPLAYERS],
	hat_selected[DOD_MAXPLAYERS],
	hat_target[DOD_MAXPLAYERS],
	hat_save[DOD_MAXPLAYERS];

new bool:hat_drawn[DOD_MAXPLAYERS],
	bool:hats_enabled[DOD_MAXPLAYERS],
	bool:hats_adminmenu[DOD_MAXPLAYERS],
	bool:hats_blocked[DOD_MAXPLAYERS];

new String:Models[MAX_HATS][64],
	String:Names[MAX_HATS][64],
	String:SteamID[DOD_MAXPLAYERS][32];

new Float:hatangles[MAX_HATS][3],
	Float:hatposition[MAX_HATS][3],
	Float:hatsize[MAX_HATS];

public Plugin:myinfo =
{
	name			= PLUGIN_NAME,
	author			= "Root",
	description		= "Attaches specified models to players above their head",
	version			= PLUGIN_VERSION,
	url				= "http://dodsplugins.com/"
};


public OnPluginStart()
{
	CreateConVar("dod_hats_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	dodhats_enable       = CreateConVar("dod_hats_allow",  "1",   "Whether or not enable hats plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodhats_access       = CreateConVar("dod_hats_menu",   "",    "Add specify admin flag or blank to allow all players access to the hats menu", FCVAR_PLUGIN);
	dodhats_opacity      = CreateConVar("dod_hats_opaque", "255", "How transparent or solid should the hats appear:\n0   = Translucent\n255 = Opaque", FCVAR_PLUGIN, true, 0.0, true, 255.0);
	dodhats_random       = CreateConVar("dod_hats_random", "1",   "Whether or not attach a random hat when player respawning (saved hats will be ignored)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dodhats_clientprefs  = CreateConVar("dod_hats_save",   "1",   "Whether or not save the players selected hats and attach when they spawn or rejoin the server\n0 = Dont save", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	HookConVarChange(dodhats_enable, OnConVarChange);

	RegConsoleCmd("sm_hat",       Command_Hat,                        "Displays a menu of hats allowing players to change what they are wearing");
	RegConsoleCmd("sm_hats",      Command_Hat,                        "Alias for \"sm_hat\"");
	RegConsoleCmd("sm_hatoff",    Command_DisableHat,                 "Toggle to turn on or off the ability of wearing hats");
	RegConsoleCmd("sm_hatshow",   Command_ShowHat,                    "Toggle to see or hide your own hat");
	RegConsoleCmd("sm_hatview",   Command_ShowHat,                    "Alias for \"sm_hatview\"");
	RegAdminCmd  ("sm_hatreload", Admin_ReloadConfig,   ADMFLAG_ROOT, "Reload \"dod_hats.cfg\"");
	RegAdminCmd  ("sm_hatoffc",   Admin_DisableHat,     ADMFLAG_ROOT, "Toggle the ability of wearing hats on specific players");
	RegAdminCmd  ("sm_hatblock",  Admin_DisableHat,     ADMFLAG_ROOT, "Alias for \"sm_hatoffc\"");
	RegAdminCmd  ("sm_hatc",      Admin_ShowHatMenu,    ADMFLAG_ROOT, "Displays a menu listing players, select one to change their hat");
	RegAdminCmd  ("sm_hatchange", Admin_ShowHatMenu,    ADMFLAG_ROOT, "Alias for \"sm_hatc\"");
	RegAdminCmd  ("sm_hatrandom", Admin_RandomizeHats,  ADMFLAG_ROOT, "Randomizes all players hats");
	RegAdminCmd  ("sm_hatrand",   Admin_RandomizeHats,  ADMFLAG_ROOT, "Alias for \"sm_hatrandom\"");
	RegAdminCmd  ("sm_hatadd",    Admin_AddHat,         ADMFLAG_ROOT, "Adds specified model to the config (must be the full model path)");
	RegAdminCmd  ("sm_hatdel",    Admin_DeleteHat,      ADMFLAG_ROOT, "Removes a model from the config (either by index or partial name matching)");
	RegAdminCmd  ("sm_hatdelete", Admin_DeleteHat,      ADMFLAG_ROOT, "Alias for \"sm_hatdel\"");
	RegAdminCmd  ("sm_hatlist",   Admin_ShowHatList,    ADMFLAG_ROOT, "Displays a list of all the hat models (for use with sm_hatdel)");
	RegAdminCmd  ("sm_hatsave",   Admin_SaveHat,        ADMFLAG_ROOT, "Saves the hat position and angels to the hat config");
	RegAdminCmd  ("sm_hatload",   Admin_ForceHat,       ADMFLAG_ROOT, "Changes all players hats to the one you have");
	RegAdminCmd  ("sm_hatforce",  Admin_ForceHat,       ADMFLAG_ROOT, "Alias for \"sm_hatload\"");
	RegAdminCmd  ("sm_hatang",    Admin_ChangeAngles,   ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat angles (affects all hats/players)");
	RegAdminCmd  ("sm_hatangles", Admin_ChangeAngles,   ADMFLAG_ROOT, "Alias for \"sm_hatang\"");
	RegAdminCmd  ("sm_hatpos",    Admin_ChangeOrigin,   ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat position (affects all hats/players)");
	RegAdminCmd  ("sm_hatorigin", Admin_ChangeOrigin,   ADMFLAG_ROOT, "Alias for \"sm_hatpos\"");
	RegAdminCmd  ("sm_hatsize",   Admin_ChangeSize,     ADMFLAG_ROOT, "Shows a menu allowing you to adjust the hat size (affects all hats/players)");

	LoadTranslations("dod_hats.phrases");
	LoadTranslations("core.phrases");

	AutoExecConfig(true, "dod_hats");

	LoadConfig();
	LoadEvents();

	dodhats_menu = CreateMenu(HatMenu);

	for (new i = 0; i < hats_count; i++)
		AddMenuItem(dodhats_menu, Models[i], Names[i]);

	SetMenuTitle(dodhats_menu, "%t", "Hat_Menu_Title");
	SetMenuExitButton(dodhats_menu, true);

	decl String:title[32];
	Format(title, sizeof(title), "%t", "Hat_Menu_Title");

	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);

	if (LibraryExists("clientprefs"))
		SetCookieMenuItem(HatCookieMenu, 0, title);

	dodhats_cookie = RegClientCookie("dod_hats", "Hat Model", CookieAccess_Protected);
}

public OnMapStart()
{
	for (new i = 0; i < hats_count; i++)
		PrecacheModel(Models[i]);
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
}

public OnClientAuthorized(client, const String:auth[])
{
	if (hats_blocked[client])
	{
		if (IsFakeClient(client)) hats_blocked[client] = false;
		else if (strcmp(auth, SteamID[client]))
		{
			strcopy(SteamID[client], sizeof(SteamID), auth);
			hats_blocked[client] = false;
		}
	}

	hats_adminmenu[client] = false;

	if (GetConVarBool(dodhats_enable) && GetConVarBool(dodhats_clientprefs))
	{
		new clientID = GetClientUserId(client);
		CreateTimer(1.0, LoadCookies, clientID);
	}
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	switch (StringToInt(newValue))
	{
		case 0: UnhookEvents();
		case 1: LoadEvents();
	}
}

LoadEvents()
{
	HookEvent("player_hurt",     Event_PlayerHurt);
	HookEvent("player_spawn",    Event_PlayerSpawn);
}

UnhookEvents()
{
	UnhookEvent("player_hurt",     Event_PlayerHurt);
	UnhookEvent("player_spawn",    Event_PlayerSpawn);
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (GetClientHealth(client) < 1) RemoveHat(client);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(dodhats_enable))
	{
		new clientID = GetEventInt(event, "userid");
		new client   = GetClientOfUserId(client);

		RemoveHat(client);

		if (GetConVarBool(dodhats_random))
			RandomHat();
		else
			CreateTimer(0.1, Timer_CreateHat, clientID);
	}
}

public Action:Command_Hat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		decl String:text[64];
		GetConVarString(dodhats_access, text, sizeof(text));
		hat_flag = ReadFlagString(text);

		new flagc = GetUserFlagBits(client);

		if (hat_flag != 0 && !(flagc & ADMFLAG_ROOT))
		{
			if (IsValidClient(client) || !(flagc & hat_flag))
			{
				CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
				return Plugin_Handled;
			}
		}

		if (args == 1)
		{
			GetCmdArg(1, text, sizeof(text));

			if (strlen(text) < 3)
			{
				new index = StringToInt(text);
				if (index < 1 || index >= (hats_count + 1))
				{
					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_No_Index", index, hats_count);
				}
				else
				{
					RemoveHat(client);
				}
			}
			else
			{
				ReplaceString(text, sizeof(text), " ", "_");

				for (new i = 0; i < hats_count; i++)
				{
					if (StrContains(Models[i], text) != -1 || StrContains(Names[i], text) != -1)
					{
						RemoveHat(client);
						return Plugin_Handled;
					}
				}

				CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Not_Found", text);
			}
		}
		else
		{
			ShowMenu(client);
		}
	}
	else
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action:Command_DisableHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		if (!hats_enabled[client])
		{
			hats_enabled[client] = true;
			RemoveHat(client);
		}
		else hats_enabled[client] = false;

		decl String:text[32];
		Format(text, sizeof(text), "%T", hats_enabled[client] ? "Hat_Off" : "Hat_On", client);
		CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Ability", text);
	}
	else
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action:Command_ShowHat(client, args)
{
	if (GetConVarBool(dodhats_enable) && IsValidClient(client))
	{
		new entity = hat_index[client];
		if (entity == 0 || (entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE)
		{
			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Missing");
			return Plugin_Handled;
		}

		if (hat_drawn[client])
		{
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
			ThirdPerson(client, false);
			hat_drawn[client] = false;
		}
		else
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
			ThirdPerson(client, true);
			hat_drawn[client] = true;
		}

		decl String:text[32];
		Format(text, sizeof(text), "%T", hat_drawn[client] ? "Hat_On" : "Hat_Off", client);
		CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_View", text);
	}
	else
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action:Admin_ReloadConfig(client, args)
{
	LoadConfig();
	return Plugin_Handled;
}

public Action:Admin_AddHat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		if (args == 1)
		{
			if (hats_count < MAX_HATS)
			{
				decl String:text[64], String:key[16];
				GetCmdArg(1, text, sizeof(text));

				if (FileExists(Models[hats_count], true))
				{
					strcopy(Models[hats_count], sizeof(text), text);
					hatangles[hats_count]   = Float:{ 0.0, 0.0, 0.0 };
					hatposition[hats_count] = Float:{ 0.0, 0.0, 0.0 };
					hatsize[hats_count]     = 1.0;

					new Handle:config = OpenConfig();
					IntToString(hats_count + 1, key, sizeof(text));
					KvJumpToKey(config, key, true);
					KvSetString(config, "model", text);
					SaveConfig(config);
					CloseHandle(config);
					hats_count++;
					ReplyToCommand (client, "%sAdded hat '\04%s\x05' %d/%d", CHAT_TAG, text, hats_count, MAX_HATS);
				}
				else ReplyToCommand(client, "%sCould not find the model '\04%s\x05'. Not adding to config.", CHAT_TAG, text);
			}
			else
			{
				ReplyToCommand(client, "%sReached maximum number of hats (%d)", CHAT_TAG, MAX_HATS);
			}
		}
	}

	return Plugin_Handled;
}

public Action:Admin_SaveHat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		new entity = hat_index[client];
		if (IsValidEntRef(entity))
		{
			new Handle:config = OpenConfig();
			new index = hat_selected[client];

			decl String:text[4];
			IntToString(index + 1, text, sizeof(text));
			if (KvJumpToKey(config, text))
			{
				decl Float:ang[3], Float:ori[3], Float:siz;

				GetEntPropVector(entity, Prop_Send, "m_angRotation", ang);
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ori);
				KvSetVector(config, "angles", ang);
				KvSetVector(config, "origin", ori);
				hatangles[index]   = ang;
				hatposition[index] = ori;

				siz = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

				if (siz == 1.0)
				{
					if (KvGetFloat(config, "size", 999.9) != 999.9)
						KvDeleteKey(config, "size");
				}
				else   KvSetFloat(config, "size", siz);

				hatsize[index] = siz;

				SaveConfig(config);
				PrintToChat(client, "%sSaved '\x04%s\x05' hat origin and angles.", CHAT_TAG, Models[index]);
			}
			else
			{
				PrintToChat(client, "%s\x04Warning: \x05Could not save '\x04%s\x05' hat origin and angles!", CHAT_TAG, Models[index]);
			}
			CloseHandle(config);
		}
	}

	return Plugin_Handled;
}

public Action:Admin_DeleteHat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		if (args == 1)
		{
			decl String:text[64], String:model[64], String:key[16];
			new index, bool:isDeleted;

			GetCmdArg(1, text, sizeof(text));
			if (strlen(text) < 3)
			{
				index = StringToInt(text);
				if (index < 1 || index >= (hats_count + 1))
				{
					ReplyToCommand(client, "%sCannot find the hat index \x04%d\x05, values between \x041\x05 and \x04%d\x05", CHAT_TAG, index, hats_count);
					return Plugin_Handled;
				}
				index--;
				strcopy(text, sizeof(text), Models[index]);
			}
			else
			{
				index = 0;
			}

			new Handle:config = OpenConfig();

			for (new i = index; i < MAX_HATS; i++)
			{
				Format(key, sizeof(key), "%d", i + 1);
				if (KvJumpToKey(config, key))
				{
					if (isDeleted)
					{
						Format(key, sizeof(key), "%d", i);
						KvSetSectionName(config, key);
						strcopy(Models[i - 1], sizeof(text), Models[i]);
						strcopy(Names[i - 1],  sizeof(text), Names[i]);
						hatangles[i - 1]   = hatangles[i];
						hatposition[i - 1] = hatposition[i];
						hatsize[i - 1]     = hatsize[i];
					}
					else
					{
						KvGetString(config, "model", model, sizeof(model));
						if (StrContains(model, text) != -1)
						{
							ReplyToCommand(client, "%sYou have deleted the hat '\x04%s\x05'", CHAT_TAG, model);
							KvDeleteKey(config, text);

							hats_count--;
							isDeleted = true;

							RemoveMenuItem(dodhats_menu, i);
						}
					}
				}
				KvRewind(config);
				if (i == MAX_HATS)
				{
					if (isDeleted) SaveConfig(config);
					else
						ReplyToCommand(client, "%sCould not delete hat, did not find model '\x04%s\x05'", CHAT_TAG, text);
				}
			}
			CloseHandle(config);
		}
		else
		{
			new index = hat_selected[client];

			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", Names[index]);
		}
	}

	return Plugin_Handled;
}

public Action:Admin_RandomizeHats(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		for (new i = 1; i <= MaxClients; i++)
			RemoveHat(i);

		RandomHat();
	}

	return Plugin_Handled;
}

public Action:Admin_ForceHat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		new selected = hat_selected[client];
		PrintToChat(client, "%sLoaded hat '\x04%s\x05' on all players.", CHAT_TAG, Models[selected]);

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				RemoveHat(i);
				CreateHat(i, selected);
			}
		}
	}

	return Plugin_Handled;
}

public Action:Admin_DisableHat(client, args)
{
	if (GetConVarBool(dodhats_enable))
	{
		hats_adminmenu[client] = true;
		ShowPlayerList(client);
	}

	return Plugin_Handled;
}

public Action:Admin_ShowHatMenu(client, args)
{
	if (GetConVarBool(dodhats_enable))
		ShowPlayerList(client);

	return Plugin_Handled;
}

public Action:Admin_ShowHatList(client, args)
{
	for (new i = 0; i < hats_count; i++)
		ReplyToCommand(client, "\x04%d) \x05%s", i + 1, Models[i]);

	return Plugin_Handled;
}

public Action:Admin_ChangeAngles(client, args)
{
	if (GetConVarBool(dodhats_enable))
		ShowAnglesMenu(client);

	return Plugin_Handled;
}

public Action:Admin_ChangeOrigin(client, args)
{
	if (GetConVarBool(dodhats_enable))
		ShowOriginMenu(client);

	return Plugin_Handled;
}

public Action:Admin_ChangeSize(client, args)
{
	if (GetConVarBool(dodhats_enable))
		ShowSizeMenu(client);

	return Plugin_Handled;
}

public HatMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_End: if (client > 0) CloseHandle(menu);
		case MenuAction_Select:
		{
			new target = hat_target[client];
			if (target)
			{
				hat_target[client] = 0;
				target = GetClientOfUserId(target);
				if (IsValidClient(target))
				{
					decl String:name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));

					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Changed", name);
					RemoveHat(target);

					if (CreateHat(target, index))
					{
						CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", Names[index]);
					}
				}
				else
				{
					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Invalid");
				}

				return;
			}
			else
			{
				RemoveHat(client);
				if (CreateHat(client, index))
				{
					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", Names[index]);
				}
			}

			new menupos = GetMenuSelectionPosition();
			DisplayMenuAtItem(menu, client, menupos, MENU_TIME_FOREVER);
		}
	}
}

public PlayersMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Select:
		{
			decl String:text[32];
			GetMenuItem(menu, index, text, sizeof(text));
			new target = StringToInt(text);
			target = GetClientOfUserId(target);
			if (hats_adminmenu[client])
			{
				hats_adminmenu[client] = false;
				hats_blocked[target] = !hats_blocked[target];

				if (hats_blocked[target] == false)
				{
					if (IsValidClient(target))
					{
						RemoveHat(target);
						CreateHat(target);

						decl String:name[MAX_NAME_LENGTH];
						GetClientName(target, name, sizeof(name));
						CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Unblocked", name);
					}
				}
				else
				{
					decl String:name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					GetClientAuthString(target, SteamID[target], sizeof(SteamID));
					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Blocked", name);
					RemoveHat(target);
				}
			}
			else
			{
				if (IsValidClient(target))
				{
					hat_target[client] = GetClientUserId(target);

					ShowMenu(client);
				}
			}
		}
	}
}

public AnglesMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if (index == MenuCancel_ExitBack)
				ShowAnglesMenu(client);
		}
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				ShowAnglesMenu(client);

				decl Float:ang[3], entity;
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						entity = hat_index[i];
						if (IsValidEntRef(entity))
						{
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

				CPrintToChat(client, "%sNew hat angles: \x04%.0f %.0f %.0f", CHAT_TAG, ang[0], ang[1], ang[2]);
			}
		}
	}
}

public OriginMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if (index == MenuCancel_ExitBack)
				ShowOriginMenu(client);
		}
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				ShowOriginMenu(client);

				decl Float:ori[3], entity;
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						entity = hat_index[i];
						if (IsValidEntRef(entity))
						{
							GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ori);
							switch (index)
							{
								case 0: ori[0] += 0.5;
								case 1: ori[1] += 0.5;
								case 2: ori[2] += 0.5;
								case 4: ori[0] -= 0.5;
								case 5: ori[1] -= 0.5;
								case 6: ori[2] -= 0.5;
							}
							TeleportEntity(entity, ori, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}

				CPrintToChat(client, "%sNew hat origin: \x04%.1f %.1f %.1f", CHAT_TAG, ori[0], ori[1], ori[2]);
			}
		}
	}
}

public SizeMenu(Handle:menu, MenuAction:action, client, index)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if (index == MenuCancel_ExitBack)
				ShowSizeMenu(client);
		}
		case MenuAction_Select:
		{
			if (IsValidClient(client))
			{
				ShowSizeMenu(client);

				decl Float:siz, entity;
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						entity = hat_index[i];
						if (IsValidEntRef(entity))
						{
							siz = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
							switch (index)
							{
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

				CPrintToChat(client, "%sNew hat scale: %.1f", CHAT_TAG, siz);
			}
		}
	}
}

public HatCookieMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	if (action == CookieMenuAction_SelectOption)
		ShowMenu(client);
}

bool:IsValidClient(client)
{
	return (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && !IsClientObserver(client) && !hats_blocked[client]) ? true : false;
}

bool:IsValidEntRef(entity)
{
	return (entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE) ? true : false;
}

public Action:Hook_SetTransmit(entity, client)
{
	return (EntIndexToEntRef(entity) == hat_index[client]) ? Plugin_Handled : Plugin_Continue;
}

public Action:LoadCookies(Handle:timer, any:client)
{
	client = GetClientOfUserId(client);

	if (client && !IsFakeClient(client))
	{
		decl String:cookie[3];
		GetClientCookie(client, dodhats_cookie, cookie, sizeof(cookie));

		if (strcmp(cookie, NULL_STRING) == 0)
			hat_save[client] = 0;
		else
		{
			new type = StringToInt(cookie);
			hat_save[client] = type;
		}
	}
}

public Action:Timer_CreateHat(Handle:timer, any:client)
{
	client = GetClientOfUserId(client);

	if (IsValidClient(client))
	{
		if (GetConVarBool(dodhats_random))
			CreateHat(client, -1);
		if (GetConVarBool(dodhats_clientprefs) && !IsFakeClient(client))
			CreateHat(client, -2);
	}
}

LoadConfig()
{
	new i, Handle:config = OpenConfig();
	decl String:text[64];
	for (i = 0; i < MAX_HATS; i++)
	{
		IntToString(i + 1, text, sizeof(text));
		if (KvJumpToKey(config, text))
		{
			KvGetString(config, "model", text, sizeof(text));

			TrimString(text);
			if (strlen(text) == 0)
				break;

			if (FileExists(text, true))
			{
				KvGetVector(config, "angles", hatangles[i]);
				KvGetVector(config, "origin", hatposition[i]);
				hatsize[i] = KvGetFloat(config, "size", 1.0);
				hats_count++;

				strcopy(Models[i], sizeof(text), text);

				KvGetString(config, "name", Names[i], sizeof(text));

				if (strlen(Names[i]) == 0)
					GetHatName(Names[i], i);
			}
			else
				LogError("Cannot find the model '%s'", text);

			KvRewind(config);
		}
	}
	CloseHandle(config);

	if (hats_count == 0) SetFailState("No models wtf?!");
}

Handle:OpenConfig()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/dod_hats.cfg");
	if (!FileExists(sPath)) SetFailState("Cannot find the file configs/dod_hats.cfg");

	new Handle:config = CreateKeyValues("Models");
	if (!FileToKeyValues(config, sPath))
	{
		CloseHandle(config);
		SetFailState("Cannot load the file 'configs/dod_hats.cfg'");
	}
	return config;
}

GetHatName(String:text[64], i)
{
	strcopy(text, sizeof(text), Models[i]);
	ReplaceString(text, sizeof(text), "_", " ");
	new ori = FindCharInString(text, '/', true) + 1;
	new len = strlen(text) - ori - 3;
	strcopy(text, len, text[ori]);
}

SaveConfig(Handle:config)
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/dod_hats.cfg");
	KvRewind(config);
	KeyValuesToFile(config, sPath);
}

ShowMenu(client)
{
	if (IsValidClient(client))
		DisplayMenu(dodhats_menu, client, MENU_TIME_FOREVER);
}

ShowPlayerList(client)
{
	decl String:text[16], String:name[MAX_NAME_LENGTH];
	new Handle:menu = CreateMenu(PlayersMenu);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsClientObserver(i))
		{
			IntToString(GetClientUserId(i), text, sizeof(text));
			GetClientName(i, name, sizeof(name));
			AddMenuItem(menu, text, name);
		}
	}

	if (hats_adminmenu[client]) SetMenuTitle(menu, "Select player to enable or disable hats:");
	else                        SetMenuTitle(menu, "Select player to change hat:");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

ShowAnglesMenu(client)
{
	new Handle:menu = CreateMenu(AnglesMenu);

	AddMenuItem(menu, NULL_STRING, "X + 5.0");
	AddMenuItem(menu, NULL_STRING, "Y + 5.0");
	AddMenuItem(menu, NULL_STRING, "Z + 5.0");
	AddMenuItem(menu, NULL_STRING, "-------");
	AddMenuItem(menu, NULL_STRING, "X - 5.0");
	AddMenuItem(menu, NULL_STRING, "Y - 5.0");
	AddMenuItem(menu, NULL_STRING, "Z - 5.0");

	SetMenuTitle(menu, "Set hat angles:");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

ShowOriginMenu(client)
{
	new Handle:menu = CreateMenu(OriginMenu);

	AddMenuItem(menu, NULL_STRING, "X + 0.5");
	AddMenuItem(menu, NULL_STRING, "Y + 0.5");
	AddMenuItem(menu, NULL_STRING, "Z + 0.5");
	AddMenuItem(menu, NULL_STRING, "-------");
	AddMenuItem(menu, NULL_STRING, "X - 0.5");
	AddMenuItem(menu, NULL_STRING, "Y - 0.5");
	AddMenuItem(menu, NULL_STRING, "Z - 0.5");

	SetMenuTitle(menu, "Set hat position:");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

ShowSizeMenu(client)
{
	new Handle:menu = CreateMenu(SizeMenu);

	AddMenuItem(menu, NULL_STRING, "+ 0.1");
	AddMenuItem(menu, NULL_STRING, "-  0.1");
	AddMenuItem(menu, NULL_STRING, "+ 0.5");
	AddMenuItem(menu, NULL_STRING, "-  0.5");
	AddMenuItem(menu, NULL_STRING, "+ 1.0");
	AddMenuItem(menu, NULL_STRING, "-  1.0");

	SetMenuTitle(menu, "Set hat size:");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

CreateHat(client, index = -1)
{
	if (hats_blocked[client] || hats_enabled[client] || IsValidEntRef(hat_index[client]) == true || IsValidClient(client) == false)
		return false;

	switch (index)
	{
		case -1:
		{
			decl String:text[32];
			GetConVarString(dodhats_access, text, sizeof(text));
			hat_flag = ReadFlagString(text);

			if (hat_flag != 0)
			{
				if (IsFakeClient(client))
					return false;

				new flagc = GetUserFlagBits(client);
				if (!(flagc & ADMFLAG_ROOT) && !(flagc & hat_flag))
					return false;
			}

			index = GetRandomInt(0, hats_count -1);
			hat_save[client] = index + 1;
		}
		case -2:
		{
			index = hat_save[client];

			if (index == 0)
			{
				if (IsFakeClient(client) == false)
					return false;
				else
					index = GetRandomInt(1, hats_count);
			}

			index--;
		}
		default: hat_save[client] = index + 1;
	}

	decl String:number[8];
	IntToString(index + 1, number, sizeof(number));

	if (GetConVarBool(dodhats_clientprefs) && !GetConVarBool(dodhats_random) && !IsFakeClient(client))
	{
		SetClientCookie(client, dodhats_cookie, number);
	}

	new entity = CreateEntityByName("prop_dynamic_override");
	if (entity != -1)
	{
		SetEntityModel(entity, Models[index]);
		DispatchSpawn(entity);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", hatsize[index]);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);
		SetVariantString("head");
		AcceptEntityInput(entity, "SetParentAttachment");
		TeleportEntity(entity, hatposition[index], hatangles[index], NULL_VECTOR);

		if (GetConVarInt(dodhats_opacity) < 255)
		{
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 255, 255, 255, GetConVarInt(dodhats_opacity));
		}

		hat_selected[client] = index;
		hat_index[client]    = EntIndexToEntRef(entity);

		if (!hat_drawn[client])
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

		return true;
	}

	return false;
}

RemoveHat(client)
{
	new entity = hat_index[client];
	hat_index[client] = 0;

	if (IsValidEntRef(entity))
		AcceptEntityInput(entity, "Kill");
}

RandomHat()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			CreateHat(i);
	}
}

ThirdPerson(client, bool:status)
{
	if (status)
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client,    Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client,    Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client,    Prop_Send, "m_iFOV", 100);
	}
	else
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 1);
		SetEntProp(client,    Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client,    Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client,    Prop_Send, "m_iFOV", 90);
	}
}