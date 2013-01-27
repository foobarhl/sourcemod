/*
 * rn-spectate: Redneck's spectate/join commands in chat
 * Copyright (c) 2012, 2013  [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
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

#define VERSION "0.2"

public Plugin:myinfo = {
	name = "RN-Spectate",
	author = "[foo] bar",
	description = "Chat spectate/jointeam commands",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};

public OnPluginStart()
{
	CreateConVar("rn_spectate_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);
	AddCommandListener(PlayerSay,"say");
	AddCommandListener(PlayerSay,"say_team");
}

public Action:PlayerSay(client, const String:cmd[], argc)
{
	
	decl String:chattxt[192];
	if(GetCmdArgString(chattxt,sizeof(chattxt))<1){
		return(Plugin_Continue);
	}

	new startidx = 0;
	if(chattxt[strlen(chattxt)-1] == '"'){
		chattxt[strlen(chattxt)-1]='\0';
		startidx=1;
	}
	if(strcmp(cmd,"say2",false)==0){
		startidx+=4;
	}
	PrintToServer("Chat was %s",chattxt[startidx]);	

	if(strcmp(chattxt[startidx],"join",false)==0){
		if(GetTeamClientCount(2) > GetTeamClientCount(3)){
			FakeClientCommandEx(client,"jointeam 3");
		} else {
			FakeClientCommandEx(client,"jointeam 2");
		}
	} else if(strcmp(chattxt[startidx],"joinrebel",false)==0){
		FakeClientCommandEx(client,"jointeam 3");
	} else if(strcmp(chattxt[startidx],"joincombine",false)==0){
		FakeClientCommandEx(client,"jointeam 2");
	} else if(strcmp(chattxt[startidx],"spectate",false)==0){
		ChangeClientTeam(client,1);
		Client_PrintToChat(client,false,"{G}Type 'join' or 'joinrebel' or 'joincombine' to come back");

	}
	return(Plugin_Continue);
}
