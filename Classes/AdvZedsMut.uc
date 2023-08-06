/*
 * Mutator that replaces regular zeds with their advanced variants
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : MIT
 * Copyright    : 2023 theengineertcr
*/
class AdvZedsMut extends Mutator
    config(KFAdvZeds);


// Load all relevant packages
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx
#exec OBJ LOAD FILE=AdvZeds_SND.uax


//Config options

var config bool bEnableHuskMoveAndShoot;                // Allows Husks to shoot and move at the same time
var config bool bEnableHuskFlamethrower;                // Allows Husks to use their flamethrower attack
var config bool bEnableHuskFlameAndMove;                // Allows Husks to use their flamethrower and move at the same time
var config bool bEnableStalkerDisorientingAttacks;      // Allows Stalkers to shake the targets view, causing them to be disoriented
var config bool bEnableStalkerPiercingAttacks;            // Allows Stalkers to pierce through the targets armour when behind them, dealing direct damage to their health
var config bool bEnableStalkerLeapIfSpotted;            // Allows Stalkers to leap behind their target if they're facing towards them and they're close
var config bool bEnableStalkerPreservativeDodge;           // Allows Stalkers to dodge away from danger to preserve their own life
var config int StalkerStealthLevel;                        // Stalkers Stealth Level. Affects both sounds and texture
var config bool bIgnoreDifficulty;                      // All special abilities are enabled on all difficulties based on the user's settings


//=======================================
//          PostBeginPlay
//=======================================

event PostBeginPlay()
{
    local KFGameType KF;

    super.PostBeginPlay();

    KF = KFGameType(Level.Game);

    if (KF == none)
    {
        log("KFGameType not found, terminating!", self.name);
        Destroy();
        return;
    }

    if (KF.MonsterCollection == class'KFGameType'.default.MonsterCollection) {
        KF.MonsterCollection = class'AdvZedsMCollection';
    }

    if (KF.MonsterCollection.default.MonsterClasses[3].MClassName != "")
        KF.MonsterCollection.default.MonsterClasses[3].MClassName = string(class'AdvZombieStalker_S');
    if (KF.MonsterCollection.default.MonsterClasses[8].MClassName != "")
        KF.MonsterCollection.default.MonsterClasses[8].MClassName = string(class'AdvZombieHusk_S');

    //Husk Configs
    class'AdvZombieHusk_S'.default.bEnableHuskMoveAndShoot = bEnableHuskMoveAndShoot;
    class'AdvZombieHusk_S'.default.bEnableHuskFlamethrower = bEnableHuskFlamethrower;
    class'AdvZombieHusk_S'.default.bEnableHuskFlameAndMove = bEnableHuskFlameAndMove;

    //Stalker Configs
    class'AdvZombieStalker_S'.default.bDisorientingAttacks = bEnableStalkerDisorientingAttacks;
    class'AdvZombieStalker_S'.default.bPiercingAttacks     = bEnableStalkerPiercingAttacks;
    class'AdvZombieStalker_S'.default.bLeapIfSpotted       = bEnableStalkerLeapIfSpotted;
    class'AdvZombieStalker_S'.default.bPreservativeDodge   = bEnableStalkerPreservativeDodge;

    StalkerStealthLevel = clamp(StalkerStealthLevel, 0, 3);
    class'AdvZombieStalker_S'.default.StealthLevel = StalkerStealthLevel;

    // General Configs
    if(bIgnoreDifficulty)
    {
        class'AdvZombieStalker_S'.default.bIgnoreDifficulty = bIgnoreDifficulty;
        class'AdvZombieHusk_S'.default.bIgnoreDifficulty    = bIgnoreDifficulty;
    }
}


//=======================================
//          Mutator Info
//=======================================

static function FillPlayInfo(PlayInfo PlayInfo)
{
    super(Info).FillPlayInfo(PlayInfo);

    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskMoveAndShoot", "Husk: Move and Shoot", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskFlamethrower", "Husk: Flamethrower", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableHuskFlameAndMove", "Husk: Flamethrower and Move", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerDisorientingAttacks", "Stalker: Disorienting Attack", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerPiercingAttacks", "Stalker: Piercing Attack", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerLeapIfSpotted", "Stalker: Leap Behind Target", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bEnableStalkerPreservativeDodge", "Stalker: Preservative Dodge", 0, 0, "Check",,,,false);
    PlayInfo.AddSetting(default.FriendlyName, "StalkerStealthLevel", "Stalker: Stealth Level", 0, 0, "Text","1;0:3",,,false);
    PlayInfo.AddSetting(default.FriendlyName, "bIgnoreDifficulty", "General: Ignore Difficulty", 0, 0, "Check",,,,false);
}


static event string GetDescriptionText(string Property)
{
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

//=======================================
//          DefaultProperties
//=======================================

defaultproperties
{
    // Don't be active with TWI muts
    GroupName="KF-MonsterMut"
    FriendlyName="Advanced Zeds"
    Description="Replaces zeds with advanced versions of themselves that use special moves."

    bAlwaysRelevant=true
    RemoteRole=ROLE_SimulatedProxy
    bAddToServerPackages=true

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