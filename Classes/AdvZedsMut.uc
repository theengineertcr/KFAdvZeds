// Mutator that replaces regular zeds with their advanced variants

class AdvZedsMut extends Mutator
    config(AdvZedsConfig);


// Load all relevant packages
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx
#exec OBJ LOAD FILE=AdvZeds_SND.uax


//Config options

var config bool bEnableHuskMoveAndShoot;    // Allows Husks to shoot and move at the same time
var config bool bEnableHuskFlamethrower;    // Allows Husks to use their flamethrower attack
var config bool bEnableHuskFlameAndMove;    // Allows Husks to use their flamethrower and move at the same time
var config bool bIgnoreDifficulty;          // All special moves are enabled on all difficulties


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

    if (KF.MonsterCollection.default.MonsterClasses[8].MClassName != "")
        KF.MonsterCollection.default.MonsterClasses[8].MClassName = string(class'AdvZombieHusk_S');

    //Husk Configs
    if(bEnableHuskMoveAndShoot)
        class'AdvZombieHusk_S'.default.bEnableHuskMoveAndShoot = true;
    if(bEnableHuskFlamethrower)
        class'AdvZombieHusk_S'.default.bEnableHuskFlamethrower = true;
    if(bEnableHuskFlameAndMove)
        class'AdvZombieHusk_S'.default.bEnableHuskFlameAndMove = true;

    // General Configs
    if(bIgnoreDifficulty)
        class'AdvZombieHusk_S'.default.bIgnoreDifficulty = true;
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
    PlayInfo.AddSetting(default.FriendlyName, "bIgnoreDifficulty", "General: Ignore Difficulty", 0, 0, "Check",,,,false);
}


static event string GetDescriptionText(string Property)
{
  switch (Property)
  {
    case "bEnableHuskMoveAndShoot":
      return "Allows Husks to have a chance to move and shoot their Husk Cannon.";
    case "bEnableHuskFlamethrower":
      return "Allows Husks to have a chance to use their Flamethrower attack on close players.";
    case "bEnableHuskFlameAndMove":
        return "Allows Husks to have a chance to move while using their Flamethrower attack.";
    case "bIgnoreDifficulty":
        return "All of the zeds special moves are enabled on all difficulties instead of being restricted to higher ones.";
    default:
      return super(Info).GetDescriptionText(Property);
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
    bIgnoreDifficulty=false
}