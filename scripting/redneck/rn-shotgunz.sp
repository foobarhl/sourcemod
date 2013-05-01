/*
 * rn-shotgunz.sp: Redneck's Customizable weapons and auto switcher 
 * Thrown together by [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

/*
 * PLAY AT THE REDNECK SERVERS!  http://steamcommunity.com/groups/redneckgraveyard 
 * The Redneck Servers are a place to come 'n play, shoot sum people 'n have sum family friendly fun! 
 */


#include <sourcemod>
#include <smlib>
#include <sdktools_sound.inc>
#include <sdkhooks>

#define VERSION "0.93"

public Plugin:myinfo = {
	name = "RN-ShotGunz",
	author = "[foo] bar",
	description = "Redneck's Custom Weapon Settings",
	version = VERSION,
	url = "https://github.com/foobarhl/sourcemod/wiki/rn-shotgunz"
};

#define USE_WEAPON_FAKECOMMAND 0

#define MAPMANAGER_ACTION_DISABLE	0
#define MAPMANAGER_ACTION_REMOVE	1

new String:configfile[PLATFORM_MAX_PATH]="";
new Handle:configfilefh = INVALID_HANDLE;
new Handle:cv_disablering = INVALID_HANDLE;
new Handle:autochangewep = INVALID_HANDLE;
new Handle:usetimer = INVALID_HANDLE;
new Handle:mapmanageraction = INVALID_HANDLE;
new bool:maphasmanager = false;
new Handle:shotgunz_enabled = INVALID_HANDLE;

public OnPluginStart()
{
	CreateConVar("rn_shotgunz_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);	
	CreateConVar("rn_noearbleed","1","Disables explosion ringing");

	shotgunz_enabled = CreateConVar("shotgunz_enabled","1","Enable/disable shotgunz plugin");		// set to 1 to enable this plugin. do not rename this cvar.
	mapmanageraction = CreateConVar("shotgunz_wepmanageraction","1","Action to take if a map has a weapon manager or player_equip.  0 = Disable shotgunz on map, 1 = remove entity from map");

	// debugging cvars
	autochangewep = CreateConVar("shotgunz_autochangeweapon","1","DEBUGGING ONLY: Enables/disabled default weapon");
	usetimer = CreateConVar("shotgunz_usetimer","0","DEBUGGING ONLY: Specifies whether to use a timer or to give player weapons in spawn event");

	AutoExecConfig(true,"rn-shotgunz");	// cvar configs

	LoadConfig();			// load the weapon configs

	HookEvent("player_spawn",Event_PlayerSpawn);

	RegAdminCmd("shotgunz_status", ReportStatus, ADMFLAG_GENERIC, "status");

	LogToGame("rn_shotgunz %s loaded", VERSION);
}

public OnMapStart()
{
	maphasmanager = false;
	new idx;
#if 0
	idx = FindEntityByClassname(-1,"game_weapon_manager");
	if(idx == -1 ){
		PrintToServer("rn-shotgunz: running on this map");
	} else {
		if(GetConVarInt(mapmanageraction) == MAPMANAGER_ACTION_DISABLE){
			LogToGame("rn-shotgunz: MAP has a game_weapon_manager; disabling for this map.");
			maphasmanager = true;
		} else if(GetConVarInt(mapmanageraction) == MAPMANAGER_ACTION_REMOVE){
			LogToGame("rn-shotgunz: MAP has a game_weapon_manager; removing from map");
			AcceptEntityInput(idx, "Kill");
		} else {
			LogToGame("rn-shotgunz: MAP has a game_weapon_manager; unsupported action %d configured!", GetConVarInt(mapmanageraction));
		}

	}
#endif

	idx = FindEntityByClassname(-1,"game_player_equip");
	if(idx == -1 ){
		PrintToServer("rn-shotgunz: running on this map");
	} else {
		if(GetConVarInt(mapmanageraction) == MAPMANAGER_ACTION_DISABLE){
			LogToGame("rn-shotgunz: MAP has a game_player_equip; disabling for this map");
			maphasmanager = true;
		} else if(GetConVarInt(mapmanageraction) == MAPMANAGER_ACTION_REMOVE){
			LogToGame("rn-shotgunz: MAP has a game_player_equip; removing from map");
			AcceptEntityInput(idx, "Kill");

		} else {
			LogToGame("rn-shotgunz: MAP has a game_player_equip; unsupported action %d configured!", GetConVarInt(mapmanageraction));
		}
	}
}


public OnClientPutInServer(client)	// from superlogs-hl2mp.sp
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
//	PrintToServer("rn-shotgunz: OnClientPutInServer(%d)",client);
}

public OnAllPluginsLoaded()	// from superlogs-hl2mp.sp
{
	if (GetExtensionFileStatus("sdkhooks.ext") != 1)
	{
		SetFailState("SDK Hooks v1.3 or higher is required for rn-shotgunz");
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{	

	cv_disablering = GetConVarInt(FindConVar("rn_noearbleed"));

	// disable ringing - https://forums.alliedmods.net/showthread.php?p=1929755#post1929755
	if(damagetype & DMG_BLAST && cv_disablering)
	{	
		damagetype = DMG_GENERIC;
	}	
	return(Plugin_Changed);

}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
//	PrintToServer("rn-shotgunz: player spawn");

	if(maphasmanager==true){
		return(Plugin_Continue);
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(GetConVarBool(usetimer)==false){
		GivePlayerWeapons(client);
	} else {
		CreateTimer(5.0,GivePlayerWeaponsTimer,client);
	}

	return(Plugin_Continue);
}

public Action:GivePlayerWeaponsTimer(Handle:timer, any:client)
{
	GivePlayerWeapons(client);
}

public GivePlayerWeapons(client)
{

	new wepent;

	if(GetConVarInt(shotgunz_enabled) != 1 ){
		PrintToServer("rn-shotgunz disabled");
		return(Plugin_Handled);	
	}
	
	if(configfilefh == INVALID_HANDLE){
		PrintToServer("rn-shotgunz: can't use configfile");
		return(Plugin_Handled);
	}


	KvRewind(configfilefh);
	KvGotoFirstSubKey(configfilefh);

	new String:buffer[255];
	new String:weapon[20];
	decl String:defaultweapon[20] = "";
	new removeweapon=0;
	new defaultw=false;


/* The GTX seems to override Client_GiveWeaponAndAmmo params, so this is commented out for now. */
/*
	new primaryclip;
	new secondaryclip;
	new primaryammo;
	new secondaryammo;


*/
	do{

		KvGetSectionName(configfilefh,weapon,sizeof(weapon));

/* The GTX seems to override Client_GiveWeaponAndAmmo params, so this is commented out for now. */
/*
		primaryammo=KvGetNum(configfilefh,"primary_ammo",8);
		primaryclip=KvGetNum(configfilefh,"primary_clip",8);
		secondaryammo=KvGetNum(configfilefh,"secondary_ammo",8);
		secondaryclip=KvGetNum(configfilefh,"secondary_clip",8);
*/
		KvGetString(configfilefh,"default",buffer,sizeof(buffer),"");

		if(strcmp(buffer,"",false)!=0){
			strcopy(defaultweapon,sizeof(defaultweapon),weapon);
			defaultw=true;
		}

		

		
		removeweapon = KvGetNum(configfilefh,"remove",0);

		if(removeweapon == 0 ){
//			PrintToServer("Giving client '%d' '%s' default=%d", client,weapon,defaultw);
			wepent = Client_GiveWeapon(client,weapon,false);

			if(wepent==INVALID_ENT_REFERENCE){
				PrintToServer("Failed to give client %d weapon %s",client,weapon);
			} else {
				decl underwater;
				underwater=KvGetNum(configfilefh,"p_underwater",0);
				if(underwater==1){
//					PrintToServer("Make %s primary fire underwater",weapon);
					SetEntProp(wepent,Prop_Data,"m_bFiresUnderwater",1);
				}

				underwater=KvGetNum(configfilefh,"a_underwater",0);
				if(underwater==1){
//					PrintToServer("Make %s alt fire underwater",weapon);
					SetEntProp(wepent,Prop_Data,"m_bAltFiresUnderwater",1);
				}
			}
		} else {
			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackString(pack, weapon);
			CreateTimer(0.1,RemoveWeapon,pack);
		}

	} while(KvGotoNextKey(configfilefh));

	if(GetConVarBool(autochangewep)==true && strcmp(defaultweapon,"",false) != 0){
//		PrintToServer("rn-shotgunz: use %s", defaultweapon);
		FakeClientCommandEx(client,"use %s", defaultweapon);
	} else {
//		PrintToServer("rn-shotgunz: default weapon change disabled");
	}
	return(Plugin_Continue);
}

public Action:RemoveWeapon(Handle:Timer, any: param)
{
	ResetPack(param);
	new String:weapon[30];
	new client = ReadPackCell(param);

	ReadPackString(param, weapon, sizeof(weapon));
	PrintToServer("Removing %s from %d", weapon, client);
	Client_RemoveWeapon(client, weapon);
}

public LoadConfig()
{
	BuildPath(Path_SM,configfile,sizeof(configfile),"configs/rn-shotgunz.cfg");

	if(!FileExists(configfile)){
		SetFailState("Unable to load %s",configfile);
		return(-1);
	}

	if(configfilefh != INVALID_HANDLE){
		CloseHandle(configfilefh);
	}

	configfilefh = CreateKeyValues("configfile");

	FileToKeyValues(configfilefh,configfile);
	KvRewind(configfilefh);

	return(0);
}



public Action:ReportStatus(client, args)
{
	PrintToConsole(client, "rn-shotgunz version %s running", VERSION);
	PrintToConsole(client, " maphasmanager: %d, mapmanageraction: %d", maphasmanager, GetConVarInt(mapmanageraction));
}

