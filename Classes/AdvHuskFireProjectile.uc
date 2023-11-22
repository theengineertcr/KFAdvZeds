/*
 * Modified Husk fireball(WIP)
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvHuskFireProjectile extends HuskFireProjectile;

/*
    todo:   Apply Physics to Fireball so that it actually has drop over distance (see: explosive pound code)
            Allow projectile to be destroyed mid-air by gunfire, as well as hit players in mid-air
            Projectile has 2 separate explosions, one at the center that deals mediumish damage, and a flame explosion
            That deals low, ticking, fire damage in a wide radius. Flame explosion needs a LinkedReplication class similar to 
            Super Zombies so that we can adjust and lengthen the burn time. Also, flame damage should temporarily mess with
            User's vision/recoil for the duration.
 */


/* !!! UNCOMMENT THIS ONCE WE'VE ADJUSTED HOW BURNING WORKS !!!

simulated function Explode(vector HitLocation, vector HitNormal) {
    // Second explosion
    HurtRadius(Damage*3,100, class'DamTypeFrag', MomentumTransfer, HitLocation );
    super.Explode(HitLocation,HitNormal);
}

defaultproperties{
    Damage=15
    DamageRadius=300
    MomentumTransfer=31250
}

 */