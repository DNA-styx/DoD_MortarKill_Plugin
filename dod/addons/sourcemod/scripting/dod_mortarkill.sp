#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define PL_VERSION "1.0"

new String:CurrentMap[64];
new String:MortarCfg[] = { "cfg/sourcemod/dod_mortar.cfg" };
new bool:cfgloaded = false;

new mortar1_user;
new mortar1_victim;
new mortar1_calltime;
new String:mortar1_entity[64];
new String:mortar1_tick1[64];
new String:mortar1_tick2[64];
new Float:mortar1_loc[3];
new mortar1_radius;
new m1_tick1;
new m1_tick2;

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


public Plugin:myinfo = 
{
	name = "DoD:S MortarKill",
	author = "BenSib",
	description = "gives up to 4 map-builded mortars kill credits",
	version = "1.0"
};

public OnPluginStart()
{
	CreateConVar("dod_mortarkill_version", PL_VERSION, "DoD:S MortarKill", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEntityOutput( "func_button", "OnPressed", pressed);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

public OnMapStart()
{
	MortarConfig();
}

public MortarConfig()
{
	if(!FileExists(MortarCfg, true))
	{
		cfgloaded = false;
		return false;
	}
	else
		cfgloaded = true;
		
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	new Handle:KeyValues = CreateKeyValues("MortarKills");
	FileToKeyValues(KeyValues, MortarCfg);

	if(KvJumpToKey(KeyValues, CurrentMap))
	{
		KvGotoFirstSubKey(KeyValues);
		KvGetString(KeyValues, "MortarName", mortar1_entity, sizeof(mortar1_entity), "0");
		KvGetString(KeyValues, "TickMin", mortar1_tick1, sizeof(mortar1_tick1), "0");
		KvGetString(KeyValues, "TickMax", mortar1_tick2, sizeof(mortar1_tick2), "0");
		mortar1_radius = KvGetNum(KeyValues, "Radius");
		KvGetVector(KeyValues, "Loc", mortar1_loc);
		m1_tick1 = StringToInt(mortar1_tick1);
		m1_tick2 = StringToInt(mortar1_tick1);
	
		KvGotoNextKey(KeyValues);
		KvGetString(KeyValues, "MortarName", mortar2_entity, sizeof(mortar2_entity), "0");
		KvGetString(KeyValues, "TickMin", mortar2_tick1, sizeof(mortar2_tick1), "0");
		KvGetString(KeyValues, "TickMax", mortar2_tick2, sizeof(mortar2_tick2), "0");
		mortar2_radius = KvGetNum(KeyValues, "Radius");
		KvGetVector(KeyValues, "Loc", mortar2_loc);
		m2_tick1 = StringToInt(mortar2_tick1);
		m2_tick2 = StringToInt(mortar2_tick2);
		
		KvGotoNextKey(KeyValues);
		KvGetString(KeyValues, "MortarName", mortar3_entity, sizeof(mortar3_entity), "0");
		KvGetString(KeyValues, "TickMin", mortar3_tick1, sizeof(mortar3_tick1), "0");
		KvGetString(KeyValues, "TickMax", mortar3_tick2, sizeof(mortar3_tick2), "0");
		mortar3_radius = KvGetNum(KeyValues, "Radius");
		KvGetVector(KeyValues, "Loc", mortar3_loc);
		m3_tick1 = StringToInt(mortar3_tick1);
		m3_tick2 = StringToInt(mortar3_tick2);
		
		KvGotoNextKey(KeyValues);
		KvGetString(KeyValues, "MortarName", mortar4_entity, sizeof(mortar4_entity), "0");
		KvGetString(KeyValues, "TickMin", mortar4_tick1, sizeof(mortar4_tick1), "0");
		KvGetString(KeyValues, "TickMax", mortar4_tick2, sizeof(mortar4_tick2), "0");
		mortar4_radius = KvGetNum(KeyValues, "Radius");
		KvGetVector(KeyValues, "Loc", mortar4_loc);
		m4_tick1 = StringToInt(mortar4_tick1);
		m4_tick2 = StringToInt(mortar4_tick2);
		CloseHandle(KeyValues);
	}
	else
	{
		CloseHandle(KeyValues);
		return false;
	}	
	return true;
}

public pressed(const String:output[], caller, attacker, Float:Any)
{
	if (!cfgloaded)
		LogError("[DOD:S Mortar] Couldn't find dod_mortar.cfg - place it in dod/cfg/sourcemod!");

	decl String:entity[1024];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));
	
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

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victimIndex   = GetClientOfUserId(GetEventInt(event,"userid"));
	new attackerIndex = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (attackerIndex == 0)
	{
		new deathtick = GetTime();
		
		new min1tick = m1_tick1 + mortar1_calltime; 
		new max1tick = m1_tick2 + mortar1_calltime; 
		new min2tick = m2_tick1 + mortar2_calltime; 
		new max2tick = m2_tick2 + mortar2_calltime; 
		new min3tick = m3_tick1 + mortar3_calltime; 
		new max3tick = m3_tick2 + mortar3_calltime; 
		new min4tick = m4_tick1 + mortar4_calltime; 
		new max4tick = m4_tick2 + mortar4_calltime; 
		
		if (ValidPlayer(victimIndex))
		{
			new Float:pVector[3];
			GetClientAbsOrigin(victimIndex, pVector);
			
			new Float:distance1 = GetVectorDistance(pVector, mortar1_loc);
			new Float:distance2 = GetVectorDistance(pVector, mortar2_loc);
			new Float:distance3 = GetVectorDistance(pVector, mortar3_loc);
			new Float:distance4 = GetVectorDistance(pVector, mortar4_loc);
		
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

public Action:Mortar1Kill(attacker)
{
	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE)
	{
		return;
	}
	SetEventInt(event, "userid", GetClientUserId(mortar1_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	
	
	FireEvent(event);
	
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
	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE)
	{
		return;
	}
	SetEventInt(event, "userid", GetClientUserId(mortar2_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);
	
	new diff = 0;
	if (GetClientTeam(mortar2_victim) == GetClientTeam(attacker))
		diff = -1;
	else
		diff = 1;
		
	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

public Action:Mortar3Kill(attacker)
{
	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE)
	{
		return;
	}
	SetEventInt(event, "userid", GetClientUserId(mortar3_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);
	
	new diff = 0;
	if (GetClientTeam(mortar3_victim) == GetClientTeam(attacker))
		diff = -1;
	else
		diff = 1;
	
	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

public Action:Mortar4Kill(attacker)
{
	new Handle:event = CreateEvent("player_death");
	if (event == INVALID_HANDLE)
	{
		return;
	}
	SetEventInt(event, "userid", GetClientUserId(mortar4_victim));
	SetEventInt(event, "attacker", GetClientUserId(attacker));
	SetEventString(event, "weapon", "dod_bomb_target");
	FireEvent(event);
	
	new diff = 0;
	if (GetClientTeam(mortar4_victim) == GetClientTeam(attacker))
		diff = -1;
	else
		diff = 1;
	
	new fkills = GetEntProp(attacker, Prop_Data, "m_iFrags") + diff;
	SetEntProp(attacker, Prop_Data, "m_iFrags", fkills);	
}

stock bool:ValidPlayer(client,bool:check_alive=false){
	if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		if(check_alive && !IsPlayerAlive(client))
		{
			return false;
		}
		return true;
	}
	return false;
}
