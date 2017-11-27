//# vim: set filetype=cpp :

/*
 * license = "https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html#SEC1",
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_NAME "Scuffle"
#define PLUGIN_VERSION "0.0.2"

public Plugin myinfo= {
    name = PLUGIN_NAME,
    author = "Lux & Victor \"NgBUCKWANGS\" Gonzalez",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
    static int attackerId;
    attackerId = 0;

    if (IsPlayerInTrouble(client, attackerId)) {
        if (attackerId != 0) {
            PrintToServer("Player in Trouble (%d)", attackerId);
        }
    }
}

bool IsPlayerInTrouble(int client, int &attackerId) {

    /* Check if player is being attacked and is immobilized. If the player is
    not being attacked, check if they're incapicated. Attacker ids > 0 mean an
    SI is attacking the player. An attacker id of -1 means the player's hanging
    from a ledge. An attacker id of -2 means the player is rotting.
    */

    static char attackTypes[4][] = {"m_pounceAttacker", "m_tongueOwner", "m_pummelAttacker", "m_jockeyAttacker"};

    for (int i = 0; i < sizeof(attackTypes); i++) {
        if (HasEntProp(client, Prop_Send, attackTypes[i])) {
            attackerId = GetEntPropEnt(client, Prop_Send, attackTypes[i]);
            if (attackerId > 0) {
                return true;
            }
        }
    }

    static char incapTypes[2][] = {"m_isHangingFromLedge", "m_isIncapacitated"};

    for (int i = 0; i < sizeof(incapTypes); i++) {
        if (HasEntProp(client, Prop_Send, incapTypes[i])) {
            if (GetEntProp(client, Prop_Send, incapTypes[i])) {
                attackerId = (i + 1) * -1;
                return true;
            }
        }
    }

    return false;
}


// CREDITS TO Timocop for L4D2_RunScript function and L4D2_Stagger function
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByNameCheat("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(iScriptLogic);
	}

	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);

	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

// use this to stagger survivor/infected (vector stagger away from origin)
stock L4D2_Stagger(iClient, Float:fPos[3])
{

	L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", GetClientUserId(iClient), RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));
}

/*
	iClient = client
	fStartTime = GetGameTime() to start the bar at the time you want.
	fDuration = GetGameTime() + 5 Progress bar will finish in 5secs
	sBarTxt = "Mash key to get up"
	any:... = any thing you want to add in sBarTxt string
*/
static ShowProgressBar(iClient, const Float:fStartTime, const Float:fDuration, const String:sBarTxt[], any:...)
{
	static String:sBuffer[64];
	VFormat(sBuffer, sizeof(sBuffer), sBarTxt, 4);

	SetEntPropFloat(iClient, Prop_Send, "m_flProgressBarStartTime", fStartTime);
	SetEntPropFloat(iClient, Prop_Send, "m_flProgressBarDuration", fDuration);
	//SetEntPropString(iClient, Prop_Send, "m_progressBarText", sBuffer);
}

/*
 Simple revive func just feed it client index and will get 50 temp hp
*/
static ReviveClient(iClient)
{
	static iIncapCount;
	iIncapCount = GetEntProp(iClient, Prop_Send, "m_currentReviveCount") + 1;

	Client_ExecuteCheat(iClient, "give", "health");
	SetEntityHealth(iClient, 1);
	SetEntProp(iClient, Prop_Send, "m_currentReviveCount", iIncapCount);

	L4D_SetPlayerTempHealth(iClient, GetSurvivorReviveHealth());

	if(GetMaxReviveCount() <= GetEntProp(iClient, Prop_Send, "m_currentReviveCount"))
		SetEntProp(iClient, Prop_Send, "m_bIsOnThirdStrike", 1, 1);
}

static Client_ExecuteCheat(iClient, const String:sCmd[], const String:sArgs[])
{
	new flags = GetCommandFlags(sCmd);
	SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(iClient, "%s %s", sCmd, sArgs);
	SetCommandFlags(sCmd, flags | FCVAR_CHEAT);
}

static GetSurvivorReviveHealth()
{
	static Handle:hSurvivorReviveHealth = INVALID_HANDLE;
	if (hSurvivorReviveHealth == INVALID_HANDLE) {
		hSurvivorReviveHealth = FindConVar("survivor_revive_health");
		if (hSurvivorReviveHealth == INVALID_HANDLE) {
			SetFailState("'survivor_revive_health' Cvar not found!");
		}
	}

	return GetConVarInt(hSurvivorReviveHealth);
}

static GetMaxReviveCount()
{
	static Handle:hMaxReviveCount = INVALID_HANDLE;
	if (hMaxReviveCount == INVALID_HANDLE) {
		hMaxReviveCount = FindConVar("survivor_max_incapacitated_count");
		if (hMaxReviveCount == INVALID_HANDLE) {
			SetFailState("'survivor_max_incapacitated_count' Cvar not found!");
		}
	}

	return GetConVarInt(hMaxReviveCount);
}

//l4d_stocks include
static L4D_SetPlayerTempHealth(iClient, iTempHealth)
{
    SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", float(iTempHealth));
    SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
}
