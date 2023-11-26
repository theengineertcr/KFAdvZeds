/*
 * Our nasty gas emitter for our puke puddles
 *
 * Author       : theengineertcr
 * Home Repo    : https://github.com/theengineertcr/KFAdvZeds
 * License      : GPL 3.0
 * Copyright    : 2023 theengineertcr
*/

class AdvZedsPukePuddleEmitter extends Emitter;

var bool bFlashed;

simulated function PostBeginPlay(){
    Super.Postbeginplay();
    NadeLight();
}

simulated function NadeLight()
{
    if ( !Level.bDropDetail && (Instigator != None) &&
        ((Level.TimeSeconds - LastRenderTime < 0.2) || (PlayerController(Instigator.Controller) != None)) ) {
        bDynamicLight = true;
        SetTimer(0.25, false);
    } else {
        Timer();
    }  
}

simulated function Timer(){
    bDynamicLight = false;
}

defaultproperties{
    Begin Object Class=SpriteEmitter Name=SpriteEmitter0
        UseColorScale=True
        RespawnDeadParticles=False
        SpinParticles=True
        UseSizeScale=True
        UseRegularSizeScale=False
        UniformSize=True
        AutomaticInitialSpawning=False
        BlendBetweenSubdivisions=True
        ColorScale(0)=(Color=(G=50,R=65,A=255))
        ColorScale(1)=(RelativeTime=1.000000,Color=(B=0,G=50,R=65,A=255))
        FadeOutFactor=(W=0.000000,X=0.000000,Y=0.000000,Z=0.000000)
        FadeOutStartTime=5.000000
        Name="SpriteEmitter0"
        SpinsPerSecondRange=(Y=(Min=0.050000,Max=0.100000),Z=(Min=0.050000,Max=0.100000))
        StartSpinRange=(X=(Min=-0.500000,Max=0.500000),Y=(Max=1.000000),Z=(Max=1.000000))
        SizeScale(0)=(RelativeSize=1.000000)
        SizeScale(1)=(RelativeTime=1.000000,RelativeSize=5.000000)
        StartSizeRange=(X=(Min=30.000000,Max=30.000000),Y=(Min=30.000000,Max=30.000000),Z=(Min=30.000000,Max=30.000000))
        InitialParticlesPerSecond=5000.000000
        DrawStyle=PTDS_AlphaBlend
        Texture=Texture'kf_fx_trip_t.Misc.smoke_animated'
        TextureUSubdivisions=8
        TextureVSubdivisions=8
        LifetimeRange=(Min=10.000000,Max=10.000000)
        StartVelocityRange=(X=(Min=-750.000000,Max=750.000000),Y=(Min=-750.000000,Max=750.000000))
        VelocityLossRange=(X=(Min=10.000000,Max=10.000000),Y=(Min=10.000000,Max=10.000000),Z=(Min=10.000000,Max=10.000000))
    End Object
    Emitters(0)=SpriteEmitter'SpriteEmitter0'
    RemoteRole=ROLE_SimulatedProxy
    bNotOnDedServer=False
    bNoDelete=False
    AutoDestroy=True
}
