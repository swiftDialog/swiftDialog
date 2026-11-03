# Sliders and steppers — things to paste

Run from the repo root; replace `dialog` with `dialogcli` / your build path.

## Command line

```
dialog --title "Sliders" --width 700 --height 480 \
  --slider "Volume,name=volume,min=0,max=100,step=5,value=50,unit=%,minlabel=Quiet,maxlabel=Loud" \
  --slider "Balance,name=balance,min=-1,max=1,step=0.25,value=0,detail=Left to right" \
  --stepper "Keep logs for,name=days,min=1,max=90,value=30,unit=days"
```

Output after pressing OK (decimal steps give decimals, whole steps give whole numbers):

```
"volume" : "50"
"balance" : "0.00"
"days" : "30"
```

## Mixed with other inputs and grouped

```
dialog --title "Mixed" --width 700 --height 520 \
  --textfield "Name,name=fullname" \
  --slider "Volume,name=volume,value=40,unit=%" \
  --checkbox "Mute,name=mute" \
  --stepper "Retries,name=retries,min=0,max=10,value=3" \
  --vieworder "[Sound],volume,mute,[Other],fullname,retries"
```

## JSON object per argument

```
dialog --title "JSON" --slider '{"title":"Brightness","name":"brightness","min":0,"max":100,"value":75,"unit":"%","detail":"Adjusts automatically"}'
```

## JSON config

The Sound & Display page in `examples/navigation/settings-example.json` uses groups, `detail`, units and labels:

```
dialog --jsonfile examples/navigation/settings-example.json --json
```
With `--json`, values are real numbers: `"volume": 60`, `"balance": 0`.

## What to look for

- The slider shows its value (with unit) on the right; the readout doesn't jiggle as digits change.
- Stepper: type a number or use the arrows; values outside min/max are held to the range.
- A page revisit in navigation style restores the values.
