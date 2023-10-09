/*
 * Stalker's armour piercing damage type used when flanking her target.
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class DamTypeStalkerAPClaws extends DamTypeZombieAttack;

defaultproperties {
    bArmorStops=false
    bCheckForHeadShots=false
    bLocationalHit=false
}