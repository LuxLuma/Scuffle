//# vim: set filetype=cpp :

/*
 * license = "https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html#SEC1",
 * TODO:
 * - add an option to strike a user for getting up (till maxRevives)
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_NAME "Scuffle"
#define PLUGIN_VERSION "0.0.5"

ConVar g_cvTokens; int g_token;
int g_tokens[MAXPLAYERS + 1];  // how many times can someone save themselves?

ConVar g_cvRequires; char g_requires[1024];
char g_requirements[32][32];  // pills, shot, kit?
float g_itemHealth[MAXPLAYERS + 1];
float g_itemHealthMap[32];

int g_attackId[MAXPLAYERS + 1];
int g_notified[MAXPLAYERS + 1];  // Is user notified of the ability to get up?
int g_payments[MAXPLAYERS + 1];  // player pays off requirements here
int g_health[MAXPLAYERS + 1];
float g_healthBuffer[MAXPLAYERS + 1];
float g_healthStamp[MAXPLAYERS + 1];
float g_cooldowns[MAXPLAYERS + 1];
int g_scuffling[MAXPLAYERS + 1];
int g_cleanup[MAXPLAYERS + 1];
int g_lastKeyPress[MAXPLAYERS + 1];
float g_lastScuffle[MAXPLAYERS + 1];
float g_secondsCheck[MAXPLAYERS + 1];
float g_scuffleStart[MAXPLAYERS + 1];

int g_maxRevives;
float g_decayRate;
float g_healthReviveBit;

ConVar g_cvCooldown; float g_cooldown;
ConVar g_cvLastLeg; int g_lastLeg;
ConVar g_cvMinHealth; int g_minHealth;
ConVar g_cvAttack; bool g_canScuffleFromAttack;
ConVar g_cvLedge; bool g_canScuffleFromLedge;
ConVar g_cvGround; bool g_canScuffleFromGround;
ConVar g_cvDuration; float g_reviveDuration;
ConVar g_cvReviveHold; float g_reviveHoldTime;
ConVar g_cvReviveTap; float g_reviveTapTime;
ConVar g_cvReviveLoss; float g_reviveLossTime;
ConVar g_cvReviveShiftBit; int g_reviveShiftBit;
ConVar g_cvKillChance; int g_killChance;

public Plugin myinfo= {
    name = PLUGIN_NAME,
    author = "Lux & Victor \"NgBUCKWANGS\" Gonzalez",
    description = "Scuffle Back Into the Fight",
    version = PLUGIN_VERSION,
    url = "https://github.com/LuxLuma/Scuffle"
}

public void OnMapStart() {
    ResetAllClients();
}

void ResetAllClients() {
    for (int i = 1; i <= MaxClients; i++) {
        ResetClient(i, true);
    }
}

void ResetClient(int client, bool hardReset=false) {
    g_cleanup[client] = 0;
    g_lastScuffle[client] = 0.0;
    g_secondsCheck[client] = 0.0;
    g_scuffleStart[client] = 0.0;
    g_lastKeyPress[client] = 0;
    g_scuffling[client] = 0;
    g_payments[client] = 0;
    g_attackId[client] = 0;
    g_notified[client] = 0;

    if (hardReset) {
        g_tokens[client] = g_token;
        g_cooldowns[client] = 0.0;
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
    SetupCvar(g_cvTokens, "scuffle_tokens", "-1", "-1: Infinitely, >0: Is a hard limit");
    SetupCvar(g_cvRequires, "scuffle_requires", "", "Semicolon separated values of inv slots 4 & 5");
    SetupCvar(g_cvCooldown, "scuffle_cooldown", "10", "Cooldown between self-revivals");
    SetupCvar(g_cvLastLeg, "scuffle_lastleg", "2", "0 to survivor_max_incapacitated_count");
    SetupCvar(g_cvMinHealth, "scuffle_minhealth", "1", "Minimum amount of health before a survivor requires help");
    SetupCvar(g_cvAttack, "scuffle_attack", "1", "Can a survivor break an SI hold");
    SetupCvar(g_cvLedge, "scuffle_ledge", "1", "Can a survivor pick themselves up from a ledge");
    SetupCvar(g_cvGround, "scuffle_ground", "1", "Can a survivor pick themselves up from the ground");
    SetupCvar(g_cvDuration, "scuffle_duration", "30.0", "Overall time to spread holds and taps");
    SetupCvar(g_cvReviveHold, "scuffle_holdtime", "0.1", "Chip away at duration when holding jump");
    SetupCvar(g_cvReviveTap, "scuffle_taptime", "1.5", "Chip away at duration when tapping jump");
    SetupCvar(g_cvReviveLoss, "scuffle_losstime", "0.2", "Progress chip away at missed jumps");
    SetupCvar(g_cvReviveShiftBit, "scuffle_shiftbit", "1", "Shift bit for revival see https://sm.alliedmods.net/api/index.php?fastload=file&id=47&");
    SetupCvar(g_cvKillChance, "scuffle_killchance", "0", "Chance of killing an SI when reviving");
    AutoExecConfig(true, "scuffle");
}

public void RoundStartHook(Handle event, const char[] name, bool dontBroadcast) {
    ResetAllClients();
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

    if (IsClientConnected(client) && GetClientTeam(client) == 2) {
        // https://forums.alliedmods.net/showpost.php?p=1583406&postcount=4
        SetEntProp(client, Prop_Send, "m_currentReviveCount", revives);

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

    if (StrEqual(cvName, "scuffle_tokens")) {
        if (newVal[0] != EOS) {
            g_token = GetConVarInt(cvHandle);
            ResetAllClients();
        }
    }

    else if (StrEqual(cvName, "scuffle_requires")) {

        // clean up the previous item arrays
        for (int i = 0; i < sizeof(g_requirements[]); i++) {
            g_itemHealthMap[i] = 0.0;
            g_requirements[i] = "";
        }

        GetConVarString(cvHandle, g_requires, sizeof(g_requires));
        ExplodeString(cvVal, ";", g_requirements, 32, sizeof(g_requirements[]));

        static char reqs[32][32];
        if (g_requirements[0][0] == EOS) {
            return;
        }

        for (int i = 0; i < sizeof(g_requirements[]); i++) {
            ExplodeString(g_requirements[i], "=", reqs, 32, sizeof(reqs[]));

            switch (g_requirements[i][0] == EOS) {
                case 1: break;
                case 0: {
                    g_requirements[i] = reqs[0];
                    g_itemHealthMap[i] = StringToFloat(reqs[1]);
                    reqs[1] = "0.0";
                }
            }
        }
    }

    else if (StrEqual(cvName, "scuffle_cooldown")) {
        g_cooldown = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_lastleg")) {
        SetConVarBounds(cvHandle, ConVarBound_Lower, true, -1.0);
        SetConVarBounds(cvHandle, ConVarBound_Upper, true, float(g_maxRevives));
        g_lastLeg = GetConVarInt(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_minhealth")) {
        g_minHealth = GetConVarInt(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_attack")) {
        g_canScuffleFromAttack = GetConVarBool(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_ledge")) {
        g_canScuffleFromLedge = GetConVarBool(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_ground")) {
        g_canScuffleFromGround = GetConVarBool(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_duration")) {
        g_reviveDuration = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_holdtime")) {
        g_reviveHoldTime = GetConVarFloat(cvHandle);
        if (g_reviveHoldTime >= g_reviveDuration) {
            g_reviveHoldTime += g_reviveLossTime;
        }
    }

    else if (StrEqual(cvName, "scuffle_taptime")) {
        g_reviveTapTime = GetConVarFloat(cvHandle);
        if (g_reviveTapTime >= g_reviveDuration) {
            g_reviveTapTime += g_reviveLossTime;
        }
    }

    else if (StrEqual(cvName, "scuffle_losstime")) {
        g_reviveLossTime = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_shiftbit")) {
        g_reviveShiftBit = 1 << GetConVarInt(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_killchance")) {
        SetConVarBounds(cvHandle, ConVarBound_Lower, true, 0.0);
        SetConVarBounds(cvHandle, ConVarBound_Upper, true, 100.0);
        g_killChance = GetConVarInt(cvHandle);
    }
}

bool HasRequirement(int client, const char item[32]) {
    for (int i = 0; i < sizeof(g_requirements[]); i++) {
        if (g_requirements[i][0] == EOS) {
            switch (i == 0) {
                case 1: return true;
                case 0: return false;
            }
        }

        if (StrContains(item, g_requirements[i]) >= 0) {
            if (g_itemHealthMap[i]) {
                g_itemHealth[client] = g_itemHealthMap[i];
            }

            //g_itemHealth[client] = g_healthReviveBit + g_itemHealthMap[i];
            return true;
        }
    }

    return false;
}

bool CanPlayerScuffle(int client) {

    static char notice[128];
    static int status[MAXPLAYERS + 1];
    static int attack[MAXPLAYERS + 1];

    if (g_scuffling[client]) {
        if (attack[client] == g_attackId[client]) {
            if (status[client] != -3) {
                return status[client] > 0;
            }

            else if (g_cooldowns[client] > GetGameTime()) {
                return false;
            }
        }
    }

    notice = "";
    status[client] = 0;
    attack[client] = g_attackId[client];
    g_scuffling[client] = 1;

    if (g_cooldowns[client] > GetGameTime()) {
        notice = "Cooling down. Call for rescue!!";
        status[client] = -3;
    }

    if (g_tokens[client] == 0) {
        notice = "Out of tokens. Call for rescue!!";
        status[client] = -1;
    }

    if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_lastLeg) {
        notice = "Out of revives. Call for rescue!!";
        status[client] = -2;
    }

    // this checks against ledges and SI *not* ground incaps
    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
        if (g_health[client] + GetClientHealthBuffer(client) <= float(g_minHealth)) {
            notice = "Not strong enough. Call for rescue!!";
            status[client] = -4;
        }
    }

    if (attack[client] != 0) {
        if (attack[client] == -1 && !g_canScuffleFromLedge) {
            notice = "Ledge scuffle disabled. Call for rescue!!";
            status[client] = -5;
        }

        else if (attack[client] == -2 && !g_canScuffleFromGround) {
            notice = "Ground scuffle disabled. Call for rescue!!";
            status[client] = -6;
        }

        else if (attack[client] > 0 && !g_canScuffleFromAttack) {
            notice = "Attack scuffle disabled. Call for rescue!!";
            status[client] = -7;
        }
    }

    if (status[client] == 0) {
        if (g_requirements[0][0] == EOS) {
            status[client] = 1;
        }

        else {
            static char item[32];
            static int ent;

            for (int i = 4; i >= 3; i--) {  // check pills, then kits, etc
                ent = GetPlayerWeaponSlot(client, i);

                if (IsEntityValid(ent)) {
                    GetEntityClassname(ent, item, sizeof(item));
                    if (HasRequirement(client, item)) {
                        g_payments[client] = ent;
                        status[client] = 2;
                        break;
                    }
                }
            }

            if (status[client] == 0) {
                notice = "Requirements missing e.g., pills, adrenaline";
                status[client] = -8;
            }
        }
    }

    if (status[client] > 0) {
        notice = "Tap or hold JUMP key to self-revive!";
    }

    Format(notice, sizeof(notice), "[scuffle] %s", notice);
    DisplayDirectorHint(client, notice, 5);
    return status[client] > 0;
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
    g_healthStamp[client] = GetGameTime();
}

void RestoreClientHealth(int client) {
    int strike = GetEntProp(client, Prop_Send, "m_currentReviveCount");

    if (g_health[client] <= 0) {
        g_health[client] = 1;

        if (g_healthBuffer[client] <= 0.0) {
            g_healthBuffer[client] = g_healthReviveBit;
            strike++;
        }
    }

    Client_ExecuteCheat(client, "give", "health");
    SetEntityHealth(client, g_health[client]);
    L4D_SetPlayerTempHealth(client, g_healthBuffer[client]);
    SetRevive(client, strike);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {

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
            g_cleanup[client] = 1;

            if (!CanPlayerScuffle(client)) {
                return;
            }

            if (g_scuffleStart[client] == 0.0) {
                g_scuffleStart[client] = gameTime;
                g_secondsCheck[client] = gameTime;
                g_lastScuffle[client] = gameTime;
            }

            if (gameTime - g_secondsCheck[client] >= 1.0) {
                g_secondsCheck[client] = gameTime;

                g_health[client]--;
                g_healthBuffer[client] -= 1.0;

                if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
                    if (attackerId != -1) {
                        g_healthBuffer[client] = 0.0;
                        g_health[client] = 0;
                    }
                }
            }

            // if autoreviving set g_reviveLossTime to < 0.0 e.g, -0.01
            if (g_reviveLossTime < 0.0) {
                g_lastScuffle[client] += g_reviveLossTime * -1;
            }

            static int reviving;
            reviving = (buttons == g_reviveShiftBit);

            if (gameTime + g_reviveDuration - g_lastScuffle[client] > g_reviveDuration) {
                switch (reviving) {
                    case 1: g_lastScuffle[client] -= g_reviveHoldTime;
                    case 0: g_lastScuffle[client] += g_reviveLossTime;
                }
            }

            if (g_lastKeyPress[client] != g_reviveShiftBit && reviving) {
                g_lastScuffle[client] -= g_reviveTapTime;
            }

            ShowProgressBar(client, g_lastScuffle[client], g_reviveDuration);
            g_lastKeyPress[client] = buttons;

            if (gameTime - g_reviveDuration >= g_lastScuffle[client]) {
                if (attackerId > 0) {
                    L4D2_Stagger(attackerId, true);

                    if (GetRandomInt(1, 100) <= g_killChance) {
                        ForcePlayerSuicide(attackerId);
                    }
                }

                RestoreClientHealth(client);
                g_cooldowns[client] = gameTime + g_cooldown;
                ent = g_payments[client];

                if (g_tokens[client] > 0) {
                    g_tokens[client]--;
                }

                if (IsEntityValid(ent)) {
                    RemovePlayerItem(client, ent);
                    AcceptEntityInput(ent,"kill");

                    if (g_itemHealth[client] > 0.0) {
                        L4D_SetPlayerTempHealth(client, g_itemHealth[client]);
                        g_itemHealth[client] = 0.0;
                    }
                }

                // and penalize ...
            }
        }

        else if (g_cleanup[client]) {
            ResetClient(client);
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

//     if (g_attackId[client] != 0) {
//         return true;
//     }

    static char attackTypes[4][] = {"m_pounceAttacker", "m_tongueOwner", "m_pummelAttacker", "m_jockeyAttacker"};

    for (int i = 0; i < sizeof(attackTypes); i++) {
        if (HasEntProp(client, Prop_Send, attackTypes[i])) {
            attackerId = GetEntPropEnt(client, Prop_Send, attackTypes[i]);
            if (attackerId > 0) {
                g_attackId[client] = attackerId;
                return true;
            }
        }
    }

    static char incapTypes[2][] = {"m_isHangingFromLedge", "m_isIncapacitated"};

    for (int i = 0; i < sizeof(incapTypes); i++) {
        if (HasEntProp(client, Prop_Send, incapTypes[i])) {
            if (GetEntProp(client, Prop_Send, incapTypes[i])) {
                attackerId = (i + 1) * -1;
                g_attackId[client] = attackerId;
                return true;
            }
        }
    }

    g_attackId[client] = 0;
    if (g_scuffleStart[client]) {
        ShowProgressBar(client, 0.1, 0.0);
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
//l4d_stocks include
static L4D_SetPlayerTempHealth(iClient, float iTempHealth)
{
    SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", iTempHealth);
    SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
}


stock DisplayDirectorHint(iClient, String:sHintTxt[128], iHintTimeout, String:sIcon[]="icon_Tip", String:sBind[]="+jump", String:sHintColorRGB[]="255 0 100")
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
