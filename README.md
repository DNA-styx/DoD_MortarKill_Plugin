# DESCRIPTION:
This plugin gives kill (or TeamKill!) credits for using a map-built mortar at the right moment. You need to configure each mortar one by one in the file "mortar.cfg".

# INSTALLATION:
- dod_mortarkill.smx --> "dod/addons/sourcemod/plugins/"
- dod_mortar.cfg --> "dod/cfg/sourcemod"

# AVAILABLE MAPS:
- dod_strand
- dod_strand_night (only axis mortars)
- dod_ardennes_rc1
- dod_ardennes_rc1_dbs_b1
- dod_helms_attack_v2
- dod_helms_attack_dbs_v5
- dod_v2_extreme_1
- dod_ebensee_b4

# TODO MAPS:
- dod_dday_h
- dod_longestday_b5
- dickmanns_deepriver_syp_final
- others?

# Images:
<img width="500" height="281" alt="image" src="https://github.com/user-attachments/assets/22299f25-7a6a-4bfe-95ac-a4f03bd21040" />
<img width="500" height="281" alt="image" src="https://github.com/user-attachments/assets/fc0ad596-496f-4416-bf96-3690b8b7f6ce" />

# CONFIG SETUP

Example
```
			"MortarName" "mortar_back_btn"
			"TickMin" "3"
			"TickMax" "4"
			"Radius" "3000"
			"Loc" "2445.0 2247.0 116.0"
```
## MortarName: 
The `targetname` of `func_button` used to fire mortar you want to track.

### Example
```
{
"model" "*15"
"classname" "func_button"
"targetname" "mortar_back_btn"
"origin" "-210.26 3241.55 49.95"
"spawnflags" "1025"
"unlocked_sentence" "0"
"locked_sentence" "0"
"unlocked_sound" "0"
"locked_sound" "0"
"wait" "0"
"sounds" "0"
"lip" "0"
"speed" "0"
"movedir" "0 0 0"
"disablereceiveshadows" "0"
"rendercolor" "255 255 255"
"renderamt" "255"
"rendermode" "0"
"renderfx" "0"
"health" "1"
"OnPressed" "mortar_back_logic,Trigger,,0,-1"   
}
```

## TickMin: 
?

## TickMax: 
?

## Radius:
Blast radius of exploding shell to count as confirmed kill?

## Loc:
Location of mortar shell impact, around which the Radius figure applies

# Links:
Original:
- https://dodsplugins.mtxserv.fr/viewtopic.php?f=6&t=71
- https://archive.is/De1Ko#selection-887.0-945.17
