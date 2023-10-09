/*
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvHuskFlameProjectile extends FlameTendril;

simulated function PostBeginPlay() {
    super.PostBeginPlay();

    // Difficulty Scaling
    if (Level.Game != none) {
        if (Level.Game.GameDifficulty < 2.0) {
            Damage = default.Damage - 3;
            DamageRadius = default.DamageRadius * 0.5;
        } else if (Level.Game.GameDifficulty < 4.0) {
            Damage = default.Damage * 1.0;
            DamageRadius = default.DamageRadius * 1.0;

        } else if (Level.Game.GameDifficulty < 5.0) {
            Damage = default.Damage + 4;
            DamageRadius = default.DamageRadius * 1.25;
            PenDamageReduction = default.PenDamageReduction * 1.25;
        } else {
            // Hardest difficulty
            Damage = default.Damage + 6;
            DamageRadius = default.DamageRadius * 1.5;
            PenDamageReduction = default.PenDamageReduction * 1.5;
        }
    }
}

defaultproperties {
    DamageAtten=5.000000
    MaxPenetrations=2
    PenDamageReduction=0.500000
    Damage=6
    DamageRadius=100.000000
}