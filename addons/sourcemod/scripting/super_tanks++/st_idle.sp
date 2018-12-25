/**
 * Super Tanks++: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2018  Alfred "Crasher_3637/Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#include <sourcemod>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include <st_clone>
#define REQUIRE_PLUGIN

#include <super_tanks++>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[ST++] Idle Ability",
	author = ST_AUTHOR,
	description = "The Super Tank forces survivors to go idle.",
	version = ST_VERSION,
	url = ST_URL
};

#define ST_MENU_IDLE "Idle Ability"

bool g_bCloneInstalled, g_bIdle[MAXPLAYERS + 1], g_bIdle2[MAXPLAYERS + 1], g_bIdle3[MAXPLAYERS + 1], g_bIdle4[MAXPLAYERS + 1], g_bIdled[MAXPLAYERS + 1], g_bLateLoad, g_bTankConfig[ST_MAXTYPES + 1];

char g_sIdleEffect[ST_MAXTYPES + 1][4], g_sIdleEffect2[ST_MAXTYPES + 1][4], g_sIdleMessage[ST_MAXTYPES + 1][3], g_sIdleMessage2[ST_MAXTYPES + 1][4];

float g_flHumanCooldown[ST_MAXTYPES + 1], g_flHumanCooldown2[ST_MAXTYPES + 1], g_flIdleChance[ST_MAXTYPES + 1], g_flIdleChance2[ST_MAXTYPES + 1], g_flIdleRange[ST_MAXTYPES + 1], g_flIdleRange2[ST_MAXTYPES + 1], g_flIdleRangeChance[ST_MAXTYPES + 1], g_flIdleRangeChance2[ST_MAXTYPES + 1];

Handle g_hSDKIdlePlayer, g_hSDKSpecPlayer;

int g_iHumanAbility[ST_MAXTYPES + 1], g_iHumanAbility2[ST_MAXTYPES + 1], g_iHumanAmmo[ST_MAXTYPES + 1], g_iHumanAmmo2[ST_MAXTYPES + 1], g_iIdleAbility[ST_MAXTYPES + 1], g_iIdleAbility2[ST_MAXTYPES + 1], g_iIdleCount[MAXPLAYERS + 1], g_iIdleHit[ST_MAXTYPES + 1], g_iIdleHit2[ST_MAXTYPES + 1], g_iIdleHitMode[ST_MAXTYPES + 1], g_iIdleHitMode2[ST_MAXTYPES + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!bIsValidGame(false) && !bIsValidGame())
	{
		strcopy(error, err_max, "\"[ST++] Idle Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bCloneInstalled = LibraryExists("st_clone");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "st_clone", false))
	{
		g_bCloneInstalled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "st_clone", false))
	{
		g_bCloneInstalled = false;
	}
}

public void OnPluginStart()
{
	LoadTranslations("super_tanks++.phrases");

	RegConsoleCmd("sm_st_idle", cmdIdleInfo, "View information about the Idle ability.");

	GameData gdSuperTanks = new GameData("super_tanks++");

	if (gdSuperTanks == null)
	{
		SetFailState("Unable to load the \"super_tanks++\" gamedata file.");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gdSuperTanks, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard");
	g_hSDKIdlePlayer = EndPrepSDKCall();

	if (g_hSDKIdlePlayer == null)
	{
		PrintToServer("%s Your \"CTerrorPlayer::GoAwayFromKeyboard\" signature is outdated.", ST_TAG);
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gdSuperTanks, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKSpecPlayer = EndPrepSDKCall();

	if (g_hSDKSpecPlayer == null)
	{
		PrintToServer("%s Your \"SetHumanSpec\" signature is outdated.", ST_TAG);
	}

	delete gdSuperTanks;

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, "24"))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		g_bLateLoad = false;
	}
}

public void OnMapStart()
{
	vReset();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	vRemoveIdle(client);
}

public void OnMapEnd()
{
	vReset();
}

public Action cmdIdleInfo(int client, int args)
{
	if (!ST_PluginEnabled())
	{
		ReplyToCommand(client, "%s Super Tanks++\x01 is disabled.", ST_TAG4);

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, "0245"))
	{
		ReplyToCommand(client, "%s This command is to be used only in-game.", ST_TAG);

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: ReplyToCommand(client, "%s %t", ST_TAG2, "Vote in Progress");
		case false: vIdleMenu(client, 0);
	}

	return Plugin_Handled;
}

static void vIdleMenu(int client, int item)
{
	Menu mAbilityMenu = new Menu(iIdleMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Idle Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int iIdleMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: ST_PrintToChat(param1, "%s %t", ST_TAG3, iIdleAbility(param1) == 0 ? "AbilityStatus1" : "AbilityStatus2");
				case 1: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityAmmo", iHumanAmmo(param1) - g_iIdleCount[param1], iHumanAmmo(param1));
				case 2: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityButtons2");
				case 3: ST_PrintToChat(param1, "%s %t", ST_TAG3, "AbilityCooldown", flHumanCooldown(param1));
				case 4: ST_PrintToChat(param1, "%s %t", ST_TAG3, "IdleDetails");
				case 5: ST_PrintToChat(param1, "%s %t", ST_TAG3, iHumanAbility(param1) == 0 ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, "24"))
			{
				vIdleMenu(param1, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[255];
			Panel panel = view_as<Panel>(param2);
			Format(sMenuTitle, sizeof(sMenuTitle), "%T", "IdleMenu", param1);
			panel.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			char sMenuOption[255];
			switch (param2)
			{
				case 0:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Status", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 1:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Ammunition", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 2:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Buttons", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 3:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Cooldown", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 4:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "Details", param1);
					return RedrawMenuItem(sMenuOption);
				}
				case 5:
				{
					Format(sMenuOption, sizeof(sMenuOption), "%T", "HumanSupport", param1);
					return RedrawMenuItem(sMenuOption);
				}
			}
		}
	}

	return 0;
}

public void ST_OnDisplayMenu(Menu menu)
{
	menu.AddItem(ST_MENU_IDLE, ST_MENU_IDLE);
}

public void ST_OnMenuItemSelected(int client, const char[] info)
{
	if (StrEqual(info, ST_MENU_IDLE, false))
	{
		vIdleMenu(client, 0);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (ST_PluginEnabled() && bIsValidClient(victim, "0234") && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof(sClassname));

		if (ST_TankAllowed(attacker) && ST_CloneAllowed(attacker, g_bCloneInstalled) && (iIdleHitMode(attacker) == 0 || iIdleHitMode(attacker) == 1) && bIsHumanSurvivor(victim))
		{
			if (StrEqual(sClassname, "weapon_tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vIdleHit(victim, attacker, flIdleChance(attacker), iIdleHit(attacker), "1", "1");
			}
		}
		else if (ST_TankAllowed(victim) && ST_CloneAllowed(victim, g_bCloneInstalled) && (iIdleHitMode(victim) == 0 || iIdleHitMode(victim) == 2) && bIsHumanSurvivor(attacker))
		{
			if (StrEqual(sClassname, "weapon_melee"))
			{
				vIdleHit(attacker, victim, flIdleChance(victim), iIdleHit(victim), "1", "2");
			}
		}
	}
}

public void ST_OnConfigsLoaded(const char[] savepath, bool main)
{
	KeyValues kvSuperTanks = new KeyValues("Super Tanks++");
	kvSuperTanks.ImportFromFile(savepath);

	for (int iIndex = ST_MinType(); iIndex <= ST_MaxType(); iIndex++)
	{
		char sTankName[33];
		Format(sTankName, sizeof(sTankName), "Tank #%i", iIndex);
		if (kvSuperTanks.JumpToKey(sTankName))
		{
			switch (main)
			{
				case true:
				{
					g_bTankConfig[iIndex] = false;

					g_iHumanAbility[iIndex] = kvSuperTanks.GetNum("Idle Ability/Human Ability", 0);
					g_iHumanAbility[iIndex] = iClamp(g_iHumanAbility[iIndex], 0, 1);
					g_iHumanAmmo[iIndex] = kvSuperTanks.GetNum("Idle Ability/Human Ammo", 5);
					g_iHumanAmmo[iIndex] = iClamp(g_iHumanAmmo[iIndex], 0, 9999999999);
					g_flHumanCooldown[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Human Cooldown", 30.0);
					g_flHumanCooldown[iIndex] = flClamp(g_flHumanCooldown[iIndex], 0.0, 9999999999.0);
					g_iIdleAbility[iIndex] = kvSuperTanks.GetNum("Idle Ability/Ability Enabled", 0);
					g_iIdleAbility[iIndex] = iClamp(g_iIdleAbility[iIndex], 0, 1);
					kvSuperTanks.GetString("Idle Ability/Ability Effect", g_sIdleEffect[iIndex], sizeof(g_sIdleEffect[]), "0");
					kvSuperTanks.GetString("Idle Ability/Ability Message", g_sIdleMessage[iIndex], sizeof(g_sIdleMessage[]), "0");
					g_flIdleChance[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Chance", 33.3);
					g_flIdleChance[iIndex] = flClamp(g_flIdleChance[iIndex], 0.0, 100.0);
					g_iIdleHit[iIndex] = kvSuperTanks.GetNum("Idle Ability/Idle Hit", 0);
					g_iIdleHit[iIndex] = iClamp(g_iIdleHit[iIndex], 0, 1);
					g_iIdleHitMode[iIndex] = kvSuperTanks.GetNum("Idle Ability/Idle Hit Mode", 0);
					g_iIdleHitMode[iIndex] = iClamp(g_iIdleHitMode[iIndex], 0, 2);
					g_flIdleRange[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Range", 150.0);
					g_flIdleRange[iIndex] = flClamp(g_flIdleRange[iIndex], 1.0, 9999999999.0);
					g_flIdleRangeChance[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Range Chance", 15.0);
					g_flIdleRangeChance[iIndex] = flClamp(g_flIdleRangeChance[iIndex], 0.0, 100.0);
				}
				case false:
				{
					g_bTankConfig[iIndex] = true;

					g_iHumanAbility2[iIndex] = kvSuperTanks.GetNum("Idle Ability/Human Ability", g_iHumanAbility[iIndex]);
					g_iHumanAbility2[iIndex] = iClamp(g_iHumanAbility2[iIndex], 0, 1);
					g_iHumanAmmo2[iIndex] = kvSuperTanks.GetNum("Idle Ability/Human Ammo", g_iHumanAmmo[iIndex]);
					g_iHumanAmmo2[iIndex] = iClamp(g_iHumanAmmo2[iIndex], 0, 9999999999);
					g_flHumanCooldown2[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Human Cooldown", g_flHumanCooldown[iIndex]);
					g_flHumanCooldown2[iIndex] = flClamp(g_flHumanCooldown2[iIndex], 0.0, 9999999999.0);
					g_iIdleAbility2[iIndex] = kvSuperTanks.GetNum("Idle Ability/Ability Enabled", g_iIdleAbility[iIndex]);
					g_iIdleAbility2[iIndex] = iClamp(g_iIdleAbility2[iIndex], 0, 1);
					kvSuperTanks.GetString("Idle Ability/Ability Effect", g_sIdleEffect2[iIndex], sizeof(g_sIdleEffect2[]), g_sIdleEffect[iIndex]);
					kvSuperTanks.GetString("Idle Ability/Ability Message", g_sIdleMessage2[iIndex], sizeof(g_sIdleMessage2[]), g_sIdleMessage[iIndex]);
					g_flIdleChance2[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Chance", g_flIdleChance[iIndex]);
					g_flIdleChance2[iIndex] = flClamp(g_flIdleChance2[iIndex], 0.0, 100.0);
					g_iIdleHit2[iIndex] = kvSuperTanks.GetNum("Idle Ability/Idle Hit", g_iIdleHit[iIndex]);
					g_iIdleHit2[iIndex] = iClamp(g_iIdleHit2[iIndex], 0, 1);
					g_iIdleHitMode2[iIndex] = kvSuperTanks.GetNum("Idle Ability/Idle Hit Mode", g_iIdleHitMode[iIndex]);
					g_iIdleHitMode2[iIndex] = iClamp(g_iIdleHitMode2[iIndex], 0, 2);
					g_flIdleRange2[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Range", g_flIdleRange[iIndex]);
					g_flIdleRange2[iIndex] = flClamp(g_flIdleRange2[iIndex], 1.0, 9999999999.0);
					g_flIdleRangeChance2[iIndex] = kvSuperTanks.GetFloat("Idle Ability/Idle Range Chance", g_flIdleRangeChance[iIndex]);
					g_flIdleRangeChance2[iIndex] = flClamp(g_flIdleRangeChance2[iIndex], 0.0, 100.0);
				}
			}

			kvSuperTanks.Rewind();
		}
	}

	delete kvSuperTanks;
}

public void ST_OnHookEvent(bool mode)
{
	switch (mode)
	{
		case true:
		{
			HookEvent("player_afk", ST_OnEventFired, EventHookMode_Pre);
			HookEvent("player_bot_replace", ST_OnEventFired);
		}
		case false:
		{
			UnhookEvent("player_afk", ST_OnEventFired, EventHookMode_Pre);
			UnhookEvent("player_bot_replace", ST_OnEventFired);
		}
	}
}

public void ST_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "player_afk"))
	{
		int iIdlerId = event.GetInt("player"), iIdler = GetClientOfUserId(iIdlerId);
		g_bIdled[iIdler] = true;
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iSurvivorId = event.GetInt("player"), iSurvivor = GetClientOfUserId(iSurvivorId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsIdlePlayer(iBot, iSurvivor)) 
		{
			DataPack dpIdleFix;
			CreateDataTimer(0.2, tTimerIdleFix, dpIdleFix, TIMER_FLAG_NO_MAPCHANGE);
			dpIdleFix.WriteCell(iSurvivorId);
			dpIdleFix.WriteCell(iBotId);

			if (g_bIdle[iSurvivor])
			{
				g_bIdle[iSurvivor] = false;
			}
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (ST_TankAllowed(iTank, "024") && ST_CloneAllowed(iTank, g_bCloneInstalled))
		{
			vRemoveIdle(iTank);
		}
	}
}

public void ST_OnAbilityActivated(int tank)
{
	if (ST_TankAllowed(tank) && (!ST_TankAllowed(tank, "5") || iHumanAbility(tank) == 0) && ST_CloneAllowed(tank, g_bCloneInstalled) && iIdleAbility(tank) == 1)
	{
		vIdleAbility(tank);
	}
}

public void ST_OnButtonPressed(int tank, int button)
{
	if (ST_TankAllowed(tank, "02345") && ST_CloneAllowed(tank, g_bCloneInstalled))
	{
		if (button & ST_SUB_KEY == ST_SUB_KEY)
		{
			if (iIdleAbility(tank) == 1 && iHumanAbility(tank) == 1)
			{
				switch (g_bIdle2[tank])
				{
					case true: ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleHuman3");
					case false: vIdleAbility(tank);
				}
			}
		}
	}
}

public void ST_OnChangeType(int tank)
{
	vRemoveIdle(tank);
}

static void vIdleAbility(int tank)
{
	if (g_iIdleCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
	{
		g_bIdle3[tank] = false;
		g_bIdle4[tank] = false;

		float flIdleRange = !g_bTankConfig[ST_TankType(tank)] ? g_flIdleRange[ST_TankType(tank)] : g_flIdleRange2[ST_TankType(tank)],
			flIdleRangeChance = !g_bTankConfig[ST_TankType(tank)] ? g_flIdleRangeChance[ST_TankType(tank)] : g_flIdleRangeChance2[ST_TankType(tank)],
			flTankPos[3];

		GetClientAbsOrigin(tank, flTankPos);

		int iSurvivorCount;

		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, "234"))
			{
				float flSurvivorPos[3];
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);

				float flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= flIdleRange)
				{
					vIdleHit(iSurvivor, tank, flIdleRangeChance, iIdleAbility(tank), "2", "3");

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (ST_TankAllowed(tank, "5") && iHumanAbility(tank) == 1)
			{
				ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleHuman4");
			}
		}
	}
	else
	{
		ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleAmmo");
	}
}

static void vIdleHit(int survivor, int tank, float chance, int enabled, const char[] message, const char[] mode)
{
	if (enabled == 1 && bIsHumanSurvivor(survivor))
	{
		if (g_iIdleCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
		{
			if (GetRandomFloat(0.1, 100.0) <= chance && !g_bIdle[survivor])
			{
				if (ST_TankAllowed(tank, "5") && iHumanAbility(tank) == 1 && StrEqual(mode, "3") && !g_bIdle2[tank])
				{
					g_bIdle2[tank] = true;
					g_iIdleCount[tank]++;

					ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleHuman", g_iIdleCount[tank], iHumanAmmo(tank));

					if (g_iIdleCount[tank] < iHumanAmmo(tank) && iHumanAmmo(tank) > 0)
					{
						CreateTimer(flHumanCooldown(tank), tTimerResetCooldown, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
					}
					else
					{
						g_bIdle2[tank] = false;
					}
				}

				if (iGetHumanCount() > 1)
				{
					FakeClientCommand(survivor, "go_away_from_keyboard");
				}
				else
				{
					SDKCall(g_hSDKIdlePlayer, survivor);
				}

				if (bIsBotIdle(survivor))
				{
					g_bIdle[survivor] = true;
					g_bIdled[survivor] = true;

					char sIdleEffect[4];
					sIdleEffect = !g_bTankConfig[ST_TankType(tank)] ? g_sIdleEffect[ST_TankType(tank)] : g_sIdleEffect2[ST_TankType(tank)];
					vEffect(survivor, tank, sIdleEffect, mode);

					char sIdleMessage[3];
					sIdleMessage = !g_bTankConfig[ST_TankType(tank)] ? g_sIdleMessage[ST_TankType(tank)] : g_sIdleMessage2[ST_TankType(tank)];
					if (StrContains(sIdleMessage, message) != -1)
					{
						char sTankName[33];
						ST_TankName(tank, sTankName);
						ST_PrintToChatAll("%s %t", ST_TAG2, "Idle", sTankName, survivor);
					}
				}
			}
			else if (StrEqual(mode, "3") && !g_bIdle2[tank])
			{
				if (ST_TankAllowed(tank, "5") && iHumanAbility(tank) == 1 && !g_bIdle3[tank])
				{
					g_bIdle3[tank] = true;

					ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleHuman2");
				}
			}
		}
		else
		{
			if (ST_TankAllowed(tank, "5") && iHumanAbility(tank) == 1 && !g_bIdle4[tank])
			{
				g_bIdle4[tank] = true;

				ST_PrintToChat(tank, "%s %t", ST_TAG3, "IdleAmmo");
			}
		}
	}
}

static void vRemoveIdle(int tank)
{
	g_bIdle[tank] = false;
	g_bIdle2[tank] = false;
	g_bIdle3[tank] = false;
	g_bIdle4[tank] = false;
	g_bIdled[tank] = false;
	g_iIdleCount[tank] = 0;
}

static void vReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, "24"))
		{
			vRemoveIdle(iPlayer);
		}
	}
}

static float flHumanCooldown(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_flHumanCooldown[ST_TankType(tank)] : g_flHumanCooldown2[ST_TankType(tank)];
}

static float flIdleChance(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_flIdleChance[ST_TankType(tank)] : g_flIdleChance2[ST_TankType(tank)];
}

static int iHumanAbility(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iHumanAbility[ST_TankType(tank)] : g_iHumanAbility2[ST_TankType(tank)];
}

static int iHumanAmmo(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iHumanAmmo[ST_TankType(tank)] : g_iHumanAmmo2[ST_TankType(tank)];
}

static int iIdleAbility(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iIdleAbility[ST_TankType(tank)] : g_iIdleAbility2[ST_TankType(tank)];
}

static int iIdleHit(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iIdleHit[ST_TankType(tank)] : g_iIdleHit2[ST_TankType(tank)];
}

static int iIdleHitMode(int tank)
{
	return !g_bTankConfig[ST_TankType(tank)] ? g_iIdleHitMode[ST_TankType(tank)] : g_iIdleHitMode2[ST_TankType(tank)];
}

public Action tTimerIdleFix(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell()), iBot = GetClientOfUserId(pack.ReadCell());
	if (!ST_PluginEnabled() || !bIsValidClient(iSurvivor, "0234") || !bIsValidClient(iBot, "0234") || !g_bIdled[iSurvivor])
	{
		return Plugin_Stop;
	}

	if (!bIsValidClient(iSurvivor, "5") || GetClientTeam(iSurvivor) != 1 || iGetIdleBot(iSurvivor))
	{
		g_bIdled[iSurvivor] = false;
	}

	if (!bIsBotIdleSurvivor(iBot) || GetClientTeam(iBot) != 2)
	{
		iBot = iGetBotSurvivor();
	}

	if (iBot < 1)
	{
		g_bIdled[iSurvivor] = false;
	}

	if (g_bIdled[iSurvivor])
	{
		g_bIdled[iSurvivor] = false;

		SDKCall(g_hSDKSpecPlayer, iBot, iSurvivor);

		SetEntProp(iSurvivor, Prop_Send, "m_iObserverMode", 5);
	}

	return Plugin_Continue;
}

public Action tTimerResetCooldown(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!ST_TankAllowed(iTank) || !ST_CloneAllowed(iTank, g_bCloneInstalled) || !g_bIdle2[iTank])
	{
		g_bIdle2[iTank] = false;

		return Plugin_Stop;
	}

	g_bIdle2[iTank] = false;

	ST_PrintToChat(iTank, "%s %t", ST_TAG3, "IdleHuman5");

	return Plugin_Continue;
}