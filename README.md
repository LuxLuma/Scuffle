# Scuffle SourceMod Plugin

If you enjoy SourceMod and its community consider helping them them meet their monthly goal [here](http://sourcemod.net/donate.php). Your help, no matter the amount goes a long way in keeping a great project like SourceMod what it is... AWESOME.

Thanks :)

## License
Scuffle a SourceMod L4D2 Plugin
Copyright (C) 2017  Lux & Victor "NgBUCKWANGS" Gonzalez

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

## About
Scuffle is a self revival plugin for survivors of Left 4 Dead 2. Enable survivors to self revive from the ground, a ledge or an SI attack or disable any or all of these abilities when certain conditions are met. Require any item or nothing at all and make it easy or make it brutal. 

### Installing Scuffle

**Scuffle is a [SourceMod](https://www.sourcemod.net/) plugin and everything in this README assumes you're installing it onto a dedicated server. Scuffle will not work without SourceMod.**

Drop the ```addons``` folder of the Scuffle package on top of your ```left4dead2``` directory. Make sure the directory you're dropping the contents of Scuffle in already contain an ```addons``` directory. Doing this will not overwrite any files that do not belong to Scuffle but should make sure all files belonging to Scuffle are where they're expected to be. Once done, you'll need to obtain the binary (smx file) to start using it.

#### Obtaining the Binary
In order to obtain the ```scuffle.smx``` file, you'll need to compile the ```scuffle.sp``` source file. Once the contents of the Scuffle package are where they need to be, compiling is only a few steps away. 

Replace ```"$SOURCEMOD_SCRIPTING"``` in the instructions below with the absolute path to your SourceMod scripting directory. On Linux, path separators are / and on Windows they're \\. Also, be sure to double quote the path to avoid white space problems.

##### Example paths
- Windows ```"C:\steamcmd\left4dead2\addons\sourcemod\scripting\"```
- Linux ```"/home/steamcmd/left4dead2/addons/sourcemod/scripting/"```

##### Compiling on Linux
- Open a terminal
- ```cd "$SOURCEMOD_SCRIPTING"```
- ```./compile.sh scuffle.sp```
- ```mv compiled/scuffle.smx ../plugins```

##### Compiling on Windows
- Open a terminal
- ```cd "$SOURCEMOD_SCRIPTING"```
- ```compile.exe scuffle.sp```
- ```move compiled\scuffle.smx ..\plugins```

#### Having Trouble?

If you're having trouble compiling ```scuffle.sp``` you can try the [ SourceMod Plugin Compiler](http://www.sourcemod.net/compiler.php) online or check the [AlliedModders Plugins Forum](https://forums.alliedmods.net/forumdisplay.php?f=108) for the official Scuffle thread (search for Scuffle) which would normally include a binary. You can also check the **Reaching Me** section below for a possible link to any official thread.

### Loading Scuffle
Once you've obtained the binary (```scuffle.smx```) and placed it in the ```...left4dead2/addons/sourcemod/plugins/``` folder and all other related files are where they need to be, you can either restart the server or in a game related console type
- ```sm_rcon sm plugins load scuffle```

### Disabling Scuffle
1. Move ```scuffle.smx``` into ```plugins/disabled```
2. ```sm_rcon sm plugins unload scuffle```

### Uninstalling Scuffle
Follow **Disabling Scuffle** (above) and then use the original Scuffle archive as a reference of the files needed for deletion. Remove the ```scuffle.smx``` file from your ```plugins``` directory. A ```scuffle.cfg``` file may have been generated and found in ```...left4dead2/cfg/sourcemod/``` and if so, it will be safe to remove.

## Configuration Variables (Cvars)
```
"scuffle_any" = "-1"
 - -1: Infinite. >0: Shared with attack, ledge and ground tokens of value -1.
"scuffle_attack" = "-1"
 - -1: Infinite. >0: Times a survivor can revive from an SI attack hold.
"scuffle_chargerstagger" = "3.5"
 - Charger stagger and secondary attack block time.
"scuffle_cooldown" = "10"
 - Cooldown (no reviving) between self-revivals.
"scuffle_duration" = "30.0"
 - Overall time to spread holds and taps.
"scuffle_ground" = "-1"
 - -1: Infinite. >0: Times a survivor can revive from the ground.
"scuffle_holdtime" = "0.1"
 - Time deduced on server frame when holding scuffle_shiftbit.
"scuffle_hunterstagger" = "3.0"
 - Hunter stagger and secondary attack block time.
"scuffle_hurt" = "1"
 - Hurt survivor this amount per second (applies on self revival).
"scuffle_jockeystagger" = "1.2"
 - Jockey stagger and secondary attack block time.
"scuffle_killchance" = "0" min. 0.000000 max. 100.000000
 - Chance of killing an SI when reviving.
"scuffle_lastleg" = "2" min. -1.000000 max. 2.000000
 - -1: Off: >=0: Stop self revivals at this strike.
"scuffle_ledge" = "-1"
 - -1: Infinite. >0: Times a survivor can revive from a ledge.
"scuffle_losstime" = "0.2"
 - Time added on server frame when missing scuffle_shiftbit.
"scuffle_minhealth" = "0"
 - Stop self revivals at this health.
"scuffle_requires" = ""
 - Semicolon separated items and health e.g., 'item1=temphealth;item2'.
"scuffle_shiftbit" = "1" min. 0.000000 max. 25.000000
 - Shift bit for revival see https://sm.alliedmods.net/api/index.php?fastload=file&id=47&
"scuffle_slots" = ""
 - Zero based slot search order (slot 1 is ignored).
"scuffle_smokerstagger" = "1.2"
 - Smoker stagger and secondary attack block time.
"scuffle_staydown" = "0"
 - 0: Break SI hold and get up. 1: Break SI hold and stay down.
"scuffle_taptime" = "1.5"
 - Time deduced on server frame when tapping scuffle_shiftbit.
 ```

## Console Variables (Cvars) Explained
The meat of customizing Scuffle is in its cvars. A ```scuffle.cfg``` will be generated on first load of the plugin and placed in your ```.../left4dead2/cfg/sourcemod/``` directory. From this file or any console connected to the game you can customize the following.

## Quotas & Conditionals
The following cvars will have the most impact at changing how, when and why survivors can either revive in all, some or no situation. 

### scuffle_any default (-1)
How many revivals does a survivor have against any type of attack (ground, ledge, SI)? If this is set to -1, it will set all types to infinite . Any value greater than -1 is shared among ```scuffle_attack```, ```scuffle_ledge``` and ```scuffle_ground``` as long as these specific cvars do not have a value of a zero. If this cvar reaches zero, all scuffling will be disabled.

### scuffle_attack default (-1)
Note: If ```scuffle_any``` is set to -1 this value is ignored.

How many self revivals does a survivor have against an SI hold? If this cvar is set to -1 the number of times a survivor can revive against the attack depends on ```scuffle_any```. If this cvar is valued at greater than zero every self revival against SI will decrement by one against the player. If this cvar is set to zero, scuffling against SI is disabled. 

### scuffle_ground default (-1)
Note: If ```scuffle_any``` is set to -1 this value is ignored.

How many self revivals does a survivor have against the ground? If this cvar is set to -1 the number of times a survivor can revive from the ground depends on ```scuffle_any```. If this cvar is valued at greater than zero every self revival from the ground will decrement by one against the player. If this cvar is set to zero, scuffling from the ground is disabled.

### scuffle_ledge default (-1)
Note: If ```scuffle_any``` is set to -1 this value is ignored.

How many self revivals does a survivor have against a ledge? If this cvar is set to -1 the number of times a survivor can revive from a ledge depends on ```scuffle_any```. If this cvar is valued at greater than zero every self revival from a ledge will decrement by one against the player. If this cvar is set to zero, scuffling from a ledge is disabled.

### scuffle_lastleg default (2)
The strike against a survivor in which to turn off all ability to scuffle. Strikes are incremented when a survivor is truly down. The default value of 2 (black and white) is based on the default value of  ```survivor_max_incapacitated_count```. A ```scuffle_lastleg``` value of -1 will turn this check off.

### scuffle_cooldown default (10)
After any successful self revival a cooldown kicks in (based on seconds) and prevents the same survivor from scuffling again while cooling down. When the cooldown is over, a survivor (if in trouble) will be notified of their ability to get back up again. A value of zero will effectively turn off all cooldown penalties.

### scuffle_hurt default (1)
This is a penalty against self reviving survivors and is applied only if they successfully revive themselves. This hurts more in some cases and is meant to reward patience. This value is docked per second from the players health if they get themselves up.

In combination with ```scuffle_cooldown``` and ```scuffle_lastleg``` this may prevent some players from abusing ledges in tight situations.

### scuffle_minhealth default (0)
The amount of overall health (including buffer) before disabling the ability to scuffle from any given situation. A value of zero turns this check off.

### scuffle_requires default ("")
Warning: If requiring anything, make sure to set the right slots in ```scuffle_slots```

A string in the form of ```"item1=50;item2=75;item3"```.  An item a survivor will need to get up and its value in temporary health (applied after being completely incapacitated). If no value is given to an item the temporary health is decided by ```survivor_revive_health```.

A special item of ```any``` can also be given and its position in the string is important. If it is the first item of the string the first item found in the players ```scuffle_slots```  is used. If ```any``` is in any other position, all items will be considered before falling back to any item.

Items can be shortened and are case insensitive e.g., Kit, kit, KIT will all match weapon_first_aid_kit. If a survivor is in trouble and has a required item, upon successful self revival, that item will be removed from the player. An empty ```scuffle_requires``` value e.g., ```""``` will require nothing and effectively turn off any requirements.

### scuffle_slots default ("")
Note: Enable only the slots you wish to scan based on ```scuffle_requires```

This is a zero based search order that ```scuffle_requires``` will go through to find an item. If you want to start from the pills slot and work your way up to the primary weapons slot the order is 4320. Slot 1 (secondary weapons) is ignored. A search order of 43 will search the pills slot before falling back onto the kit slot.

### scuffle_killchance default (0)
This value defines the chances of an SI dying from a survivors self revival. If this is at zero, SI will never die. If this is at 100, SI will always die.

### scuffle_staydown default (0)
Note: If you are requiring items for survivors to scuffle, one item may be used to break the hold and another used to finally get up (it depends on ```scuffle_killchance```).

A value of 1 will cause a survivor after successfully scuffling from an SI hold to stay down (only if they're already incapacitated) and the attacking SI is still alive. If this cvar is at value 1 and ```scuffle_killchance``` results in the SI dying, the survivor will also get up. If this is set to 0, survivors will always get up after a successful scuffle.

## Staggering SI
If players are allowed to break away from SI, it is important to stagger the SI for as long as the player is in their recovery animation. During this time, it is important to block the damage staggering SI may inflict with their secondary attack (only protects the recovering survivor).

### scuffle_chargerstagger default (3.5)
When scuffling against a Charger, the value here defines how long the Charger will stagger. This value correlates to the animation time a survivor requires before the player is put back in control of the character again. This value will also protect the survivor against any secondary attacks by the offender only.

### scuffle_hunterstagger default (3.0)
When scuffling against a Hunter, the value here defines how long the Hunter will stagger. This value correlates to the animation time a survivor requires before the player is put back in control of the character again. This value will also protect the survivor against any secondary attacks by the offender only.

### scuffle_jockeystagger default (1.2)
When scuffling against a Jockey, the value here defines how long the Jockey will stagger. This value correlates to the animation time a survivor requires before the player is put back in control of the character again. This value will also protect the survivor against any secondary attacks by the offender only.

### scuffle_smokerstagger default (1.2)
When scuffling against a Smoker, the value here defines how long the Smoker will stagger. This value correlates to the animation time a survivor requires before the player is put back in control of the character again. This value will also protect the survivor against any secondary attacks by the offender only.

## Defining the Revive Key & Times
Define the button for players to use, how long the block of time they have and how much time is reduced overall on successful holds and taps. Important to note is "time" is based on frames and can feel finicky so remember this

1. A time greater than duration is instantaneous 
2. A time of exactly zero plays out in exactly the amount of duration
3. A time between duration and zero is not exact
4. Finding the sweet spots require trial and error

### scuffle_shiftbit default (1)
This is the key survivors will either tap or hold to revive themselves. Please see this [API reference](https://sm.alliedmods.net/api/index.php?fastload=file&id=47&) for possible options. By default, the value is 1 taken from the shift bit (number on the right of (1 << SHIFTBIT) which is "IN\_JUMP"). If you wanted to make reload the key to revive with, it's (1 << 13) "IN_RELOAD" and you would make ```scuffle_shiftbit``` 13.

### scuffle_duration default (30.0)
The total amount of time that is shared with ```scuffle_holdtime``` , ```scuffle_taptime``` and ```scuffle_losstime```. If hold or loss are valued at zero the duration time is exact. The values of hold, loss and tap are applied on server frame otherwise.

### scuffle_holdtime default (0.1)
Amount of time to deduce overall from ```scuffle_duration``` on hold.  If this is valued at zero, holding the ```scuffle_shiftbit``` key will self revive in exactly the amount of time of ```scuffle_duration```. If this cvar value is greater than ```scuffle_duration``` the revival will be instantaneous on hold.

### scuffle_losstime default (0.2)
Amount of time subtracted from overall progress on missed holds and taps.  If this is valued at zero automatic revival kicks in (based on ```scuffle_duration```).

### scuffle_taptime default (1.5)
Note: The name here is a bit misleading, this is applied on release, not tap.

This value should be several times higher than ```scuffle_holdtime``` in order to be faster and more rewarding (compared to holding the ```scuffle_shiftbit```).  If this cvar value is greater than ```scuffle_duration``` the revival will be instantaneous on release.

## Thanks
This plugin was heavily influenced by the works of [panxiaohai Struggle](https://forums.alliedmods.net/showthread.php?t=175806) plugin. Thanks to **Timocop** for being a great friend and wizard at this. Thanks to **Lux** for his collaboration, tenacity and uncanny ability to break stuff. 

## Reaching Us
We have a thread on AlliedModders for feedback regarding Scuffle.

- [AlliedModders Thread](https://forums.alliedmods.net/showthread.php?t=303635)

### NgBUCKWANGS
I love L4D2, developing, testing and running servers more than I like playing the game. Although I do enjoy the game and it is undoubtedly my favorite game, it is the community I think I love the most. It's always good to meet new people with the same interest :)

- [NgBUCKWANGS Steam Profile](http://steamcommunity.com/id/buckwangs/)
- [NgBUCKWANGS Scuffle GitLab Page](https://gitlab.com/vbgunz/Scuffle)

### Lux
Don't steal daddy's car.

- [Don't Steal Daddy's Car](https://www.youtube.com/watch?v=UOlaEZg1hlc)
- [Lux Scuffle GitHub Page](https://github.com/LuxLuma/Scuffle)
