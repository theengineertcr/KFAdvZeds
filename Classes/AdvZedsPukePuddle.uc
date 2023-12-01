/*
 * Bloat's spicy puke puddle
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/

class AdvZedsPukePuddle extends MedicNade;


#exec OBJ LOAD FILE=Frightyard_snd.uax

// Don't disintegrate from a Siren scream
function TakeDamage( int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector Momentum, class<DamageType> damageType, optional int HitIndex){
}


simulated function Explode(vector HitLocation, vector HitNormal) {
    bHasExploded = True;
    BlowUp(HitLocation);

    PlaySound(ExplosionSound,,TransientSoundVolume);

    if( Role == ROLE_Authority ) {
        bNeedToPlayEffects = true;
        // This needs to be louder
        AmbientSound=Sound'Frightyard_snd.Ambient.ENV_Bile_LP';
    }

    if ( EffectIsRelevant(Location,false) ) {
        Spawn(Class'AdvZedsPukePuddleEmitter',,, HitLocation, rotator(vect(0,0,1)));
        Spawn(ExplosionDecal,self,,HitLocation, rotator(-HitNormal));
    }
}

//Overriden to only deal damage to players that step in the puddle and do nothing to Zeds
function HealOrHurt(float DamageAmount, float DamageRadius, class<DamageType> DamageType, float Momentum, vector HitLocation) {
    local actor Victims;
    local float damageScale;
    local vector dir;
    local KFMonster KFMonsterVictim;
    local Pawn P;
    local KFPawn KFP;
    local array<Pawn> CheckedPawns;
    local int i;
    local bool bAlreadyChecked;

    if ( bHurtEntry ) {
        return;
    }

    NextHealTime = Level.TimeSeconds + HealInterval;

    bHurtEntry = true;

    foreach CollidingActors (class 'Actor', Victims, DamageRadius, HitLocation) {
        // don't let blast damage affect fluid - VisibleCollisingActors doesn't really work for them - jag
        if( (Victims != self) && (Hurtwall != Victims) && (Victims.Role == ROLE_Authority) && !Victims.IsA('FluidSurfaceInfo')
         && ExtendedZCollision(Victims)==None ) {

            damageScale = 1.0;

            if ( Instigator == None || Instigator.Controller == None ) {
                Victims.SetDelayedDamageInstigatorController( InstigatorController );
            }

            P = Pawn(Victims);

            if( P != none ) {
                for (i = 0; i < CheckedPawns.Length; i++) {
                    if (CheckedPawns[i] == P) {
                        bAlreadyChecked = true;
                        break;
                    }
                }

                if( bAlreadyChecked ) {
                    bAlreadyChecked = false;
                    P = none;
                    continue;
                }

                KFMonsterVictim = KFMonster(Victims);

                if( KFMonsterVictim != none && KFMonsterVictim.Health <= 0 ) {
                    KFMonsterVictim = none;
                }

                KFP = KFPawn(Victims);

                if( KFMonsterVictim != none ) {
                    damageScale *= KFMonsterVictim.GetExposureTo(Location + 15 * -Normal(PhysicsVolume.Gravity));
                } else if( KFP != none ) {
                    damageScale *= KFP.GetExposureTo(Location + 15 * -Normal(PhysicsVolume.Gravity));
                }

                CheckedPawns[CheckedPawns.Length] = P;

                if ( damageScale <= 0) {
                    P = none;
                    continue;
                } else {
                    //Victims = P;
                    P = none;
                }
            } else {
                continue;
            }

            if( KFMonsterVictim == none ) {
                //log(Level.TimeSeconds@"Hurting "$Victims$" for "$(damageScale * DamageAmount)$" damage");

                if( Pawn(Victims) != none && Pawn(Victims).Health > 0 ) {
                    Victims.TakeDamage(damageScale * DamageAmount,Instigator,Victims.Location - 0.5 * (Victims.CollisionHeight + Victims.CollisionRadius)
                     * dir,(damageScale * Momentum * dir),DamageType);
                }
            }

            KFMonsterVictim = none;
        }
    }
    bHurtEntry = false;
}

// Overridden to get rid of the limit of 8 ticks of damage
function Tick(float DeltaTime ){
    if( Role < ROLE_Authority ){
        return;
    }

    if( NextHealTime < Level.TimeSeconds ){
        HealOrHurt(Damage,DamageRadius, MyDamageType, MomentumTransfer, Location);
    }
}

defaultproperties{
    ExplosionDecal=class'VomitDecal'
    DrawType=DT_StaticMesh
    Speed=400.000000
    Damage=10.000000
    DamageRadius=100.000000
    HealInterval=0.5
    MomentumTransfer=2000.000000
    MyDamageType=Class'KFMod.DamTypeVomit'
    LifeSpan=10.0
    Skins(0)=Texture'kf_fx_trip_t.Gore.pukechunk_diffuse'
    CollisionRadius=2.000000
    CollisionHeight=2.000000
    bUseCollisionStaticMesh=False
    StaticMesh=StaticMesh'kf_gore_trip_sm.puke.puke_chunk'
    ImpactSound=Sound'KF_EnemiesFinalSnd.Bloat_AcidSplash'
    bBlockHitPointTraces=false
    ExplosionSound=None
}
