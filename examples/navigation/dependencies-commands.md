# Control dependencies — things to paste

`enabledif` disables a control, `visibleif` hides it, depending on other inputs on the same page.
Run from the repo root; replace `dialog` with `dialogcli` / your build path.

## Command line

```
dialog --title "Proxy" --width 640 --height 420 \
  --checkbox "Use proxy,name=useproxy" \
  --textfield "Host,name=host,enabledif=useproxy" \
  --textfield "Port,name=port,enabledif=useproxy,detail=Numbers only" \
  --textfield "Bypass,name=bypass,visibleif=useproxy"
```

Tick the box: Host and Port become editable and Bypass appears.

## Comparisons, combinations and other input types

```
dialog --title "Conditions" --width 700 --height 520 \
  --selecttitle "Contact me by,name=channel" --selectvalues "Email,Chat,Phone" \
  --textfield "Phone number,name=phone,visibleif=channel=Phone" \
  --slider "Volume,name=volume,value=40" \
  --checkbox "Mute,name=mute" \
  --stepper "Boost,name=boost,min=0,max=10,enabledif=volume>50 && !mute"
```

- Phone number appears only when "Phone" is chosen.
- Boost is editable only when volume is above 50 and Mute is off.

## JSON config

```
dialog --jsonfile examples/navigation/settings-example.json --json
```

- Proxy page: fields disabled until "Use proxy"; "Bypass for" appears with it.
- Sound & Display page: Brightness is disabled while Auto-dim is on.
- Software Updates page: "Restart automatically" needs automatic app updates.

## What to look for

- A disabled or hidden control is put back to its default and stays there. Try it: tick "Use proxy", type a host, untick "Use proxy" and the Host field clears; the output shows the default.
- A disabled control is dimmed and can't be changed; it is still in the output, with its default.
- A required field that is disabled or hidden doesn't block the OK button.
- In a vieworder group, hiding a row leaves no gap and no double divider.
