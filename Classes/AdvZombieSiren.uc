/*
 * Modified Siren - blind and deadly.
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */
class AdvZombieSiren extends AdvZombieSirenBase
    abstract;

// todo: make her take extra dmg from fire

var bool bEnableLiterallyBlind;         // When the Siren is not near any zeds, or isn't taking any gun fire, she loses her ability to path effectively. When entering this state, she starts screaming helpessly.
var bool bEnableNewScreamMechanics;     // Sirens scream when they're in pain or when she hears the death rattle of nearby zeds. She stops screaming when a Fleshpound rages, a Scrake bumps into her, or taking blunt melee damage.
var bool bEnableNewScreamCancel;        // Sirens will not be able to scream for a short time after taking any headshot damage. Headshotting interrupts any active scream.
var bool bEnablePullingScream;          // Sirens can pull in players and projectiles alike. Locked to Hard and above.
var bool bEnableExtinguishingScream;    // Sirens screams extinguishes flames and any burning zeds that are nearby. Locked to Suicidal and above.
var bool bEnableDestructiveScream;      // Sirens screams can detonate explosives and destroy projectiles. Players carrying explosives immediately explode if they're too close. Locked to HoE and above.