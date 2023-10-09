/*
 * Modified Bloat
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */

class AdvZombieBloat extends AdvZombieBloatBase
    abstract;


var bool bEnableAbsorption;           // Stops projectiles and hitscan weapons with penetration from going through him. Does not affect damage.
var bool bEnableNewBurnBehaviour;     // When Bloats die while on fire, their body explodes into flames and ignites anyone nearby.
var bool bEnableUsedAsCover;          // Zeds use him as a cover. Locked to Hard and above.
var bool bEnableHeadlessBileSpray;    // While headless, Bloats spray bile from their neck until they die. Locked to Suicidal and above.
var bool bEnableBileRemains;          // Bile on the floor is equivalent to standing in lava, burning players to death. Locked to HoE and above.