class AdvHuskFlameProjectile extends FlameTendril;

//-----------------------------------------------------------------------------
// PostBeginPlay
//-----------------------------------------------------------------------------
simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    // Difficulty Scaling
    if (Level.Game != none)
    {
        if( Level.Game.GameDifficulty < 2.0 )
        {
            Damage = default.Damage - 3;
        }
        else if( Level.Game.GameDifficulty < 4.0 )
        {
            Damage = default.Damage * 1.0;
        }
        else if( Level.Game.GameDifficulty < 5.0 )
        {
            Damage = default.Damage + 2;
        }
        else // Hardest difficulty
        {
            Damage = default.Damage + 4;
        }
    }
}

defaultproperties
{
    DamageAtten=5.000000
    MaxPenetrations=2
    PenDamageReduction=0.500000
    Damage=6
    DamageRadius=100.000000
}
