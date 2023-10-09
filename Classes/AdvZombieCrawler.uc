/*
 * Modified Crawler
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
 */

// Were going to be using arachnophobia crawlers code and tweak it
class AdvZombieCrawler extends AdvZombieCrawlerBase
    abstract;

var bool bEnableFireResistance;     // No longer loses sight of his target when burning.
var bool bEnableDodge;              // Dodges from fire, explosives, and what not.
var bool bEnableWallClimb;          // Jumps on walls/ceilings.
var int DodgeLevel;                 // 0 = none || 1 = Explosive projectiles and flames || 2 = when taking damage(low %) || 3 = attaches to walls/ceilings when dodging.