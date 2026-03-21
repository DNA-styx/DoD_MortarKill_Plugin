#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define PL_VERSION "2.0.2"
#define MAX_MORTARS 32

// Team definitions
#define TEAM_ALLIES 2
#define TEAM_AXIS 3

// ---------------------------
// Global Variables
// ---------------------------

// Current map name
new String:g_CurrentMap[64];

// Path to the mortar config
new String:g_MortarCfg[PLATFORM_MAX_PATH] = "cfg/sourcemod/dod_mortar.cfg";

// Flag to indicate if config was successfully loaded
new bool:g_CfgLoaded = false;

// Mortar count
new g_MortarCount = 0;

// Mortar data arrays
new g_MortarUser[MAX_MORTARS];
new g_MortarCallTime[MAX_MORTARS];
new String:g_MortarEntity[MAX_MORTARS][64];
new Float:g_MortarLoc[MAX_MORTARS][3];
new g_MortarRadius[MAX_MORTARS];
new g_MortarTickMin[MAX_MORTARS];
new g_MortarTickMax[MAX_MORTARS];

// ConVars
new Handle:g_CvarDebug = INVALID_HANDLE;

// ---------------------------
// Plugin Info
// ---------------------------
public Plugin:myinfo = 
{
    name = "DoD:S MortarKill",
    author = "BenSib, Claude.ai guided by DNA.styx",
    description = "Gives kill credits for map-built mortars (supports unlimited mortars)",
    version = PL_VERSION,
    url = ""
};

// ---------------------------
// Plugin Start
// ---------------------------
public OnPluginStart()
{
    // Expose plugin version as a ConVar
    CreateConVar("dod_mortarkill_version", PL_VERSION, "DoD:S MortarKill Version", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    // Debug ConVar
    g_CvarDebug = CreateConVar("dod_mortarkill_debug", "0", "Enable debug logging (0=off, 1=on)", FCVAR_NONE, true, 0.0, true, 1.0);

    // Hook func_button outputs for mortars
    HookEntityOutput("func_button", "OnPressed", OnButtonPressed);

    // Hook events
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("dod_round_start", OnRoundStart, EventHookMode_PostNoCopy);
}

// ---------------------------
// Map Start
// ---------------------------
public OnMapStart()
{
    g_CfgLoaded = LoadMortarConfig();
}

// ---------------------------
// Round Start - Clear mortar state
// ---------------------------
public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i = 0; i < g_MortarCount; i++)
    {
        g_MortarUser[i] = 0;
        g_MortarCallTime[i] = 0;
    }
    
    if (GetConVarBool(g_CvarDebug))
    {
        LogMessage("[MortarKill] Round started - cleared %d mortar states", g_MortarCount);
    }
}

// ---------------------------
// Load Mortar Config
// ---------------------------
public bool:LoadMortarConfig()
{
    if (!FileExists(g_MortarCfg, true))
    {
        LogError("[MortarKill] Couldn't find dod_mortar.cfg! Place it in dod/cfg/sourcemod");
        return false;
    }

    new Handle:hKeyValues = CreateKeyValues("MortarKills");
    if (hKeyValues == INVALID_HANDLE)
    {
        LogError("[MortarKill] Failed to create KeyValues handle!");
        return false;
    }

    if (!FileToKeyValues(hKeyValues, g_MortarCfg))
    {
        LogError("[MortarKill] Failed to parse dod_mortar.cfg!");
        CloseHandle(hKeyValues);
        return false;
    }

    GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));

    if (!KvJumpToKey(hKeyValues, g_CurrentMap))
    {
        LogMessage("[MortarKill] No entry for map \"%s\" in dod_mortar.cfg", g_CurrentMap);
        CloseHandle(hKeyValues);
        return false;
    }

    // Reset mortar count
    g_MortarCount = 0;

    // Loop through all mortars
    if (KvGotoFirstSubKey(hKeyValues))
    {
        do
        {
            if (g_MortarCount >= MAX_MORTARS)
            {
                LogError("[MortarKill] Max mortars (%d) exceeded! Ignoring remaining mortars.", MAX_MORTARS);
                break;
            }

            // Get mortar name
            KvGetString(hKeyValues, "MortarName", g_MortarEntity[g_MortarCount], 64, "");
            
            // Skip if no name
            if (strlen(g_MortarEntity[g_MortarCount]) == 0)
            {
                if (GetConVarBool(g_CvarDebug))
                {
                    LogMessage("[MortarKill] Skipping mortar with no name");
                }
                continue;
            }

            // Load mortar data
            g_MortarTickMin[g_MortarCount] = KvGetNum(hKeyValues, "TickMin", 0);
            g_MortarTickMax[g_MortarCount] = KvGetNum(hKeyValues, "TickMax", 0);
            g_MortarRadius[g_MortarCount] = KvGetNum(hKeyValues, "Radius", 0);
            KvGetVector(hKeyValues, "Loc", g_MortarLoc[g_MortarCount]);

            // Validate data
            if (g_MortarRadius[g_MortarCount] <= 0)
            {
                LogError("[MortarKill] Mortar \"%s\" has invalid radius (%d), skipping", 
                    g_MortarEntity[g_MortarCount], g_MortarRadius[g_MortarCount]);
                continue;
            }

            if (g_MortarTickMax[g_MortarCount] < g_MortarTickMin[g_MortarCount])
            {
                LogError("[MortarKill] Mortar \"%s\" has invalid tick window (min=%d, max=%d), skipping", 
                    g_MortarEntity[g_MortarCount], g_MortarTickMin[g_MortarCount], g_MortarTickMax[g_MortarCount]);
                continue;
            }
            
            if (g_MortarTickMin[g_MortarCount] < 0 || g_MortarTickMax[g_MortarCount] > 15)
            {
                LogError("[MortarKill] Mortar \"%s\" has tick values outside valid range 0-15 (min=%d, max=%d), skipping", 
                    g_MortarEntity[g_MortarCount], g_MortarTickMin[g_MortarCount], g_MortarTickMax[g_MortarCount]);
                continue;
            }

            // Initialize tracking
            g_MortarUser[g_MortarCount] = 0;
            g_MortarCallTime[g_MortarCount] = 0;

            if (GetConVarBool(g_CvarDebug))
            {
                LogMessage("[MortarKill] Loaded mortar #%d: %s (radius=%d, ticks=%d-%d, loc=%.1f,%.1f,%.1f)", 
                    g_MortarCount + 1,
                    g_MortarEntity[g_MortarCount],
                    g_MortarRadius[g_MortarCount],
                    g_MortarTickMin[g_MortarCount],
                    g_MortarTickMax[g_MortarCount],
                    g_MortarLoc[g_MortarCount][0],
                    g_MortarLoc[g_MortarCount][1],
                    g_MortarLoc[g_MortarCount][2]);
            }

            g_MortarCount++;

        } while (KvGotoNextKey(hKeyValues));
    }

    CloseHandle(hKeyValues);
    
    if (GetConVarBool(g_CvarDebug))
    {
        LogMessage("[MortarKill] Loaded %d mortar(s) for map %s", g_MortarCount, g_CurrentMap);
    }
    
    return (g_MortarCount > 0);
}

// ---------------------------
// Hook for func_button presses
// ---------------------------
public OnButtonPressed(const String:output[], caller, attacker, Float:delay)
{
    if (!g_CfgLoaded || !IsValidPlayer(attacker))
        return;

    decl String:entity[64];
    GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

    // Find matching mortar
    for (new i = 0; i < g_MortarCount; i++)
    {
        if (strcmp(entity, g_MortarEntity[i], false) == 0)
        {
            g_MortarCallTime[i] = GetTime();
            g_MortarUser[i] = attacker;
            
            if (GetConVarBool(g_CvarDebug))
            {
                LogMessage("[MortarKill] Player %N triggered mortar #%d (%s) at time %d", 
                    attacker, i + 1, g_MortarEntity[i], g_MortarCallTime[i]);
            }
            break;
        }
    }
}

// ---------------------------
// Player Death Hook
// ---------------------------
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victimIndex = GetClientOfUserId(GetEventInt(event, "userid"));
    new attackerIndex = GetClientOfUserId(GetEventInt(event, "attacker"));

    // Only handle environmental deaths (no attacker)
    if (attackerIndex != 0 || !IsValidPlayer(victimIndex))
        return Plugin_Continue;

    new deathTime = GetTime();
    new Float:victimPos[3];
    GetClientAbsOrigin(victimIndex, victimPos);

    // Check each mortar
    for (new i = 0; i < g_MortarCount; i++)
    {
        // Skip if no one has triggered this mortar
        if (!IsValidPlayer(g_MortarUser[i]))
            continue;

        // Check time window
        new minTick = g_MortarTickMin[i] + g_MortarCallTime[i];
        new maxTick = g_MortarTickMax[i] + g_MortarCallTime[i];

        if (deathTime < minTick || deathTime > maxTick)
            continue;

        // Check distance
        new Float:distance = GetVectorDistance(victimPos, g_MortarLoc[i]);
        
        if (GetConVarBool(g_CvarDebug))
        {
            LogMessage("[MortarKill] Checking mortar #%d: distance=%.1f, radius=%d, time=%d (window=%d-%d)", 
                i + 1, distance, g_MortarRadius[i], deathTime, minTick, maxTick);
        }

        if (distance > g_MortarRadius[i])
            continue;

        // Award kill
        AwardMortarKill(g_MortarUser[i], victimIndex, i);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// ---------------------------
// Award Mortar Kill
// ---------------------------
stock AwardMortarKill(attacker, victim, mortarIndex)
{
    if (!IsValidPlayer(attacker) || !IsValidPlayer(victim))
        return;

    // Get player names and teams
    decl String:attackerName[MAX_NAME_LENGTH];
    decl String:victimName[MAX_NAME_LENGTH];
    GetClientName(attacker, attackerName, sizeof(attackerName));
    GetClientName(victim, victimName, sizeof(victimName));
    
    new attackerTeam = GetClientTeam(attacker);
    new victimTeam = GetClientTeam(victim);
    
    // Color names by team
    decl String:attackerColored[MAX_NAME_LENGTH + 16];
    decl String:victimColored[MAX_NAME_LENGTH + 16];
    
    switch (attackerTeam)
    {
        case TEAM_ALLIES:
            Format(attackerColored, sizeof(attackerColored), "\x074d7942%s\x01", attackerName);
        case TEAM_AXIS:
            Format(attackerColored, sizeof(attackerColored), "\x07ff4040%s\x01", attackerName);
        default:
            Format(attackerColored, sizeof(attackerColored), "\x01%s", attackerName);
    }
    
    switch (victimTeam)
    {
        case TEAM_ALLIES:
            Format(victimColored, sizeof(victimColored), "\x074d7942%s\x01", victimName);
        case TEAM_AXIS:
            Format(victimColored, sizeof(victimColored), "\x07ff4040%s\x01", victimName);
        default:
            Format(victimColored, sizeof(victimColored), "\x01%s", victimName);
    }
    
    // Format: [Mortar] (killer) killed (victim)
    // Green for [Mortar], team colors for player names
    PrintToChatAll("\x01\x04[Mortar]\x01 %s killed %s", attackerColored, victimColored);

    // Adjust frags (penalty for teamkill)
    new diff = (GetClientTeam(attacker) == GetClientTeam(victim)) ? -1 : 1;
    new frags = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
    SetEntProp(attacker, Prop_Data, "m_iFrags", frags);
    
    if (GetConVarBool(g_CvarDebug))
    {
        LogMessage("[MortarKill] Awarded kill to %N for victim %N (mortar #%d, teamkill=%s, new frags=%d)", 
            attacker, victim, mortarIndex + 1, (diff == -1) ? "yes" : "no", frags);
    }
}

// ---------------------------
// Helper: Validate Player
// ---------------------------
stock bool:IsValidPlayer(client, bool:checkAlive = false)
{
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
    {
        if (checkAlive && !IsPlayerAlive(client))
            return false;
            
        return true;
    }
    return false;
}