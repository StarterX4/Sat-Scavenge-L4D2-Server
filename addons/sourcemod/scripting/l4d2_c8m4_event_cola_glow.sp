#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_direct>
#include <l4d_stocks>
//#include <left4downtown>
#include <l4d2lib>

#define C8M4_EVENT_ID              	3
#define C8M4_COLA_BOTTLES			"cola_bottles"
#define C8M4_COLA_BOTTLES_GLOW_COLOR	{220, 60, 120}

new Handle:hComplexEventMapTrie = INVALID_HANDLE;
new iComplexEventID;

public Plugin:myinfo = 
{
	name = "Confogl Sky Customization Plugin",
	author = "Visor, JaneDoe, StarterX4",
	description = "Everything Stripper can't do (limited to c8m4 for Kether needs)",
	version = "2.0e",
	url = "https://github.com/Attano"
}

public OnPluginStart()
{
	decl String:sGame[128];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	
	HookEvent("weapon_drop", OnWeaponDrop, EventHookMode_Pre);
	
	hComplexEventMapTrie = BuildComplexEventTrie();
	
	LoadTranslations("common.phrases");
	LoadTranslations("plugin.basecommands");
	}

public OnMapStart()
{
	new String:sBuffer[128];
	GetCurrentMap(sBuffer, sizeof(sBuffer));
	
	iComplexEventID = -1;
	
	GetTrieValue(hComplexEventMapTrie, sBuffer, iComplexEventID);
	
}

public Action:OnWeaponDrop(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch (iComplexEventID)
	{
		case C8M4_EVENT_ID:
		{
			decl String:classname[64];
			GetEventString(event, "item", classname, sizeof(classname));
			
			// Setting up glow
			if (StrEqual(classname, C8M4_COLA_BOTTLES))
			{
				L4D2_SetEntityGlow(GetEventInt(event, "propid"), L4D2Glow_Constant, 0, 22, C8M4_COLA_BOTTLES_GLOW_COLOR, true);
			}
		}
	}
	
	return Plugin_Continue;
}

Handle:BuildComplexEventTrie()
{
	new Handle: trie = CreateTrie();
	SetTrieValue(trie, "c8m4_interior", C8M4_EVENT_ID);
	return trie;
}