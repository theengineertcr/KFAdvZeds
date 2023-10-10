/*
 * Modified Patriarch
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombiePatriarch extends AdvZombiePatriarchBase
    abstract;

// TODO:
// Doesn't charge unless he takes damage while cloaked
// Cloak gradually weakens when he goes to heal, making him flicker more.

var bool bEnableDismemberment;          // Can lose his arms, head, and stomach tentacle. I would do legs too, but I can't animate :))))
var bool bEnableSmartTargetPriority;    // Focuses on hurt/armoured players.
var bool bEnableSuckle;                 // The stomach tentacle grabs a player, stunning them and and sucks the life out of them, healing the Patriarch. Player is freed when Patriarch is knocked down.
var bool bSyringeOfRegrowth;            // Patriarch can restore destroyed limbs by healing himself.
var bool bBagOfRockets;                 // Patriarch fires various types of rockets. Chemical rockets to block off a small-medium area permanently(turns the floor into lava, except it's gas). Smoke for escape. Sound for disorientation. Incendiary for wide area denial(lasts for a short while). Cluster for reaching around cover/corners.
var bool bHomingRockets;                // Rockets home in on players. Uses "lesser" rockets that deals less damage, but enough to hurt players badly.
var int StealthLevel;                   // Just like the Stalker, his cloak is harder to see and he's harder to hear.