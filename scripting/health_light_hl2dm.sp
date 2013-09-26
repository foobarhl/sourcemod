#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define LIGHT_MODEL "models/effects/vol_light64x256.mdl"
#if 0
#define LIGHT_SOUND "ambient/weather/rumble_rain.wav"
#endif
#define LIGHT_SOUND "items/medcharge4.wav"

#if 0
#define VEND_MODEL "models/props/cs_office/vending_machine.mdl"
#endif

#define VEND_MODEL "models/props_interiors/vendingmachinesoda01a.mdl"

public Plugin:myinfo = 
{
	name = "Health_Light for hl2dm",
	author = "wS / Schmidt, [foo] bar",
	description = "Health light for hl2dm",
	version = "1.2foobar1"
};

new Handle:wS_Timer[MAXPLAYERS+1], Handle:PANEL;
new light_hp = 2, light_max_num = 0, light_index[101] = {-1, ...};
new Float:light_pos[101][3];

public OnPluginStart()
{
	HookConVarChange(CreateConVar("light_hp", "2"), cvar_light_hp);
	HookEvent("round_start", round_start, EventHookMode_PostNoCopy);

	PANEL = CreatePanel();
	SetPanelTitle(PANEL, "[ Health_Light ] Menu\n \n");
	DrawPanelItem(PANEL, "Create Light");
	DrawPanelItem(PANEL, "Delete Light (aim)");
	DrawPanelItem(PANEL, "Save Settings");
	DrawPanelItem(PANEL, "Exit");

	RegAdminCmd("light_admin", light_admin, ADMFLAG_ROOT);
//	ServerCommand("mp_restartgame 1");
}

public OnMapStart()
{
	PrecacheModel(VEND_MODEL, true);
	PrecacheModel(LIGHT_MODEL, true);
	PrecacheSound(LIGHT_SOUND, true);
	decl String:map[65];
	GetCurrentMap(map, 65);
	light_max_num = 0;
	new Handle:KV = CreateKeyValues("wS_Light");
	if (FileToKeyValues(KV, "cfg/wS_Light.txt") && KvJumpToKey(KV, map))
	{
		decl String:wS_Key[5];
		for (new x = 1; x < 101; x++)
		{
			IntToString(x, wS_Key, 5);
			KvGetVector(KV, wS_Key, light_pos[x], Float:{387335538.0, 0.0, 0.0});
			if (light_pos[x][0] == 387335538.0) break;
			light_max_num += 1;
		}
		if (0 < light_max_num < 100)
		{
			for (new x = light_max_num; x < 101; x++) light_index[x] = -1;
		}
	}
	CloseHandle(KV);
}

public cvar_light_hp(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if ((light_hp = StringToInt(newValue)) < 1) light_hp = 2;
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (light_max_num > 0)
	{
		for (new x = 1; x <= light_max_num; x++) light_index[x] = wS_CreateLight(light_pos[x]);
	}
}

wS_CreateLight(const Float:ground_pos[3])
{
	new light = CreateEntityByName("prop_dynamic");
	if (light < 1)
	{
		LogError("prop_dynamic error");
		return -1;
	}
	new trigger = CreateEntityByName("trigger_multiple");
	if (trigger < 1)
	{
		AcceptEntityInput(light, "Kill");
		LogError("trigger_multiple error");
		return -1;
	}
	new xMusic = CreateEntityByName("ambient_generic");
	if (xMusic < 1)
	{
		AcceptEntityInput(light, "Kill");
		AcceptEntityInput(trigger, "Kill");
		LogError("ambient_generic error");
		return -1;
	}
	// light
	decl Float:air_pos[3];
	air_pos[0] = ground_pos[0];
	air_pos[1] = ground_pos[1];
	air_pos[2] = ground_pos[2] + 256.0;
	DispatchKeyValueVector(light, "origin", air_pos);
	DispatchKeyValue(light, "model", LIGHT_MODEL);
	decl String:light_name[20];
	Format(light_name, 20, "light_%d", light);
	DispatchKeyValue(light, "targetname", light_name);
	DispatchSpawn(light);

	// trigger
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "wait", "0");
	DispatchSpawn(trigger);
	ActivateEntity(trigger);
	SetEntityModel(trigger, VEND_MODEL);
	TeleportEntity(trigger, ground_pos, NULL_VECTOR, NULL_VECTOR);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", Float:{-30.0, -30.0, -10.0});
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", Float:{30.0, 30.0, 256.0});
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
	new iEffects = GetEntProp(trigger, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(trigger, Prop_Send, "m_fEffects", iEffects);
	SetVariantString(light_name);
	AcceptEntityInput(trigger, "SetParent");
	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch);

	// xMusic
	DispatchKeyValueVector(xMusic, "origin", ground_pos);
	DispatchKeyValue(xMusic, "message", LIGHT_SOUND);
	DispatchKeyValue(xMusic, "radius", "700");
	DispatchKeyValue(xMusic, "health", "10");
	DispatchKeyValue(xMusic, "preset", "0");
	DispatchKeyValue(xMusic, "volstart", "10");
	DispatchKeyValue(xMusic, "pitch", "100");
	DispatchKeyValue(xMusic, "pitchstart", "100");
	DispatchSpawn(xMusic);
	ActivateEntity(xMusic);
	SetVariantString(light_name);
	AcceptEntityInput(xMusic, "SetParent");
	AcceptEntityInput(xMusic, "PlaySound");

	return light;
}

///

public OnStartTouch(const String:output[], ent, client, Float:delay)
{
	if (0 < client <= MaxClients && wS_Timer[client] == INVALID_HANDLE && 0 < GetEntProp(client, Prop_Send, "m_iHealth") < 100)
	{
		wS_Timer[client] = CreateTimer(1.0, wS_TimerFunc, client, TIMER_REPEAT);
	}
}

public OnEndTouch(const String:output[], ent, client, Float:delay) wS_StopTimer(client);
public OnClientDisconnect(client) wS_StopTimer(client);

wS_StopTimer(client)
{
	if (wS_Timer[client] != INVALID_HANDLE)
	{
		KillTimer(wS_Timer[client]);
		wS_Timer[client] = INVALID_HANDLE;
	}
}

public Action:wS_TimerFunc(Handle:timer, any:client)
{
	new hp = GetEntProp(client, Prop_Send, "m_iHealth") + light_hp;
	if (hp > 100) hp = 100;
	SetEntProp(client, Prop_Send, "m_iHealth", hp);
	if (hp < 100) return Plugin_Continue;
	wS_Timer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

///

public Action:light_admin(client, args)
{
	if (args < 1) SendPanelToClient(PANEL, client, Select_PANEL, 0);
	return Plugin_Handled;
}

public Select_PANEL(Handle:menu, MenuAction:action, client, option)
{
	if (action != MenuAction_Select || option > 3) return;
	if (option == 1)
	{
		if (light_max_num > 99) PrintToChat(client, "[ Health_Light ] Limit: 100");
		else
		{
			decl Float:end_pos[3];
			wS_GetEndPos(client, end_pos);
			if (!wS_ItsGoodDistForCreateLight(end_pos)) PrintToChat(client, "[ Health_Light ] Here it is impossible");
			else
			{
				new index = wS_CreateLight(end_pos);
				if (index > 0)
				{
					light_max_num += 1;
					light_index[light_max_num] = index;
					light_pos[light_max_num][0] = end_pos[0];
					light_pos[light_max_num][1] = end_pos[1];
					light_pos[light_max_num][2] = end_pos[2];
					PrintToChat(client, "\x04[ Health_Light ] Light Created");
				}
				else PrintToChat(client, "[ Health_Light ] error.. oO");
			}
		}
	}
	else if (option == 2)
	{
		if (light_max_num < 1) PrintToChat(client, "[ Health_Light ] Light not found (1)");
		else
		{
			decl Float:end_pos[3];
			wS_GetEndPos(client, end_pos);
			new nuM = 0;
			for (new x = 1; x <= light_max_num; x++)
			{
				if (GetVectorDistance(end_pos, light_pos[x]) < 75.0)
				{
					nuM = x;
					break;
				}
			}
			if (nuM < 1) PrintToChat(client, "[ Health_Light ] Light not found (2)");
			else wS_DelLight(nuM, light_index[nuM]);
		}
	}
	else
	{
		decl String:map[65];
		GetCurrentMap(map, 65);
		new Handle:KV = CreateKeyValues("wS_Light");
		if (FileToKeyValues(KV, "cfg/wS_Light.txt") && KvJumpToKey(KV, map))
		{
			KvDeleteThis(KV);
			KvRewind(KV);
		}
		if (light_max_num > 0)
		{
			KvJumpToKey(KV, map, true);
			decl String:wS_Key[5];
			for (new x = 1; x <= light_max_num; x++)
			{
				IntToString(x, wS_Key, 5);
				KvSetVector(KV, wS_Key, light_pos[x]);
			}
		}
		KvRewind(KV);
		KeyValuesToFile(KV, "cfg/wS_Light.txt");
		CloseHandle(KV);
		PrintToChat(client, "\x04[ Health_Light ] Settings Saved (wS_Light.txt)");
	}
	SendPanelToClient(PANEL, client, Select_PANEL, 0);
}

///

wS_GetEndPos(client, Float:end_pos[3])
{
	decl Float:EyePosition[3], Float:EyeAngles[3];
	GetClientEyePosition(client, EyePosition);
	GetClientEyeAngles(client, EyeAngles);
	TR_TraceRayFilter(EyePosition, EyeAngles, MASK_SOLID, RayType_Infinite, wS_Filter, client);
	TR_GetEndPosition(end_pos);
}

public bool:wS_Filter(ent, mask, any:client) return client != ent;

///

wS_DelLight(light_num, index)
{
	if (IsValidEntity(index)) AcceptEntityInput(index, "Kill");
	if (light_num != light_max_num)
	{
		new curr_num = light_num, next_num;
		while(curr_num < light_max_num)
		{
			next_num = curr_num + 1;
			light_index[curr_num] = light_index[next_num];
			light_pos[curr_num][0] = light_pos[next_num][0];
			light_pos[curr_num][1] = light_pos[next_num][1];
			light_pos[curr_num][2] = light_pos[next_num][2];
			curr_num += 1;
		}
	}
	light_index[light_max_num--] = -1;
}

bool:wS_ItsGoodDistForCreateLight(const Float:x_pos[3])
{
	for (new x = 1; x <= light_max_num; x++)
	{
		if (GetVectorDistance(x_pos, light_pos[x]) < 75.0) return false;
	}
	return true;
}