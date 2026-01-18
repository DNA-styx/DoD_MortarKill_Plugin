/////////////////////////////////////////////////////
// DoD Mortar Visualiser v1.22
// Reads dod_mortar.cfg from dod/cfg/sourcemod
// Spawns env_sprite at mortar locations, scaled to radius
/////////////////////////////////////////////////////

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "DoD Mortar Visualiser",
    author      = "ChatGPT, Guided by DNA.styx",
    description = "Displays env_sprite at mortar locations scaled to radius",
    version     = "1.22"
};

#define MAX_MORTARS 32

// Current map name
new String:CurrentMap[64];

// Path to the mortar config
new String:MortarCfg[PLATFORM_MAX_PATH] = "cfg/sourcemod/dod_mortar.cfg";

// Flag to indicate if config was successfully loaded
new bool:cfgloaded = false;

// Mortar data arrays
float g_MortarX[MAX_MORTARS];
float g_MortarY[MAX_MORTARS];
float g_MortarZ[MAX_MORTARS];
float g_MortarRadius[MAX_MORTARS];
int   g_MortarCount = 0;

// Env_sprite entities
int g_SpriteEntities[MAX_MORTARS];

public void OnMapStart()
{
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));

    LoadMortarsForMap();

    if (!cfgloaded)
        return;

    // Spawn env_sprite markers scaled to radius
    for (int i = 0; i < g_MortarCount; i++)
    {
        float vec[3];
        vec[0] = g_MortarX[i];
        vec[1] = g_MortarY[i];
        vec[2] = g_MortarZ[i]; // center of the radius

        float spriteScale = g_MortarRadius[i] / 64.0; // scale relative to default sprite size
        if (spriteScale > 10.0) // optional max cap
            spriteScale = 10.0;

        g_SpriteEntities[i] = CreateEntityByName("env_sprite");
        if (g_SpriteEntities[i] != -1)
        {
            DispatchKeyValue(g_SpriteEntities[i], "model", "sprites/redglow1.vmt");
            DispatchKeyValue(g_SpriteEntities[i], "rendermode", "5");   // soft glow
            DispatchKeyValue(g_SpriteEntities[i], "rendercolor", "255 0 0");
            DispatchKeyValueFloat(g_SpriteEntities[i], "scale", spriteScale);

            TeleportEntity(g_SpriteEntities[i], vec, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(g_SpriteEntities[i]);
            ActivateEntity(g_SpriteEntities[i]);
        }
    }

    PrintToServer("[MortarVis] Spawned %d mortar markers for map %s", g_MortarCount, CurrentMap);
}

public void OnMapEnd()
{
    // Remove sprite markers safely
    for (int i = 0; i < g_MortarCount; i++)
    {
        if (g_SpriteEntities[i] != -1)
        {
            AcceptEntityInput(g_SpriteEntities[i], "Kill");
            g_SpriteEntities[i] = -1;
        }
    }
}

// -----------------------------
// Load mortars for current map
// -----------------------------
void LoadMortarsForMap()
{
    g_MortarCount = 0;
    cfgloaded = false;

    Handle kv = CreateKeyValues("MortarKills");
    if (!FileToKeyValues(kv, MortarCfg))
    {
        CloseHandle(kv);
        PrintToServer("[MortarVis] Failed to load config: %s", MortarCfg);
        return;
    }

    // Jump to the current map key
    if (!KvJumpToKey(kv, CurrentMap, false))
    {
        PrintToServer("[MortarVis] No mortars defined for map %s", CurrentMap);
        CloseHandle(kv);
        return;
    }

    if (!KvGotoFirstSubKey(kv))
    {
        PrintToServer("[MortarVis] No mortar entries found for map %s", CurrentMap);
        CloseHandle(kv);
        return;
    }

    // Loop through all numbered subkeys under this map
    do
    {
        if (g_MortarCount >= MAX_MORTARS)
            break;

        char name[64];
        KvGetString(kv, "MortarName", name, sizeof(name));
        if (StrEqual(name, "EMPTY"))
            continue;

        char locStr[64];
        KvGetString(kv, "Loc", locStr, sizeof(locStr));

        char parts[3][16];
        if (ExplodeString(locStr, " ", parts, 3, 16) != 3)
            continue;

        float x = StringToFloat(parts[0]);
        float y = StringToFloat(parts[1]);
        float z = StringToFloat(parts[2]);
        if (x == 0.0 && y == 0.0 && z == 0.0)
            continue;

        float radius = KvGetFloat(kv, "Radius", 1000.0);
        if (radius <= 0.0)
            continue;

        g_MortarX[g_MortarCount] = x;
        g_MortarY[g_MortarCount] = y;
        g_MortarZ[g_MortarCount] = z;
        g_MortarRadius[g_MortarCount] = radius;

        g_MortarCount++;

    } while (KvGotoNextKey(kv));

    CloseHandle(kv);

    cfgloaded = true;
    PrintToServer("[MortarVis] Loaded %d mortars for map %s", g_MortarCount, CurrentMap);
}
