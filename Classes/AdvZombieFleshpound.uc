/*
 * Modified Fleshpound
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieFleshpound extends AdvZombieFleshpoundBase
    abstract;

// Base changes TODO:
// Melee attack when raged = instant kill
// Modified Clot Headloss animation used when hit by LAW rocket as a new stun mechanic(?)

var bool bEnablePush;                       // Fleshpounds deal heavy damage to players blocking their path while raged
var bool bEnableSmartTargetPriority;        // Fleshpounds use their intelligence to analyze the situation before selecting their target. Targets HVTs(Demos > Sharpshooters > Medics), players that are low on health, or unarmored. Takes into account distance as well.
var bool bEnableBlock;                      // Fleshpounds place their hands infront of them to block bullets and projectiles.
// We already have bloats explode when on fire, and husks have(or might not have) a suicide bomb attack, so how can we make his explosion unique? A stun effect? Shrapnel everywhere?
var bool bEnableSelfDestructOnDeath;        // Fleshpounds explode on death - Toontown style.