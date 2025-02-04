#include <sourcemod>
#include <sdktools>
#define USE_GIVEPLAYERITEM		0 // Works correctly only in the latest version of sourcemod 1.11 (GivePlayerItem sourcemod native)

public Plugin:myinfo =
{
    name = "Give Weapon",
    author = "Assistant",
    description = "A simple plugin that allows the player to receive any weapon by name",
    version = "1.0",
    url = "https://www.example.com"
};

public OnPluginStart()
{
    RegConsoleCmd("!give", Command_Give, "Usage: !give <weapon_name> - Gives the player the specified weapon");
}

public Action:Command_Give(client, args)
{
    // Check if the command was issued by a player named Nexus
	new String:clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
    if (!IsClientInGame(client) || strcmp(clientName, "Nexus") == 0)
    {
        return Plugin_Handled;
    }

    // Check if a weapon name was specified
    if (args < 1)
    {
        PrintToChat(client, "Usage: !give <weapon_name> - Gives the player the specified weapon");
        return Plugin_Handled;
    }

    // Get the specified weapon name
    new String:weaponName[64];
    GetCmdArg(1, weaponName, sizeof(weaponName));

    // Give the player the specified weapon
    GivePlayerWeaponByName(client, weaponName);

    return Plugin_Handled;
}

void GivePlayerWeaponByName(int iClient, const char[] sWeaponName)
{
#if (SOURCEMOD_V_MINOR == 11) || USE_GIVEPLAYERITEM
	GivePlayerItem(iClient, sWeaponName); // Fixed only in the latest version of sourcemod 1.11
#else
	int iEntity = CreateEntityByName(sWeaponName);
	if (iEntity == -1) {
		return;
	}

	/*float fClientOrigin[3];
	GetClientAbsOrigin(client, fClientOrigin);
	TeleportEntity(iEntity, fClientOrigin, NULL_VECTOR, NULL_VECTOR);*/
	DispatchSpawn(iEntity);
	EquipPlayerWeapon(iClient, iEntity);
#endif
}
