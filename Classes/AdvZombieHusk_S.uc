/*
 * Standard Advanced Husk Skin
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvZombieHusk_S extends AdvZombieHusk;

// We need to let the game load our Animation set
#exec OBJ LOAD FILE=KFAdvZeds_A.ukx

defaultproperties {
    DetachedArmClass=class'SeveredArmHusk'
    DetachedSpecialArmClass=class'SeveredArmHuskGun'
    DetachedLegClass=class'SeveredLegHusk'
    DetachedHeadClass=class'SeveredHeadHusk'

    Mesh=SkeletalMesh'KF_Freaks2_Trip.Burns_Freak'

    Skins(0)=Texture'KF_Specimens_Trip_T_Two.burns.burns_tatters'

    AmbientSound=Sound'KF_BaseHusk.Husk_IdleLoop'
    MoanVoice=Sound'KF_EnemiesFinalSnd.Husk_Talk'
    JumpSound=Sound'KF_EnemiesFinalSnd.Husk_Jump'
    MeleeAttackHitSound=sound'KF_EnemiesFinalSnd.Bloat_HitPlayer'

    HitSound(0)=Sound'KF_EnemiesFinalSnd.Husk_Pain'
    DeathSound(0)=Sound'KF_EnemiesFinalSnd.Husk_Death'

    ChallengeSound(0)=Sound'KF_EnemiesFinalSnd.Husk_Challenge'
    ChallengeSound(1)=Sound'KF_EnemiesFinalSnd.Husk_Challenge'
    ChallengeSound(2)=Sound'KF_EnemiesFinalSnd.Husk_Challenge'
    ChallengeSound(3)=Sound'KF_EnemiesFinalSnd.Husk_Challenge'
}