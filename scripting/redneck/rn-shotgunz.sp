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
#define VERSION "0.8a"

public Plugin:myinfo = {
	name = "RN-ShotGunz",
	author = "[foo] bar",
	description = "Redneck's Custom Weapon Settings",
	version = VERSION,
	url = "https://github.com/foobarhl/sourcemod/wiki/rn-shotgunz"
};

new String:configfile[PLATFORM_MAX_PATH]="";
new Handle:configfilefh = INVALID_HANDLE;
new Handle:cv_disablering = INVALID_HANDLE;

public OnPluginStart()
{
	CreateConVar("rn_shotgunz_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);	
	CreateConVar("shotgunz_enabled","1","Enable/disable shotgunz plugin");		// set to 1 to enable this plugin. do not rename this cvar.
	CreateConVar("rn_noearbleed","1","Disables explosion ringing");

	LoadConfig();

	PrintToServer("rn_shotgunz %s loaded", VERSION);
	HookEvent("player_spawn",Event_PlayerSpawn);
}


public OnClientPutInServer(client)	// from superlogs-hl2mp.sp
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	PrintToServer("rn-shotgunz: OnClientPutInServer(%d)",client);
}

public OnAllPluginsLoaded()	// from superlogs-hl2mp.sp
{
	if (GetExtensionFileStatus("sdkhooks.ext") != 1)
	{
		SetFailState("SDK Hooks v1.3 or higher is required for SuperLogs: HL2MP");
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

//public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
                Float:damageForce[3], Float:damagePosition[3], damagecustom)
{	

	cv_disablering = GetConVarInt(FindConVar("rn_noearbleed"));

	// disable ringing - https://forums.alliedmods.net/showthread.php?p=1929755#post1929755
	PrintToServer("rn-shotgunz: ONTakeDamage %d %d damage=%f damagetype=%d %s",victim,attacker,damage,damagetype,weapon);
	if(damagetype & DMG_BLAST && cv_disablering)
	{	
		damagetype = DMG_GENERIC;
	}	
	return(Plugin_Changed);

}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	PrintToServer("rn-shotgunz: Event_PlayerSpawn	");
	new pluginEnabled = GetConVarInt(FindConVar("shotgunz_enabled"));

	if(pluginEnabled != 1 ){
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
		}

		

		
		removeweapon = KvGetNum(configfilefh,"remove",0);
		if(removeweapon == 0 ){
			PrintToServer("Giving client '%s'", weapon);
			new wepent = Client_GiveWeapon(client,weapon,false);
			if(wepent==INVALID_ENT_REFERENCE){
				PrintToServer("Failed to give client %d weapon %s",client,weapon);
			} else {
				decl underwater;
				underwater=KvGetNum(configfilefh,"p_underwater",0);
				if(underwater==1){
					PrintToServer("Make %s primary fire underwater",weapon);
					SetEntProp(wepent,Prop_Data,"m_bFiresUnderwater",1);
				}

				underwater=KvGetNum(configfilefh,"a_underwater",0);
				if(underwater==1){
					PrintToServer("Make %s alt fire underwater",weapon);
					SetEntProp(wepent,Prop_Data,"m_bAltFiresUnderwater",1);
				}
			}
		} else {
			PrintToServer("Scheduling removal %s from %d", weapon, client);
/*
			CreateDataTimer(0.9, RemoveWeapon, param);
			WritePackCell(param, client);
			WritePackString(param, weapon);*/

		}

	} while(KvGotoNextKey(configfilefh));

	if(strcmp(defaultweapon,"",false) != 0){
		FakeClientCommandEx(client,"use %s", defaultweapon);
	}

	return(Plugin_Handled);
}

public Action:RemoveWeapon(Handle:Timer, any: param)
{
	ResetPack(param);
	new String:weapon[30];
	new client = ReadPackCell(param);

	ReadPackString(param, weapon, sizeof(weapon));
//	PrintToServer("Removing %s from %d", weapon, client);
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

