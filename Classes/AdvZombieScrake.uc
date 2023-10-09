/*
 * Modified Scrake
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */

class AdvZombieScrake extends AdvZombieScrakeBase
    abstract;


/*
Base changes TODO:

Scrake melee attack = instant kill
Scrake doesn't turn to face target while melee attacking, allowing flanking from speedy perks.
Scrake continues moving while melee attacking but can't rotate during it
Scrake laughs after killing his target(modify pat anims)
 */

var bool bEnablePush;               // Scrakes pushes zeds and players away while charging.
var bool bFocusTarget;              // Scrake will pursue the first player he sees until they die or they lose sight of them for more than 10-15 seconds.
var bool bEnableThrow;              // Scrake will knock players infront of him away if they block him from his main target. If possible, when this happens, all zeds target this player.
var bool bPassiveSpeedIncrease;     // Scrakes walking speed keeps increasing the longer the player avoids him. Reaches maximum after 10 seconds(Walking speed is equal to player running speed with a knife). Locked to Hard and above.
var bool bBetterControl;            // Scrakes can rotate towards his target while attacking much more effectively. Locked to Suicidal and above.
var bool bRagesOnFocusTargetLoss;   // Instead of changing target, they rage if they lose sight of them for too long. Basically the opposite of a Fleshpounds rage. Locked to HoE and above.