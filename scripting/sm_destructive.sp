/*
 * sm_destructive.sp: Displays the most destructive player
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



// TODO:  -Configuration flag to indicate whether to display winner as top killer, or top damager
//          -Configurable message with colour support

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.2"

new Float:damages[MAXPLAYERS+1];
new playernames[MAXPLAYERS+1][100];

public Plugin:myinfo = {
	name = "sm_destructive",
	author = "[foo] bar",
	description = "Displays the most destructive player",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};

public OnPluginStart()
{
	CreateConVar("sm_destructive_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);	

	CreateConVar("sm_destructive_mode","0","The mode to determine destructiveness.  0 = most damage inflicted, 1 = most kills");
	CreateConVar("sm_destructive_message","Woo!  %player% inflicted the most damage this round with %damage% hit damage!","The message to display");
	
	HookEvent("round_end",Event_RoundEnd);
//	HookEvent("player_connect",Event_PlayerConnect);
	HookEvent("player_disconnect",Event_PlayerDisconnect);
	RegConsoleCmd("sm_destructive_stat",PrintStat);

	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamage);
		}
	}
}

public OnClientPutInServer(cli)
{
	damages[cli]=0.00;
	SDKHook(cli, SDKHook_OnTakeDamagePost, OnTakeDamage);
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new cli = GetClientOfUserId(GetEventInt(event, "userid"));
	damages[cli]=0.00;
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	damages[attacker]+=damage;
	PrintToServer("Set %d/%d dmg to %f",attacker,GetClientOfUserId(attacker),damage);

}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Float:highestdmg, highestp;
	new mode = GetConVarInt(FindConVar("sm_destructive_mode"));
	if(mode==0){		// most damage inflicted
		for(new i=1; i<MaxClients;i++){
			if(damages[i]>0){
				PrintToServer("damages[%d] is %f",i,damages[i]);
			}
			if(damages[i]>highestdmg){
		
				PrintToServer("So far %d is the highest damager",i);
				highestdmg = damages[i];
				highestp = i;
			}
		}
	} else if(mode==1){ // most kills
		for(new i=1; i<MaxClients; i++){
			if(IsClientInGame(i)){
				if(GetClientFrags(i)>highestdmg){
					highestdmg = GetClientFrags(i);
					highestp = i;
				}
			}
		}
		PrintToServer("%d has the most kills with %d of them", highestp, highestdmg);
	}

	if(highestp>0){
		decl String:buffer[50];
		decl String:bufferstr[200];


		GetConVarString(FindConVar("sm_destructive_message"),bufferstr,sizeof(bufferstr));

		GetClientName(highestp,buffer,sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%player%",buffer,false);

		IntToString(GetClientFrags(highestp),buffer,sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%kills%",buffer,false);

		IntToString(RoundFloat(damages[highestp]),buffer,sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%damage%",buffer,false);

		PrintCenterTextAll(bufferstr);//"The most destructive player is\n\x03%s with\n%d kills and %d damage", buffer, GetClientFrags(highestp),RoundFloat(damages[highestp]));
		PrintToServer(buffer);//
	} else {
		PrintToServer("Couldn't figure out who the most destructive player was");
	}
}

public Action:PrintStat(client,args)
{
	Event_RoundEnd(any:0,any:"",any:0);
}
