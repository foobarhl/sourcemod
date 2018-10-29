/*
 * sm_foocrossbow.sp: [foo] bar's crossbow
 * Copyright (c) 2018 [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/ 
 * Website: www.foo-games.com
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
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.30"

new entityGroups[4096];

public Plugin:myinfo = {
        name = "[foo] bar's crossbow",
        description = "foo's crossbow",
        author = "[foo] bar",
        version = VERSION,
        url = "www.foo-games.com"
};

public OnPluginStart()
{
	CreateConVar("sm_foocrossbow_version", VERSION, "Damage Indicator Sound", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public OnEntityCreated(entity, const String:classname[])
{
	if(entity){
		if(strcmp(classname, "crossbow_bolt", true) == 0){
			SDKHook(entity, SDKHook_StartTouch, Hook_EntityStartTouch);
			SDKHook(entity, SDKHook_EndTouch, Hook_EntityEndTouch);
		}
	}
}

public Hook_EntityStartTouch(entity, other)
{
	entityGroups[other] = GetEntProp(other, Prop_Data, "m_CollisionGroup");
	SetEntProp(other, Prop_Data, "m_CollisionGroup", 6);
}  

public Hook_EntityEndTouch(entity, other)
{
	SetEntProp(other, Prop_Data, "m_CollisionGroup", entityGroups[other]);
}  

