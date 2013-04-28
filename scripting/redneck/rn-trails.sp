/*
 * rn-trails.sp: Redneck's custom trails
 * Thrown together by [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
 *
 * With code from vog_fireworks.sp by FlyingMongoose http://forums.alliedmods.net/showthread.php?t=71051 
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

/* TODO: 
	-Figure out how to detect a headshot with a crossbow
	-Don't use KeyVars in OnGameFrame, load up config in memory instead. Perf hit?
	-Add additional effects
	-Clean up code
*/

// With code from vog_fireworks.sp

#include <sourcemod>
#include <smlib>
#include <sdkhooks>

#include <sdktools_sound.inc>

#define VERSION  "0.6"

public Plugin:myinfo = {
	name = "RN-Trails",
	author = "[foo] bar",
	description = "Redneck's custom trails",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};

new String:configfile[PLATFORM_MAX_PATH]="";
new Handle:configfilefh = INVALID_HANDLE;
new smokeModel1;
new smokeModel2;
new firelineModel;

new g_ExplosionSprite;
new g_Smoke1;
new g_Smoke2;
new g_BlueGlowSprite;
new g_RedGlowSprite;
new g_GreenGlowSprite;
new g_YellowGlowSprite;
new g_PurpleGlowSprite;
new g_OrangeGlowSprite;
new g_WhiteGlowSprite;

new g_BlueLaser;

new hitGroups[MAXPLAYERS+1];

public OnPluginStart()
{

	CreateConVar("rn_trails_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);
//	SetRandomSeed(GetEntineTime());
}

public OnMapStart()
{
	LoadConfig();
	smokeModel1 = PrecacheModel("materials/effects/fire_cloud1.vmt",true);
	smokeModel2 = PrecacheModel("materials/effects/fire_cloud2.vmt",true);
	firelineModel =  PrecacheModel("materials/sprites/fire.vmt",true);

	g_ExplosionSprite = PrecacheModel("materials/sprites/sprite_fire01.vmt",true);
	g_Smoke1 = PrecacheModel("materials/effects/fire_cloud1.vmt",true);
	g_Smoke2 = PrecacheModel("materials/effects/fire_cloud2.vmt",true);

	g_BlueLaser = g_BlueGlowSprite = PrecacheModel("materials/sprites/blueglow1.vmt",true);
	g_RedGlowSprite = PrecacheModel("materials/sprites/redglow1.vmt",true);
	g_GreenGlowSprite = PrecacheModel("materials/sprites/greenglow1.vmt",true);
	g_YellowGlowSprite = PrecacheModel("materials/sprites/yellowglow1.vmt",true);
	g_PurpleGlowSprite = PrecacheModel("materials/sprites/purpleglow1.vmt",true);
	g_OrangeGlowSprite = PrecacheModel("materials/sprites/orangeglow1.vmt",true);
	g_WhiteGlowSprite = PrecacheModel("materials/sprites/glow1.vmt",true);
}

public OnGameFrame()
{
	new entid = -1;
	new Float:position[3];
	decl String:entityname[100];
	KvRewind(configfilefh);
	KvGotoFirstSubKey(configfilefh);
	
	decl String:effect[10];
	decl String:effect2[10];
	new Float:framerate=0.01;
	new Float:scale = 1.0;

	do
	{
		KvGetSectionName(configfilefh,entityname,sizeof(entityname));

		KvGetString(configfilefh,"effect",effect,sizeof(effect));
		KvGetString(configfilefh,"effect2",effect2,sizeof(effect2));

		if(strcmp(effect,"",false)==0)
		{
			continue;
		}

		framerate = KvGetFloat(configfilefh,"framerate",0.01);
		scale = KvGetFloat(configfilefh,"scale",1.00);
		entid = -1;
		while((entid = Entity_FindByClassName(entid,entityname))>0)
		{
			GetEntPropVector(entid,Prop_Send,"m_vecOrigin",position);

//			PrintToServer("  Doing stuff to %s",entityname);
			if(strcmp(effect,"smoke",false)==0){
				smoke(position,scale,framerate);
			} else if(strcmp(effect,"energy",false)==0){
				energy(position);
			} else if(strcmp(effect,"sparks",false)==0){
				spark(position,scale,framerate);
			} else if(strcmp(effect,"dust",false)==0){
				dust(position,scale,framerate);
			} else if(strcmp(effect,"beam",false)==0){
//				FireSprites(position);//,scale,framerate);
				beam(position);
			} else if(strcmp(effect,"beamfollow",false)==0){
				new color[4] = {255,255,255,200};
				TE_SetupBeamFollow(entid,g_BlueLaser,0,1.0,1.0,2.0,5.0,color);
				TE_SendToAll();
			}
		}

	} while(KvGotoNextKey(configfilefh));	
}

public LoadConfig()
{
	BuildPath(Path_SM,configfile,sizeof(configfile),"configs/rn-trails.cfg");

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

public smoke(const Float:vec[3], const Float:smokescale, const Float:smokeframerate)
{
	TE_SetupSmoke(vec, smokeModel1, smokescale, smokeframerate);
//	TE_SetupSmoke(vec, smokeModel2, smokescale, smokeframerate);
	TE_SendToAll();
}


public spark(const Float:position[3], const Float:scale, const Float:framerate)
{
	new Float:dir[3]={0.0,0.0,0.0}
	TE_SetupSparks(position,dir,scale,framerate);
	TE_SendToAll();
}

public dust(Float:position[3], Float:scale, Float:framerate)
{
	new Float:dir[3]={0.0,0.0,0.0};
	TE_SetupDust(position,dir,scale,framerate);

	
}

public energy(Float:position[3])
{
	new Float:dir[3]={0.0,0.0,0.0};
	TE_SetupEnergySplash(position,dir,false);
	TE_SendToAll();
}


public beam(Float:startvec[3])
{
	new Float:endvec[3]={0.0,0.0,0.0};
	endvec[0] = startvec[0]+2.0;
	endvec[1] = startvec[1]+2.0;
	endvec[2] = startvec[2]+2.0;


//	fire_line(startvec,endvec);
	new color[4]={255,255,255,200};
#if 1
	color[0] = GetRandomInt(0,255);
	color[1] = GetRandomInt(0,255);
	color[2] = GetRandomInt(0,255);
	color[3] = 255;
#endif
	new r = GetRandomInt(0,3);
	new laser;
	if(r==0){ 
		laser = g_BlueLaser;
	} else if (r==1){
		laser =  g_GreenGlowSprite;
	} else if(r==2){
		laser = g_PurpleGlowSprite;
	} else if(r==3){
		laser = g_WhiteGlowSprite;
	} else if(r==4){

	}

	laser = g_BlueGlowSprite;
//	PrintToServer("Beam color is %d %d %d %d",color[0],color[1],color[2],color[3]);
	TE_SetupBeamPoints( 
		startvec,
		endvec, 
		laser,//		firelineModel, 	// model index
		0, 	//halo index
		0, 	//initial frame to render
		0, 	//beam frame rate
		0.5, 	//time duration
		2.0, 	//initial width
		5.0, 	//final width
		0, 	//fade time duration
		10.0, 	// beam amplitude
		color, 	// color
		10	// speed
	);
	TE_SendToAll();
}

// from vog_fireworks.sp
public fire_line(Float:startvec[3],Float:endvec[3])
{
	new color[4]={255,255,255,200};
	TE_SetupBeamPoints( startvec,endvec, firelineModel, 0, 0, 0, 0.8, 2.0, 1.0, 1, 0.0, color, 10);
	TE_SendToAll();
}

public FireSprites(Float:vec[3])
{
	new Float:vec2[3];
	vec2 = vec;
	vec2[2] = vec[2] + 300.0;
	fire_line(vec,vec2);
//	sound(vec2);
	//explode(vec2);
	sphere(vec2);
	spark(vec2,1,0.01);
//scale,framerate);
}

public sphere(Float:vec[3])
{
	new Float:rpos[3], Float:radius, Float:phi, Float:theta, Float:live, Float: size, Float:delay;
	new Float:direction[3];
	new Float:spos[3];
	new bright = 255;
	direction[0] = 0.0;
	direction[1] = 0.0;
	direction[2] = 0.0;
	radius = GetRandomFloat(75.0,150.0);
	new rand;

	for (new i=0;i<50;i++)
	{
		rand = GetRandomInt(0,6);
		delay = GetRandomFloat(0.0,0.5);
		bright = GetRandomInt(128,255);
		live = 2.0 + delay;
		size = GetRandomFloat(0.5,0.7);
		phi = GetRandomFloat(0.0,6.283185);
		theta = GetRandomFloat(0.0,6.283185);
		spos[0] = radius*Sine(phi)*Cosine(theta);
		spos[1] = radius*Sine(phi)*Sine(theta);
		spos[2] = radius*Cosine(phi);
		rpos[0] = vec[0] + spos[0];
		rpos[1] = vec[1] + spos[1];
		rpos[2] = vec[2] + spos[2];

		switch(rand)
		{
			case 0:	TE_SetupGlowSprite(rpos, g_BlueGlowSprite,live, size, bright);
			case 1:	TE_SetupGlowSprite(rpos, g_RedGlowSprite,live, size, bright);
			case 2: TE_SetupGlowSprite(rpos, g_GreenGlowSprite,live, size, bright);
			case 3: TE_SetupGlowSprite(rpos, g_YellowGlowSprite,live, size, bright);
			case 4: TE_SetupGlowSprite(rpos, g_PurpleGlowSprite,live, size, bright);
			case 5: TE_SetupGlowSprite(rpos, g_OrangeGlowSprite,live, size, bright);
			case 6: TE_SetupGlowSprite(rpos, g_WhiteGlowSprite,live, size, bright);
		}
		TE_SendToAll(delay);
	}
}

public explode(Float:vec[3])
{
	TE_SetupExplosion(vec, g_ExplosionSprite, 10.0, 1, 0, 0, 5000); // 600
	TE_SendToAll();
}



