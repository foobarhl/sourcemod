/*
 * rn-countdown: Redneck's Kill Countdown
 * Copyright (c) 2012 [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
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

#define VERSION "0.4"

public Plugin:myinfo = {
	name = "RN-Countdown",
	author = "[foo] bar",
	description = "Kill countdown",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};

new String:configfile[PLATFORM_MAX_PATH]="";
new Handle:configfilefh = INVALID_HANDLE;
new fraglimit = 0;
new Bool:notifications[100];	// assumes an upper framg limit of 100.  Should make this dynamic.

public OnPluginStart()
{
	CreateConVar("rn_countdown_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);
	HookEvent("player_death",Event_PlayerDeath);	
}

public OnMapStart()
{

	new i=0;


	LoadConfig();
	PrecacheSounds();	

	for(i=0;i<sizeof(notifications);i++){
		notifications[i]=false;
	}


//	return(Plugin_Handled);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:doneBroadcast)
{
	//GetClientFrags
	if(fraglimit==0){
		new mp_fraglimit = FindConVar("mp_fraglimit");
		if(mp_fraglimit==INVALID_HANDLE){
			SetFailState("mp_fraglimit is not set; rn-countdown is unloading");
		}
		fraglimit = GetConVarInt(mp_fraglimit);
	}

	if(fraglimit==0)
		return(Plugin_Handled);

	if(fraglimit <= 0){
		SetFailState("mp_fraglimit is %d; rn-countdown is unloading",fraglimit);
	}

	if(GetEventInt(event, "userid") == GetEventInt(event, "attacker")){	// suicide is painless
		return(Plugin_Handled);
	}

	new attackerfrag	= GetClientFrags(GetClientOfUserId(GetEventInt(event, "attacker")));
	decl String:attackerName[100];
	new remaining = (fraglimit - attackerfrag -1 );	

	GetClientName(GetClientOfUserId(GetEventInt(event,"attacker")),attackerName,sizeof(attackerName));

	if(notifications[remaining] == true ){
		return(Plugin_Handled);
	}

	new String:remainingStr[4];

	IntToString(remaining,remainingStr,sizeof(remainingStr));
	KvRewind(configfilefh);
		
	if(!KvJumpToKey(configfilefh,remainingStr)){
		return(Plugin_Handled);
	}

	new String:soundfile[100];
	new String:message[100];

	KvGetString(configfilefh,"message",message,sizeof(message));
	KvGetString(configfilefh,"sound",soundfile,sizeof(soundfile));


	EmitSoundToAll(soundfile);
	PrintCenterTextAll(message);

	notifications[remaining]=true;

	return(Plugin_Handled);

}

public LoadConfig()
{
	BuildPath(Path_SM,configfile,sizeof(configfile),"configs/rn-countdown.cfg");

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

	return(Plugin_Handled);

}

public PrecacheSounds()
{
	
	KvRewind(configfilefh);
	KvGotoFirstSubKey(configfilefh);

	decl String:buffer[255];
	decl String:buffer2[255];

	do{
		KvGetString(configfilefh,"sound",buffer,sizeof(buffer));
		Format(buffer2,sizeof(buffer2),"sound/%s",buffer);

		PrintToServer("rn-countdown: AddFileToDownloadsTable %s",buffer2);
		AddFileToDownloadsTable(buffer2);

		PrintToServer("rn-countdown: PrecacheSound(%s,true)",buffer);
		if(PrecacheSound(buffer,true)==false){
		} else {
		}
	} while(KvGotoNextKey(configfilefh));
}