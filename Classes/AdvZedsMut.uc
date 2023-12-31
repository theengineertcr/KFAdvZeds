/*
 * Mutator that replaces regular zeds with their advanced variants
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvZedsMut extends Mutator
    config(KFAdvZeds);

// Load all relevant packages
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx
#exec OBJ LOAD FILE=AdvZeds_SND.uax

// Array that stores all the replacement pairs
var array<struct oldNewZombiePair {
    var string oldClass;
    var string newClass;
}> replacementArray;
var array<string> replCaps;

// Replicated data
var int RepStalkerStealthLevel;

// Config options
var config bool bEnableHuskMoveAndShoot;                // Allows Husks to shoot and move at the same time
var config bool bEnableHuskFlamethrower;                // Allows Husks to use their flamethrower attack
var config bool bEnableHuskFlameAndMove;                // Allows Husks to use their flamethrower and move at the same time
var config bool bEnableStalkerDisorientingAttacks;      // Allows Stalkers to shake the targets view, causing them to be disoriented
var config bool bEnableStalkerPiercingAttacks;          // Allows Stalkers to pierce through the targets armour when behind them, dealing direct damage to their health
var config bool bEnableStalkerLeapIfSpotted;            // Allows Stalkers to leap behind their target if they're facing towards them and they're close
var config bool bEnableStalkerPreservativeDodge;        // Allows Stalkers to dodge away from danger to preserve their own life
var config int StalkerStealthLevel;                     // Stalkers Stealth Level. Affects both sounds and texture
var config bool bIgnoreDifficulty;                      // All special abilities are enabled on all difficulties based on the user's settings

replication {
    reliable if (Role == ROLE_Authority)
        RepStalkerStealthLevel;
}

simulated function PostNetBeginPlay() {
    RepStalkerStealthLevel = clamp(RepStalkerStealthLevel, 0, 3);
    class'AdvZombieStalker'.default.StealthLevel = RepStalkerStealthLevel;
}

event PostBeginPlay() {
    local KFGameType KF;
    local array<string> mcCaps;
    local int i, k;

    super.PostBeginPlay();

    KF = KFGameType(Level.Game);
    if (KF == none) {
        log("KFGameType not found, terminating!", self.name);
        Destroy();
        return;
    }

    if (KF.MonsterCollection == class'KFGameType'.default.MonsterCollection) {
        KF.MonsterCollection = class'AdvZedsMCollection';
    }

    for (i= 0; i < KF.MonsterCollection.default.MonsterClasses.Length; i++) {
        mcCaps[mcCaps.Length] = Caps(KF.MonsterCollection.default.MonsterClasses[i].MClassName);
    }
    for (i= 0; i < replacementArray.Length; i++) {
        replCaps[replCaps.Length] = Caps(replacementArray[i].oldClass);
    }
    // Replace all instances of the old specimens with the new ones
    for (i= 0; i < mcCaps.Length; i++) {
        for (k= 0; k < replCaps.Length; k++) {
            if (InStr(mcCaps[i], replCaps[k]) != -1) {
                log(
                    "KFAdvZeds - Replacing" @
                    KF.MonsterCollection.default.MonsterClasses[i].MClassName @
                    "with" @
                    replacementArray[k].newClass
                );
                KF.MonsterCollection.default.MonsterClasses[i].MClassName =
                    replacementArray[k].newClass;
            }
        }
    }

    // Replace the special squad arrays
    replaceSpecialSquad(KF.MonsterCollection.default.ShortSpecialSquads);
    replaceSpecialSquad(KF.MonsterCollection.default.NormalSpecialSquads);
    replaceSpecialSquad(KF.MonsterCollection.default.LongSpecialSquads);
    replaceSpecialSquad(KF.MonsterCollection.default.FinalSquads);

    // KF.MonsterCollection.default.EndGameBossClass = PLACEHOLDER;
    KF.MonsterCollection.default.FallbackMonsterClass = string(class'AdvZombieStalker');

    for (i= 0; i < KF.SpecialEventMonsterCollections.Length; i++) {
        KF.SpecialEventMonsterCollections[i] = KF.MonsterCollection;
    }

    // Husk Configs
    class'AdvZombieHusk'.default.bEnableHuskMoveAndShoot = bEnableHuskMoveAndShoot;
    class'AdvZombieHusk'.default.bEnableHuskFlamethrower = bEnableHuskFlamethrower;
    class'AdvZombieHusk'.default.bEnableHuskFlameAndMove = bEnableHuskFlameAndMove;
    // Stalker Configs
    class'AdvZombieStalker'.default.bDisorientingAttacks = bEnableStalkerDisorientingAttacks;
    class'AdvZombieStalker'.default.bPiercingAttacks     = bEnableStalkerPiercingAttacks;
    class'AdvZombieStalker'.default.bLeapIfSpotted       = bEnableStalkerLeapIfSpotted;
    class'AdvZombieStalker'.default.bPreservativeDodge   = bEnableStalkerPreservativeDodge;

    if ((KF.GameDifficulty <= 2.0 && !bIgnoreDifficulty) || StalkerStealthLevel == 0 && bIgnoreDifficulty) {
        RepStalkerStealthLevel = 0;
    } else if( (KF.GameDifficulty <= 4.0 && !bIgnoreDifficulty) || StalkerStealthLevel == 1 && bIgnoreDifficulty) {
        RepStalkerStealthLevel = 1;
    } else if((KF.GameDifficulty <= 5.0 && !bIgnoreDifficulty) || StalkerStealthLevel == 2 && bIgnoreDifficulty) {
        RepStalkerStealthLevel = 2;
    } else if( (KF.GameDifficulty > 5.0 && !bIgnoreDifficulty) || StalkerStealthLevel == 3 && bIgnoreDifficulty) {
        RepStalkerStealthLevel = 3;
    }

    // General Configs
    if (bIgnoreDifficulty) {
        class'AdvZombieStalker'.default.bIgnoreDifficulty = bIgnoreDifficulty;
        class'AdvZombieHusk'.default.bIgnoreDifficulty = bIgnoreDifficulty;
    }
}

// Replaces the zombies in the given squadArray
function replaceSpecialSquad(out array<KFMonstersCollection.SpecialSquad> squadArray) {
    local int i,j,k;

    for (j=0; j<squadArray.Length; j++) {
        for (i=0;i<squadArray[j].ZedClass.Length; i++) {
            for (k=0; k<replacementArray.Length; k++) {
                if (InStr(Caps(squadArray[j].ZedClass[i]), replCaps[k]) != -1) {
                    squadArray[j].ZedClass[i] = replacementArray[k].newClass;
                }
            }
        }
    }
}

static function FillPlayInfo(PlayInfo PlayInfo) {
    super(Info).FillPlayInfo(PlayInfo);

    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskMoveAndShoot", "Husk: Move and Shoot", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskFlamethrower", "Husk: Flamethrower", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskFlameAndMove", "Husk: Flamethrower and Move", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerDisorientingAttacks", "Stalker: Disorienting Attack", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerPiercingAttacks", "Stalker: Piercing Attack", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerLeapIfSpotted", "Stalker: Leap Behind Target", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerPreservativeDodge", "Stalker: Preservative Dodge", 0, 0, "Check",,,, false);
    PlayInfo.AddSetting(default.FriendlyName, "StalkerStealthLevel", "Stalker: Stealth Level", 0, 0, "Text","1;0:3",,, false);
    PlayInfo.AddSetting(default.FriendlyName, "bIgnoreDifficulty", "General: Ignore Difficulty", 0, 0, "Check",,,, false);
}

static event string GetDescriptionText(string Property) {
    switch (Property)
    {
        case "bEnableHuskMoveAndShoot":
            return "Allows Husks to have a chance to move and shoot their Husk Cannon.";
        case "bEnableHuskFlamethrower":
            return "Allows Husks to use their Flamethrower attack on close players.";
        case "bEnableHuskFlameAndMove":
            return "Allows Husks to have a chance to move while using their Flamethrower attack.";
        case "bEnableStalkerDisorientingAttacks":
            return "Allows Stalkers to disorient the player's view with a strike if they're not exhausted from leaping. Backstabs always disorient the player's view.";
        case "bEnableStalkerPiercingAttacks":
            return "Allows Stalkers to deal damage to a players health through armour on a backstab.";
        case "bEnableStalkerLeapIfSpotted":
            return "Allows Stalkers to leap behind their target if the target is looking in her direction.";
        case "bEnableStalkerPreservativeDodge":
            return "Allows Stalkers to dodge out of the way of grenades and from any zeds that have died next to her.";
        case "StalkerStealthLevel":
            return "How difficult it is to hear or see a Stalker.";
        case "bIgnoreDifficulty":
            return "All of the zeds special moves are enabled on all difficulties instead of being restricted to higher ones.";
        default:
            return super.GetDescriptionText(Property);
    }
}

defaultproperties {
    // Don't be active with TWI muts
    GroupName="KF-MonsterMut"
    FriendlyName="Advanced Zeds"
    Description="Replaces zeds with advanced versions of themselves that use special moves."

    bAlwaysRelevant=true
    RemoteRole=ROLE_SimulatedProxy
    bAddToServerPackages=true

    replacementArray(0)=(oldClass="KFChar.ZombieHusk",newClass="KFAdvZeds.AdvZombieHusk")
    replacementArray(1)=(oldClass="KFChar.ZombieStalker",newClass="KFAdvZeds.AdvZombieStalker")
    replacementArray(2)=(oldClass="KFChar.ZombieClot",newClass="KFAdvZeds.AdvZombieClot")
    replacementArray(3)=(oldClass="KFChar.ZombieBloat",newClass="KFAdvZeds.AdvZombieBloat")
    replacementArray(4)=(oldClass="KFChar.ZombieSiren",newClass="KFAdvZeds.AdvZombieSiren")

    bEnableHuskMoveAndShoot=true
    bEnableHuskFlamethrower=true
    bEnableHuskFlameAndMove=true
    bEnableStalkerDisorientingAttacks=true
    bEnableStalkerLeapIfSpotted=true
    bEnableStalkerPiercingAttacks=true
    bEnableStalkerPreservativeDodge=true
    StalkerStealthLevel=0
    bIgnoreDifficulty=false
}