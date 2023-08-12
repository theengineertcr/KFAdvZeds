# Killing Floor: Advanced Zeds

[![GitHub all releases](https://img.shields.io/github/downloads/theengineertcr/KFAdvZeds/total)](https://github.com/theengineertcr/KFAdvZeds/releases)

A Killing Floor modification that enhances enemies base abilities and gives them additional abilities per difficulty level.

## Installation & Usage

For Singleplayer: Enable the `Advanced Zeds` mutator and adjust settings to your liking if you are not comfortable with the defaults. Select a map, game and difficulty, and start the game when ready.

For Server Owners: Enable the `Advanced Zeds` mutator by adding the package name following the mutator name into your server's batch script listed below.

```unrealscript
KFAdvZeds.AdvZedsMut
```

## Documentation

Check out upcoming features in the [**Features**](Docs/FEATURES.MD) document. Changelog will be available upon stable release.

### Monster list / Summon codes

```unrealscript
KFAdvZeds.AdvZombieHusk_S
KFAdvZeds.AdvZombieStalker_S
```

## Building and Dependancies

- Download and install the mod (for asset files).
- Use [KF Compile Tool](https://github.com/InsultingPros/KFCompileTool) for easy compilation.

```ini
EditPackages=KFAdvZeds
```