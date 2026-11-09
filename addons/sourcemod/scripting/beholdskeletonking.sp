#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define KUKRI 3
#define EF_BONEMERGE 1
#define EF_NOSHADOW 16
#define EF_NODRAW 32
#define SND_SPAWN		"Halloween.HeadlessBossSpawn"
#define SND_DEATH		"misc/halloween/skeleton_break.wav"
#define SKELETON_KING_MODEL	"models/player/skeleton_king_player/skeleton_king_player.mdl"
#define CROWN_MODEL		"models/player/items/demo/crown.mdl"

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = 
{
	name = "[TF2] Behold, the Skeleton King!",
	author = "Bradasparky",
	description = "Allows for admins and other plugins to turn players into the Skeleton King",
	version = PLUGIN_VERSION,
	url = "https://github.com/Bradasparky/tf-beholdskeletonking"
}

enum
{
	Taunt_None,
	Taunt_Repurpose,
	Taunt_UsesWeapon
}

char g_sModelFiles[][] =
{
	SKELETON_KING_MODEL,
	"models/player/skeleton_king_player/skeleton_king_player.dx80.vtx",
	"models/player/skeleton_king_player/skeleton_king_player.dx90.vtx",
	"models/player/skeleton_king_player/skeleton_king_player.phy",
	"models/player/skeleton_king_player/skeleton_king_player.vvd",
	"models/player/skeleton_king_player/skeleton_king_player_animations.mdl"
};

char g_sndLaugh[][] = 
{
	"misc/halloween/skeletons/skelly_giant_01.wav",
	"misc/halloween/skeletons/skelly_giant_02.wav",
	"misc/halloween/skeletons/skelly_giant_03.wav"
};

char g_sndSpawn[][] =
{
	"Announcer.Helltower_Red_Skeleton_King01",
	"Announcer.Helltower_Red_Skeleton_King02",
	"Announcer.Helltower_Red_Skeleton_King03",
	"Announcer.Helltower_Red_Skeleton_King04",
	"Announcer.Helltower_Blue_Skeleton_King01",
	"Announcer.Helltower_Blue_Skeleton_King02",
	"Announcer.Helltower_Blue_Skeleton_King03",
	"Announcer.Helltower_Blue_Skeleton_King04"
};

ConVar cvDropAmmo;
ConVar cvMaxHealth;
ConVar cvMeleeDamage;
ConVar cvStompRadius;
ConVar cvStompDamage;
ConVar cvStompCooldown;
ConVar cvSpellTier;

bool g_bInStomp[MAXPLAYERS + 1];
bool g_bInAnimation[MAXPLAYERS + 1];
bool g_bIsSkeletonKing[MAXPLAYERS + 1];
bool g_bIsAlternate[MAXPLAYERS + 1];
int g_iCrown[MAXPLAYERS + 1] = { -1, ...};
int g_iAnimProp[MAXPLAYERS + 1] = { -1, ...};
float g_flLastSndPlayTime;
float g_flNextStompTime[MAXPLAYERS + 1];
Handle g_hSDKCall_GetMaxHealth;
Handle g_hHudSyncronizer;
Handle g_hHudTimer[MAXPLAYERS + 1];

int g_iRingParticle = -1;
int g_iRedBloodParticle = -1;
int g_iBlueBloodParticle = -1;
int g_iGreenBloodParticle = -1;
int g_iSkeletonModelIndex = -1;
int g_iLastWinningTeam = -1;

public void OnPluginStart()
{	
	LoadTranslations("common.phrases");
	LoadTranslations("beholdskeletonking.phrases");
	
    GameData hGameData = new GameData("sdkhooks.games/engine.ep2v");
    if (!hGameData)
        SetFailState("Failed to find gamedata at sdkhooks.games/engine.ep2v");

    StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

    g_hSDKCall_GetMaxHealth = EndPrepSDKCall();
    if (!g_hSDKCall_GetMaxHealth)
    {
        delete g_hSDKCall_GetMaxHealth;
        SetFailState("Failed to hook SDKCall GetMaxHealth");
    }

    delete hGameData;

	CreateConVar("sm_beholdskeletonking_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvDropAmmo = CreateConVar("sm_beholdskeletonking_dropammo", "0", "Whether Skeleton King should drop an ammo kit on death.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvMaxHealth = CreateConVar("sm_beholdskeletonking_maxhealth", "1000", "Skeleton King max health.", FCVAR_NOTIFY, true, 0.0);
	cvMeleeDamage = CreateConVar("sm_beholdskeletonking_melee_damage", "100", "Skeleton King melee damage.", FCVAR_NOTIFY, true, 0.0);
	cvStompRadius = CreateConVar("sm_beholdskeletonking_stomp_radius", "200", "Skeleton King stomp radius.", FCVAR_NOTIFY, true, 0.0);
	cvStompDamage = CreateConVar("sm_beholdskeletonking_stomp_damage", "100", "Skeleton King stomp damage.", FCVAR_NOTIFY, true, 0.0);
	cvStompCooldown = CreateConVar("sm_beholdskeletonking_stomp_cooldown", "8.0", "Skeleton King stomp cooldown.", FCVAR_NOTIFY, true, 0.0);
	cvSpellTier = CreateConVar("sm_beholdskeletonking_spelltier", "2", "The tier of spell Skeletong King should drop (0 = None, 1 = Normal, 2 = Rare)", FCVAR_NOTIFY, true, 0.0, true, 2.0);

	AutoExecConfig(true, "beholdskeletonking");

	RegAdminCmd("sm_beskeletonking", Command_Skeleton, ADMFLAG_ROOT, "sm_beskeletonking <#userid|name> [health] [0/1 (Default: 0) Use alternate skin] [0/1 (Default: 0) Do spawn animation].");
	
	HookEvent("arrow_impact", Event_OnArrowImpact, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_Resupply);
	HookEvent("player_team", Event_OnPlayerChangeTeam);
	HookEvent("player_death", Event_OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeathPost, EventHookMode_Post);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	
	AddTempEntHook("TFBlood", TempHook);
	AddNormalSoundHook(SoundHook_SkeletonKing);

	g_hHudSyncronizer = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
	for (int i = MaxClients; i; i--)
		if (g_bIsSkeletonKing[i])
			RemoveSkeletonKing(i);
}

public void OnMapStart()
{
	for (int i; i < sizeof(g_sModelFiles); i++)
	{
		if (FileExists(g_sModelFiles[i], true))
			AddFileToDownloadsTable(g_sModelFiles[i]);
		else
			SetFailState("Failed to add '%s' to the downloads table. File does not exist.", g_sModelFiles[i]);
	}
	
	PrecacheModel(CROWN_MODEL, true);
	g_iSkeletonModelIndex = PrecacheModel(SKELETON_KING_MODEL, true);

	PrecacheSound(SND_SPAWN, true);
	PrecacheSound(SND_DEATH, true);
	for (int i; i < sizeof(g_sndLaugh); i++)
		PrecacheSound(g_sndLaugh[i], true);

	for (int i; i < sizeof(g_sndSpawn); i++)
		PrecacheScriptSound(g_sndSpawn[i]);
	
	int iTable = FindStringTable("ParticleEffectNames");
	g_iRingParticle = FindStringIndex(iTable, "bomibomicon_ring");
	g_iRedBloodParticle = FindStringIndex(iTable, "spell_pumpkin_mirv_goop_red");
	g_iBlueBloodParticle = FindStringIndex(iTable, "spell_pumpkin_mirv_goop_blue");
	g_iGreenBloodParticle = FindStringIndex(iTable, "spell_skeleton_goop_green");
}

public void OnClientPutInServer(int iClient)
{
	g_bInStomp[iClient] = false;
	g_bInAnimation[iClient] = false;
	g_bIsAlternate[iClient] = false;
	g_bIsSkeletonKing[iClient] = false;
	g_iCrown[iClient] = -1;
	g_iAnimProp[iClient] = -1;
	g_flNextStompTime[iClient] = 0.0;
}

public void OnClientDisconnect(int iClient)
{
	if (g_bIsSkeletonKing[iClient])
		RemoveSkeletonKing(iClient);
}

Action Command_Skeleton(int iClient, int iArgs)
{
	if (!iClient && iArgs < 1)
	{
		ReplyToCommand(iClient, "%t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_beskeletonking <#userid|name> [health] [0/1 (Default: 0) Use alternate skin] [0/1 (Default: 0) Do spawn animation]");
		return Plugin_Handled;
	}
	
	char sPattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, sPattern, sizeof(sPattern));

	bool bTargetNameIsMultilingual;
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS], iTargetCount;
	if ((iTargetCount = ProcessTargetString(
			sPattern,
			iClient, 
			iTargetList, 
			sizeof(iTargetList), 
			COMMAND_FILTER_ALIVE | (StrEqual(sPattern, "@me") ? COMMAND_FILTER_NO_IMMUNITY : 0),
			sTargetName,
			sizeof(sTargetName),
			bTargetNameIsMultilingual)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}

	bool bAlt, bPerformAnim = true;
	int iHealth;
	if (iArgs > 1)
	{
		iHealth = GetCmdArgInt(2);
		if (iHealth < 1)
			iHealth = cvMaxHealth.IntValue;	

		if (iArgs > 2)
			bAlt = GetCmdArgInt(3) != 0;
		
		if (iArgs > 3)
			bPerformAnim = GetCmdArgInt(4) != 0;
	}
	else
		iHealth = cvMaxHealth.IntValue;	
	
	for (int i; i < iTargetCount; i++)
		if (!g_bIsSkeletonKing[iTargetList[i]])
			CreateSkeletonKing(iTargetList[i], iHealth, bAlt, bPerformAnim);
	
	if (bTargetNameIsMultilingual)
        ShowActivity2(iClient, "[SM] ", "%t", "Create Skeleton King", sTargetName);
    else
        ShowActivity2(iClient, "[SM] ", "%t", "Create Skeleton King", "_s", sTargetName);

	return Plugin_Handled;
}

/*
*	Skeleton King Creation
*/

void CreateSkeletonKing(int iClient, int iHealth = 0, bool bAlt = false, bool bPerformAnim = true)
{
	RemoveSkeletonKing(iClient);
	TF2_RemoveCondition(iClient, TFCond_Taunting);
	TF2_SetPlayerClass(iClient, TFClass_Sniper, _, false);
	TF2_RegeneratePlayer(iClient);
	TF2_RemoveAllItems(iClient);
	
	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");

	SetVariantString("2.0");
	AcceptEntityInput(iClient, "SetModelScale");
	
	SetVariantString(SKELETON_KING_MODEL);
	AcceptEntityInput(iClient, "SetCustomModelWithClassAnimations");

	if (bAlt)
	{
		g_bIsAlternate[iClient] = true;
		SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 1);
		SetEntProp(iClient, Prop_Send, "m_nForcedSkin", TF2_GetClientTeam(iClient) == TFTeam_Red ? 3 : 2);
	}
	
	int iWep = GiveSkeletonWeapon(iClient, iHealth);
	DataPack hData = new DataPack();
	hData.WriteCell(GetClientSerial(iClient));
	hData.WriteCell(bPerformAnim);
	hData.Reset();

	RequestFrame(NextFrame_CreateCrownWorldModel, hData);
	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
	
	if (bPerformAnim)
	{
		SetEntPropFloat(iWep, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
		
		char sAnim[16];
		Format(sAnim, sizeof(sAnim), "spawn0%i", GetRandomInt(1, 7));

		PlayAnimation(iClient, sAnim);
	}

	// This is so players' eardrums don't get blown outSND_COOLDOWN
	static const float SND_COOLDOWN = 5.0;
	if (GetGameTime() - g_flLastSndPlayTime > SND_COOLDOWN)
	{
		EmitGameSoundToAll(SND_SPAWN);
		EmitGameSoundToAll(g_sndSpawn[GetRandomInt(0, sizeof(g_sndSpawn) - 1)]);
		g_flLastSndPlayTime = GetGameTime();
	}

	g_bIsSkeletonKing[iClient] = true;
	g_flNextStompTime[iClient] = GetGameTime() + cvStompCooldown.FloatValue + 2.0;
	g_hHudTimer[iClient] = CreateTimer(0.1, Timer_Hud, GetClientSerial(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void NextFrame_CreateCrownWorldModel(DataPack hData)
{
	int iClient = GetClientFromSerial(hData.ReadCell());
	bool bPerformAnim = hData.ReadCell();
	delete hData;

	if (!iClient || !g_bIsSkeletonKing[iClient])
		return;
	
	g_iCrown[iClient] = EntIndexToEntRef(CreateClientWorldModel(iClient, CROWN_MODEL));
	SetEntProp(g_iCrown[iClient], Prop_Send, "m_iTeamNum", TF2_GetClientTeam(iClient));

	if (bPerformAnim)
		AddEffectFlags(g_iCrown[iClient], EF_NODRAW);
}

void RemoveSkeletonKing(int iClient)
{
	if (!g_bIsSkeletonKing[iClient])
		return;
	
	if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
	{
		FireEntityOutput(g_iAnimProp[iClient], "OnAnimationDone");
		g_iAnimProp[iClient] = -1;
	}
	else
	{
		EndAbility(iClient);
		SetEntityMoveType(iClient, MOVETYPE_WALK);
		SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iClient, 255, 255, 255, 255);
	}
	
	g_bIsSkeletonKing[iClient] = false;
	g_bIsAlternate[iClient] = false;
	delete g_hHudTimer[iClient];

	if (EntRefToEntIndex(g_iCrown[iClient]) != -1)
	{
		RemoveEntity(g_iCrown[iClient]);
		g_iCrown[iClient] = -1;
	}

	SetEntProp(iClient, Prop_Send, "m_bForcedSkin", 0);
	
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");

	SetVariantString("1.0");
	AcceptEntityInput(iClient, "SetModelScale");

	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");
	
	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);

	if (IsPlayerAlive(iClient))
	{
		TF2_RemoveCondition(iClient, TFCond_Taunting);
		TF2_RemoveAllItems(iClient);
		TF2_RegeneratePlayer(iClient);
		SetEntProp(iClient, Prop_Send, "m_iHealth", GetMaxHealth(iClient));
	}
}

int GiveSkeletonWeapon(int iClient, int iHealth)
{
	int iWep = CreateEntityByName("tf_weapon_club");
	SetEntProp(iWep, Prop_Send, "m_bInitialized", true);
	SetEntProp(iWep, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntProp(iWep, Prop_Send, "m_iItemDefinitionIndex", KUKRI);
	SetEntProp(iWep, Prop_Send, "m_iEntityLevel", 100);
	SetEntProp(iWep, Prop_Send, "m_bOnlyIterateItemViewAttributes", true);
	SetEntProp(iWep, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient));

	char sNetClass[32];
	GetEntityNetClass(iWep, sNetClass, sizeof(sNetClass));
    SetEntData(iWep, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 5); // Unusual

	char sFormat[128];
	FormatEx(sFormat, sizeof(sFormat), "self.AddAttribute(\"max health additive bonus\", %i, -1)", iHealth - 125);
	RunScriptCode(iWep, sFormat);

	static const float BASE_MELEE_DAMAGE = 65.0;
	float flDamageMult = cvMeleeDamage.FloatValue / BASE_MELEE_DAMAGE;
	Format(sFormat, sizeof(sFormat), "self.AddAttribute(\"damage bonus\", %f, -1)", flDamageMult);
	RunScriptCode(iWep, sFormat);
	RunScriptCode(iWep, "self.AddAttribute(\"fire rate penalty\", 1.65, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"health from packs decreased\", 0.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"health from healers reduced\", 0.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"cancel falling damage\", 1.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"cannot be backstabbed\", 1.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"crit mod disabled\", 0.0, -1)");
	SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);

	DispatchSpawn(iWep);
	EquipPlayerWeapon(iClient, iWep);

	AddEffectFlags(iWep, EF_NODRAW);

	SetVariantString("!activator");
    AcceptEntityInput(iWep, "SetParent", iClient, iWep);

	return iWep;
}

stock void PlayAnimation(int iClient, char[] sAnim)
{
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, { 0.0, 0.0, 0.0 });
	SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iClient, 255, 255, 255, 0);	
	SetEntityMoveType(iClient, MOVETYPE_NONE);
	
	float vOrigin[3], vAngles[3];
	GetClientAbsOrigin(iClient, vOrigin);
	GetClientAbsAngles(iClient, vAngles);
	vAngles[0] = 0.0;

	int iAnimEntity = CreateEntityByName("prop_dynamic");
	DispatchKeyValueVector(iAnimEntity, "origin", vOrigin);
	DispatchKeyValueVector(iAnimEntity, "angles", vAngles);
	DispatchKeyValue(iAnimEntity, "model", SKELETON_KING_MODEL);
	DispatchKeyValue(iAnimEntity, "defaultanim", sAnim);
	DispatchSpawn(iAnimEntity);
	SetEntPropEnt(iAnimEntity, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntPropFloat(iAnimEntity, Prop_Send, "m_flModelScale", 2.0);

	TFTeam eTeam = TF2_GetClientTeam(iClient);
	int iSkin = g_bIsAlternate[iClient] ? view_as<TFTeam>((eTeam == TFTeam_Red ? 3 : 2)) : eTeam - view_as<TFTeam>(2);
	SetEntProp(iAnimEntity, Prop_Send, "m_nSkin", iSkin);

	// Hide wearable crown and give the anim prop a crown
	if (EntRefToEntIndex(g_iCrown[iClient]) != -1)
		AddEffectFlags(g_iCrown[iClient], EF_NODRAW);
	
	// EF_BONEMERGE and SetParentAttachment (any attachment point) are necessary for the crown to bonemerge properly

	int iProp = CreateEntityByName("prop_dynamic");
	SetEntityModel(iProp, CROWN_MODEL);
	DispatchKeyValueInt(iProp, "skin", eTeam - view_as<TFTeam>(2));
	DispatchKeyValueInt(iProp, "effects", EF_BONEMERGE);
	DispatchSpawn(iProp);

	SetVariantString("!activator");
	AcceptEntityInput(iProp, "SetParent", iAnimEntity);
	SetVariantString("head");
	AcceptEntityInput(iProp, "SetParentAttachment");

	SetVariantString("OnAnimationDone !self:KillHierarchy::0.0:1");
	AcceptEntityInput(iAnimEntity, "AddOutput");
	
	HookSingleEntityOutput(iAnimEntity, "OnAnimationDone", OnAnimationDone, true);
	g_iAnimProp[iClient] = EntIndexToEntRef(iAnimEntity);
	g_bInAnimation[iClient] = true;
}

void OnAnimationDone(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{	
	int iClient = GetEntPropEnt(iCaller, Prop_Send, "m_hOwnerEntity");
	if (!IsEntityClient(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if (g_bInStomp[iClient])
		EndAbility(iClient);
	
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iClient, 255, 255, 255, 255);

	if (EntRefToEntIndex(g_iCrown[iClient]) != -1)
		RemoveEffectFlags(g_iCrown[iClient], EF_NODRAW);

	g_bInAnimation[iClient] = false;
}

/*
*	Ability
*/

void EndAbility(int iClient)
{
	float flGameTime = GetGameTime();
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee != -1)
		SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", flGameTime + 0.5);
	g_flNextStompTime[iClient] = flGameTime + cvStompCooldown.FloatValue;
	g_bInStomp[iClient] = false;
}

void Timer_PerformStomp(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsSkeletonKing[iClient] || !g_bInStomp[iClient])
		return;
	
	float vAngles[3], vOrigin[3];
	GetClientAbsAngles(iClient, vAngles);
	GetClientAbsOrigin(iClient, vOrigin);
	vAngles[0] = 0.0;
	
	float vForward[3], vLeft[3];
	GetAngleVectors(vAngles, vForward, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(vAngles, NULL_VECTOR, vLeft, NULL_VECTOR);
	vOrigin[0] += (vForward[0] * 55);
	vOrigin[1] += (vForward[1] * 55);
	vOrigin[2] += (vForward[2] * 55);
	
	vOrigin[0] += (vLeft[0] * -35);
	vOrigin[1] += (vLeft[1] * -35);
	vOrigin[2] += (vLeft[2] * -35);
	
	TE_SetupTFParticleEffect(g_iRingParticle, vOrigin);
	TE_SendToAll();
	
	int iTeam = GetClientTeam(iClient);
	float flStompDistanceSqr = cvStompRadius.FloatValue * cvStompRadius.FloatValue;
	float vTargetPos[3], vVel[3];
	int iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	for (int i = MaxClients; i; i--)
	{
		if (iClient == i || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == iTeam)
			continue;
		
		GetClientAbsOrigin(i, vTargetPos);
		float flDist = GetVectorDistance(vOrigin, vTargetPos, true);
		if (flDist > flStompDistanceSqr)
			continue;
		
		GetClientEyePosition(i, vTargetPos);
		SubtractVectors(vTargetPos, vOrigin, vVel);
		NormalizeVector(vVel, vVel);
		vVel[2] = 1.0;
		ScaleVector(vVel, 500.0);
		
		char sScript[1024];
		FormatEx(sScript, sizeof(sScript), 
			"::sk <- EntIndexToHScript(%i), " ...
			"self.TakeDamageCustom(sk, sk, %i, Vector(0,0,0), Vector(0,0,0), %i, Constants.FDmgType.DMG_SLASH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_SPELL_SKELETON)",
			iClient, iWeapon, cvStompDamage.IntValue);
		RunScriptCode(i, sScript);
		TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

Action Timer_Hud(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient)
		return Plugin_Stop;
	
	if (GetClientButtons(iClient) & IN_SCORE || IsOnLosingTeam(iClient))
		return Plugin_Continue;
	
	SetHudTextParams(-1.0, 0.75, 0.35, 0, 255, 0, 255, 0, 0.0, 0.0, 0.1);
	
	if (g_bInStomp[iClient])
	{
		ShowSyncHudText(iClient, g_hHudSyncronizer, "%t: %t", "Stomp", "Active");
		return Plugin_Continue;
	}

	float flCooldown = g_flNextStompTime[iClient] - GetGameTime();
	if (flCooldown > 0.0)
		ShowSyncHudText(iClient, g_hHudSyncronizer, "%t: %.1fs", "Stomp", flCooldown);
	else
		ShowSyncHudText(iClient, g_hHudSyncronizer, "%t: %t (MOUSE2)", "Stomp", "Ready!");

	return Plugin_Continue;
}

/*
*	Events
*/

Action Event_OnArrowImpact(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	// Block arrows from getting stuck in Skeleton King so when the player is made invis
	// during the stomp animation, you won't see arrows sticking out of them
	int iClient = hEvent.GetInt("attachedEntity");
	if (IsEntityClient(iClient) && g_bIsSkeletonKing[iClient])
		hEvent.BroadcastDisabled = true;

	return Plugin_Continue;
}

void Event_OnPlayerChangeTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("disconnect"))
		return;
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsSkeletonKing[iClient])
		RemoveSkeletonKing(iClient);
}

void Event_Resupply(Event hEvent, char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsSkeletonKing[iClient])
		RemoveSkeletonKing(iClient);
}

Action Event_OnPlayerDeathPre(Event hEvent, char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("attacker") != 0)
	{
		int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
		if (g_bIsSkeletonKing[iAttacker] && hEvent.GetInt("damagebits") & DMG_CLUB)
		{
			hEvent.SetInt("customkill", TF_CUSTOM_SPELL_SKELETON);
			hEvent.SetString("weapon", "spellbook_skeleton");
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

void Event_OnPlayerDeathPost(Event hEvent, char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!g_bIsSkeletonKing[iClient])
		return;

	RequestFrame(NextFrame_RemoveSkeleton, GetClientSerial(iClient));

	float vOrigin[3];
	GetClientAbsOrigin(iClient, vOrigin);

	BfWrite bf = UserMessageToBfWrite(StartMessageAll("BreakModel", USERMSG_RELIABLE));
	bf.WriteShort(g_iSkeletonModelIndex);

	float vAng[3];
	GetClientAbsAngles(iClient, vAng);
	bf.WriteVecCoord(vOrigin);
	bf.WriteAngles(vAng);

	TFTeam eTeam = TF2_GetClientTeam(iClient);
	bf.WriteShort(g_bIsAlternate[iClient] ? eTeam == TFTeam_Red ? 3 : 2 : eTeam == TFTeam_Red ? 0 : 1);

	EndMessage();
	
	//Drop a Rare spellbook
	int iSpellTier = cvSpellTier.IntValue;
	if (iSpellTier > 0)
	{
		int iSpell = CreateEntityByName("tf_spell_pickup");
		if (!IsValidEntity(iSpell))
			return;

		DispatchKeyValueVector(iSpell, "origin", vOrigin);
		DispatchKeyValueVector(iSpell, "basevelocity", { 0.0, 0.0, 0.0 });
		DispatchKeyValueVector(iSpell, "velocity", { 0.0, 0.0, 0.0 });
		if (iSpellTier == 1)
			DispatchKeyValue(iSpell, "powerup_model", "models/props_halloween/hwn_spellbook_upright.mdl");
		else
			DispatchKeyValue(iSpell, "powerup_model", "models/props_halloween/hwn_spellbook_upright_major.mdl");
		DispatchKeyValue(iSpell, "OnPlayerTouch", "!self,Kill,,0,-1");
		
		DispatchSpawn(iSpell);
		
		SetVariantString("OnUser1 !self:kill::60:1");
		AcceptEntityInput(iSpell, "AddOutput");
		AcceptEntityInput(iSpell, "FireUser1");
		
		SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
		SetEntProp(iSpell, Prop_Data, "m_nTier", iSpellTier - 1);
	}

	EmitSoundToAll(SND_DEATH, iClient);

	for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_dropped_weapon")) != -1;)
	{
		int iAccountID = GetSteamAccountID(iClient, false);
		if (iAccountID == GetEntProp(iEnt, Prop_Send, "m_iAccountID"))
			RemoveEntity(iEnt);
	}

	if (!cvDropAmmo.BoolValue)
	{
		for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_ammo_pack")) != -1;)
		{
			int iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
			if (IsEntityClient(iOwner))
			{
				RemoveEntity(iEnt);
				break;
			}
		}
	}
}

void NextFrame_RemoveSkeleton(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (iClient)
		RemoveSkeletonKing(iClient);
	
	int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (iRagdoll != -1)
		SetEdictFlags(iRagdoll, FL_EDICT_DONTSEND);
}

void Event_OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = -1;
}

void Event_OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = hEvent.GetInt("team");
}

/*
*	Hooks
*/

public Action TempHook(const char[] sName, const int[] iPlayers, int iNumClients, float flDelay)
{
	int iClient = TE_ReadNum("entindex");
	if (!g_bIsSkeletonKing[iClient])
		return Plugin_Continue;
	
	float vOrigin[3];
	vOrigin[0] = TE_ReadFloat("m_vecOrigin[0]");
	vOrigin[1] = TE_ReadFloat("m_vecOrigin[1]");
	vOrigin[2] = TE_ReadFloat("m_vecOrigin[2]");
	
	if (g_bIsAlternate[iClient])
		TE_SetupTFParticleEffect(TF2_GetClientTeam(iClient) == TFTeam_Red ? g_iRedBloodParticle : g_iGreenBloodParticle, vOrigin, _, _, _, PATTACH_WORLDORIGIN);
	else
		TE_SetupTFParticleEffect(TF2_GetClientTeam(iClient) == TFTeam_Red ? g_iRedBloodParticle : g_iBlueBloodParticle, vOrigin, _, _, _, PATTACH_WORLDORIGIN);
	TE_SendToAll();

	return Plugin_Stop;
}

Action SoundHook_SkeletonKing(int iClients[MAXPLAYERS], int &iNumClients, char sSample[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &iVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[256], int &iSeed)
{
	if (!IsEntityClient(iEntity) || !g_bIsSkeletonKing[iEntity])
		return Plugin_Continue;

	if (strncmp(sSample, "vo/sniper", 9, false) != 0 && strncmp(sSample, "vo\\sniper", 9, false) != 0 
		&& strncmp(sSample, "vo/taunts/sniper", 16, false) != 0 && strncmp(sSample, "vo\\taunts\\sniper", 16, false) != 0)
		return Plugin_Continue;

	if (strncmp(sSample, "vo/sniper_pain", 14, false) == 0)
		return Plugin_Handled;

	// Voicelines trigger sound hooks multiple times
	static char sLastVO[64];
	static int iLastVOTick[MAXPLAYERS];
	if (iLastVOTick[iEntity] != GetGameTickCount())
	{
		iLastVOTick[iEntity] = GetGameTickCount();
		strcopy(sLastVO, sizeof(sLastVO), g_sndLaugh[GetRandomInt(0, 2)]);
	}
	
	strcopy(sSample, sizeof(sSample), sLastVO);

	return Plugin_Changed;
}

void Hook_OnPostThinkPost(int iClient)
{
	// Stomp attack
	if (IsControlStunned(iClient) || IsOnLosingTeam(iClient))
	{
		if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
			FireEntityOutput(g_iAnimProp[iClient], "OnAnimationDone", iClient);
	}
	else if (g_bInAnimation[iClient])
	{
		if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
		{
			float vAng[3];
			GetClientAbsAngles(iClient, vAng);
			TeleportEntity(g_iAnimProp[iClient], NULL_VECTOR, vAng);
		}
	}
	else if (TF2_IsPlayerInCondition(iClient, TFCond_Taunting)) 
	{
		int iTauntIndex = GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex");
		int iActiveWep = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
		switch (GetTauntWeaponState(iTauntIndex))
		{
			case Taunt_None, Taunt_UsesWeapon: SetEntityInvis(iActiveWep, true);
			case Taunt_Repurpose: SetEntityInvis(iActiveWep, false);
		}
	}
	else
	{
		int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if (iMelee == -1)
			return;

		float flGameTime = GetGameTime();
		int iWep = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
		if (iMelee == iWep && g_flNextStompTime[iClient] - flGameTime < 0.0 
			&& GetEntPropFloat(iWep, Prop_Send, "m_flNextPrimaryAttack") < flGameTime
			&& (GetEntProp(iClient, Prop_Data, "m_nButtons") & IN_ATTACK2) 
			&& GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1
			&& !IsOnLosingTeam(iClient))
		{
			g_bInStomp[iClient] = true;
			PlayAnimation(iClient, "MELEE_swing3");
			SetEntPropFloat(iWep, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
			CreateTimer(0.9, Timer_PerformStomp, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
			SetEntityInvis(iMelee, true);
	}
}

/*
*	Utility
*/

int GetMaxHealth(int iClient)
{
	return SDKCall(g_hSDKCall_GetMaxHealth, iClient);
}

bool IsOnLosingTeam(int iClient)
{
	return g_iLastWinningTeam != -1 && g_iLastWinningTeam != GetClientTeam(iClient);
}

// This determines which taunts should hide the tf_wearable world model. Covers every taunt up until Halloween 2026.
int GetTauntWeaponState(int iTauntIndex)
{
	switch (iTauntIndex)
	{
		case 167, 438, 463, 1106, 1107, 1110, 1111, 1116, 1118, 1157, 1162, 1183, 31162, 31288, 31413, 31441, 31467, 31577: return Taunt_None;
		case 1015, 1172, 1182, 30609, 30614, 30621, 30672, 30816, 30839, 31237, 31348, 31412, 31440, 31492, 31518, 31521: return Taunt_Repurpose;
		case -1: return Taunt_UsesWeapon;
		default: return Taunt_None;
	}
}

/*
*	Natives
*/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iSize)
{
	CreateNative("BeholdSkeletonKing_Create", Native_CreateSkeletonKing);
	CreateNative("BeholdSkeletonKing_Remove", Native_RemoveSkeletonKing);
	CreateNative("BeholdSkeletonKing_IsBoss", Native_IsSkeletonKing);
	CreateNative("BeholdSkeletonKing_IsStomping", Native_IsStomping);
	
	RegPluginLibrary("beholdskeletonking");
	
	return APLRes_Success;
}

any Native_CreateSkeletonKing(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (g_bIsSkeletonKing[iClient])
		return false;

	int iHealth = GetNativeCell(2);
	if (iHealth < 1)
		iHealth = cvMaxHealth.IntValue;

	CreateSkeletonKing(GetNativeCell(1), iHealth, GetNativeCell(3), GetNativeCell(4));
	return true;
}

any Native_RemoveSkeletonKing(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (!g_bIsSkeletonKing[iClient])
		return false;
	
	RemoveSkeletonKing(iClient);
	return true;
}

any Native_IsSkeletonKing(Handle hPlugin, int iNumParams)
{
	return g_bIsSkeletonKing[GetNativeCell(1)];
}

any Native_IsStomping(Handle hPlugin, int iNumParams)
{
	return g_bInStomp[GetNativeCell(1)];
}

/*
*	Stocks
*/

stock bool IsEntityClient(int iEntity)
{
	return 0 < iEntity <= MaxClients;
}

stock bool IsControlStunned(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_iStunFlags") & (TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_BONKSTUCK);
}

stock void GetClientCenter(int iClient, float vCenter[3])
{
    float vOrigin[3], vMaxs[3];
    GetClientMaxs(iClient, vMaxs);
    GetClientAbsOrigin(iClient, vOrigin);
    vCenter[0] = vOrigin[0];
    vCenter[1] = vOrigin[1];
    vCenter[2] = vMaxs[2] * 0.5 + vOrigin[2];
}

stock void TF2_RemoveAllItems(int iClient)
{
    TF2_RemoveAllWeapons(iClient);
    TF2_RemoveAllWearables(iClient);
}

stock void TF2_RemoveAllWearables(int iClient)
{
	int iNextMovePeer = -1;
	int iMoveChild = GetEntPropEnt(iClient, Prop_Data, "m_hMoveChild");
    if (iMoveChild == -1)
		return;
	
	do
	{
		char sChildName[12];
		GetEntityClassname(iMoveChild, sChildName, sizeof(sChildName));
		iNextMovePeer = GetEntPropEnt(iMoveChild, Prop_Data, "m_hMovePeer");
		
		if (StrContains(sChildName, "tf_wearable") == 0 || StrContains(sChildName, "tf_powerup") == 0)
			TF2_RemoveWearable(iClient, iMoveChild);
	}
	while ((iMoveChild = iNextMovePeer) != -1);
}

stock int CreateClientWorldModel(int iClient, char[] sModelName)
{
    int iWorldModel = CreateEntityByName("tf_wearable");
    
    PrecacheModel(sModelName, true);
    SetEntityModel(iWorldModel, sModelName);
    SetEntProp(iWorldModel, Prop_Data, "m_bForcePurgeFixedupStrings", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bValidatedAttachedEntity", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bInitialized", true);
    SetEntPropEnt(iWorldModel, Prop_Data, "m_hOwnerEntity", iClient);
    DispatchSpawn(iWorldModel);
    SetVariantString("!activator");
    AcceptEntityInput(iWorldModel, "SetParent", iClient);

    // Removes preserved entity status, won't persist through rounds
    SetEntPropString(iWorldModel, Prop_Data, "m_iClassname", "tf_custom_wearable"); 
    
    return iWorldModel;
}

stock void RunScriptCode(int iEntity, char[] sScript)
{
	SetVariantString(sScript);
    AcceptEntityInput(iEntity, "RunScriptCode");
}

stock void SetEntityInvis(int iEntity, bool bInvis)
{
	int iColor = GetEntProp(iEntity, Prop_Send, "m_clrRender");
	if (bInvis)
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.0);
		if ((iColor & 0xFF000000) != 0)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor & ~0xFF000000);
	}
	else
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 1.0);
		if ((iColor & 0xFF000000) != 0xFF000000)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor | 0xFF000000);
	}
}

stock void AddEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags) != iFlags)
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects | iFlags);
}

stock void RemoveEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags))
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects & ~iFlags);
}

enum ParticleAttachment_t
{
	PATTACH_ABSORIGIN = 0,
	PATTACH_ABSORIGIN_FOLLOW,
	PATTACH_CUSTOMORIGIN,
	PATTACH_POINT,
	PATTACH_POINT_FOLLOW,
	PATTACH_WORLDORIGIN,
	PATTACH_ROOTBONE_FOLLOW
};

stock void TE_SetupTFParticleEffect(
	int iParticleIndex, 
	const float vOrigin[3] = NULL_VECTOR, 
	const float vStart[3] = NULL_VECTOR,
	const float vAngles[3] = NULL_VECTOR, 
	int iEntity = -1, 
	ParticleAttachment_t iAttachType = view_as<ParticleAttachment_t>(-1), 
	int iAttachPoint = -1,
	int iControlPoint1 = -1,
	ParticleAttachment_t eParticleAttachment = view_as<ParticleAttachment_t>(-1),
	float vParticleOffset[3] = { 0.0, 0.0, 0.0 })
{
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vStart[0]);
	TE_WriteFloat("m_vecStart[1]", vStart[1]);
	TE_WriteFloat("m_vecStart[2]", vStart[2]);
	TE_WriteVector("m_vecAngles", vAngles);
	TE_WriteNum("m_iParticleSystemIndex", iParticleIndex);
	TE_WriteNum("entindex", iEntity);
	TE_WriteNum("m_iAttachType", view_as<int>(iAttachType));
	TE_WriteNum("m_iAttachmentPointIndex", iAttachPoint);
	TE_WriteNum("m_bResetParticles", true);
	TE_WriteNum("m_bControlPoint1", iControlPoint1);
	TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", eParticleAttachment);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", vParticleOffset[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", vParticleOffset[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", vParticleOffset[2]);
}
