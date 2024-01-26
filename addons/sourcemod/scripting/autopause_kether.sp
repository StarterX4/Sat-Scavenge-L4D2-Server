/*
	SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <sourcemod>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN

#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#include "pause"
#include "readyup"


public Plugin:myinfo =
{
    name = "L4D2 Auto-pause",
    author = "Darkid, Griffin, StarterX4",
    description = "When a player disconnects due to crash, automatically pause the game. When they rejoin, give them a correct spawn timer.",
    version = "2.1",
    url = "https://github.com/jbzdarkid/AutoPause"
}

//ConVar sv_pausable;

new Handle:g_hCvarEnabled;
new Handle:g_hCvarForce;
new Handle:g_hCvarApdebug;
new Handle:g_hCvarForceUnPause;
new Handle:g_hCvarAutoReady;

new Handle:crashedPlayers;
new Handle:generalCrashers
new Handle:infectedPlayers;
new Handle:survivorPlayers;
new bool:IsPauseAvailable;
new bool:readyUpIsAvailable;
new bool:RoundEnd;

public OnPluginStart() {
    // Suggestion by Nati: Disable for any 1v1
    g_hCvarEnabled = CreateConVar("autopause_enable", "1", "Whether or not to automatically pause when a player crashes.");
    g_hCvarForce = CreateConVar("autopause_force", "0", "Whether or not to force pause when a player crashes.");
    g_hCvarApdebug = CreateConVar("autopause_apdebug", "0", "Whether or not to debug information.");
    g_hCvarForceUnPause = CreateConVar("autopause_forceunpause", "1", "Whether or not to force unpause when a crashed player rejoins.");
    // Doesn't work for now. Needs a handle to pause.smx that would mark
    g_hCvarAutoReady = CreateConVar("autopause_autoready", "0", "Whether or not to automatically mark crashed player ready for an unpause on rejoin.");

    crashedPlayers = CreateTrie();
    generalCrashers = CreateArray(64);
    infectedPlayers = CreateArray(64);
    survivorPlayers = CreateArray(64);

    HookEvent("round_start", round_start);
    HookEvent("round_end", round_end);
    HookEvent("player_team", playerTeam);
    HookEvent("player_disconnect", playerDisconnect, EventHookMode_Pre);
}

public OnAllPluginsLoaded()
{
    readyUpIsAvailable = LibraryExists("readyup");
    IsPauseAvailable = LibraryExists("pause");
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
    if (StrEqual(name, "pause")) IsPauseAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
    if (StrEqual(name, "pause")) IsPauseAvailable = true;
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
    ClearTrie(crashedPlayers);
    ClearArray(generalCrashers);
    ClearArray(infectedPlayers);
    ClearArray(survivorPlayers);
    RoundEnd = false;
}

public round_end(Handle:event, const String:name[], bool:dontBroadcast) {
    RoundEnd = true;
}

// Handles players leaving and joining the infected team.
public playerTeam(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    decl String:steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    if (strcmp(steamId, "BOT") == 0) return;
    new oldTeam = GetEventInt(event, "oldteam");
    new newTeam = GetEventInt(event, "team");

    new index = FindStringInArray(infectedPlayers, steamId);
    new survindex = FindStringInArray(survivorPlayers, steamId);
    if (oldTeam == 3) {
        if (index != -1) RemoveFromArray(infectedPlayers, index);
        if (GetConVarBool(g_hCvarApdebug)) LogMessage("[AutoPause] Removed player %s from infected team.", steamId);
    }
    else if (oldTeam == 2) {
        if (survindex != -1) RemoveFromArray(survivorPlayers, survindex);
        if (GetConVarBool(g_hCvarApdebug)) LogMessage("[AutoPause] Removed player %s from survivor team.", steamId);
    }
    if (newTeam == 3) {
        decl Float:spawnTime;
        if (GetTrieValue(crashedPlayers, steamId, spawnTime)) {
            new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
            CTimer_Start(spawnTimer, spawnTime);
            RemoveFromTrie(crashedPlayers, steamId);
            LogMessage("[AutoPause] Player %s rejoined, set spawn timer to %f.", steamId, spawnTime);
        } else if (index == -1) {
            PushArrayString(infectedPlayers, steamId);
            if (GetConVarBool(g_hCvarApdebug)) LogMessage("[AutoPause] Added player %s to infected team.", steamId);
        }
    }
    else if (newTeam == 2 && survindex == -1) {
        PushArrayString(survivorPlayers, steamId);
        if (GetConVarBool(g_hCvarApdebug)) LogMessage("[AutoPause] Added player %s to survivor team.", steamId);
    }
}

public playerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    decl String:steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    if (strcmp(steamId, "BOT") == 0) return;

    // Player wasn't actually a gamer, ignore
    if (FindStringInArray(infectedPlayers, steamId) == -1 && FindStringInArray(survivorPlayers, steamId) == -1) return;

    decl String:reason[128];
    GetEventString(event, "reason", reason, sizeof(reason));
    decl String:playerName[128];
    GetEventString(event, "name", playerName, sizeof(playerName));
    decl String:timedOut[256];
    Format(timedOut, sizeof(timedOut), "%s timed out", playerName);

    if (GetConVarBool(g_hCvarApdebug)) LogMessage("[AutoPause] Player %s (%s) left the game: %s", playerName, steamId, reason);

    // If the leaving player crashed, pause.
    if (strcmp(reason, timedOut) == 0 || strcmp(reason, "No Steam logon") == 0)
    {
        if ((!readyUpIsAvailable || !IsInReady()) && !RoundEnd && GetConVarBool(g_hCvarEnabled)) 
        {
            if (GetConVarBool(g_hCvarForce)) 
            {
                ServerCommand("sm_forcepause");
            } 
            else 
            {
                FakeClientCommand(client, "sm_pause");
            }
            CPrintToChatAll("{blue}[{default}AutoPause{blue}] {olive}%s {default}crashed.", playerName);

            // General crashed players array (for autounpause)
            if (FindStringInArray(generalCrashers, steamId) == -1) {
                PushArrayString(generalCrashers, steamId);
            }
        }
    }

    // If the leaving player was on infected, save their spawn timer.
    if (FindStringInArray(infectedPlayers, steamId) != -1) {
        decl Float:timeLeft;
        new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
        if (spawnTimer != CTimer_Null) {
            timeLeft = CTimer_GetRemainingTime(spawnTimer);
            LogMessage("[AutoPause] Player %s left the game with %f time until spawn.", steamId, timeLeft);
            SetTrieValue(crashedPlayers, steamId, timeLeft);
        }
    }
}

public void OnClientPutInServer(int client)
{
    if (IsPauseAvailable && IsInPause())
    {
        if (client <= 0 || client > MaxClients) return;
        decl String:steamId[64];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        if (strcmp(steamId, "BOT") == 0) return;
        // Give up on strangers.
        if (FindStringInArray(infectedPlayers, steamId) == -1 && 
            FindStringInArray(survivorPlayers, steamId) == -1 && 
            FindStringInArray(generalCrashers, steamId) == -1) return;

        if (!IsFakeClient(client))
        { // Enabling forced Pause also turns forced Unpause on.
            if (GetConVarBool(g_hCvarForceUnPause) || GetConVarBool(g_hCvarForce))
            {
                ServerCommand("sm_forceunpause");
                if (GetConVarBool(g_hCvarApdebug)) LogMessage("Player %s rejoined. Forced Unpause got invoked.", client);
            }
            // Needs testing. Is the player gaining his old team or is a spectator?
            // Spectators can't mark themselves ready for an unpause.
            // Therefore this function won't probably work without swithing teams.
            // Or a handle to Pause.smx that would mark the team ready?
            else if (GetConVarBool(g_hCvarAutoReady) && GetClientTeam(client) != L4D2Team_Spectator)
            {
                FakeClientCommand(client, "sm_unpause");
                if (GetConVarBool(g_hCvarApdebug)) LogMessage("Player %s rejoined. Marking them ready for an Unpause.", client);
            }
            RemoveFromArray(generalCrashers, FindStringInArray(generalCrashers, steamId));
        }
    }
}
