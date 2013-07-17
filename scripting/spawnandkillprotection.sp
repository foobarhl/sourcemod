		
// enforce semicolons after each code statement
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <smlib>

#define PLUGIN_VERSION "1.4.6"

#define KILLPROTECTION_DISABLE_BUTTONS (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_USE | IN_LEFT | IN_RIGHT | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2 | IN_RUN |  IN_WALK | IN_GRENADE1 | IN_GRENADE2 )
#define SHOOT_DISABLE_BUTTONS (IN_ATTACK | IN_ATTACK2)


/*****************************************************************


		P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = {
	name = "Spawn & kill protection",
	author = "Berni, Chanz, ph, [foo] bar",
	description = "Spawn protection against spawnkilling and kill protection when you stand close to the wall for a longer time",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=901294"
}



/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/

// ConVar Handles
new Handle:version                          = INVALID_HANDLE;
new Handle:enabled                          = INVALID_HANDLE;
new Handle:walltime                         = INVALID_HANDLE;
new Handle:takedamage                       = INVALID_HANDLE;
new Handle:punishmode                       = INVALID_HANDLE;
new Handle:notify                           = INVALID_HANDLE;
new Handle:disableonmoveshoot               = INVALID_HANDLE;
new Handle:disableweapondamage              = INVALID_HANDLE;
new Handle:disabletime                      = INVALID_HANDLE;
new Handle:disabletime_team1                = INVALID_HANDLE;
new Handle:disabletime_team2                = INVALID_HANDLE;
new Handle:keypressignoretime               = INVALID_HANDLE;
new Handle:keypressignoretime_team1         = INVALID_HANDLE;
new Handle:keypressignoretime_team2         = INVALID_HANDLE;
new Handle:maxspawnprotection               = INVALID_HANDLE;
new Handle:maxspawnprotection_team1         = INVALID_HANDLE;
new Handle:maxspawnprotection_team2         = INVALID_HANDLE;
new Handle:fadescreen                       = INVALID_HANDLE;
new Handle:hidehud                          = INVALID_HANDLE;
new Handle:player_color_r                   = INVALID_HANDLE;
new Handle:player_color_g                   = INVALID_HANDLE;
new Handle:player_color_b                   = INVALID_HANDLE;
new Handle:player_color_a                   = INVALID_HANDLE;
new Handle:noblock                          = INVALID_HANDLE;
new Handle:collisiongroupcvar               = INVALID_HANDLE;

// Misc
new bool:bNoBlock                           = true;
new defaultcollisiongroup                   = 8;
new bool:isKillProtected[MAXPLAYERS+1]      = { false, ... };
new bool:isSpawnKillProtected[MAXPLAYERS+1] = { false, ... };
new bool:isWallKillProtected[MAXPLAYERS+1]  = { false, ... };
new Handle:activeDisableTimer[MAXPLAYERS+1] = { INVALID_HANDLE, ... };
new Float:keyPressOnTime[MAXPLAYERS+1]      = { 0.0, ... };
new timeLookingAtWall[MAXPLAYERS+1]         = { 0, ... };
new Handle:hudSynchronizer                  = INVALID_HANDLE;



/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{	
   CreateNative("SAKP_IsClientProtected", Native_IsClientProtected);
   return APLRes_Success;
}

public OnPluginStart()
{
	if (!LibraryExists("sdkhooks")) {
		SetFailState("[Spawn & Kill Protection] Error: needs sdkhooks 2.* or greater");
	}

	// ConVars with sakp_ prefix
	version                  = Sakp_CreateConVar("version", PLUGIN_VERSION, "Spawn & kill protection plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Set it to the correct version, in case the plugin gets updated...
	SetConVarString(version, PLUGIN_VERSION);

	enabled                  = Sakp_CreateConVar("enabled", "1", "Spawn & Kill Protection enabled");
	HookConVarChange(enabled, ConVarChange_Enabled);
	walltime                 = Sakp_CreateConVar("walltime", "4", "How long a player has to look at a wall to get kill protection activated, set to -1 to disable");
	takedamage               = Sakp_CreateConVar("takedamage", "5", "The amount of health to take from the player when shooting at protected players (when punishmode = 2)");
	punishmode               = Sakp_CreateConVar("punishmode", "0", "0 = off, 1 = slap, 2 = decrease health 3 = slay, 4 = apply damage done to enemy");
	notify                   = Sakp_CreateConVar("notify", "4", "0 = off, 1 = HUD message, 2 = center message, 3 = chat message, 4 = auto");
	HookConVarChange(notify, ConVarChange_Notify);

	noblock                   = Sakp_CreateConVar("noblock", "1", "1 = enable noblock when protected, 0 = disabled feature");
 	bNoBlock                  = GetConVarBool(noblock);
	
	HookConVarChange(noblock, ConVarChange_Noblock);

	collisiongroupcvar       = Sakp_CreateConVar("collisiongroup", "8", "Collision group players are part of.  Change to match group if you are using a noblock.smx (2) or anti stick plugin");
	defaultcollisiongroup    = GetConVarInt(collisiongroupcvar);
        HookConVarChange(collisiongroupcvar, ConVarChange_CollisionGroup);

	disableonmoveshoot       = Sakp_CreateConVar("disableonmoveshoot", "1", "0 = don't disable, 1 = disable the spawnprotection when player moves or shoots, 2 = disable the spawn protection when shooting only");
	disableweapondamage      = Sakp_CreateConVar("disableweapondamage", "0", "0 = spawn protected players can inflict damage, 1 = spawn protected players inflict no damage");
	disabletime              = Sakp_CreateConVar("disabletime", "0", "Time in seconds until the protection is removed after the player moved and/or shooted, 0 = immediately");
	disabletime_team1        = Sakp_CreateConVar("disabletime_team1", "-1", "same as sakp_disabletime, but for team 2 only (overrides sakp_disabletime if not set to -1)");
	disabletime_team2        = Sakp_CreateConVar("disabletime_team2", "-1", "same as sakp_disabletime, but for team 2 only (overrides sakp_disabletime if not set to -1)");
	keypressignoretime       = Sakp_CreateConVar("keypressignoretime", "0.8", "The amount of time in seconds pressing any keys will not turn off spawn protection");
	keypressignoretime_team1 = Sakp_CreateConVar("keypressignoretime_team1", "-1", "same as sakp_keypressignoretime, but for team 1 only (overrides sakp_keypressignoretime if not set to -1)");
	keypressignoretime_team2 = Sakp_CreateConVar("keypressignoretime_team2", "-1", "same as sakp_keypressignoretime, but for team 1 only (overrides sakp_keypressignoretime if not set to -1)");
	maxspawnprotection       = Sakp_CreateConVar("maxspawnprotection", "0", "max timelimit in seconds the spawnprotection stays, 0 = no limit",FCVAR_PLUGIN);
	maxspawnprotection_team1 = Sakp_CreateConVar("maxspawnprotection_team1", "-1", "same as sakp_maxspawnprotection, but for team 1 only (overrides sakp_maxspawnprotection if not set to -1)",FCVAR_PLUGIN);
	maxspawnprotection_team2 = Sakp_CreateConVar("maxspawnprotection_team2", "-1", "same as sakp_maxspawnprotection, but for team 2 only (overrides sakp_maxspawnprotection if not set to -1)",FCVAR_PLUGIN);
	fadescreen               = Sakp_CreateConVar("fadescreen", "1", "Fade screen to black");
	hidehud                  = Sakp_CreateConVar("hidehud", "1", "Set to 1 to hide the HUD when being protected");
	player_color_r           = Sakp_CreateConVar("player_color_red", "255", "amount of red when a player is protected 0-255");
	player_color_g           = Sakp_CreateConVar("player_color_green", "0", "amount of green when a player is protected 0-255");
	player_color_b           = Sakp_CreateConVar("player_color_blue", "0", "amount of blue when a player is protected 0-255");
	player_color_a           = Sakp_CreateConVar("player_alpha", "50", "alpha amount of a protected player 0-255");

	AutoExecConfig(true);
	File_LoadTranslations("spawnandkillprotection.phrases");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);

	// Hooking the existing clients in case of lateload
	LOOP_CLIENTS(client, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		SDKHook(client, SDKHook_OnTakeDamage,  Hook_OnTakeDamage);
		SDKHook(client, SDKHook_ShouldCollide, Hook_ShouldCollide);
	}

	new value = GetConVarInt(notify);

	if (value == 1 || value == 4) {
		CreateTestHudSynchronizer();
	}

	RegAdminCmd("sm_enablekillprotection", Command_EnableKillProtection, ADMFLAG_ROOT);
}

public Action:Command_EnableKillProtection(client, args)
{
	new clientAimTarget = GetClientAimTarget(client, true);

	if (clientAimTarget > 0) {
		ReplyToCommand(client, "Enabling kill protection for player %N", clientAimTarget);
		EnableKillProtection(clientAimTarget);
	}

	return Plugin_Handled;
}

public OnMapStart() 
{	
	CreateTimer(1.0, Timer_CheckWall, INVALID_HANDLE, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
	DisableKillProtectionAll();
}

public OnPluginEnd()
{	
	DisableKillProtectionAll();
}

public OnClientPutInServer(client)
{	
	isKillProtected[client] = false;
	isSpawnKillProtected[client] = false;
	isWallKillProtected[client] = false;
	keyPressOnTime[client] = 0.0;
	timeLookingAtWall[client] = 0;
	activeDisableTimer[client] = INVALID_HANDLE;

	SDKHook(client, SDKHook_OnTakeDamage,  Hook_OnTakeDamage);
	SDKHook(client, SDKHook_ShouldCollide, Hook_ShouldCollide);
}

public OnGameFrame() 
{
	LOOP_CLIENTS(client, CLIENTFILTER_ALIVE | CLIENTFILTER_NOBOTS) {

		if (isKillProtected[client]) {
			
			if (activeDisableTimer[client] != INVALID_HANDLE) {
				continue;
			}

			new clientButtons = Client_GetButtons(client);

			if (!(clientButtons & KILLPROTECTION_DISABLE_BUTTONS)) {
				continue;
			}

			if (GetGameTime() < keyPressOnTime[client]) {
				continue;
			}
			
			if (isSpawnKillProtected[client]) {
				
				if (GetConVarInt(disableonmoveshoot) == 0) {
					continue;
				}
				
				if (GetConVarInt(disableonmoveshoot) == 2 && !(clientButtons & SHOOT_DISABLE_BUTTONS)) {
					continue;
				}
			}

			new Float:disabletime_value = GetDisableTime(client);
			if (disabletime_value > 0.0) {
				activeDisableTimer[client] = CreateTimer(disabletime_value, Timer_DisableSpawnProtection, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			else {
				DisableKillProtection(client);
			}
		}
	}
}



/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/

public ConVarChange_Notify(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (StringToInt(oldValue) == 1) {
		CloseHandle(hudSynchronizer);
		hudSynchronizer = INVALID_HANDLE;
	}
	
	new value = StringToInt(newValue);
	if (value == 1 || value == 4) {
		CreateTestHudSynchronizer();
	}
}

public ConVarChange_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0) {
		DisableKillProtectionAll();
	}
}

public ConVarChange_Noblock(Handle:convar, const String:oldValue[], const String:newValue[])
{
	bNoBlock = bool:StringToInt(newValue);
}


public ConVarChange_CollisionGroup(Handle:convar, const String:oldValue[], const String:newValue[])
{
	defaultcollisiongroup = StringToInt(newValue);
}

public Action:Timer_EnableSpawnProtection(Handle:timer, any:userId)
{
	new client = GetClientOfUserId(userId);	
	if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}
	
	isSpawnKillProtected[client] = true;


	EnableKillProtection(client);
	
	return Plugin_Stop;
}

public Action:Timer_DisableSpawnProtection(Handle:timer, any:userId)
{
	new client = GetClientOfUserId(userId);
	if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Stop;
	}

	activeDisableTimer[client] = INVALID_HANDLE;
	isSpawnKillProtected[client] = false;



	DisableKillProtection(client);
	return Plugin_Stop;
}

public Action:Timer_CheckWall(Handle:timer)
{
	if (!GetConVarBool(enabled) || (GetConVarInt(walltime) == -1)) {
		return Plugin_Continue;
	}

	LOOP_CLIENTS(client, CLIENTFILTER_INGAME | CLIENTFILTER_NOBOTS) {
		
		if (Client_IsLookingAtWall(client) && !(Client_GetButtons(client) & KILLPROTECTION_DISABLE_BUTTONS)) {
			if (!isWallKillProtected[client] && timeLookingAtWall[client] >= GetConVarInt(walltime)) {
				
				if (activeDisableTimer[client] != INVALID_HANDLE) {
					KillTimer(activeDisableTimer[client]);	
					activeDisableTimer[client] = INVALID_HANDLE;
				}
				
				isWallKillProtected[client] = true;
				EnableKillProtection(client);
			}
			
			timeLookingAtWall[client]++;
		}
		else {
			timeLookingAtWall[client] = 0;
			
			if (isKillProtected[client] && activeDisableTimer[client] != INVALID_HANDLE) {
				
				if (isWallKillProtected[client]) {
					isWallKillProtected[client] = false;
					
					new Float:disabletime_value = GetDisableTime(client);
					if (disabletime_value > 0.0) {
						activeDisableTimer[client] = CreateTimer(disabletime_value, Timer_DisableSpawnProtection, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					}
					else {
						DisableKillProtection(client);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:broadcast)
{
	if (!GetConVarBool(enabled)) {
		return;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client)) {
		return;
	}

	isSpawnKillProtected[client] = true;
	CreateTimer(0.1, Timer_EnableSpawnProtection, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	new Float:maxspawnprotection_value = GetMaxSpawnProtectionTime(client);

	if (maxspawnprotection_value > 0.0) {
		CreateTimer(maxspawnprotection_value, Timer_DisableSpawnProtection, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client)) {
		return;
	}

	if (isKillProtected[client]) {
		DisableKillProtection(client);
	}
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
								Float:damageForce[3], Float:damagePosition[3], damagecustom)
{	
	if (isKillProtected[victim]) {

		ProtectedPlayerHurted(victim, inflictor, RoundToFloor(damage));

		damage = 0.0;
		return Plugin_Changed;
	}

	if(attacker < 0 || attacker > MAXPLAYERS ) {
		PrintToServer("spawnandkillprotection: Hook_OnTakeDamage: Attacker is %d weapon=%s", attacker,weapon);
		return(Plugin_Continue);
	}

	if(GetConVarBool(disableweapondamage) == true && isKillProtected[attacker]){
//		ProtectedPlayerHurted(attacker, inflictor, RoundToFloor(damage));
		damage = 0.0;
		return Plugin_Changed;		
	}
	return Plugin_Continue;
}

public bool:Hook_ShouldCollide(entity, collisiongroup, contentsmask, bool:originalResult)
{
	if(collisiongroup != defaultcollisiongroup){		
		return(true);
	}
	if (isKillProtected[entity] && bNoBlock ) {
		return false;
	}
	return true;
}



/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/

Float:GetMaxSpawnProtectionTime(client)
{
	new Float:maxspawnprotection_value = 0.0;

	switch (GetClientTeam(client)) {
		case 0: {
			maxspawnprotection_value = -1.00;
		}
		case 2: {
			maxspawnprotection_value = GetConVarFloat(maxspawnprotection_team1);		
		}
		case 3: {
			maxspawnprotection_value = GetConVarFloat(maxspawnprotection_team2);
		}
	}

	if (maxspawnprotection_value < 0.0) {
		maxspawnprotection_value = GetConVarFloat(maxspawnprotection);
	}

	return maxspawnprotection_value;
}

Float:GetDisableTime(client)
{
	new Float:disabletime_value = 0.0;

	switch (GetClientTeam(client)) {
		case 0: {
			disabletime_value = -1.00;
		}
		case 2: {
			disabletime_value = GetConVarFloat(disabletime_team1);		
		}
		case 3: {
			disabletime_value = GetConVarFloat(disabletime_team2);
		}
	}
	
	if (disabletime_value < 0.0) {
		disabletime_value = GetConVarFloat(disabletime);
	}
	return disabletime_value;
}

Float:GetKeyPressIgnoreTime(client)
{
	new Float:keypressignoretime_value = 0.0;

	switch (GetClientTeam(client)) {
		case 0: {
			keypressignoretime_value = -1.00;
		}
		case 2: {
			keypressignoretime_value = GetConVarFloat(keypressignoretime_team1);		
		}
		case 3: {
			keypressignoretime_value = GetConVarFloat(keypressignoretime_team2);
		}
	}
	
	if (keypressignoretime_value < 0.0) {
		keypressignoretime_value = GetConVarFloat(keypressignoretime);
	}
	
	return keypressignoretime_value;
}

public Native_IsClientProtected(Handle:plugin, numParams)
{
	new bool:isClientProtected = GetNativeCell(1);

	return isKillProtected[isClientProtected];
}

CreateTestHudSynchronizer()
{	
	hudSynchronizer = CreateHudSynchronizer();
	
	if (hudSynchronizer == INVALID_HANDLE) {
		PrintToServer("[Spawn & Kill Protection] %t", "server_warning_notify");
		SetConVarInt(notify, 3);
	}
	else {
		SetConVarInt(notify, 1);
	}
}

stock ProtectedPlayerHurted(client, inflictor, damage)
{	
	if (!Client_IsValid(inflictor, false)) {
		return;
	}

	new punishmode_value = GetConVarInt(punishmode);

	if (punishmode_value) {

		switch (punishmode_value) {

			case 2: { // Decrase Health
				Entity_TakeHealth(inflictor, GetConVarInt(takedamage));
			}
			case 3: { // Slay
				ForcePlayerSuicide(inflictor);
			}
			case 4: { // Damage done to enemy
				Entity_TakeHealth(inflictor, damage);
			}
			case 1: { //case 1: Slap
				SlapPlayer(inflictor, GetConVarInt(takedamage));
			}
		}
	}
}

EnableKillProtection(client)
{	
	if (!IsPlayerAlive(client)) {
		return;
	}

	isKillProtected[client] =  true;
	keyPressOnTime[client] = GetGameTime() + GetKeyPressIgnoreTime(client);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, GetConVarInt(player_color_r), GetConVarInt(player_color_g), GetConVarInt(player_color_b), GetConVarInt(player_color_a));

	if (GetConVarBool(hidehud)) {
		Client_SetHideHud(client, HIDEHUD_WEAPONSELECTION | HIDEHUD_HEALTH | HIDEHUD_CROSSHAIR);
	}
		
	if (GetConVarBool(fadescreen)) {
		Client_ScreenFade(client, 0, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE, -1, 0, 0, 0, 240);
	}

	NotifyClientEnableProtection(client);
}

DisableKillProtection(client)
{	
	if (!isKillProtected[client]) {
		return;
	}

	isKillProtected[client] =  false;
	isSpawnKillProtected[client] = false;
	isWallKillProtected[client] = false;
	timeLookingAtWall[client] = 0;
	keyPressOnTime[client] = 0.0;

	if (IsPlayerAlive(client)) {
		SetEntityRenderColor(client, 255, 255, 255, 255);
		
		if (GetConVarBool(hidehud)) {
			Client_SetHideHud(client, 0);
		}
	}
	
	if (GetConVarBool(fadescreen)) {
		Client_ScreenFade(client, 0, FFADE_IN | FFADE_PURGE, -1, 0, 0, 0, 0);
	}

	NotifyClientDisableProtection(client);
}

DisableKillProtectionAll()
{
	LOOP_CLIENTS(client, CLIENTFILTER_ALIVE) {

		if (!isKillProtected[client]) {
			continue;
		}

		DisableKillProtection(client);
	}
}

NotifyClientEnableProtection(client)
{
	new notify_value = GetConVarInt(notify);

	if (!notify_value) {
		return;
	}
	
	if (isSpawnKillProtected[client]) {

		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Spawnprotection Enabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Spawnprotection Enabled");
			}
			default: { // case 1
				SetHudTextParams(-1.0, -1.0, 99999999.0, 255, 0, 0, 255, 0, 6.0, 0.1, 0.2);
				ShowSyncHudText(client, hudSynchronizer, "%t", "Spawnprotection Enabled");
			}
		}
	}
	else {

		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Killprotection Enabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Killprotection Enabled");
			}
			default: { // case 1
				SetHudTextParams(-1.0, -1.0, 99999999.0, 255, 0, 0, 255, 0, 6.0, 0.1, 0.2);
				ShowSyncHudText(client, hudSynchronizer, "%t", "Killprotection Enabled");
			}
		}
	}

}

NotifyClientDisableProtection(client)
{	
	new notify_value = GetConVarInt(notify);
	
	if (isSpawnKillProtected[client]) {
		
		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Spawnprotection Disabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Spawnprotection Disabled");
			}
		}
	}
	else {
		
		switch (notify_value) {
			
			case 2: {
				PrintCenterText(client, "%t", "Killprotection Disabled");
			}
			case 3: {
				PrintToChat(client, "\x04[SAKP] \x01%t", "Killprotection Disabled");
			}
		}
	}
	
	if(hudSynchronizer != INVALID_HANDLE) {
		ClearSyncHud(client, hudSynchronizer);
	}
}

Handle:Sakp_CreateConVar(
		const String:name[],
		const String:defaultValue[],
		const String:description[]="",
		flags=0,
		bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0)
{
	decl String:newName[64];
	decl String:newDescription[256];

	Format(newName, sizeof(newName), "sakp_%s", name);
	Format(newDescription, sizeof(newDescription), "Sourcemod Spawn & kill protection plugin:\n%s", description);

	return CreateConVar(newName, defaultValue, newDescription, flags | FCVAR_PLUGIN, hasMin, min, hasMax, max);
}
