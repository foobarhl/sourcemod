// add blood exploding
// move crossbow kill effect to rn-gibs

/*
 * rn-gibs: Redneck's Gibs
 * Thrown together by [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
 */

/*
 * Inspired by, and code borrowed from Funny Gibs for TF2 by Raven Coda. http://forums.alliedmods.net/showthread.php?p=661702
 */


/*
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
#include <sdktools>

#define VERSION "0.4"


public Plugin:myinfo = {
	name = "Redneck Gibs",
	author = "[foo] bar",
	description = "Redneck's Gibs",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};


const numGibs = 4;
static String:GibName[numGibs][60] = 
{
	"models/gibs/hgibs.mdl",
	"models/gibs/hgibs_rib.mdl",
	"models/gibs/hgibs_scapula.mdl",
	"models/gibs/hgibs_spine.mdl"
};

new moff;

public OnPluginStart() 
{ 
	moff = FindSendPropOffs("CBaseEntity", "m_clrRender");
	if (moff == -1) {
		SetFailState("Could not find \"m_clrRender\" moff");
	}
	CreateConVar("rn_gibs_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);
	HookEvent("player_death",PlayerDeath);
}

public OnMapStart()
{
	for (new i=0; i<sizeof(GibName); i++)
	{
		PrecacheModel(GibName[i], true);
	}
}



public OnEventShutdown()
{
	UnhookEvent("player_death",PlayerDeath);
}



public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client, attacker;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	new String:weaponName[32];
	GetEventString(event, "weapon", weaponName, sizeof(weaponName));

	ReplaceGibs(client, attacker, sizeof(GibName));

	return Plugin_Continue;
}

public Action:RemoveRagdoll(Handle:Timer, any:client)
{
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll>0)
	  {
		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", -1);
		RemoveEdict(ragdoll);	
	  }
	else
	  {
		LogError("Could not find ragdoll");
	  }
}


stock Action:ReplaceGibs(any:client, any:attacker, count =1)
{
	if (!IsValidEntity(client))
	{
		LogError("Could not find Client");  
		return;
	}
  
	//Shuffle
	new ord[numGibs];
	for (new j=0; j<sizeof(GibName) ;j++)
	{
		ord[j]=j;
	}
 
	for (new j=0; j<sizeof(GibName); j++)
	{
		new n = GetRandomInt(j, sizeof(GibName)-1);
		new t=ord[j];
		ord[j]=ord[n];
		ord[n]=t;
	}
	
	decl Float:pos[3];
	GetClientAbsOrigin(client, pos);

	for(new i = 0; i < count; i++)
	{
		new gib =  CreateEntityByName("prop_physics");//_multiplayer");
		if(gib<0){
			return;
		}
		decl CollisionOffset;
		DispatchKeyValue(gib, "model", GibName[ord[i]]);

		// I want gibs to explode if someone makes contact with then, and to be 
		// manipulatable with the grav gun.  NFI how to do this atm.
#if 0
		new flags = GetEntityFlags(gib);
		flags = 1048896;
		flags = 1048576;	
		SetEntityFlags(gib,flags);
		if(DispatchKeyValueFloat(gib,"forcetoenablemotion",10.0)==false){
			PrintToServer("forcetoenablemotion fail");
		}
		DispatchKeyValueFloat(gib,"ExplodeDamage",150.0);
		DispatchKeyValueFloat(gib,"ExplodeRadius",400.0);
		DispatchKeyValueFloat(gib,"physdamagescale",0.1);
		DispatchKeyValueFloat(gib,"inertiaScale",1.0);
#endif


		 if (DispatchSpawn(gib))
		 {

			 CollisionOffset = GetEntSendPropOffs(gib, "m_CollisionGroup");
			 if(IsValidEntity(gib)) SetEntData(gib, CollisionOffset, 1, 1, true);
			 new Float:vel[3];
			 vel[0]=GetRandomFloat(-300.0, 100.0);
			 vel[1]= GetRandomFloat(-300.0, 100.0);
			 vel[2] = GetRandomFloat(100.0, 100.0);
			 TeleportEntity(gib, pos, NULL_VECTOR, vel);
#if 0
			// Try to attach blood to the gib
			 AttachParticle(gib, "env_fire_large", 5.0);	// was grenade_explosion_01
#endif
			 CreateTimer(15.0, RemoveGib, gib);
		 } else	 {
			PrintToServer("Could not create gib %s", GibName[ord[i]]);
			LogError("Could not create gib");
		 }
	}
}  

//Remove Gib:
public Action:RemoveGib(Handle:Timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		CreateTimer(0.1, fadeout, ent, TIMER_REPEAT);
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	}
}

public Action:fadeout(Handle:Timer, any:ent)
{
    if (!IsValidEntity(ent))
    {
        KillTimer(Timer);
        return;
    }

    new alpha = GetEntData(ent, moff + 3, 1);
    if (alpha - 25 <= 0)
    {
        RemoveEdict(ent);
        KillTimer(Timer);
    }
    else
    {
        SetEntData(ent, moff + 3, alpha - 25, 1, true);
    }
}  



public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
    new particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particlename);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, particle);
    }
    else
    {
        LogError("ShowParticle: could not create info_particle_system");
    }    
}



AttachParticle(ent, String:particleType[], Float:time)
{
	decl String:tName[64];
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
        new Float:pos[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
        DispatchKeyValue(particle, "targetname", "particle");	// was tf2particle
        DispatchKeyValue(particle, "parentname", tName);
        DispatchKeyValue(particle, "effect_name", particleType);
        DispatchSpawn(particle);
        SetVariantString(tName);
        AcceptEntityInput(particle, "SetParent", particle, particle, 0);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, particle);
	PrintToServer("AttachParticle");
	}
	else
	{
        LogError("AttachParticle: could not create info_particle_system");
	}
}



public Action:DeleteParticles(Handle:timer, any:particle)
{
    if (IsValidEntity(particle))
    {
        new String:classname[64];
        GetEdictClassname(particle, classname, sizeof(classname));
        if (StrEqual(classname, "info_particle_system", false))
        {
		PrintToServer("Delete particle");
        	RemoveEdict(particle);
        }
        else
        {
		LogError("DeleteParticles: not removing entity - not a particle '%s'", classname);
        }
    }
}

