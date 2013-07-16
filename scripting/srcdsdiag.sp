#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#define VERSION "0.4"

new logFile[1024];
new g_iCurEntities;
new inDump=0;

new hOnEntityCreateShow;
new hTooManyEntitiesAction;
new hTooManyEntitiesThreshold;
new hEntityDumpMinPeriod;
new hEntityKillThem;


new clientDisplays[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name="Foo's Diagnostics",
	author = "[foo] bar",
	description="Miscellaneous diagnostics and watches",
	version=VERSION,
}

public OnPluginStart()
{
	CreateConVar("srcdsdiag_version",VERSION,"Version of this mod",FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);
	CreateConVar("srcdsdiag_onentitycreate_show","0","Whether to show onEntityCreates on the console");
	CreateConVar("srcdsdiag_toomanyentities_action","0","What to do if too many entities are active.  0 == do nothing, 1 == reset map, 2 == kill volatile entities, 3 == kick all players");
	CreateConVar("srcdsdiag_toomanyentities_threshold","10","Threshold for taking action if less than this number of entity slots are available");
	CreateConVar("srcdsdiag_dumpminperiod","120","Minimum number of seconds between dump if entity threshold exceeded. ");

	CreateConVar("srcdsdiag_toomanyentities_killents","env_sprite,env_steam,env_sprite_oriented", "Entity class names to kill off if the threshold is exceeded");


	hOnEntityCreateShow = FindConVar("srcdsdiag_onentitycreate_show");
	hTooManyEntitiesAction = FindConVar("srcdsdiag_toomanyentities_action");
	hTooManyEntitiesThreshold = FindConVar("srcdsdiag_toomanyentities_threshold");
	hEntityDumpMinPeriod = FindConVar("srcdsdiag_dumpminperiod");
	hEntityKillThem = FindConVar("srcdsdiag_toomanyentities_killents");


	BuildPath(Path_SM,logFile,sizeof(logFile),"logs/srcdsdiag.log");	
	LogToFile(logFile,"Diagnostics %s onPluginStart", VERSION);
	RegAdminCmd("sm_entreport",ReportEntities,ADMFLAG_GENERIC,"Report on entities");
	RegAdminCmd("sm_toomanyentities",MakeToManyEntities,ADMFLAG_GENERIC,"Crash the server");
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
/*
	player_hurt
	player_death
*/
}

public OnMapStart()
{

	LogToFile(logFile,"OnMapStart()");
	LogMapInfo();

	g_iCurEntities = 0;

	for(new i = 1; i <= GetMaxEntities(); i++)
        	if(IsValidEntity(i))
			g_iCurEntities++;

	LogEntityInfo();
//	CreateTimer(15.0,CheckEntityCount,0,TIMER_REPEAT);	
}

public OnMapEnd()
{
	LogToFile(logFile,"OnMapEnd()");
	LogEntityInfo();
	return(Plugin_Continue);
}

public Action:CheckEntityCount(Handle:timer, any:strpack)
{
	decl ent;
	new time;
	time=GetTime();

	new diff = GetMaxEntities() - g_iCurEntities;
	if(diff <= GetConVarInt(hTooManyEntitiesThreshold)){
		
		LogToFile(logFile,"Server is running out of free entities! ");
//		PrintToAdmins("Admins: %s is running out of free edicts; the server will probably crash.  Please note this map and report.","b");
		LogMapInfo();
		LogPlayerInfo();
		LogEntityInfo();
		if( inDump == 0 || (inDump>0 && time - inDump > GetConVarInt(hEntityDumpMinPeriod))){	// Only dump out entities if not dumped in past two minutes
			inDump=GetTime();
			EntityDump();
		}
		
		new action = GetConVarInt(hTooManyEntitiesAction);
		if(action==1){ 	// reset map
			decl currentMap[255];
			PrintToServer("Too many entities Changing map to %s to avoid crash", currentMap);
			LogToFile(logFile,"Too many entities Changing map to %s to avoid crash", currentMap);
			GetCurrentMap(currentMap,sizeof(currentMap));
			ForceChangeLevel(currentMap,"Too many entities, resetting map to avoid crash");
		} else if(action==2){	// kill volatile entities
	
		} else if(action==3){	// kick all players
			
		}
	
		// entities we can probably nuke arbitrarely: env_sprite
	}
}



public LogMapInfo()
{
	decl currentmap[80],nextmap[80],lastmap[80],lastmapreason[80];
	new timeleft,timelimit,lastmapstart;
	new maphistory = GetMapHistorySize();
	GetCurrentMap(currentmap,sizeof(currentmap));
	GetNextMap(nextmap,sizeof(nextmap));

	PrintToServer("maphistory = %d",maphistory);
	if(maphistory>0)
		maphistory--;
//	GetMapHistory(0,lastmap,sizeof(lastmap),lastmapreason,sizeof(lastmapreason),lastmapstart);

	GetMapTimeLeft(timeleft);
	GetMapTimeLimit(timelimit);
	LogToFile(logFile,"Current Map = %s, nextmap = %s, timeleft=%d, timelimit=%d.",currentmap,nextmap,timeleft,timelimit);
	
		
}

public LogPlayerInfo()
{
	decl buffer[255],buffer2[255],buffer3[255];
	decl string[255];
	LogToFile(logFile,"*** CURRENT PLAYERS");
	for(new i=1; i<=MaxClients;i++){
           if (!IsClientConnected(i) || IsClientInKickQueue(i))
                {
                        continue;
                }
		GetClientName(i,buffer,sizeof(buffer));
		GetClientAuthString(i,buffer2,sizeof(buffer2));
		GetClientIP(i,buffer3,sizeof(buffer3),true);
		Format(string,sizeof(string),"%d) %s (%s) %s", i, buffer,buffer2,buffer3);
		LogToFile(logFile,string);	
	}		
	LogToFile(logFile,"*** -- END CURRENT PLAYERS");
}

public GetPlayerCount()
{
	new i2=0;
	for(new i=1; i<MaxClients;i++){
		if(IsClientConnected(i)){
			i2++;
		}
	}
	return(i2);
}

public LogEntityInfo()
{
	decl currentmap[100];
	GetCurrentMap(currentmap,sizeof(currentmap));
	LogToFile(logFile,"GetMaxEntities()=%d, GetEntityCount()=%d, g_iCurEntities=%d, currentmap=%s, players=%d",GetMaxEntities(),GetEntityCount(),g_iCurEntities,currentmap, GetPlayerCount());
}


public EntityDump()
{

	

	decl clsname[255];
	decl netclsname[255];
	LogToFile(logFile,"**** DUMPING ENTITIES");
	for(new i = 1; i <= GetMaxEntities(); i++){
        	if(IsValidEntity(i)) {
			bool:GetEntityClassname(i,clsname,sizeof(clsname));
			GetEntityNetClass(i,netclsname,sizeof(netclsname));
			LogToFile(logFile,"Entity %d className=%s netClass=%s", i,clsname,netclsname);
		}
	}
	LogToFile(logFile,"---- END OF ENTITY DUMP");

}


public Action:MakeToManyEntities(client,args)
{
	decl whom[80];
	GetClientName(client,whom,sizeof(whom));
	PrintToServer("Client %d (%s) called MakeToManyEntities.  Server will crash shortly.",client,whom);

	PrintToChatAll("Admin requested server crash.  Should die shortly.");
	LogToFile(logFile,"MakeToManyEntities called");
	
	for(new i=0;i<GetMaxEntities()+1;i+=5){
		CreateTimer(5.0,_MakeToManyEntities,any:5);
	}		

	return(Plugin_Handled);
}

public Action:ReportEntities(client,args)
{
	if(clientDisplays[client] == INVALID_HANDLE){
		clientDisplays[client] = CreateTimer(1.0,_ReportEntities,client,TIMER_REPEAT);
		PrintToChat(client,"Periodic entity reporting enabled.");
	} else {
		KillTimer(clientDisplays[client]);
		clientDisplays[client]=INVALID_HANDLE;
		PrintToChat(client,"Periodic entity reporting disabled.");
	}

}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(clientDisplays[client]!=INVALID_HANDLE){
		KillTimer(clientDisplays[client]);
	}
//	OnPlayerDisconnect(client);
	return Plugin_Continue;
}

public Action:_ReportEntities(Handle:timer, any:client)
{
	if(IsClientInGame(client)){
		decl currentmap[200];
		GetCurrentMap(currentmap,sizeof(currentmap));
		PrintToChat(client,"GMX()=%d GEC()=%d g_i=%d map=%s",GetMaxEntities(),GetEntityCount(),g_iCurEntities,currentmap);
	}
}

public Action:_MakeToManyEntities(Handle:t,any:m)
{
	PrintToServer("_MakeToManyEntities making %d entities",m);
	for(new i=0;i<m;i++){
		new ent=CreateEntityByName("item_ammo_357");
		DispatchSpawn(ent);
	}
}

public OnEntityDestroyed(entity)
{
    if(entity >= 0)
    {
         g_iCurEntities=g_iCurEntities-1;
    }
}

public OnEntityCreated(entity, const String:classname[])
{
    if(entity >= 0)
    {
        g_iCurEntities=g_iCurEntities+1;
	if(GetConVarBool(hOnEntityCreateShow)){
		PrintToServer("OnEntityCreated(%d,%s) %d total entities", entity,classname,g_iCurEntities);
	}
	CheckEntityCount(0,0);
    }
}


stock bool:IsValidAdmin(client, const String:flags[]) 
{ 
    new ibFlags = ReadFlagString(flags); 
    if ((GetUserFlagBits(client) & ibFlags) == ibFlags) 
    { 
        return true; 
    } 
    if (GetUserFlagBits(client) & ADMFLAG_ROOT) 
    { 
        return true; 
    } 
    return false; 
} 

stock PrintToAdmins(const String:message[], const String:flags[]) 
{ 
    for (new x = 1; x <= MaxClients; x++) 
    { 
        if (IsClientInGame(x) && IsValidAdmin(x,flags))
        { 
            PrintToChat(x, message); 
        } 
    } 
} 