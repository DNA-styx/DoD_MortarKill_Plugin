/////////////////////////////////////////////////////
// DoD Mortar Visualiser v2.0.3
// Displays env_sprite at mortar loc and MortarName func_button
// Uses matching sprite pairs from a sprite list
/////////////////////////////////////////////////////

#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name        = "DoD Mortar Visualiser",
    author      = "claude.ai, Guided by DNA.styx",
    description = "Displays env_sprite at mortar locations and MortarName func_buttons with matching sprites",
    version     = "2.0.28",
    url         = "https://github.com/DNA-styx/DoD_MortarKill_Plugin"
};

// Constants
#define MAX_MORTARS 64
#define MAX_SPRITES 7
#define CONFIG_PATH "cfg/sourcemod/dod_mortar.cfg"

// Mortar data structure
enum struct MortarData
{
    float x;
    float y;
    float z;
    float originalX;  // Store original coordinates from config
    float originalY;
    float originalZ;
    float radius;
    float originalRadius;  // Store original radius from config
    char name[64];
    int spriteEntity;
    int buttonSpriteEntity;
}

// Global variables
MortarData g_Mortars[MAX_MORTARS];
int g_MortarCount = 0;
char g_CurrentMap[64];
bool g_ConfigLoaded = false;

// Admin menu
TopMenu g_hTopMenu;
TopMenuObject g_MortarMenuCategory;

// Axis guides
int g_BeamSprite;
int g_HaloSprite;
int g_EditingMortarIndex = -1;  // Only one person editing at a time
Handle g_AxisTimer = INVALID_HANDLE;

// Sprite list
char g_Sprites[MAX_SPRITES][64] =
{
    "sprites/blueglow1.vmt",
    "sprites/redglow1.vmt",
    "sprites/greenglow1.vmt",
    "sprites/yellowglow1.vmt",
    "sprites/purpleglow1.vmt",
    "sprites/orangeglow1.vmt",
    "sprites/glow1.vmt"
};

// ConVars
ConVar g_cvEnabled;
ConVar g_cvShowButtons;

// Forward declarations
public void ShowMortarListMenu(int client);
public void ShowEditMortarMenu(int client, int mortarIndex);
public void ShowChangeRadiusMenu(int client, int mortarIndex);
public void ShowChangeLocMenu(int client, int mortarIndex);

//=============================================================================
// Plugin Lifecycle
//=============================================================================

public void OnPluginStart()
{
    // Create ConVars
    g_cvEnabled = CreateConVar("sm_mortarvis_enable", "1", "Enable mortar visualization", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvShowButtons = CreateConVar("sm_mortarvis_showbuttons", "1", "Show sprites at func_buttons", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // Admin commands
    RegAdminCmd("sm_mortarvis_reload", Command_ReloadConfig, ADMFLAG_CONFIG, "Reload mortar configuration");
    RegAdminCmd("sm_mortarvis_list", Command_ListMortars, ADMFLAG_CONFIG, "List all mortars for current map");
    RegAdminCmd("sm_mortarvis_findbuttons", Command_FindButtons, ADMFLAG_CONFIG, "Find all func_button entities on map");
    RegAdminCmd("sm_mortarvis_menu", Command_OpenMenu, ADMFLAG_CONFIG, "Open mortar admin menu");
    
    // Auto-generate config
    AutoExecConfig(true, "dod_mortarvis");
    
    // Hook to existing admin menu if available
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
    
    PrintToServer("[MortarVis] Plugin loaded - v2.0.6");
}

public void OnMapStart()
{
    GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));
    
    // Precache beam sprites
    g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
    
    // Reset state
    g_MortarCount = 0;
    g_ConfigLoaded = false;
    
    // Start axis guide timer
    if (g_AxisTimer != INVALID_HANDLE)
    {
        delete g_AxisTimer;
    }
    g_AxisTimer = CreateTimer(0.1, Timer_DrawAxisGuides, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    
    // Load and spawn
    if (LoadMortarConfig())
    {
        SpawnAllMortarSprites();
    }
}

public void OnMapEnd()
{
    RemoveAllSprites();
    
    if (g_AxisTimer != INVALID_HANDLE)
    {
        delete g_AxisTimer;
        g_AxisTimer = INVALID_HANDLE;
    }
    
    g_EditingMortarIndex = -1;
    g_MortarCount = 0;
    g_ConfigLoaded = false;
}

//=============================================================================
// Admin Menu Integration
//=============================================================================

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    
    // Don't add twice
    if (topmenu == g_hTopMenu)
        return;
    
    g_hTopMenu = topmenu;
    
    // Add category to admin menu
    g_MortarMenuCategory = g_hTopMenu.AddCategory("mortar_config", CategoryHandler, "sm_mortarvis_menu", ADMFLAG_CONFIG);
    
    // Add items to our category
    if (g_MortarMenuCategory != INVALID_TOPMENUOBJECT)
    {
        g_hTopMenu.AddItem("mortar_list", ItemHandler_ListMortars, g_MortarMenuCategory, "sm_mortarvis_list", ADMFLAG_CONFIG);
        g_hTopMenu.AddItem("mortar_reload", ItemHandler_Reload, g_MortarMenuCategory, "sm_mortarvis_reload", ADMFLAG_CONFIG);
    }
}

public void CategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayTitle)
    {
        Format(buffer, maxlength, "DoD Mortar Vis");
    }
    else if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "DoD Mortar Vis");
    }
}

public void ItemHandler_ListMortars(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "List Mortars (%d)", g_MortarCount);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        int client = param;
        ShowMortarListMenu(client);
    }
}

public void ItemHandler_Reload(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Reload Config");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        int client = param;
        Command_ReloadConfig(client, 0);
        g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
    }
}

public void ItemHandler_FindButtons(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Find Buttons");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        int client = param;
        Command_FindButtons(client, 0);
        g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
    }
}

//=============================================================================
// Mortar List Menu
//=============================================================================

public void ShowMortarListMenu(int client)
{
    if (g_MortarCount == 0)
    {
        PrintToChat(client, "[MortarVis] No mortars configured for this map!");
        if (g_hTopMenu != null)
        {
            g_hTopMenu.DisplayCategory(g_MortarMenuCategory, client);
        }
        return;
    }
    
    Menu menu = new Menu(MenuHandler_MortarList);
    menu.SetTitle("Mortars on %s:", g_CurrentMap);
    
    for (int i = 0; i < g_MortarCount; i++)
    {
        char index[8];
        IntToString(i, index, sizeof(index));
        menu.AddItem(index, g_Mortars[i].name);
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MortarList(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && g_hTopMenu != null)
        {
            g_hTopMenu.DisplayCategory(g_MortarMenuCategory, param1);
        }
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[8];
        menu.GetItem(param2, info, sizeof(info));
        int index = StringToInt(info);
        
        // Turn on sprite if not already visible
        if (g_Mortars[index].spriteEntity == -1)
        {
            SpawnMortarSprite(index);
            if (g_cvShowButtons.BoolValue)
            {
                SpawnButtonSprite(index);
            }
        }
        
        // Show edit menu for this mortar
        g_EditingMortarIndex = index;  // Mark as editing
        ShowEditMortarMenu(client, index);
    }
    
    return 0;
}

//=============================================================================
// Edit Mortar Menu
//=============================================================================

public void ShowEditMortarMenu(int client, int mortarIndex)
{
    Menu menu = new Menu(MenuHandler_EditMortar);
    
    char title[256];
    Format(title, sizeof(title), "Edit: %s\nRadius: %.0f", 
        g_Mortars[mortarIndex].name,
        g_Mortars[mortarIndex].radius);
    menu.SetTitle(title);
    
    char indexStr[8];
    IntToString(mortarIndex, indexStr, sizeof(indexStr));
    
    char item[16];
    Format(item, sizeof(item), "radius_%s", indexStr);
    menu.AddItem(item, "Change Radius");
    
    Format(item, sizeof(item), "loc_%s", indexStr);
    menu.AddItem(item, "Change Loc");
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EditMortar(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
        {
            g_EditingMortarIndex = -1;  // Stop editing
            ShowMortarListMenu(param1);
        }
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        
        // Parse action and index
        char parts[2][8];
        ExplodeString(info, "_", parts, 2, 8);
        int mortarIndex = StringToInt(parts[1]);
        
        if (StrEqual(parts[0], "radius"))
        {
            ShowChangeRadiusMenu(client, mortarIndex);
        }
        else if (StrEqual(parts[0], "loc"))
        {
            ShowChangeLocMenu(client, mortarIndex);
        }
    }
    
    return 0;
}

//=============================================================================
// Change Radius Menu
//=============================================================================

public void ShowChangeRadiusMenu(int client, int mortarIndex)
{
    Menu menu = new Menu(MenuHandler_ChangeRadius);
    
    char title[256];
    Format(title, sizeof(title), "Change Radius: %s\nOriginal: %.0f | New: %.0f", 
        g_Mortars[mortarIndex].name,
        g_Mortars[mortarIndex].originalRadius,
        g_Mortars[mortarIndex].radius);
    menu.SetTitle(title);
    
    char indexStr[16];
    
    // Increase option
    Format(indexStr, sizeof(indexStr), "inc_%d", mortarIndex);
    menu.AddItem(indexStr, "Increase (+500)");
    
    // Decrease option
    Format(indexStr, sizeof(indexStr), "dec_%d", mortarIndex);
    menu.AddItem(indexStr, "Decrease (-500)");
    
    // Reset option
    Format(indexStr, sizeof(indexStr), "reset_%d", mortarIndex);
    menu.AddItem(indexStr, "Reset to Original");
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChangeRadius(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
        {
            int client = param1;
            char info[16];
            menu.GetItem(0, info, sizeof(info));
            
            // Extract mortar index from first item
            char parts[2][8];
            ExplodeString(info, "_", parts, 2, 8);
            int mortarIndex = StringToInt(parts[1]);
            
            ShowEditMortarMenu(client, mortarIndex);
        }
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        
        // Parse action and index
        char parts[2][8];
        ExplodeString(info, "_", parts, 2, 8);
        int mortarIndex = StringToInt(parts[1]);
        
        float newRadius = g_Mortars[mortarIndex].radius;
        
        if (StrEqual(parts[0], "inc"))
        {
            newRadius += 500.0;
            if (newRadius > 5000.0)
                newRadius = 5000.0;
        }
        else if (StrEqual(parts[0], "dec"))
        {
            newRadius -= 500.0;
            if (newRadius < 500.0)
                newRadius = 500.0;
        }
        else if (StrEqual(parts[0], "reset"))
        {
            newRadius = g_Mortars[mortarIndex].originalRadius;
        }
        
        // Update radius
        g_Mortars[mortarIndex].radius = newRadius;
        
        // Respawn sprite with new size
        RemoveMortarSprite(mortarIndex);
        SpawnMortarSprite(mortarIndex);
        if (g_cvShowButtons.BoolValue)
        {
            SpawnButtonSprite(mortarIndex);
        }
        
        // Show menu again with updated radius
        ShowChangeRadiusMenu(client, mortarIndex);
    }
    
    return 0;
}

//=============================================================================
// Change Location Menu
//=============================================================================

public void ShowChangeLocMenu(int client, int mortarIndex)
{
    Menu menu = new Menu(MenuHandler_ChangeLoc);
    
    char title[256];
    Format(title, sizeof(title), "Change Loc: %s\n%.1f, %.1f, %.1f", 
        g_Mortars[mortarIndex].name,
        g_Mortars[mortarIndex].x,
        g_Mortars[mortarIndex].y,
        g_Mortars[mortarIndex].z);
    menu.SetTitle(title);
    
    char indexStr[16];
    
    // X axis options (Red)
    Format(indexStr, sizeof(indexStr), "xplus_%d", mortarIndex);
    menu.AddItem(indexStr, "X+ (Red)");
    
    Format(indexStr, sizeof(indexStr), "xminus_%d", mortarIndex);
    menu.AddItem(indexStr, "X- (Red)");
    
    // Y axis options (Green)
    Format(indexStr, sizeof(indexStr), "yplus_%d", mortarIndex);
    menu.AddItem(indexStr, "Y+ (Green)");
    
    Format(indexStr, sizeof(indexStr), "yminus_%d", mortarIndex);
    menu.AddItem(indexStr, "Y- (Green)");
    
    // Z axis options (Blue)
    Format(indexStr, sizeof(indexStr), "zplus_%d", mortarIndex);
    menu.AddItem(indexStr, "Z+ (Blue)");
    
    Format(indexStr, sizeof(indexStr), "zminus_%d", mortarIndex);
    menu.AddItem(indexStr, "Z- (Blue)");
    
    // Reset option
    Format(indexStr, sizeof(indexStr), "reset_%d", mortarIndex);
    menu.AddItem(indexStr, "Reset to Original");
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChangeLoc(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
        {
            int client = param1;
            char info[16];
            menu.GetItem(0, info, sizeof(info));
            
            // Extract mortar index from first item
            char parts[2][8];
            ExplodeString(info, "_", parts, 2, 8);
            int mortarIndex = StringToInt(parts[1]);
            
            ShowEditMortarMenu(client, mortarIndex);
        }
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));
        
        // Parse action and index
        char parts[2][8];
        ExplodeString(info, "_", parts, 2, 8);
        int mortarIndex = StringToInt(parts[1]);
        
        // Adjust coordinates based on selection
        if (StrEqual(parts[0], "xplus"))
        {
            g_Mortars[mortarIndex].x += 100.0;
        }
        else if (StrEqual(parts[0], "xminus"))
        {
            g_Mortars[mortarIndex].x -= 100.0;
        }
        else if (StrEqual(parts[0], "yplus"))
        {
            g_Mortars[mortarIndex].y += 100.0;
        }
        else if (StrEqual(parts[0], "yminus"))
        {
            g_Mortars[mortarIndex].y -= 100.0;
        }
        else if (StrEqual(parts[0], "zplus"))
        {
            g_Mortars[mortarIndex].z += 100.0;
        }
        else if (StrEqual(parts[0], "zminus"))
        {
            g_Mortars[mortarIndex].z -= 100.0;
        }
        else if (StrEqual(parts[0], "reset"))
        {
            g_Mortars[mortarIndex].x = g_Mortars[mortarIndex].originalX;
            g_Mortars[mortarIndex].y = g_Mortars[mortarIndex].originalY;
            g_Mortars[mortarIndex].z = g_Mortars[mortarIndex].originalZ;
        }
        
        // Respawn sprite at new location
        RemoveMortarSprite(mortarIndex);
        SpawnMortarSprite(mortarIndex);
        if (g_cvShowButtons.BoolValue)
        {
            SpawnButtonSprite(mortarIndex);
        }
        
        // Show menu again with updated coordinates
        ShowChangeLocMenu(client, mortarIndex);
    }
    
    return 0;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "adminmenu"))
    {
        g_hTopMenu = null;
        g_MortarMenuCategory = INVALID_TOPMENUOBJECT;
    }
}

//=============================================================================
// Admin Commands
//=============================================================================

public Action Command_OpenMenu(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[MortarVis] This command must be used in-game");
        return Plugin_Handled;
    }
    
    if (g_hTopMenu != null)
    {
        g_hTopMenu.DisplayCategory(g_MortarMenuCategory, client);
    }
    else
    {
        ReplyToCommand(client, "[MortarVis] Admin menu not available");
    }
    
    return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
    RemoveAllSprites();
    
    if (LoadMortarConfig())
    {
        SpawnAllMortarSprites();
        ReplyToCommand(client, "[MortarVis] Reloaded %d mortars for map %s", g_MortarCount, g_CurrentMap);
    }
    else
    {
        ReplyToCommand(client, "[MortarVis] Failed to reload config");
    }
    
    return Plugin_Handled;
}

public Action Command_ListMortars(int client, int args)
{
    if (!g_ConfigLoaded)
    {
        ReplyToCommand(client, "[MortarVis] No config loaded for this map");
        return Plugin_Handled;
    }
    
    ReplyToCommand(client, "[MortarVis] === Mortars for %s ===", g_CurrentMap);
    
    for (int i = 0; i < g_MortarCount; i++)
    {
        ReplyToCommand(client, "%d. %s | Loc: (%.1f, %.1f, %.1f) | Radius: %.0f", 
            i + 1,
            g_Mortars[i].name,
            g_Mortars[i].x,
            g_Mortars[i].y,
            g_Mortars[i].z,
            g_Mortars[i].radius
        );
    }
    
    ReplyToCommand(client, "[MortarVis] Total: %d mortars", g_MortarCount);
    
    return Plugin_Handled;
}

public Action Command_FindButtons(int client, int args)
{
    int count = 0;
    int ent = -1;
    
    ReplyToCommand(client, "[MortarVis] === func_button entities on %s ===", g_CurrentMap);
    
    while ((ent = FindEntityByClassname(ent, "func_button")) != -1)
    {
        char targetname[64];
        if (GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname)) > 0)
        {
            float pos[3];
            GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
            
            count++;
            ReplyToCommand(client, "%d. '%s' at (%.1f, %.1f, %.1f)", 
                count, targetname, pos[0], pos[1], pos[2]);
        }
    }
    
    if (count == 0)
    {
        ReplyToCommand(client, "[MortarVis] No named func_button entities found");
    }
    else
    {
        ReplyToCommand(client, "[MortarVis] Found %d named buttons", count);
    }
    
    return Plugin_Handled;
}

//=============================================================================
// Config Management
//=============================================================================

bool LoadMortarConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "../../%s", CONFIG_PATH);
    
    KeyValues kv = new KeyValues("MortarKills");
    
    if (!kv.ImportFromFile(configPath))
    {
        delete kv;
        LogError("[MortarVis] Failed to load config: %s", configPath);
        return false;
    }
    
    if (!kv.JumpToKey(g_CurrentMap, false))
    {
        delete kv;
        PrintToServer("[MortarVis] No mortars defined for map %s", g_CurrentMap);
        return false;
    }
    
    if (!kv.GotoFirstSubKey())
    {
        delete kv;
        PrintToServer("[MortarVis] No mortar entries found for map %s", g_CurrentMap);
        return false;
    }
    
    g_MortarCount = 0;
    
    do
    {
        if (g_MortarCount >= MAX_MORTARS)
        {
            LogError("[MortarVis] Maximum mortar limit (%d) reached for map %s", MAX_MORTARS, g_CurrentMap);
            break;
        }
        
        if (!ParseMortarEntry(kv, g_MortarCount))
            continue;
            
        g_MortarCount++;
        
    } while (kv.GotoNextKey());
    
    delete kv;
    
    g_ConfigLoaded = (g_MortarCount > 0);
    
    if (g_ConfigLoaded)
    {
        PrintToServer("[MortarVis] Loaded %d mortars for map %s", g_MortarCount, g_CurrentMap);
    }
    
    return g_ConfigLoaded;
}

bool ParseMortarEntry(KeyValues kv, int index)
{
    char name[64];
    kv.GetString("MortarName", name, sizeof(name));
    
    // Skip empty entries
    if (StrEqual(name, "EMPTY") || strlen(name) == 0)
        return false;
    
    // Get location string
    char locStr[64];
    kv.GetString("Loc", locStr, sizeof(locStr));
    
    // Parse coordinates
    char parts[3][16];
    if (ExplodeString(locStr, " ", parts, 3, 16) != 3)
    {
        LogError("[MortarVis] Invalid location format for mortar '%s': %s", name, locStr);
        return false;
    }
    
    float x = StringToFloat(parts[0]);
    float y = StringToFloat(parts[1]);
    float z = StringToFloat(parts[2]);
    
    // Validate coordinates
    if (!ValidateCoordinates(x, y, z))
    {
        LogError("[MortarVis] Invalid coordinates for mortar '%s': (%.1f, %.1f, %.1f)", name, x, y, z);
        return false;
    }
    
    // Get radius
    float radius = kv.GetFloat("Radius", 1000.0);
    
    if (!ValidateRadius(radius))
    {
        LogError("[MortarVis] Invalid radius for mortar '%s': %.1f", name, radius);
        return false;
    }
    
    // Store data
    g_Mortars[index].x = x;
    g_Mortars[index].y = y;
    g_Mortars[index].z = z;
    g_Mortars[index].originalX = x;  // Store originals
    g_Mortars[index].originalY = y;
    g_Mortars[index].originalZ = z;
    g_Mortars[index].radius = radius;
    g_Mortars[index].originalRadius = radius;  // Store original
    strcopy(g_Mortars[index].name, sizeof(MortarData::name), name);
    g_Mortars[index].spriteEntity = -1;
    g_Mortars[index].buttonSpriteEntity = -1;
    
    return true;
}

//=============================================================================
// Sprite Management
//=============================================================================

void SpawnAllMortarSprites()
{
    if (!g_cvEnabled.BoolValue)
    {
        PrintToServer("[MortarVis] Visualization disabled by ConVar");
        return;
    }
    
    // Don't spawn sprites on map start - they'll be spawned when selected in menu
    PrintToServer("[MortarVis] Loaded %d mortars for map %s (sprites hidden until selected)", g_MortarCount, g_CurrentMap);
}

void SpawnMortarSprite(int index)
{
    if (index < 0 || index >= g_MortarCount)
        return;
    
    float pos[3];
    pos[0] = g_Mortars[index].x;
    pos[1] = g_Mortars[index].y;
    pos[2] = g_Mortars[index].z;
    
    // Scale represents the blast radius
    float scale = g_Mortars[index].radius / 100.0;
    
    // Get sprite path
    int spriteIndex = index % MAX_SPRITES;
    char spritePath[64];
    strcopy(spritePath, sizeof(spritePath), g_Sprites[spriteIndex]);
    
    // Create sprite
    int entity = CreateSprite(pos, spritePath, scale);
    g_Mortars[index].spriteEntity = entity;
    
    if (entity == -1)
    {
        LogError("[MortarVis] Failed to create sprite for mortar '%s'", g_Mortars[index].name);
    }
}

void SpawnButtonSprite(int index)
{
    if (index < 0 || index >= g_MortarCount)
        return;
    
    int buttonEnt = FindButtonByName(g_Mortars[index].name);
    
    if (buttonEnt == -1)
    {
        LogError("[MortarVis] func_button '%s' not found on map", g_Mortars[index].name);
        return;
    }
    
    float pos[3];
    GetEntPropVector(buttonEnt, Prop_Send, "m_vecOrigin", pos);
    
    // Get sprite path (same as mortar sprite)
    int spriteIndex = index % MAX_SPRITES;
    char spritePath[64];
    strcopy(spritePath, sizeof(spritePath), g_Sprites[spriteIndex]);
    
    // Create sprite at button location
    int entity = CreateSprite(pos, spritePath, 1.0);
    g_Mortars[index].buttonSpriteEntity = entity;
    
    if (entity == -1)
    {
        LogError("[MortarVis] Failed to create button sprite for mortar '%s'", g_Mortars[index].name);
    }
}

int CreateSprite(float pos[3], const char[] spritePath, float scale)
{
    int entity = CreateEntityByName("env_sprite");
    
    if (entity == -1)
        return -1;
    
    DispatchKeyValue(entity, "model", spritePath);
    DispatchKeyValue(entity, "rendermode", "5");
    DispatchKeyValueFloat(entity, "scale", scale);
    
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
    DispatchSpawn(entity);
    ActivateEntity(entity);
    
    return entity;
}

void RemoveAllSprites()
{
    for (int i = 0; i < g_MortarCount; i++)
    {
        RemoveMortarSprite(i);
    }
}

void RemoveMortarSprite(int index)
{
    if (index < 0 || index >= MAX_MORTARS)
        return;
    
    // Remove mortar location sprite
    if (g_Mortars[index].spriteEntity != -1 && IsValidEntity(g_Mortars[index].spriteEntity))
    {
        AcceptEntityInput(g_Mortars[index].spriteEntity, "Kill");
        g_Mortars[index].spriteEntity = -1;
    }
    
    // Remove button sprite
    if (g_Mortars[index].buttonSpriteEntity != -1 && IsValidEntity(g_Mortars[index].buttonSpriteEntity))
    {
        AcceptEntityInput(g_Mortars[index].buttonSpriteEntity, "Kill");
        g_Mortars[index].buttonSpriteEntity = -1;
    }
}

//=============================================================================
// Axis Guide System (using Temp Entity Beams)
//=============================================================================

public Action Timer_DrawAxisGuides(Handle timer)
{
    // Only draw if someone is editing
    if (g_EditingMortarIndex < 0 || g_EditingMortarIndex >= g_MortarCount)
        return Plugin_Continue;
    
    DrawMortarAxes(g_EditingMortarIndex);
    
    return Plugin_Continue;
}

void DrawMortarAxes(int mortarIndex)
{
    float origin[3];
    origin[0] = g_Mortars[mortarIndex].x;
    origin[1] = g_Mortars[mortarIndex].y;
    origin[2] = g_Mortars[mortarIndex].z;
    
    float length = 500.0;  // Fixed length for visibility
    
    // Draw X axis (Red) - line through center
    DrawAxisBeam(origin, length, 0, true);   // Positive direction
    DrawAxisBeam(origin, length, 0, false);  // Negative direction
    
    // Draw Y axis (Green) - line through center
    DrawAxisBeam(origin, length, 1, true);
    DrawAxisBeam(origin, length, 1, false);
    
    // Draw Z axis (Blue) - line through center
    DrawAxisBeam(origin, length, 2, true);
    DrawAxisBeam(origin, length, 2, false);
}

void DrawAxisBeam(const float origin[3], float length, int axis, bool positive)
{
    float end[3];
    
    // Copy origin to end
    end[0] = origin[0];
    end[1] = origin[1];
    end[2] = origin[2];
    
    // Extend along the specified axis in positive or negative direction
    if (positive)
        end[axis] += length;
    else
        end[axis] -= length;
    
    int color[4] = {0, 0, 0, 255};
    
    if (axis == 0)
        color[0] = 255;      // X = Red
    else if (axis == 1)
        color[1] = 255;      // Y = Green
    else if (axis == 2)
        color[2] = 255;      // Z = Blue
    
    TE_SetupBeamPoints(
        origin,
        end,
        g_BeamSprite,
        g_HaloSprite,
        0,                  // startframe
        0,                  // framerate
        0.2,                // life (slightly longer than timer interval)
        8.0,                // width
        8.0,                // endwidth
        0,                  // fade length
        0.0,                // amplitude
        color,              // color (r,g,b,a)
        0                   // flags
    );
    
    TE_SendToAll();
}

//=============================================================================
// Utility Functions
//=============================================================================

int FindButtonByName(const char[] targetname)
{
    int ent = -1;
    
    while ((ent = FindEntityByClassname(ent, "func_button")) != -1)
    {
        char name[64];
        if (GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name)) > 0)
        {
            if (StrEqual(name, targetname))
                return ent;
        }
    }
    
    return -1;
}

bool ValidateCoordinates(float x, float y, float z)
{
    // Check for invalid zero coordinates (only during config load)
    if (x == 0.0 && y == 0.0 && z == 0.0)
        return false;
    
    // Allow any values during editing
    return true;
}

bool ValidateRadius(float radius)
{
    // Reasonable radius range
    return (radius >= 500.0 && radius <= 5000.0);
}