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
#define PLUGIN_VERSION "0.0.10"

ConVar g_cvRequires; char g_requires[1024];  // e.g., "kit=30;pills=50;adrenaline"
char g_requirements[32][32];  // required items to revive e.g., kit, pills, adrenaline
float g_itemHealthMap[32];  // health map of items (above) e.g., 50.0, 0.0, 10.0
float g_itemHealth[MAXPLAYERS + 1];  // [client] current item health e.g, 50.0, 0.0, 10.0

int g_attackId[MAXPLAYERS + 1];  // who is attacking [client]? -1 ledge, -2 ground, >0 SI Id
int g_payments[MAXPLAYERS + 1];  // if an item to revive is required, this holds [client] entity to be killed
int g_health[MAXPLAYERS + 1];  // [client] health state
float g_healthBuffer[MAXPLAYERS + 1];  // [client] health buffer state
float g_cooldowns[MAXPLAYERS + 1];  // [client] = GetGameTime() + float;
int g_scuffling[MAXPLAYERS + 1];  // is [client] in a scuffle?
int g_cleanup[MAXPLAYERS + 1];  // clean up [client] arrays?
int g_lastKeyPress[MAXPLAYERS + 1];  // last key [client] pressed (during scuffle)
float g_lastScuffle[MAXPLAYERS + 1];  // time remaining until [client] meets g_reviveDuration

//lux always gotta be different :D
// static Float:fAnimChangeDur[MAXPLAYERS+1];
// static Float:fAnimChangeSpeed[MAXPLAYERS+1];

// int g_maxRevives;
// float g_decayRate;
// float g_healthReviveBit;

ConVar g_cvDecayRate;
ConVar g_cvHealthReviveBit;
ConVar g_cvMaxRevives;

#define g_decayRate GetConVarFloat(g_cvDecayRate)
#define g_healthReviveBit GetConVarFloat(g_cvHealthReviveBit)
#define g_maxRevives GetConVarInt(g_cvMaxRevives)

ConVar g_cvCooldown; float g_cooldown;  // time it takes before reviving is possible again
ConVar g_cvLastLeg; int g_lastLeg;  // reviving turns off when m_currentReviveCount matches
ConVar g_cvMinHealth; int g_minHealth;  // minimum amount of health to be able to revive

ConVar g_cvAllTokens; int g_allToken;  // initial number of times a survivor can self revive
int g_allTokens[MAXPLAYERS + 1];  // how many tokens does [client] have left?
ConVar g_cvAttackTokens; int g_attackToken;
int g_attackTokens[MAXPLAYERS + 1];
ConVar g_cvLedgeTokens; int g_ledgeToken;
int g_ledgeTokens[MAXPLAYERS + 1];
ConVar g_cvGroundTokens; int g_groundToken;
int g_groundTokens[MAXPLAYERS + 1];

ConVar g_cvDuration; float g_reviveDuration;  //
ConVar g_cvReviveHold; float g_reviveHoldTime;
ConVar g_cvReviveTap; float g_reviveTapTime;
ConVar g_cvReviveLoss; float g_reviveLossTime;
ConVar g_cvReviveShiftBit; int g_reviveShiftBit;
ConVar g_cvKillChance; int g_killChance;
ConVar g_cvStayDown; bool g_stayDown;

int g_blockDamage[MAXPLAYERS + 1];  // block [client] = attackerId
float g_staggerTime[MAXPLAYERS + 1];  // stagger time on [attackerId] until GetGameTime + float
float g_staggers[4];  // hunter, smoker, charger, jockey

ConVar g_cvHunterStagger;
ConVar g_cvSmokerStagger;
ConVar g_cvChargerStagger;
ConVar g_cvJockeyStagger;

char g_shiftKey[26];
char g_shiftKeyMap[26][26] = {
    "+attack",      // 0    IN_ATTACK
    "+jump",        // 1    IN_JUMP
    "+duck",        // 2    IN_DUCK
    "+forward",     // 3    IN_FORWARD
    "+back",        // 4    IN_BACK
    "+use",         // 5    IN_USE
    "+cancel",      // 6?   IN_CANCEL
    "+left",        // 7    IN_LEFT
    "+right",       // 8?   IN_RIGHT
    "+moveleft",    // 9?   IN_MOVELEFT
    "+moveright",   // 10   IN_MOVERIGHT
    "+attack2",     // 11   IN_ATTACK2
    "+run",         // 12?  IN_RUN
    "+reload",      // 13   IN_RELOAD
    "+alt1",        // 14?  IN_ALT1
    "+alt2",        // 15?  IN_ALT2
    "+score",       // 16?  IN_SCORE
    "+speed",       // 17   IN_SPEED  // THIS IS WALK
    "+walk",        // 18?  IN_WALK
    "+zoom",        // 19   IN_ZOOM
    "+weapon1",     // 20?  IN_WEAPON1
    "+weapon2",     // 21?  IN_WEAPON2
    "+bullrush",    // 22?  IN_BULLRUSH
    "+grenade1",    // 23?  IN_GRENADE1
    "+grenade2",    // 24?  IN_GRENADE2
    "+attack3"      // 25   IN_ATTACK3
};

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
    g_staggerTime[client] = 0.0;
    g_lastKeyPress[client] = 0;
    g_scuffling[client] = 0;
    g_payments[client] = 0;
    g_attackId[client] = 0;

//     fAnimChangeDur[client] = 0.0;
//     fAnimChangeSpeed[client] = 0.0;

    if (hardReset) {
        ResetClientTokens(client);
        g_cooldowns[client] = 0.0;
        g_blockDamage[client] = 0;
    }
}

ResetAllClientTokens() {
    for (int i = 1; i <= MaxClients; i++) {
        ResetClientTokens(i);
    }
}

ResetClientTokens(int client) {
    g_ledgeTokens[client] = g_ledgeToken;
    g_groundTokens[client] = g_groundToken;
    g_attackTokens[client] = g_attackToken;
    g_allTokens[client] = g_allToken;

    if (g_allToken > -1) {
        if (g_ledgeToken > 0) {
            g_allTokens[client] += g_ledgeToken;
        }

        if (g_groundToken > 0) {
            g_allTokens[client] += g_groundToken;
        }

        if (g_attackToken > 0) {
            g_allTokens[client] += g_attackToken;
        }
    }
}

bool IsEntityValid(int ent) {
    return (ent > MaxClients && ent <= 2048 && IsValidEntity(ent));
}

public void OnClientPostAdminCheck(int client) {
    if (client > 0) {
        if (IsClientConnected(client) && !IsFakeClient(client)) {
            SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageHook);
            ResetClient(client, true);
        }
    }
}

public void OnPluginStart() {
    HookEvent("round_start", RoundStartHook);
    HookEvent("heal_success", HealSuccessHook);
    HookEvent("player_death", PlayerDeathHook);
    HookEvent("bot_player_replace", BotPlayerReplaceHook, EventHookMode_Pre);

    g_cvDecayRate = FindConVar("pain_pills_decay_rate");
    g_cvHealthReviveBit = FindConVar("survivor_revive_health");
    g_cvMaxRevives = FindConVar("survivor_max_incapacitated_count");

    SetupCvar(g_cvAllTokens, "scuffle_tokens", "-1", "-1: Infinitely, >0: Total times a survivor can self revive");
    SetupCvar(g_cvAttackTokens, "scuffle_attack", "-1", "-1: Infinitely, >0: Times a survivor can revive from an SI incap");
    SetupCvar(g_cvLedgeTokens, "scuffle_ledge", "-1", "-1: Infinitely, >0: Times a survivor can revive from a ledge");
    SetupCvar(g_cvGroundTokens, "scuffle_ground", "-1", "-1: Infinitely, >0: Times a survivor can revive from the ground");
    SetupCvar(g_cvRequires, "scuffle_requires", "", "Semicolon separated values of inv slots 4 & 5");
    SetupCvar(g_cvCooldown, "scuffle_cooldown", "10", "Cooldown between self-revivals");
    SetupCvar(g_cvLastLeg, "scuffle_lastleg", "2", "0 to survivor_max_incapacitated_count");
    SetupCvar(g_cvMinHealth, "scuffle_minhealth", "1", "Minimum amount of health before a survivor requires help");
    SetupCvar(g_cvDuration, "scuffle_duration", "30.0", "Overall time to spread holds and taps");
    SetupCvar(g_cvReviveHold, "scuffle_holdtime", "0.1", "Chip away at duration when holding jump");
    SetupCvar(g_cvReviveTap, "scuffle_taptime", "1.5", "Chip away at duration when tapping jump");
    SetupCvar(g_cvReviveLoss, "scuffle_losstime", "0.2", "Progress chip away at missed jumps");
    SetupCvar(g_cvReviveShiftBit, "scuffle_shiftbit", "1", "Shift bit for revival see https://sm.alliedmods.net/api/index.php?fastload=file&id=47&");
    SetupCvar(g_cvKillChance, "scuffle_killchance", "0", "Chance of killing an SI when reviving");
    SetupCvar(g_cvStayDown, "scuffle_staydown", "0", "0: Break SI hold and get up. 1: Break SI hold and stay down (unless SI dies, if requiring items, this makes it require double)");

    SetupCvar(g_cvHunterStagger, "scuffle_hunterstagger", "3.0", "Hunter stagger and block time");
    SetupCvar(g_cvSmokerStagger, "scuffle_smokerstagger", "1.2", "Smoker stagger and block time");
    SetupCvar(g_cvChargerStagger, "scuffle_chargerstagger", "3.5", "Charger stagger and block time");
    SetupCvar(g_cvJockeyStagger, "scuffle_jockeystagger", "1.2", "Jockey stagger and block time");

    AutoExecConfig(true, "scuffle");

    for (int i = 1; i <= MaxClients; i++) {
        OnClientPostAdminCheck(i);
    }
}

public void RoundStartHook(Handle event, const char[] name, bool dontBroadcast) {
    ResetAllClients();
}

public void HealSuccessHook(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "subject"));
    ResetClient(client, true);
    SetRevive(client, 0);
}

public void PlayerDeathHook(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    ResetClient(client, true);
    SetRevive(client, 0);
}

public void BotPlayerReplaceHook(Handle event, const char[] name, bool dontBroadcast) {
    int target = GetClientOfUserId(GetEventInt(event, "bot"));
    int client = GetClientOfUserId(GetEventInt(event, "player"));
    SetRevive(client, GetEntProp(target, Prop_Send, "m_currentReviveCount"));
}

void SetRevive(int client, int count) {
    if (client <= 0) {
        return;
    }

    // https://forums.alliedmods.net/showpost.php?p=1583406&postcount=4
    if (IsClientConnected(client) && GetClientTeam(client) == 2) {
        if (!IsFakeClient(client)) {
            bool isMaxed = count >= g_maxRevives;

            switch (isMaxed && !GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1)) {
                case 1: EmitSoundToClient(client, "player/heartbeatloop.wav");
                case 0: StopSound(client, SNDCHAN_AUTO, "player/heartbeatloop.wav");
            }

            SetEntProp(client, Prop_Send, "m_currentReviveCount", count);
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", isMaxed, 1);
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

    if (StrEqual(cvName, "scuffle_requires")) {
        // clean up the previous item/health arrays
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

    else if (StrEqual(cvName, "scuffle_tokens")) {
        g_allToken = GetConVarInt(cvHandle);
        ResetAllClientTokens();
    }

    else if (StrEqual(cvName, "scuffle_attack")) {
        g_attackToken = GetConVarInt(cvHandle);
        ResetAllClientTokens();
    }

    else if (StrEqual(cvName, "scuffle_ledge")) {
        g_ledgeToken = GetConVarInt(cvHandle);
        ResetAllClientTokens();
    }

    else if (StrEqual(cvName, "scuffle_ground")) {
        g_groundToken = GetConVarInt(cvHandle);
        ResetAllClientTokens();
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
        static int shiftBit;
        shiftBit = GetConVarInt(cvHandle);
        SetConVarBounds(cvHandle, ConVarBound_Lower, true, 0.0);
        SetConVarBounds(cvHandle, ConVarBound_Upper, true, 25.0);
        g_shiftKey = g_shiftKeyMap[shiftBit];
        g_reviveShiftBit = 1 << shiftBit;
    }

    else if (StrEqual(cvName, "scuffle_killchance")) {
        SetConVarBounds(cvHandle, ConVarBound_Lower, true, 0.0);
        SetConVarBounds(cvHandle, ConVarBound_Upper, true, 100.0);
        g_killChance = GetConVarInt(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_staydown")) {
        g_stayDown = GetConVarBool(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_hunterstagger")) {
        g_staggers[0] = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_smokerstagger")) {
        g_staggers[1] = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_chargerstagger")) {
        g_staggers[2] = GetConVarFloat(cvHandle);
    }

    else if (StrEqual(cvName, "scuffle_jockeystagger")) {
        g_staggers[3] = GetConVarFloat(cvHandle);
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

            return true;
        }
    }

    return false;
}

bool CanPlayerScuffle(int client) {

    static char key[32];
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

    key = "";
    notice = "";
    status[client] = 0;
    attack[client] = g_attackId[client];
    g_scuffling[client] = 1;

    if (g_cooldowns[client] > GetGameTime()) {
        notice = "Cooling down. Call for rescue!!";
        status[client] = -3;
    }

    if (g_allTokens[client] == 0) {
        notice = "All scuffling disabled. Call for rescue!!";
        status[client] = -1;
    }

    else if (attack[client] == -1 && g_ledgeTokens[client] == 0) {
        notice = "Ledge scuffle disabled. Call for rescue!!";
        status[client] = -5;
    }

    else if (attack[client] == -2 && g_groundTokens[client] == 0) {
        notice = "Ground scuffle disabled. Call for rescue!!";
        status[client] = -6;
    }

    else if (attack[client] > 0 && g_attackTokens[client] == 0) {
        notice = "Attack scuffle disabled. Call for rescue!!";
        status[client] = -7;
    }

    if (g_lastLeg >= 0) {
        if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_maxRevives) {
            notice = "Out of revives. Call for rescue!!";
            status[client] = -2;
        }
    }

    // this checks against ledges and SI *not* ground incaps
    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
        if (g_health[client] + GetClientHealthBuffer(client) <= float(g_minHealth)) {
            notice = "Not strong enough. Call for rescue!!";
            status[client] = -4;
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
        notice = "Tap or hold to self-revive!";
        key = g_shiftKey;
    }

    Format(notice, sizeof(notice), "[scuffle] %s", notice);
    DisplayDirectorHint(client, notice, 5, "icon_Tip", key);
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

    static float attackHealth[MAXPLAYERS + 1];
    static float gameTime;
    gameTime = GetGameTime();

    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
        g_health[client] = GetClientHealth(client);
        g_healthBuffer[client] = GetClientHealthBuffer(client);
        attackHealth[client] = gameTime;
    }

    else if (g_attackId[client] != 0) {

        // if we're not hanging on a ledge, we're officially down
        if (g_attackId[client] != -1) {
            g_healthBuffer[client] = 0.0;
            g_health[client] = 0;
        }

        // this penalty will apply if the user gets themselves up
        if (attackHealth[client] < gameTime) {
            attackHealth[client] = gameTime + 1.0;
            g_healthBuffer[client] -= 1.0;
            g_health[client] -= 1;
        }
    }
}

void RestoreClientHealth(int client) {
    int strike = GetEntProp(client, Prop_Send, "m_currentReviveCount");

    if (g_health[client] <= 0) {
        g_health[client] = 1;

        if (g_healthBuffer[client] <= 0.0) {
            strike++;

            switch (g_itemHealth[client] > 0.0) {
                case 1: g_healthBuffer[client] = g_itemHealth[client];
                case 0: g_healthBuffer[client] = g_healthReviveBit;
            }
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

    if (IsClientConnected(client) && GetClientTeam(client) == 2) {

        RecordClientHealth(client);
        if (IsFakeClient(client)) {
            return;
        }

        attackerId = 0;
        gameTime = GetGameTime();

        if (IsPlayerInTrouble(client, attackerId)) {
            g_cleanup[client] = 1;

            if (!CanPlayerScuffle(client)) {
                return;
            }

            if (g_lastScuffle[client] == 0.0) {
                g_lastScuffle[client] = gameTime;
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
                if (g_allTokens[client] > 0) {
                    g_allTokens[client]--;
                }

                if (attackerId == -1 && g_ledgeTokens[client] > 0) {
                    g_ledgeTokens[client]--;
                } else if (attackerId == -2 && g_groundTokens[client] > 0) {
                    g_groundTokens[client]--;
                } else if (attackerId > 0 && g_attackTokens[client] > 0) {
                    g_attackTokens[client]--;
                }

                ent = g_payments[client];
                if (IsEntityValid(ent)) {
                    RemovePlayerItem(client, ent);
                    AcceptEntityInput(ent,"kill");
                }

                if (attackerId > 0) {
                    g_blockDamage[client] = attackerId;
                    CreateTimer(0.01, StaggerTimer, client, TIMER_REPEAT);
                    L4D2_Stagger(attackerId);

                    if (GetRandomInt(1, 100) <= g_killChance) {
                        ForcePlayerSuicide(attackerId);
                        g_blockDamage[client] = 0;
                    }
                }

                if (g_blockDamage[client] > 0 && g_stayDown) {
                    g_lastScuffle[client] = gameTime;
                    return;
                }

                g_cooldowns[client] = gameTime + g_cooldown;
                RestoreClientHealth(client);
                // and penalize ...
            }
        }

        else if (g_cleanup[client]) {
            ResetClient(client);
        }
    }
}

public Action OnTakeDamageHook(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (attacker > 0 && g_blockDamage[victim] == attacker) {
        damage = 0.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action StaggerTimer(Handle timer, int client) {

    static int attackerId;
    attackerId = g_blockDamage[client];

    if (attackerId > 0 && GetGameTime() <= g_staggerTime[attackerId]) {
        if (IsClientConnected(attackerId) && IsPlayerAlive(attackerId)) {
            if (GetClientTeam(attackerId) == 3) {
                L4D2_Stagger(attackerId);
                return Plugin_Continue;
            }
        }
    }

    g_blockDamage[client] = 0;
    return Plugin_Stop;
}

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
                g_staggerTime[attackerId] = GetGameTime() + g_staggers[i];
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
    if (g_lastScuffle[client]) {
        ShowProgressBar(client, 0.1, 0.0);
    }

    return false;
}

// void ResetAbility(int attacker) {
//     // It would be nice to reset an SI's special attack
// }

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
stock L4D2_Stagger(iClient, Float:fPos[3]=NULL_VECTOR)
{
    L4D2_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", GetClientUserId(iClient), RoundFloat(fPos[0]), RoundFloat(fPos[1]), RoundFloat(fPos[2]));
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

static Client_ExecuteCheat(iClient, const String:sCmd[], const String:sArgs[])
{
    new flags = GetCommandFlags(sCmd);
    SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "%s %s", sCmd, sArgs);
    SetCommandFlags(sCmd, flags | FCVAR_CHEAT);
}

//l4d_stocks include
static L4D_SetPlayerTempHealth(iClient, float iTempHealth)
{
    SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", iTempHealth);
    SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
}

//	to use hint icons sBind needs to be an empty string like ""
//	example mr wangs is (DisplayDirectorHint(iClient, "Meoow", 5, "icon_Tip", "", "255 0 100"))
//	String:sIcon[]="icon_Tip", String:sBind[]="+jump"
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

    if(sBind[0] == '\0')
        DispatchKeyValue(iEntity, "hint_icon_onscreen", sIcon);
    else
    {
        DispatchKeyValue(iEntity, "hint_icon_onscreen", "use_binding");
        DispatchKeyValue(iEntity, "hint_binding", sBind);
    }

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

/*
Simple revive func just feed it client index and will get 50 temp hp
*/

/*
static ReviveClient(iClient)
{
    static iIncapCount;
    iIncapCount = GetEntProp(iClient, Prop_Send, "m_currentReviveCount") + 1;

    while (g_health[iClient] > 100) {
        g_health[iClient] -= 100;
    }

    Client_ExecuteCheat(iClient, "give", "health");
    SetEntityHealth(iClient, g_health[iClient]);
    SetEntProp(iClient, Prop_Send, "m_currentReviveCount", iIncapCount);

    L4D_SetPlayerTempHealth(iClient, g_healthBuffer[iClient]);

    if(GetMaxReviveCount() <= GetEntProp(iClient, Prop_Send, "m_currentReviveCount"))
        SetEntProp(iClient, Prop_Send, "m_bIsOnThirdStrike", 1, 1);
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

public OnClientPutInServer(iClient)
{
    fAnimChangeDur[iClient] = 0.0;

    if(IsFakeClient(iClient))
        return;

    SDKHook(iClient, SDKHook_PostThinkPost, HooksSpeedUpAnim);
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamageHook);
}

public OnClientDisconnect(iClient)
{
    fAnimChangeDur[iClient] = 0.0;

    if(IsFakeClient(iClient))
        return;

    SDKUnhook(iClient, SDKHook_PostThinkPost, HooksSpeedUpAnim);
    SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamageHook);
}

public HooksSpeedUpAnim(iClient)
{
    if(!IsPlayerAlive(iClient) || GetClientTeam(iClient) != 2)
        return;

    if(fAnimChangeDur[iClient] < GetGameTime())
        return;

    SetEntPropFloat(iClient, Prop_Send, "m_flPlaybackRate", fAnimChangeSpeed[iClient]);
}

//iClient		Client index
//fAnimTime		5.0 // animation manipulation duration
//fAnimSpeed	2.0 // doubles animation speed

SetAnimationSpeed(iClient, Float:fAnimTime, Float:fAnimSpeed)
{
    fAnimChangeDur[iClient] = GetGameTime() + fAnimTime;
    fAnimChangeSpeed[iClient] = GetGameTime() + fAnimSpeed;
}
*/
