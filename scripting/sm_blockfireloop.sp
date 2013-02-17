#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
	name="Block ambient/fire/fire_small_loop2.wav",
	author="[foo] bar",
	description="A Lame workaround for looping ambient fire that shouldn't loop",
	url="?",
	version="0.1"
};

public OnPluginStart()
{
	AddNormalSoundHook(BlockSound);
}


public Action:BlockSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(StrEqual(sample,"ambient/fire/fire_small_loop2.wav")){
		return(Plugin_Handled);
	}
	return(Plugin_Continue);

}