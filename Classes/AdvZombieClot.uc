/*
 * Modified Clot
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */

class AdvZombieClot extends AdvZombieClotBase
    abstract;

/*
todo: clot base health to 400, head health to 95,
new "brain shot" hitzone above main head that has 25 hp,
no head = instantly dead
 */

var bool bEnableDismemberment;          // Clots can lose their limbs.
var bool bDisableIncreasedDurability;   // Clots use default health
var int  GrabLevel;                     // How effective their grabbing is. 0 = default || 1 = gun recoil and spread increase || 2 = player can't reload or swap weapons(if alone, latter is disabled) || 3 = player is stunned/cannot turn if grabbed from behind(if alone/berserker, lasts for only a second)