/*
 * sm_hlstatsrcon.sp: A Simple plugin to allow a remote HLStats server limited rcon access
 * Copyright (c) 2013 [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
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

#include <sourcemod>
#include <smrcon>

#define NAME "sm_hlstatsrcon"

#define VERSION "0.03"

public Plugin:myinfo = {
	name = "Limited RCON Control for HLStats",
	author = "[foo] bar",
	description = "Limited RCON Control for HLStats",
	version = VERSION,
	url = "http://github.com/foobarhl"
};


new Handle:cv_hlstats_ipaddress = INVALID_HANDLE;
new Handle:cv_hlstats_rconpw = INVALID_HANDLE;
new Handle:cv_debug = INVALID_HANDLE;
new String:hlstats_ipaddress[16];
new String:hlstats_rconpw[50];

new const String:allowedCommands[][] = { 
	"stats", "status", "hlx_sm_psay", "hlx_sm_csay", "hlx_sm_hint", "sm_chat"
};

public OnPluginStart()
{
	CreateConVar("sm_hlstatsrcon_version",  VERSION, "version", FCVAR_PLUGIN|FCVAR_NOTIFY);
	cv_hlstats_ipaddress = CreateConVar("sm_hlstatsrcon_ipaddress","","IP Address of the HLStats collector");
	cv_hlstats_rconpw = CreateConVar("sm_hlstatsrcon_password","","Custom password for this host to use for RCon.  Do NOT use your main rcon password!");
	cv_debug = CreateConVar("sm_hlstatsrcon_debug","0","Display extra logging information about limited RCON usage");
	AutoExecConfig();
	HookConVarChange(cv_hlstats_ipaddress, OnHlstatsIpAddressChange);
	HookConVarChange(cv_hlstats_rconpw, OnHlstatsPasswordChange);

	decho("RN Control %s loaded", VERSION);
	
}

public OnConfigsExecuted()
{
	GetConVarString(cv_hlstats_ipaddress, hlstats_ipaddress, sizeof(hlstats_ipaddress));
	GetConVarString(cv_hlstats_rconpw, hlstats_rconpw, sizeof(hlstats_rconpw)); 

}

public OnHlstatsIpAddressChange(Handle:cvar, const String:oldval[], const String:newval[])
{
	strcopy(hlstats_ipaddress, sizeof(hlstats_ipaddress), newval);
	decho("HLStats limited RCON IP change to %s", hlstats_ipaddress);
}

public OnHlstatsPasswordChange(Handle:cvar, const String:oldval[], const String:newval[])
{
	strcopy(hlstats_rconpw, sizeof(hlstats_rconpw), newval);
	decho("HLstats limited rcon password change to %s", hlstats_rconpw);
}


public Action:SMRCon_OnAuth(rconId, const String:address[], const String:password[], &bool:allow)
{
	if(hlstats_rconpw[0] != '\0' && !strcmp(address, hlstats_ipaddress) && !strcmp(password, hlstats_rconpw)){
		decho("Allowing RCon from %s/%s", address, password);
		allow=true;
		return Plugin_Changed;
	}	
	decho("Fall through rcon");
	return Plugin_Continue;
}

public Action:SMRCon_OnCommand(rconId, const String:address[], const String:command[], &bool:allow)
{
	if(!strcmp(address, hlstats_ipaddress)) {
		decho("Got command '%s' from %s", address, command);
		for(new i = 0; i < sizeof(allowedCommands); i++){
//			PrintToServer("allowedCommands[%s] == %s = ?", allowedCommands[i], command);
			if(StrEqual(command, allowedCommands[i])==true){
				allow=true;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}



stock decho(const String:myString[], any:...)
{
	if(GetConVarBool(cv_debug)==false)
		return;

	decl String:myFormattedString[1024];
	VFormat(myFormattedString, sizeof(myFormattedString), myString, 2)
 
	PrintToServer("%s: %s", NAME, myFormattedString);
	
}

