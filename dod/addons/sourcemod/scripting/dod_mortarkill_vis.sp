/////////////////////////////////////////////////////
// DoD Mortar Visualiser v1.32
// Displays env_sprite at mortar loc and MortarName func_button
// Uses matching sprite pairs from a sprite list
/////////////////////////////////////////////////////

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "DoD Mortar Visualiser",
    author      = "ChatGPT, Guided by DNA.styx",
    description = "Displays env_sprite at mortar locations and MortarName func_buttons with matching sprites",
    version     = "1.32",
    url         = "https://github.com/DNA-styx/DoD_MortarKill_Plugin"
};

#define MAX_MORTARS 32
#define MAX_SPRITES 7

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
char  g_MortarName[MAX_MORTARS][64];
int   g_MortarCount = 0;

// Env_sprite entities
int g_SpriteEntities[MAX_MORTARS];
int g_ButtonSpriteEntities[MAX_MORTARS];

// Sprite list
new String:g_Sprites[MAX_SPRITES][64] =
{
    "sprites/blueglow1.vmt",
    "sprites/redglow1.vmt",
    "sprites/greenglow1.vmt",
    "sprites/yellowglow1.vmt",
    "sprites/purpleglow1.vmt",
    "sprites/orangeglow1.vmt",
    "sprites/glow1.vmt"
};

public void OnMapStart()
{
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));

    LoadMortarsForMap();

    if (!cfgloaded)
        return;

    char spritePath[64];

    // Spawn env_sprite markers at mortar loc and MortarName
    for (int i = 0; i < g_MortarCount; i++)
    {
        float vec[3];
        vec[0] = g_MortarX[i];
        vec[1] = g_MortarY[i];
        vec[2] = g_MortarZ[i];

        float spriteScale = g_MortarRadius[i] / 64.0;
        if (spriteScale > 10.0)
            spriteScale = 10.0;

        int spriteIndex = i % MAX_SPRITES;
        strcopy(spritePath, sizeof(spritePath), g_Sprites[spriteIndex]);

        // Sprite at mortar loc
        g_SpriteEntities[i] = CreateEntityByName("env_sprite");
        if (g_SpriteEntities[i] != -1)
        {
            DispatchKeyValue(g_SpriteEntities[i], "model", spritePath);
            DispatchKeyValue(g_SpriteEntities[i], "rendermode", "5");
            DispatchKeyValueFloat(g_SpriteEntities[i], "scale", spriteScale);

            TeleportEntity(g_SpriteEntities[i], vec, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(g_SpriteEntities[i]);
            ActivateEntity(g_SpriteEntities[i]);
        }

        // Sprite at func_button MortarName
        int ent = -1;
        bool foundButton = false;
        while ((ent = FindEntityByClassname(ent, "func_button")) != -1)
        {
            char targetname[64];
            if (!GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname)))
                continue;

            if (StrEqual(targetname, g_MortarName[i]))
            {
                float buttonVec[3];
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", buttonVec);

                g_ButtonSpriteEntities[i] = CreateEntityByName("env_sprite");
                if (g_ButtonSpriteEntities[i] != -1)
                {
                    DispatchKeyValue(g_ButtonSpriteEntities[i], "model", spritePath);
                    DispatchKeyValue(g_ButtonSpriteEntities[i], "rendermode", "5");
                    DispatchKeyValueFloat(g_ButtonSpriteEntities[i], "scale", 1.0);

                    TeleportEntity(g_ButtonSpriteEntities[i], buttonVec, NULL_VECTOR, NULL_VECTOR);
                    DispatchSpawn(g_ButtonSpriteEntities[i]);
                    ActivateEntity(g_ButtonSpriteEntities[i]);
                }

                foundButton = true;
                break;
            }
        }

        if (!foundButton)
        {
            g_ButtonSpriteEntities[i] = -1;
        }
    }

    PrintToServer("[MortarVis] Spawned %d mortar markers for map %s", g_MortarCount, CurrentMap);
}

public void OnMapEnd()
{
    for (int i = 0; i < g_MortarCount; i++)
    {
        if (g_SpriteEntities[i] != -1)
        {
            AcceptEntityInput(g_SpriteEntities[i], "Kill");
            g_SpriteEntities[i] = -1;
        }
        if (g_ButtonSpriteEntities[i] != -1)
        {
            AcceptEntityInput(g_ButtonSpriteEntities[i], "Kill");
            g_ButtonSpriteEntities[i] = -1;
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
        strcopy(g_MortarName[g_MortarCount], sizeof(g_MortarName[]), name);

        g_SpriteEntities[g_MortarCount] = -1;
        g_ButtonSpriteEntities[g_MortarCount] = -1;

        g_MortarCount++;

    } while (KvGotoNextKey(kv));

    CloseHandle(kv);

    cfgloaded = true;
    PrintToServer("[MortarVis] Loaded %d mortars for map %s", g_MortarCount, CurrentMap);
}
