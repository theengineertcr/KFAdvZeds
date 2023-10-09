/*
 * Modified Stalker Controller class to check if she's flanking her target and time until she can leap again.
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/
class AdvStalkerController extends KFMonsterController;

var float LastPounceTime;
var bool bDoneSpottedCheck;
var bool bFlanking;

state ZombieHunt {
    event SeePlayer(Pawn SeenPlayer) {
        super.SeePlayer(SeenPlayer);
    }
}

function bool IsInPounceDist(actor PTarget) {
    local vector DistVec;
    local float time;
    local float HeightMoved;
    local float EndHeight;

    // work out time needed to reach target
    DistVec = pawn.location - PTarget.location;
    DistVec.Z = 0;

    time = vsize(DistVec) / AdvZombieStalker(pawn).PounceSpeed;

    // vertical change in that time
    // assumes downward grav only
    HeightMoved = Pawn.JumpZ*time + 0.5 * pawn.PhysicsVolume.Gravity.z * time * time;
    EndHeight = pawn.Location.z + HeightMoved;
    // log(Vsize(Pawn.Location - PTarget.Location));

    if (
        abs(EndHeight - PTarget.Location.Z) < Pawn.CollisionHeight + PTarget.CollisionHeight &&
        VSize(pawn.Location - PTarget.Location) < KFMonster(pawn).MeleeRange * 5
    ) {
        return true;
    } else {
        return false;
    }
}

function bool FireWeaponAt(Actor A) {
    local vector aFacing, aToB, TargetFacing, BToa;
    local float RelativeDir, TargetRelativeDir;

    if (A == none) {
        A = Enemy;
    }
    if (A == none || Focus != A) {
        return false;
    }

    if (VSize(Pawn.Location - A.Location) < 300) {
        aFacing = Normal(Vector(Pawn.Rotation));
        TargetFacing = Normal(Vector(A.Rotation));

        // Get the vector from A to B
        aToB = A.Location - Pawn.Location;
        BToa = Pawn.Location - A.Location;

        RelativeDir = aFacing dot aToB;
        TargetRelativeDir = TargetFacing dot BToa;

        if (TargetRelativeDir < -15) {
            bFlanking = true;
        } else {
            bFlanking = false;
        }
    }

    if (CanAttack(A)) {
        Target = A;
        Monster(Pawn).RangedAttack(Target);
    } else {
        // TODO - base off land time rather than launch time?
        if ((LastPounceTime + (12 - 1.5)) < Level.TimeSeconds) {
            if (TargetRelativeDir > 100 && RelativeDir > 0.85) {
                // Facing enemy
                if (IsInPounceDist(A)) {
                    if (AdvZombieStalker(Pawn).DoPounce()) {
                        LastPounceTime = Level.TimeSeconds;
                    }
                }
            }
        }
    }
    return false;
}

function bool NotifyLanded(vector HitNormal) {
    if (AdvZombieStalker(pawn).bPouncing) {
        // restart pathfinding from landing location
        GotoState('hunting');
        return false;
    } else {
        return super.NotifyLanded(HitNormal);
    }
}

defaultproperties {
    StrafingAbility=0.100000
}