#if defined _beholdskeletonking_included_
  #endinput
#endif
#define _beholdskeletonking_included_

#define LIB_BEHOLDSKELETONKING "beholdskeletonking"

/**
 * Turns a client into the Skeleton King.
 *
 * @param iClient			Index of the client.
 * @param iHealth			The client's health, leave as 0 or below to use the convar health value.
 * @param bAlt			    Whether to use the alternate skin for the client's team.
 * @param bPerformAnim		Whether to perform a rising from the ground animation before becoming actionable.
 * @return Whether the client was turned into the Skeleton King.
 */
native bool BeholdSkeletonKing_Create(int iClient, int iHealth = 0, bool bAlt = false, bool bPerformAnim = true);

/**
 * Removes the Skeleton King transformation from a client.
 *
 * @param iClient			Index of the client.
 * @return Whether the client was the Skeleton King.
 */
native bool BeholdSkeletonKing_Remove(int iClient);

/**
 * Whether the client is the Skeleton King.
 */
native bool BeholdSkeletonKing_IsBoss(int iClient);

/**
 * Whether the client is stomping as the Skeleton King.
 */
native bool BeholdSkeletonKing_IsStomping(int iClient);

public SharedPlugin __pl_beholdskeletonking = 
{
	name = LIB_BEHOLDSKELETONKING,
	file = LIB_BEHOLDSKELETONKING ... ".smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_beholdskeletonking_SetNTVOptional()
{
	MarkNativeAsOptional("BeholdSkeletonKing_Create");
	MarkNativeAsOptional("BeholdSkeletonKing_Remove");
	MarkNativeAsOptional("BeholdSkeletonKing_IsBoss");
	MarkNativeAsOptional("BeholdSkeletonKing_IsStomping");
}
#endif
