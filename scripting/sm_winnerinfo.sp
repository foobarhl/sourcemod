/*
 * sm_winnerinfo.sp: Displays the most winnerinfo player
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
 * Configuration:  Auto creates cfg/sourcemod/sm_winnerinfo.cfg
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#define VERSION "0.12.2"
#define MAX_PLAYER_NAME 50

//#define TRACK_NON_TRACE_WEAPONS	// Uncomment if you want to track non trace weapons.  This is kinda dodgy

static const String:trackWeapons[][] = {
	"weapon_pistol",
	"weapon_357",
	"npc_grenade_frag",
	"weapon_ar2",
	"grenade_ar2",
	"prop_combine_ball",
	"rpg_missile",
	"crossbow_bolt",
	"weapon_smg1",
	"weapon_shotgun",
	"weapon_annabelle",
	"weapon_alyxgun"
};

enum EPlayerStat
{
	st_kills,
	String:playerName[MAX_PLAYER_NAME],
	Float:damageInflicted,
	Float:damageTaken,
	headShots,			// HEad shot count
	st_shots,			// Times shot weapon
	st_damages,			// Times received damage
	Float:st_selfinflicteddmg,	// Self inflicted
	st_sui,				// Suicides
	
	st_killstreak,			// Current kill streak counter
	st_killstreakcount,		// How many killstreaks player has had
	st_killstreakmax,		// Highest kill streaks
	
	st_deathstreak,			// Current death streak
	st_deathstreakcount,
	st_deathstreakmax,		// Maximum death streak
}

enum ENonTrace
{
	en_entity,
	String:en_classname[30]
}


new playerStats[MAXPLAYERS+1][EPlayerStat];

new bool:inScoreboard[MAXPLAYERS+1];

//new Float:damageInflicted[MAXPLAYERS+1];
//new Float:damageTaken[MAXPLAYERS+1];
//new headShots[MAXPLAYERS+1];


new Handle:cvarStatColor;
new Handle:cvarMsgColor;
new Handle:cvarFade;
new Handle:cvarMsgX;
new Handle:cvarMsgY;
new Handle:cvarStatusX;
new Handle:cvarStatusY;
new Handle:cvarSoundFile;

#if defined TRACK_NON_TRACE_WEAPONS
new Handle:nontraceChecks = INVALID_HANDLE;
#endif

new UserMsg:VGuiMenu;
new Handle:hudSynchronizerMsg                  = INVALID_HANDLE;
new Handle:hudSynchronizerStats                  = INVALID_HANDLE;

new msgColor[4];
new statColor[4];
new fadeColor[4];
new Float:msgX = -1.0;
new Float:msgY = -1.0;
new Float:statusX = 0.01;
new Float:statusY = 0.03;

new String:soundFile[PLATFORM_MAX_PATH];

new UserMsg:gameendMsgId = UserMsg:-1;

#define NOTIFYTYPE_USERSCOREBOARD 1
#define NOTIFYTYPE_GAMEEND 2


public Plugin:myinfo = {
	name = "sm_winnerinfo",
	author = "[foo] bar",
	description = "Displays winner information",
	version = VERSION,
	url = "https://www.foo-games.com/"
};

public OnPluginStart()
{

	
	CreateConVar("sm_winnerinfo_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);	
	CreateConVar("sm_winnerinfo_mode", "1", "The mode to determine which player wins.   0 = most damage inflicted, 1 = most kills");
//	CreateConVar("sm_winnerinfo_printmethod", "0", "Where to print the message.  0 = center text, 1 = hint box, 2 = chat");	// no longer used 0.7
	CreateConVar("sm_winnerinfo_message", "Wooo hooo!  %player% Wins!\\n \\nKilled %kills% times, %headshots% of which where headshots\nfor a total frag count of %frags%!", "The message to display.");

	cvarMsgColor = CreateConVar("sm_winnerinfo_message_color", "255 255 255 255", "RGBA Color of winning message printed to players");
	cvarStatColor = CreateConVar("sm_winnerinfo_status_color", "5 230 50 255", "RGBA Color of status display printed to players");
	cvarMsgX = CreateConVar("sm_winnerinfo_message_x", "-1.0", "Message display: X position");
	cvarMsgY = CreateConVar("sm_winnerinfo_message_y", "-1.0", "Message display: Y position");
	cvarStatusX = CreateConVar("sm_winnerinfo_status_x", "0.01", "Status display: X position");
	cvarStatusY = CreateConVar("sm_winnerinfo_status_y", "0.03", "Status display: Y position");

	cvarFade = CreateConVar("sm_winnerinfo_fade", "0 0 0 175", "RGBA Color to fade player screens on game end");
	cvarSoundFile = CreateConVar("sm_winnerinfo_soundfile", "", "Sound file to play on game end");

	PrintToServer("sm_winnerinfo by Foo Bar <www.foo-games.com> started - show your appreciation by throwing us a bone! ;) https://foo-games.com/project-donations/");

#if defined TRACK_NON_TRACE_WEAPONS
	nontraceChecks = CreateStack();
#endif
	AutoExecConfig(true, "sm_winnerinfo");	

	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

}

public OnPluginEnd()
{
	UnhookEvent("player_disconnect", Event_PlayerDisconnect);
	UnhookEvent("player_death", Event_PlayerDeath);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
}

public OnConfigsExecuted()
{
	decl String:buffer2[4][4], String:buffer[30];

	VGuiMenu = GetUserMessageId("VGUIMenu");
	HookUserMessage(VGuiMenu, _VGuiMenu, false, _VGuiMenuPosthook);	

	hudSynchronizerMsg = CreateHudSynchronizer();	
	hudSynchronizerStats = CreateHudSynchronizer();	

	// status display configs
	GetConVarString(cvarStatColor, buffer, sizeof(buffer));
	ExplodeString(buffer, " ", buffer2, sizeof(buffer2), sizeof(buffer2[]));
	statColor[0] = StringToInt(buffer2[0]);
	statColor[1] = StringToInt(buffer2[1]);
	statColor[2] = StringToInt(buffer2[2]);
	statColor[3] = StringToInt(buffer2[3]);

	statusX = GetConVarFloat(cvarStatusX);
	statusY = GetConVarFloat(cvarStatusY);

	// winning message configs

	GetConVarString(cvarMsgColor, buffer, sizeof(buffer));
	ExplodeString(buffer, " ", buffer2, sizeof(buffer2), sizeof(buffer2[]));
	msgColor[0] = StringToInt(buffer2[0]);
	msgColor[1] = StringToInt(buffer2[1]);
	msgColor[2] = StringToInt(buffer2[2]);
	msgColor[3] = StringToInt(buffer2[3]);

	msgX = GetConVarFloat(cvarMsgX);
	msgY = GetConVarFloat(cvarMsgY);

	// 
	GetConVarString(cvarFade, buffer, sizeof(buffer));
	ExplodeString(buffer, " ", buffer2, sizeof(buffer2), sizeof(buffer2[]));
	fadeColor[0] = StringToInt(buffer2[0]);
	fadeColor[1] = StringToInt(buffer2[1]);
	fadeColor[2] = StringToInt(buffer2[2]);
	fadeColor[3] = StringToInt(buffer2[3]);

	GetConVarString(cvarMsgColor, buffer, sizeof(buffer));
	GetConVarString(cvarSoundFile, soundFile, sizeof(soundFile));
	
	if(soundFile[0]!='\0'){
		MyAddSoundToDownloadsTable(soundFile);
	}

	RegConsoleCmd("sm_winnerinfo_stat",PrintStat);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamage);
			SDKHook(i, SDKHook_TraceAttackPost, OnTraceAttack);
			SDKHook(i, SDKHook_FireBulletsPost, OnFireBullets);
		}
	}


}

public OnMapStart()
{
	gameendMsgId = UserMsg:-1;
}

public OnClientPutInServer(cli)
{
//	damageInflicted[cli] = 0.00;
//	damageTaken[cli] = 0.00;
	
	ResetPlayerStats(cli);

	SDKHook(cli, SDKHook_OnTakeDamagePost, OnTakeDamage);
	SDKHook(cli, SDKHook_TraceAttackPost, OnTraceAttack);
	SDKHook(cli, SDKHook_FireBulletsPost, OnFireBullets);
}

ResetPlayerStats(cli)
{
	if(IsClientConnected(cli)){
		GetClientName(cli, playerStats[cli][playerName], MAX_PLAYER_NAME);
	} else {
		playerStats[cli][playerName][0] = '\0';
	}
	playerStats[cli][st_kills]=0;
	playerStats[cli][damageInflicted] = 0.00;
	playerStats[cli][damageTaken] = 0.00;
	playerStats[cli][headShots] = 0;
	playerStats[cli][st_shots] = 0;
	playerStats[cli][st_damages] = 0;
	playerStats[cli][st_selfinflicteddmg] = 0.0;
	playerStats[cli][st_sui] = 0;
	
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
//	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	playerStats[attacker][st_killstreak]=0;
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:weapon[30];

	GetEventString(event, "weapon", weapon, sizeof(weapon));
	PrintToServer("Player death! attacker=%d victim=%d weapon=%s", attacker, victim, weapon);

	if(attacker==victim) {
		playerStats[attacker][st_sui]++;
	} else {
		playerStats[attacker][st_kills]++;
	}

	playerStats[attacker][st_killstreak]++;
	if(playerStats[attacker][st_killstreak]>1){
		if(playerStats[attacker][st_killstreak] == 2) {		// brand new killstreak
			playerStats[attacker][st_killstreakcount]++;
		}
		if(playerStats[attacker][st_killstreak] > playerStats[attacker][st_killstreakmax]){
			playerStats[attacker][st_killstreakmax] = playerStats[attacker][st_killstreak];
		}
	}

	playerStats[victim][st_killstreak]=0;

	playerStats[victim][st_deathstreak]++;
	if(playerStats[victim][st_deathstreak]>1){
		if(playerStats[victim][st_deathstreak] == 2 ) {	// brand new deathstreak
			playerStats[victim][st_deathstreakcount]++;
		}
		if(playerStats[victim][st_deathstreak] > playerStats[victim][st_deathstreakmax]){
			playerStats[victim][st_deathstreakmax] = playerStats[victim][st_deathstreak];
		}
	}

	return Plugin_Continue;
}
	

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new cli = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetPlayerStats(cli);
	return Plugin_Continue;
}	

public Action:Event_PlayerShoot(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new weapon = GetEventInt(event, "weapon");
	new mode = GetEventInt(event, "mode");
	PrintToServer("sm_winnerinfo: %s %d fired %d mode %d", name, attacker, weapon, mode);

}

public OnTraceAttack(victim, attacker, inflictor, Float:damage, damagetype, ammotype, hitbox, hitgroup)
{
	if(hitgroup==1){
		playerStats[attacker][headShots]++;//[attacker]++;
	}
}

public OnFireBullets(attacker, shots, String:weaponname[])	// This only works on trace wep
{
	playerStats[attacker][st_shots]++;
}

#if defined TRACK_NON_TRACE_WEAPONS
public OnEntityCreated(entity, const String:classname[])
{
	PrintToServer("sm_winnerinfo: classname=%s", classname);
	new bool:found=false;
	for(new i=0; i<sizeof(trackWeapons);i++){
		if(StrEqual(trackWeapons[i], classname)){
			found=true;
		}
	}
	if(found==false)
		return;
	PushStackCell(nontraceChecks, entity);	
}
#endif

#if defined TRACK_NON_TRACE_WEAPONS
public OnGameFrame()
{
	decl String:className[50];
	decl String:netClassname[50];
	decl owner;
	new entity;

	while(PopStackCell(nontraceChecks, entity)){
		if(!IsValidEntity(entity)){
			PrintToServer("sm_winnerinfo: OnGameFrame Invalid entity %d !", entity);
			continue;
		}

		owner=-1;

		GetEntityClassname(entity, className, sizeof(className));
		GetEntityNetClass(entity, netClassname, sizeof(netClassname));
PrintToServer("%d %s = %s", entity, className, netClassname);
	
		if(StrEqual(className,"crossbow_bolt")){
			 owner = GetEntDataEnt2(entity, g_iCrossBowOwnerOffs);
		} else if(StrEqual(className, "rpg_missile")){
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		} else if(StrEqual(className, "npc_grenade_frag")){
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		} else if(StrEqual(className, "grenade_ar2")){
			owner =  GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		} else if(StrEqual(className, "prop_combine_ball")){
			owner =  GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");			
		} else if(StrEqual(className, "npc_satchel")) { 
			owner =  GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");			
		} else if ( StrEqual(className, "npc_tripmine")){	// how do you find owner of npc_tripmine.  CBaseGrenade
			owner = GetEntData(entity, g_iTripmineOwnerOffs);
//                        owner =  GetEntPropEnt(entity, Prop_Data, "m_hThrower");//m_hOwnerEntity");

		} else {
			PrintToServer("sm_winnerinfo: OnGameFrame: Unknown entity classname '%s' in Nontrace weapon check!!", className);
			continue;
		}

		PrintToServer("%s owner is %d", className, owner);
		if(owner<0||owner>=MaxClients)
			continue;

		playerStats[owner][st_shots]++;
	}
}
#endif

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype, weapon, damageForce, damagePosition)
{
//	damageInflicted[attacker] += damage;
//	damageTaken[victim] += damage;

	decl String:attackerWeapon[30];

//	

	if(!(attacker > 0 && attacker < MaxClients+1))
		return;
		
	GetEdictClassname(inflictor, attackerWeapon, sizeof(attackerWeapon));
	if(StrEqual(attackerWeapon, "player")){	// What a load of BS
		GetClientWeapon(attacker, attackerWeapon, sizeof(attackerWeapon));
	}



	PrintToServer("sm_winnerinfo: OnTakeDamage weapon=%s weapond=%d GetPlayerWeaponSlot=%d", attackerWeapon, weapon, GetPlayerWeaponSlot(attacker, weapon));

	new bool:found=false;
	for(new i=0; i<sizeof(trackWeapons);i++){
		if(StrEqual(trackWeapons[i], attackerWeapon)){
			found=true;
		}
	}
	if(found==false)
		return;
// bah fuck.  
	if(StrEqual(attackerWeapon, "weapon_crowbar") || StrEqual(attackerWeapon,"weapon_stunstick") || StrEqual(attackerWeapon, "npc_tripmine") ){
		PrintToServer("sm_winnerinfo: ignoring damage from %s", attackerWeapon);
		return;
	}
	
	if(victim==attacker) {
		playerStats[attacker][st_selfinflicteddmg] += damage;
		return;
	}

	playerStats[victim][damageTaken] += damage;
	playerStats[attacker][damageInflicted] += damage;
	playerStats[attacker][st_damages]++;


	PrintToServer("inflictor = %d, weapon=%s", inflictor, attackerWeapon);
	
}

public NotifyWinnerInfo(type)
{
	new Float:highestdmg, highestp;
	new highestkills;

	new mode = GetConVarInt(FindConVar("sm_winnerinfo_mode"));

	if(mode==0){		// most damage inflicted
		for(new i=1; i<= MaxClients;i++){
			if(!IsClientConnected(i)){
				continue;
			}

//			if(damageInflicted[i]>highestdmg){
			if(playerStats[i][damageInflicted] > highestdmg){
				highestdmg = playerStats[i][damageInflicted];//damageInflicted[i];
				highestp = i;
			}
		}
	} else if(mode==1){ // most kills
		for(new i=1; i<=MaxClients; i++){
			if(IsClientConnected(i)){
				if(GetClientFrags(i)>highestkills){
					highestkills = GetClientFrags(i);
					highestp = i;
				}
			}
		}
	}

	if(highestp>0){
		decl String:buffer[50];
		decl String:bufferstr[300];
	

		GetConVarString(FindConVar("sm_winnerinfo_message"),bufferstr,sizeof(bufferstr));

		// %player%	- highest player name
		GetClientName(highestp,buffer,sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%player%",buffer,false);

		// %kills%	- highest player kills
		IntToString(playerStats[highestp][st_kills], buffer, sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%kills%",buffer,false);

		// %frags%
		IntToString(GetClientFrags(highestp),buffer,sizeof(buffer));
		ReplaceString(bufferstr,sizeof(bufferstr),"%frags%",buffer,false);

		// %deaths%	- highest player deaths
		IntToString(GetClientDeaths(highestp), buffer, sizeof(buffer));
		ReplaceString(bufferstr, sizeof(bufferstr), "%deaths%", buffer, false);

		// %headshots%  
		IntToString(playerStats[highestp][headShots], buffer, sizeof(buffer));
		ReplaceString(bufferstr, sizeof(bufferstr), "%headshots%", buffer, false);

		// %suicides%
		IntToString(playerStats[highestp][st_sui], buffer, sizeof(buffer));
		ReplaceString(bufferstr, sizeof(bufferstr), "%suicides%", buffer, false);

		// %misses%
//		IntToString(playerStats[highestp][st_shots] -  playerStats[highestp][st_damages], buffer, sizeof(buffer));
//		ReplaceString(bufferstr, sizeof(bufferstr), "%misses%", buffer, false);

		// %shots%
		IntToString(playerStats[highestp][st_shots], buffer, sizeof(buffer));
		ReplaceString(bufferstr, sizeof(bufferstr), "%shots%", buffer, false);
		// %damage%	- highest player damage

//		IntToString(RoundFloat(damageInflicted[highestp]),buffer,sizeof(buffer));
		IntToString(RoundFloat(playerStats[highestp][damageInflicted]),buffer,sizeof(buffer));
		ReplaceString(bufferstr, sizeof(bufferstr), "%damage%", buffer, false);

		if(StrContains(bufferstr,"\\n")){		// i hate this.

			new String:StringLines[10][300];
			new String:bufferstr2[300];
			new String:bufferstr3[300];

			ExplodeString(bufferstr, "\\n", StringLines, sizeof(StringLines), sizeof(StringLines[]));
			new  maxlen;

			for(new i=0; i<sizeof(StringLines); i++){
				if(StringLines[i][0]=='\0')
					break;
				if(strlen(StringLines[i]) > maxlen)
					maxlen=strlen(StringLines[i]);
			}
			new diff;
			for(new i=0;  i<sizeof(StringLines); i++){
				if(StringLines[i][0]=='\0')
					break;

				diff = maxlen - strlen( StringLines[i]);
				Format(bufferstr2, sizeof(bufferstr2), "%s\n", StringLines[i]);
				if(diff>0){
					diff =  (maxlen / 2) - (strlen(bufferstr2)/2);	// or use maxlen / 2 only to make it look centered, even though it's not.  
//					diff = (maxlen/2);
					for(new i2=0; i2<diff; i2++){
						StrCat(bufferstr3, sizeof(bufferstr3), " ");
					}
				}

				StrCat(bufferstr3, sizeof(bufferstr3), bufferstr2);

			}
			strcopy(bufferstr, sizeof(bufferstr),bufferstr3);

		}

#if defined USECENTERTEXT

		new printmethod = GetConVarInt(FindConVar("sm_winnerinfo_printmethod"));
		new dp = CreateDataPack();
		WritePackCell(dp, printmethod);
		WritePackString(dp, bufferstr);

		
		CreateTimer(1.0, _PrintNotifyInfo, dp, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT|TIMER_DATA_HNDL_CLOSE);

#endif
		if(soundFile[0] != '\0'){
			EmitSoundToAll(soundFile);
		}

//	PrintToServer("Bufferstr = %s", bufferstr);
		for(new i=1; i<=MaxClients; i++){
			if(IsClientConnected(i)){
#if !defined USECENTERTEXT
				Client_ScreenFade(i, 0,  FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE, -1, fadeColor[0], fadeColor[1], fadeColor[2], fadeColor[3]);
				SetHudTextParams(msgX, msgY, 10.0, msgColor[0], msgColor[1], msgColor[2], msgColor[3]);
				ShowSyncHudText(i, hudSynchronizerMsg, bufferstr);
#endif
				DisplayPlayerStats(i, 10.0);
			}
		}

//		LogMessage(buffer);
	} else {
//		LogMessage("Couldn't figure out who the most winnerinfo player was");
	}
}

public Action:_PrintNotifyInfo(Handle:t, any:dp)
{
	new String:buffer[255];
	ResetPack(dp);
	ReadPackString(dp, buffer, sizeof(buffer));	
	
	PrintCenterTextAll(buffer);
}


DisplayPlayerStats(client, Float:fadetime=1.0)
{
	new String:msg[1024];
	new String:clName[64];

	GetClientName(client, clName, sizeof(clName));

#if 0
	new Float:kdr;
	if(GetClientDeaths(client)==0)
		kdr = GetClientFrags(client) / 1;
	else
		kdr = GetClientFrags(client) / GetClientDeaths(client);
#endif

//	new misses = playerStats[client][st_shots] - playerStats[client][st_damages];
//	Format(msg, sizeof(msg), "-=[ %s ]=-\n\nDamage Inflicted: %.2f\nDamage Taken: %.2f\nKills: %d\nDeaths: %d\n", clName,  damageInflicted[client], damageTaken[client], GetClientFrags(client), GetClientDeaths(client));
	Format(msg, sizeof(msg), 
		"-=[ %s ]=-\n\nScore (frags): %d\nKills: %d\nDeaths: %d (%d sui)\nHeadshots: %d\n\nKill Streaks: %d\nLongest Kill Streak: %d\nDeath Streaks: %d\nLongest Death Streak: %d",
		clName,
		GetClientFrags(client),
		playerStats[client][st_kills],
		GetClientDeaths(client),
		playerStats[client][st_sui],
		playerStats[client][headShots],
		playerStats[client][st_killstreakcount],
		playerStats[client][st_killstreakmax],
		playerStats[client][st_deathstreakcount],
		playerStats[client][st_deathstreakmax]


	);

	SetHudTextParams(statusX, statusY, fadetime, statColor[0], statColor[1], statColor[2], statColor[3]);
	ShowSyncHudText(client, hudSynchronizerStats, msg);	
}

public Action:OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon)
{
	if(iButtons & IN_SCORE){
		inScoreboard[client]=true;
		Client_ScreenFade(client, 0,  FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE, -1, fadeColor[0], fadeColor[1], fadeColor[2], fadeColor[3]);
		DisplayPlayerStats(client);
	} else {
		if(inScoreboard[client]==true){
			inScoreboard[client]=false;
			ShowSyncHudText(client, hudSynchronizerStats, "");
			Client_ScreenFade(client, 0, FFADE_IN | FFADE_PURGE, -1, 0, 0, 0, 0);
		}
	}
}



public Action:_VGuiMenu(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	new String:Type[10];

	BfReadString(bf, Type, sizeof(Type));

	if(strcmp(Type, "scores", false) == 0)
	{
        	if(BfReadByte(bf) == 1 && BfReadByte(bf) == 0)
	        {
			gameendMsgId = msg_id;
		}
	}
}

public _VGuiMenuPosthook(UserMsg:msg_id, bool:sent)
{
	if(msg_id == gameendMsgId ) {

#if 1
		NotifyWinnerInfo(NOTIFYTYPE_GAMEEND);	// the old board
#else
		// display a motd panel
		new String:winnerName[255];
		if(winnerId && IsClientConnected(winnerId)){
			GetClientName(winnerId, winnerName, sizeof(winnerName));
		} else if(!winnerId){
			strcopy(winnerName, sizeof(winnerName), "No one!");
		} else {
			strcopy(winnerName, sizeof(winnerName), "some hacker");
		}
		new String:url[2048];
	
		new String:steamId[20];
		new bool:sendto[MAXPLAYERS+1];
		new String:buffer[30];

		Format(url, sizeof(url), "http://stats.vag-clan.tk/winnerinfo.php?cx=\%cx\%&w=%d&p=", winnerId);

		for(new i=1; i<= MaxClients; i++){
			if(IsClientConnected(i)){
				GetClientAuthString(i, steamId, sizeof(steamId));
				Format(buffer, sizeof(buffer), "%s;%d;%d|", steamId, GetClientFrags(i), GetClientDeaths(i));
				StrCat(url, sizeof(url), buffer);
				sendto[i]=true;
			}
		}

		new String:pUrl[2048];

		for(new i=1; i<MaxClients+1; i++){		// Send the url's out to players
			if(sendto[i]==true){
				strcopy(pUrl, sizeof(pUrl), url);
				IntToString(i, buffer, sizeof(buffer));
				ReplaceString(pUrl, sizeof(pUrl), "%cx%", buffer);
				ShowMOTDPanel(i, "And the Winner is!!", pUrl, MOTDPANEL_TYPE_URL);
			}
		}
#endif

		gameendMsgId = UserMsg:-1;
	}

}


public Action:PrintStat(client,args)
{
	NotifyWinnerInfo(NOTIFYTYPE_USERSCOREBOARD);
}


MyAddSoundToDownloadsTable(const String:name[])
{
	decl String:sndFile[255];
	Format(sndFile, sizeof(sndFile), "sound/%s", name);
	AddFileToDownloadsTable(sndFile);
	PrecacheSound(name,true);

}
