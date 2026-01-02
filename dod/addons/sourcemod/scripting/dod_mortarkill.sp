#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define PL_VERSION "1.5-dev"

// ---------------------------
// Global Variables
// ---------------------------

// Current map name
new String:CurrentMap[64];

// Path to the mortar config
new String:MortarCfg[PLATFORM_MAX_PATH] = "cfg/sourcemod/dod_mortar.cfg";

// Flag to indicate if config was successfully loaded
new bool:cfgloaded = false;

// ---------------------------
// Mortar 1
// ---------------------------
new mortar1_user;           // Client index of the player who triggered the mortar
new mortar1_victim;         // Client index of the victim killed by the mortar
new mortar1_calltime;       // Timestamp when the mortar was triggered
new String:mortar1_entity[64]; // Entity name of the mortar
new String:mortar1_tick1[64];  // Tick window min (from config)
new String:mortar1_tick2[64];  // Tick window max (from config)
new Float:mortar1_loc[3];      // Mortar explosion location
new mortar1_radius;             // Mortar effect radius
new m1_tick1;                   // Tick min as integer
new m1_tick2;                   // Tick max as integer

// ---------------------------
// Mortar 2
// ---------------------------
new mortar2_user;
new mortar2_victim;
new mortar2_calltime;
new String:mortar2_entity[64];
new String:mortar2_tick1[64];
new String:mortar2_tick2[64];
new Float:mortar2_loc[3];
new mortar2_radius;
new m2_tick1;
new m2_tick2;

// ---------------------------
// Mortar 3
// ---------------------------
new mortar3_user;
new mortar3_victim;
new mortar3_calltime;
new String:mortar3_entity[64];
new String:mortar3_tick1[64];
new String:mortar3_tick2[64];
new Float:mortar3_loc[3];
new mortar3_radius;
new m3_tick1;
new m3_tick2;

// ---------------------------
// Mortar 4
// ---------------------------
new mortar4_user;
new mortar4_victim;
new mortar4_calltime;
new String:mortar4_entity[64];
new String:mortar4_tick1[64];
new String:mortar4_tick2[64];
new Float:mortar4_loc[3];
new mortar4_radius;
new m4_tick1;
new m4_tick2;

// ---------------------------
// Plugin Info
// ---------------------------
public Plugin:myinfo = 
{
	name = "DoD:S MortarKill",
	author = "BenSib, DNA.styx",
	description = "Gives kill credits for up to 4 map-builded mortars (dev version)",
	version = PL_VERSION
};

// ---------------------------
// Plugin Start
// ---------------------------
public OnPluginStart()
{
	// Expose plugin version as a ConVar
	CreateConVar("dod_mortarkill_version", PL_VERSION, "DoD:S MortarKill", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	// Hook func_button outputs for mortars
	HookEntityOutput("func_button", "OnPressed", pressed);

	// Hook the player death event (pre-hook)
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

// ---------------------------
// Map Start
// ---------------------------
public OnMapStart()
{
	MortarConfig(); // Load the mortar configuration for this map
}

// ---------------------------
// Load Mortar Config
// ---------------------------
public bool:MortarConfig()
{
    // Check if config file exists
    if (!FileExists(MortarCfg, true))
    {
        cfgloaded = false;
        LogError("[DOD:S Mortar] Couldn't find dod_mortar.cfg! Place it in dod/cfg/sourcemod");
        return false;
    }

    cfgloaded = true;

    // Create KeyValues handle
    new Handle:hKeyValues = CreateKeyValues("MortarKills");
    if (hKeyValues == INVALID_HANDLE)
    {
        cfgloaded = false;
        LogError("[DOD:S Mortar] Failed to create KeyValues handle!");
        return false;
    }

    // Load the KeyValues file
    if (!FileToKeyValues(hKeyValues, MortarCfg))
    {
        cfgloaded = false;
        LogError("[DOD:S Mortar] Failed to parse dod_mortar.cfg!");
        CloseHandle(hKeyValues);
        return false;
    }

    // Get the current map key
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));

    if (KvJumpToKey(hKeyValues, CurrentMap))
    {
        // ---------------------------
        // Load each mortar's data
        // ---------------------------

        // Mortar 1
        KvGotoFirstSubKey(hKeyValues);
        KvGetString(hKeyValues, "MortarName", mortar1_entity, sizeof(mortar1_entity), "0");
        KvGetString(hKeyValues, "TickMin", mortar1_tick1, sizeof(mortar1_tick1), "0");
        KvGetString(hKeyValues, "TickMax", mortar1_tick2, sizeof(mortar1_tick2), "0");
        mortar1_radius = KvGetNum(hKeyValues, "Radius");
        KvGetVector(hKeyValues, "Loc", mortar1_loc);
        m1_tick1 = StringToInt(mortar1_tick1);
        m1_tick2 = StringToInt(mortar1_tick2);

        // Mortar 2
        KvGotoNextKey(hKeyValues);
        KvGetString(hKeyValues, "MortarName", mortar2_entity, sizeof(mortar2_entity), "0");
        KvGetString(hKeyValues, "TickMin", mortar2_tick1, sizeof(mortar2_tick1), "0");
        KvGetString(hKeyValues, "TickMax", mortar2_tick2, sizeof(mortar2_tick2), "0");
        mortar2_radius = KvGetNum(hKeyValues, "Radius");
        KvGetVector(hKeyValues, "Loc", mortar2_loc);
        m2_tick1 = StringToInt(mortar2_tick1);
        m2_tick2 = StringToInt(mortar2_tick2);

        // Mortar 3
        KvGotoNextKey(hKeyValues);
        KvGetString(hKeyValues, "MortarName", mortar3_entity, sizeof(mortar3_entity), "0");
        KvGetString(hKeyValues, "TickMin", mortar3_tick1, sizeof(mortar3_tick1), "0");
        KvGetString(hKeyValues, "TickMax", mortar3_tick2, sizeof(mortar3_tick2), "0");
        mortar3_radius = KvGetNum(hKeyValues, "Radius");
        KvGetVector(hKeyValues, "Loc", mortar3_loc);
        m3_tick1 = StringToInt(mortar3_tick1);
        m3_tick2 = StringToInt(mortar3_tick2);

        // Mortar 4
        KvGotoNextKey(hKeyValues);
        KvGetString(hKeyValues, "MortarName", mortar4_entity, sizeof(mortar4_entity), "0");
        KvGetString(hKeyValues, "TickMin", mortar4_tick1, sizeof(mortar4_tick1), "0");
        KvGetString(hKeyValues, "TickMax", mortar4_tick2, sizeof(mortar4_tick2), "0");
        mortar4_radius = KvGetNum(hKeyValues, "Radius");
        KvGetVector(hKeyValues, "Loc", mortar4_loc);
        m4_tick1 = StringToInt(mortar4_tick1);
        m4_tick2 = StringToInt(mortar4_tick2);
    }
    else
    {
        LogError("[DOD:S Mortar] No entry for map \"%s\" in dod_mortar.cfg", CurrentMap);
        cfgloaded = false;
    }

    CloseHandle(hKeyValues);
    return cfgloaded;
}

// ---------------------------
// Hook for func_button presses
// ---------------------------
public pressed(const String:output[], caller, attacker, Float:Any)
{
    // Skip if config not loaded
    if (!cfgloaded)
    {
        LogError("[DOD:S Mortar] Config not loaded; cannot process mortar!");
        return;
    }

    // Validate attacker (humans or bots)
    if (!ValidPlayer(attacker))
    {
        LogError("[DOD:S Mortar] Ignoring button press by invalid attacker");
        return;
    }

    // Get entity name of pressed button
    decl String:entity[1024];
    GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

    // Assign mortar user and timestamp if the entity matches
    if (strcmp(entity, mortar1_entity, false) == 0)
    {
        mortar1_calltime = GetTime();
        mortar1_user = attacker;
    }
    else if (strcmp(entity, mortar2_entity, false) == 0)
    {
        mortar2_calltime = GetTime();
        mortar2_user = attacker;
    }
    else if (strcmp(entity, mortar3_entity, false) == 0)
    {
        mortar3_calltime = GetTime();
        mortar3_user = attacker;
    }
    else if (strcmp(entity, mortar4_entity, false) == 0)
    {
        mortar4_calltime = GetTime();
        mortar4_user = attacker;
    }
}

// ---------------------------
// Player Death Hook
// ---------------------------
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victimIndex   = GetClientOfUserId(GetEventInt(event,"userid"));
	new attackerIndex = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	// Only process deaths where the attacker is "world" (attackerIndex==0)
	if (attackerIndex == 0)
	{
		new deathtick = GetTime();
		
		// Compute min/max tick windows for each mortar
		new min1tick = m1_tick1 + mortar1_calltime; 
		new max1tick = m1_tick2 + mortar1_calltime; 
		new min2tick = m2_tick1 + mortar2_calltime; 
		new max2tick = m2_tick2 + mortar2_calltime; 
		new min3tick = m3_tick1 + mortar3_calltime; 
		new max3tick = m3_tick2 + mortar3_calltime; 
		new min4tick = m4_tick1 + mortar4_calltime; 
		new max4tick = m4_tick2 + mortar4_calltime; 
		
		// Ensure victim is valid
		if (ValidPlayer(victimIndex))
		{
			new Float:pVector[3];
			GetClientAbsOrigin(victimIndex, pVector);
			
			// Compute distance from each mortar
			new Float:distance1 = GetVectorDistance(pVector, mortar1_loc);
			new Float:distance2 = GetVectorDistance(pVector, mortar2_loc);
			new Float:distance3 = GetVectorDistance(pVector, mortar3_loc);
			new Float:distance4 = GetVectorDistance(pVector, mortar4_loc);
		
			// Check if death falls within mortar tick window and radius
			if (deathtick >= min1tick && deathtick <= max1tick && distance1 <= mortar1_radius && ValidPlayer(mortar1_user))
			{
				mortar1_victim = victimIndex;
				Mortar1Kill(mortar1_user);
				return Plugin_Handled;
			}
			else if (deathtick >= min2tick && deathtick <= max2tick && distance2 <= mortar2_radius && ValidPlayer(mortar2_user))
			{
				mortar2_victim = victimIndex;
				Mortar2Kill(mortar2_user);
				return Plugin_Handled;
			}
			else if (deathtick >= min3tick && deathtick <= max3tick && distance3 <= mortar3_radius && ValidPlayer(mortar3_user))
			{
				mortar3_victim = victimIndex;
				Mortar3Kill(mortar3_user);
				return Plugin_Handled;
			}
			else if (deathtick >= min4tick && deathtick <= max4tick && distance4 <= mortar4_radius && ValidPlayer(mortar4_user))
			{
				mortar4_victim = victimIndex;
				Mortar4Kill(mortar4_user);
				return Plugin_Handled;
			}
		}
	}		
	return Plugin_Continue;
}

// ---------------------------
// Mortar Kill Functions
// ---------------------------
public Action:Mortar1Kill(attacker)
{
	// Skip if attacker is invalid
	if (!ValidPlayer(attacker))
		return;

	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE)
		return;

	SetEventInt(event, "userid", GetClientUserId(mortar1_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);
	
	// Adjust frags safely
	new diff = 0;
	if (GetClientTeam(mortar1_victim) == GetClientTeam(attacker))
		diff = -1;
	else
		diff = 1;
	
	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

public Action:Mortar2Kill(attacker)
{
	if (!ValidPlayer(attacker)) return;

	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE) return;

	SetEventInt(event, "userid", GetClientUserId(mortar2_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);

	new diff = 0;
	if (GetClientTeam(mortar2_victim) == GetClientTeam(attacker)) diff = -1;
	else diff = 1;

	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

public Action:Mortar3Kill(attacker)
{
	if (!ValidPlayer(attacker)) return;

	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE) return;

	SetEventInt(event, "userid", GetClientUserId(mortar3_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);

	new diff = 0;
	if (GetClientTeam(mortar3_victim) == GetClientTeam(attacker)) diff = -1;
	else diff = 1;

	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

public Action:Mortar4Kill(attacker)
{
	if (!ValidPlayer(attacker)) return;

	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE) return;

	SetEventInt(event, "userid", GetClientUserId(mortar4_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);

	new diff = 0;
	if (GetClientTeam(mortar4_victim) == GetClientTeam(attacker)) diff = -1;
	else diff = 1;

	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

// ---------------------------
// Helper: Validate Player
// ---------------------------
stock bool:ValidPlayer(client,bool:check_alive=false)
{
	if(client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		if(check_alive && !IsPlayerAlive(client))
		{
			return false;
		}
		return true;
	}
	return false;
}
