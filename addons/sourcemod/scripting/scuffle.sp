//# vim: set filetype=cpp :

/*
 * license = "https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html#SEC1",
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_NAME "Scuffle"
#define PLUGIN_VERSION "0.0.3"

int g_limit;
ConVar g_cvLimit;
int g_limits[MAXPLAYERS + 1];  // how many times can someone save themselves?

char g_requires[1024];
ConVar g_cvRequires;
char g_requirements[32][32];  // pills, shot, kit?

int g_payments[MAXPLAYERS + 1];  // player pays off requirements here

public Plugin myinfo= {
    name = PLUGIN_NAME,
    author = "Lux & Victor \"NgBUCKWANGS\" Gonzalez",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnMapStart() {
    for (int i = 1; i <= MaxClients; i++) {
        g_limits[i] = g_limit;
        g_payments[i] = 0;
    }
}

bool IsEntityValid(int ent) {
    return (ent > MaxClients && ent <= 2048 && IsValidEntity(ent));
}

public void OnPluginStart() {
     SetupCvar(g_cvLimit, "scuffle_limit", "-1", "-1: Infinitely, >0: Is a hard limit");
     SetupCvar(g_cvRequires, "scuffle_requires", "", "Semicolon separated values of inv slots 4 & 5");
     AutoExecConfig(true, "scuffle");
}

void SetupCvar(Handle &cvHandle, char[] name, char[] value, char[] details) {
    cvHandle = CreateConVar(name, value, details);
    HookConVarChange(cvHandle, UpdateConVarsHook);
    UpdateConVarsHook(cvHandle, value, value);
}

public void UpdateConVarsHook(Handle cvHandle, const char[] oldVal, const char[] newVal) {
    char cvName[32], cvVal[128];
    GetConVarName(cvHandle, cvName, sizeof(cvName));
    Format(cvVal, sizeof(cvVal), "%s", newVal);
    SetConVarString(cvHandle, newVal);

    if (newVal[0] == EOS) {
        return;
    }

    if (StrEqual(cvName, "scuffle_limit")) {
        g_limit = GetConVarInt(cvHandle);
        OnMapStart();  // will reset all player limits
    }

    else if (StrEqual(cvName, "scuffle_requires")) {
        for (int i = 0; i < sizeof(g_requirements[]); i++) {
            switch (g_requirements[i][0] != EOS) {
                case 1: g_requirements[i] = "";
                case 0: break;
            }
        }

        GetConVarString(cvHandle, g_requires, sizeof(g_requires));
        ExplodeString(cvVal, ";", g_requirements, 32, sizeof(g_requirements[]));
    }
}

bool HasRequirement(const char item[32]) {
    for (int i = 0; i < sizeof(g_requirements[]); i++) {
        if (g_requirements[i][0] == EOS) {
            switch (i == 0) {
                case 1: return true;
                case 0: return false;
            }
        }

        if (StrContains(item, g_requirements[i]) >= 0) {
            return true;
        }
    }

    return false;
}

bool CanPlayerScuffle(int client) {
    // check if the player has the ability to get up, e.g., pills, tries, etc
    static char item[32];
    static ent;

    if (g_limits[client] == 0) {
        return false;
    }

    if (g_requirements[0][0] == EOS) {
        return true;
    }

    for (int i = 4; i >= 3; i--) {  // check pills, then kits, etc
        ent = GetPlayerWeaponSlot(client, i);

        if (IsEntityValid(ent)) {
            GetEntityClassname(ent, item, sizeof(item));
            if (HasRequirement(item)) {
                g_payments[client] = ent;
                return true;
            }
        }
    }

    return false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
    static int lastKeyPress[MAXPLAYERS + 1];
    static float strugglers[MAXPLAYERS + 1];
    static float duration = 1.0;
    static float gameTime;
    static int attackerId;
    static int ent;

    attackerId = 0;
    gameTime = GetGameTime();

    if (IsClientConnected(client) && GetClientTeam(client) == 2 && !IsFakeClient(client)) {
        if (IsPlayerInTrouble(client, attackerId) && CanPlayerScuffle(client)) {
            if (!strugglers[client]) {
                strugglers[client] = gameTime;
            }

            else if (gameTime + duration - strugglers[client] > duration) {
                switch (buttons == IN_JUMP) {
                    case 1: strugglers[client] -= 0.1;
                    case 0: strugglers[client] += 0.5;
                }
            }

            if (lastKeyPress[client] != IN_JUMP && buttons == IN_JUMP) {
                strugglers[client] -= 1.9;
            }

            ShowProgressBar(client, strugglers[client], duration);
            lastKeyPress[client] = buttons;

            if (gameTime - duration >= strugglers[client]) {
                if (attackerId > 0) {
                	static Float:fPos[3];
                	GetClientAbsOrigin(client, fPos);
                    L4D2_Stagger(attackerId, 2.0, fPos);
                    //ResetAbility(attackerId);
                }

                ReviveClient(client);

                if (g_limits[client] > 0) {
                    g_limits[client]--;
                }

                ent = g_payments[client];
                if (IsEntityValid(ent)) {
                    RemovePlayerItem(client, ent);
                    AcceptEntityInput(ent,"kill");
                }

                // and penalize ...
            }
        }

        else {
            strugglers[client] = 0.0;
            lastKeyPress[client] = 0;
            g_payments[client] = 0;
        }
    }
}

// void ResetAbility(int attacker) {
//     // It would be nice to reset an SI special attack
// }

bool IsPlayerInTrouble(int client, int &attackerId) {

    /* Check if player is being attacked and is immobilized. If the player is
    not being attacked, check if they're incapacitated. An attackerId > 0 is the
    ID of the SI attacking the player. An attackerId of -1 means the player is
    hanging from a ledge. An attackerId of -2 means the player is rotting.
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
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
		{
			SetFailState("Could not create 'logic_script'");
        }

		DispatchSpawn(iScriptLogic);
	}

	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);

	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

// use this to stagger survivor/infected (vector stagger away from origin)
stock L4D2_Stagger(iClient, const Float:fStaggerTime=-1.0, const Float:fPos[3]=NULL_VECTOR)
{
	L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", GetClientUserId(iClient), RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));

	if(fStaggerTime < 0)
		return;
	
	SetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", fStaggerTime, 1);
}

/*
	iClient = client
	fStartTime = GetGameTime() to start the bar at the time you want.
	fDuration = GetGameTime() + 5 Progress bar will finish in 5secs
*/
static ShowProgressBar(iClient, const Float:fStartTime, const Float:fDuration)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flProgressBarStartTime", fStartTime);
	SetEntPropFloat(iClient, Prop_Send, "m_flProgressBarDuration", fDuration);
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


