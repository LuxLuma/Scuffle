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

int g_notified[MAXPLAYERS + 1];  // Is user notified of the ability to get up?
int g_payments[MAXPLAYERS + 1];  // player pays off requirements here

float g_healthReviveBit;
int g_strike[MAXPLAYERS + 1];
int g_health[MAXPLAYERS + 1];
float g_healthBuffer[MAXPLAYERS + 1];
float g_healthRecord[MAXPLAYERS + 1];
int g_maxRevives;
float g_decayRate;
float g_cvCooldown;

public Plugin myinfo= {
    name = PLUGIN_NAME,
    author = "Lux & Victor \"NgBUCKWANGS\" Gonzalez",
    description = "Scuffle Back Into the Fight",
    version = PLUGIN_VERSION,
    url = "https://github.com/LuxLuma/Scuffle"
}

public void OnMapStart() {
    ResetArrays();
}

void ResetArrays() {
    for (int i = 1; i <= MaxClients; i++) {
        g_limits[i] = g_limit;
        g_payments[i] = 0;
    }
}

bool IsEntityValid(int ent) {
    return (ent > MaxClients && ent <= 2048 && IsValidEntity(ent));
}

public void OnPluginStart() {
    HookEvent("round_start", RoundStartHook);
    HookEvent("heal_success", HealSuccessHook);
    HookEvent("player_death", PlayerDeathHook);
    HookEvent("bot_player_replace", BotPlayerReplaceHook);

    g_decayRate = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
    g_healthReviveBit = GetConVarFloat(FindConVar("survivor_revive_health"));
    g_maxRevives = GetConVarInt(FindConVar("survivor_max_incapacitated_count"));
    SetupCvar(g_cvLimit, "scuffle_limit", "-1", "-1: Infinitely, >0: Is a hard limit");
    SetupCvar(g_cvRequires, "scuffle_requires", "", "Semicolon separated values of inv slots 4 & 5");
    AutoExecConfig(true, "scuffle");
}

public void RoundStartHook(Handle event, const char[] name, bool dontBroadcast) {
    ResetArrays();
}

public void HealSuccessHook(Handle event, const char[] name, bool dontBroadcast) {
    SetRevive(GetClientOfUserId(GetEventInt(event, "subject")), 0);
}

public void PlayerDeathHook(Handle event, const char[] name, bool dontBroadcast) {
    SetRevive(GetClientOfUserId(GetEventInt(event, "userid")), 0);
}

public void BotPlayerReplaceHook(Handle event, const char[] name, bool dontBroadcast) {
    int bot = GetClientOfUserId(GetEventInt(event, "bot"));
    int player = GetClientOfUserId(GetEventInt(event, "player"));
    int revive = GetEntProp(bot, Prop_Send, "m_currentReviveCount");
    SetRevive(player, revive);
}

void SetRevive(int client, int revives) {
    if (client <= 0) {
        return;
    }

    if (revives > g_maxRevives) {
        revives = g_maxRevives;
    }

    if (IsClientConnected(client) && GetClientTeam(client) == 2) {
        // https://forums.alliedmods.net/showpost.php?p=1583406&postcount=4
        SetEntProp(client, Prop_Send, "m_currentReviveCount", revives);
        g_strike[client] = revives;

        if (revives == g_maxRevives) {
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1, 1);
            EmitSoundToClient(client, "player/heartbeatloop.wav");
        }

        else {
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0, 1);
            StopSound(client, SNDCHAN_AUTO, "player/heartbeatloop.wav");
        }
    }
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

    if (StrEqual(cvName, "scuffle_limit")) {
        if (newVal[0] != EOS) {
            g_limit = GetConVarInt(cvHandle);
            ResetArrays();  // will reset all player limits
        }
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

    int x = GetEntProp(client, Prop_Send, "m_currentReviveCount");
    PrintToChatAll("client %N currentRevive %d of %d", client, x, g_maxRevives);

    if (GetEntProp(client, Prop_Send, "m_currentReviveCount") == g_maxRevives) {
        PrintToChat(client, "[scuffle] You're to weak. Call for rescue!!");
        return false;
    }

    if (g_limits[client] == 0) {
        if (g_notified[client]++ == 0) {
            PrintToChat(client, "[scuffle] 0 revivals left. Call for rescue!!", g_limits[client]);
        }

        return false;
    }

    if (g_notified[client]++ == 0 && g_limits[client] != 0) {
        PrintToChat(client, "[scuffle] %d revivals left. Tap or hold JUMP key", g_limits[client]);
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

float GetClientHealthBuffer(int client, float defaultVal=0.0) {
    // https://forums.alliedmods.net/showpost.php?p=1365630&postcount=1
    static float healthBuffer, healthBufferTime, tempHealth;
    healthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    healthBufferTime = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    tempHealth = healthBuffer - (healthBufferTime / (1.0 / g_decayRate));
    return tempHealth < 0.0 ? defaultVal : tempHealth;
}

void RecordClientHealth(int client) {
    g_health[client] = GetClientHealth(client);
    g_healthBuffer[client] = GetClientHealthBuffer(client);
    g_healthRecord[client] = GetGameTime();
}

void RestoreClientHealth(int client) {
    g_healthBuffer[client] = GetClientHealthBuffer(client);

    if (g_health[client] <= 0) {
        g_health[client] = 1;
        g_healthBuffer[client] = g_healthReviveBit;
        //g_strike[client]++;  // GetEntProp(client, Prop_Send, "m_currentReviveCount");
        g_strike[client] = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1;
    }

    Client_ExecuteCheat(client, "give", "health");
    SetEntityHealth(client, g_health[client]);
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", g_healthBuffer[client]);
    SetRevive(client, g_strike[client]);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
    static int lastKeyPress[MAXPLAYERS + 1];
    static float strugglers[MAXPLAYERS + 1];
    static float duration = 60.0;
    static float gameTime;
    static int attackerId;
    static int ent;

    attackerId = 0;
    gameTime = GetGameTime();

    if (IsClientConnected(client) && GetClientTeam(client) == 2) {
        if (!GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
            RecordClientHealth(client);
        }

        if (IsFakeClient(client)) {
            return;
        }

        if (IsPlayerInTrouble(client, attackerId)) {
            if (!CanPlayerScuffle(client)) {
                return;
            }

            if (g_health[client] != 0) {
                if (GetClientHealth(client) > g_health[client]) {
                    if (attackerId > 0 || attackerId == -2) {
                        g_healthBuffer[client] = g_healthReviveBit;
                        g_health[client] = 0;
                    }
                }
            }

            if (strugglers[client] == 0.0) {
                strugglers[client] = gameTime;
            }

            else if (gameTime + duration - strugglers[client] > duration) {
                switch (buttons == IN_JUMP) {
                    case 1: strugglers[client] -= 0.1;
                    case 0: strugglers[client] += 0.5;
                }
            }

            if (lastKeyPress[client] != IN_JUMP && buttons == IN_JUMP) {
                strugglers[client] -= 4.5;
            }

            ShowProgressBar(client, strugglers[client], duration);
            lastKeyPress[client] = buttons;

            if (gameTime - duration >= strugglers[client]) {
                if (attackerId > 0) {
                    L4D2_Stagger(attackerId, true);
                }

                else if (attackerId == -1) {
                    g_health[client] -= RoundToZero(gameTime - g_healthRecord[client]);
                }

                RestoreClientHealth(client);

                if (g_limits[client] > 0) {
                    //g_limits[client]--;
                    PrintToChat(client, "[scuffle] %d revivals left", --g_limits[client]);
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
            if (strugglers[client] > 0.0) {
                ShowProgressBar(client, 0.1, 0.1);
            }

            g_notified[client] = 0;
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
stock L4D2_Stagger(iClient, bool:bResetStagger=false, Float:fPos[3]=NULL_VECTOR)
{
    L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", GetClientUserId(iClient), RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));

    if(bResetStagger)
        SetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 0.0, 1);
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
// static ReviveClient(iClient)
// {
//     static iIncapCount;
//     iIncapCount = GetEntProp(iClient, Prop_Send, "m_currentReviveCount") + 1;
//
//     while (g_health[iClient] > 100) {
//         g_health[iClient] -= 100;
//     }
//
//     Client_ExecuteCheat(iClient, "give", "health");
//     SetEntityHealth(iClient, g_health[iClient]);
//
//     PrintToServer(" --- %d %f", g_health[iClient], g_healthBuffer[iClient]);
//
//     SetEntProp(iClient, Prop_Send, "m_currentReviveCount", iIncapCount);
//
//     L4D_SetPlayerTempHealth(iClient, g_healthBuffer[iClient]);
//
//     if(GetMaxReviveCount() <= GetEntProp(iClient, Prop_Send, "m_currentReviveCount"))
//         SetEntProp(iClient, Prop_Send, "m_bIsOnThirdStrike", 1, 1);
// }

static Client_ExecuteCheat(iClient, const String:sCmd[], const String:sArgs[])
{
    new flags = GetCommandFlags(sCmd);
    SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "%s %s", sCmd, sArgs);
    SetCommandFlags(sCmd, flags | FCVAR_CHEAT);
}

// static GetSurvivorReviveHealth()
// {
//     static Handle:hSurvivorReviveHealth = INVALID_HANDLE;
//     if (hSurvivorReviveHealth == INVALID_HANDLE) {
//         hSurvivorReviveHealth = FindConVar("survivor_revive_health");
//         if (hSurvivorReviveHealth == INVALID_HANDLE) {
//             SetFailState("'survivor_revive_health' Cvar not found!");
//         }
//     }
//
//     return GetConVarInt(hSurvivorReviveHealth);
// }

// static GetMaxReviveCount()
// {
//     static Handle:hMaxReviveCount = INVALID_HANDLE;
//     if (hMaxReviveCount == INVALID_HANDLE) {
//         hMaxReviveCount = FindConVar("survivor_max_incapacitated_count");
//         if (hMaxReviveCount == INVALID_HANDLE) {
//             SetFailState("'survivor_max_incapacitated_count' Cvar not found!");
//         }
//     }
//
//     return GetConVarInt(hMaxReviveCount);
// }
//
// //l4d_stocks include
// static L4D_SetPlayerTempHealth(iClient, float iTempHealth)
// {
//     SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", iTempHealth);
//     SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
// }


stock DisplayDirectorHint(iClient, String:sHintTxt[32], iHintTimeout, String:sIcon[]="icon_Tip", String:sBind[]="+jump", String:sHintColorRGB[]="255 0 100")
{
	static iEntity;
	iEntity = CreateEntityByName("env_instructor_hint");
	
	static String:sValues[64];
	
	FormatEx(sValues, sizeof(sValues), "hint%d", iClient);
	DispatchKeyValue(iClient, "targetname", sValues);
	DispatchKeyValue(iEntity, "hint_target", sValues);
	
	Format(sValues, sizeof(sValues), "%d", iHintTimeout);
	DispatchKeyValue(iEntity, "hint_timeout", sValues);
	DispatchKeyValue(iEntity, "hint_range", "100");
	Format(sValues, sizeof(sValues), "%s", sIcon);
	DispatchKeyValue(iEntity, "hint_icon_onscreen", sValues);
	DispatchKeyValue(iEntity, "hint_binding", sBind);
	Format(sValues, sizeof(sValues), "%s", sHintTxt);
	DispatchKeyValue(iEntity, "hint_caption", sHintTxt);
	DispatchKeyValue(iEntity, "hint_color", sHintColorRGB);
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "ShowHint", iClient);
	
	Format(sValues, sizeof(sValues), "OnUser1 !self:Kill::%d:1", iHintTimeout);
	SetVariantString(sValues);
	AcceptEntityInput(iEntity, "AddOutput");
	AcceptEntityInput(iEntity, "FireUser1");
}