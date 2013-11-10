#include <sourcemod>
#include <sdktools>

#include <smlib>

#define VERSION "0.99"

new Handle:hudSynchronizer = INVALID_HANDLE;
new Handle:cVarMovedMessaged = INVALID_HANDLE;
new Handle:cVarMovedIP = INVALID_HANDLE;

new String:theMessage[255];

public Plugin:myinfo = {
	name = "Moved theMessage",
	description = "Display a message to players that a server has moved",
	author = "[foo] bar",
	version = VERSION,
	url = "http://github.com/foobarhl"
}

public OnPluginStart()
{
	cVarMovedMessaged = CreateConVar("sm_moved_message", "This server has moved!\\n The new IP is:  %ip%\\n\\n Thanks for playing!", "Message template");
	cVarMovedIP = CreateConVar("sm_moved_ip", "209.247.83.61:27015", "The new IP:PORT of the server")

	hudSynchronizer = CreateHudSynchronizer();

	AutoExecConfig(true);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public OnConfigsExecuted()
{
	new String:buffer2[30];
	
	GetConVarString(cVarMovedMessaged, theMessage, sizeof(theMessage));
	GetConVarString(cVarMovedIP, buffer2, sizeof(buffer2));
	ReplaceString(theMessage, sizeof(theMessage), "\\n", "\n");
	ReplaceString(theMessage, sizeof(theMessage), "%ip%", buffer2, false);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsFakeClient(client)) {
		return;
	}


	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 0, 0,  50);
	Client_SetHideHud(client, HIDEHUD_WEAPONSELECTION | HIDEHUD_HEALTH | HIDEHUD_CROSSHAIR);
	Client_ScreenFade(client, 0, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE);//, -1, 0, 0, 0, 0);

	CreateTimer(1.0, ShowNotice, GetEventInt(event, "userid"), TIMER_REPEAT);
}

public Action:ShowNotice(Handle:Timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(client==0){
		return Plugin_Stop;
	}
	if(!IsClientConnected(client)) {
		return Plugin_Stop;
	}

	PrintCenterText(client, theMessage);	//"{6o4} House of {V@G} has moved!\n The new IP is:  209.247.83.61:27015\n  Thanks for playing!");

	return Plugin_Continue;

	new msgColor[4];

/*	msgColor[0] = GetRandomInt(1,254);
	msgColor[1] = GetRandomInt(1,254);
	msgColor[2] = GetRandomInt(1,254);
	msgColor[3] = GetRandomInt(1,254);
*/
	msgColor[0] = 237;
	msgColor[1] = 87;
	msgColor[1] = 64;
	
	SetHudTextParams(-1.0, -1.0, 1.0, msgColor[0], msgColor[1], msgColor[2], msgColor[3]);
	ShowSyncHudText(client, hudSynchronizer, theMessage);
	return Plugin_Continue;
}