# Page buttons — things to paste

Run from the repo root; replace `dialog` with `dialogcli` / your build path.
All commands only write under /tmp, so they're safe to try.

## 1. Single buttons on the command line (one --button = one row)

```
dialog --title "Buttons" --message "Click a button, then OK" --width 600 --height 360 \
  --button "label=Open Example,url=https://example.com" \
  --button "label=Write a file,name=writefile,shell=echo hello > /tmp/swiftdialog-demo" \
  --button "name=help,symbol=questionmark,display=symbol,sheet=Some **markdown** help text"
```

Output after pressing OK includes lines like:

```
"writefile" : "clicked"
"writefile" exitcode : "0"
```

## 2. A row of several buttons (JSON object)

```
dialog --title "Row" --width 640 --height 320 \
  --buttons '{"name":"tools","title":"Tools","items":[
    {"name":"one","label":"One","url":"https://example.com"},
    {"name":"two","label":"Two","shell":"echo two > /tmp/swiftdialog-demo-two"},
    {"name":"info","symbol":"info.circle","display":"symbol","sheet":"About these tools"}]}'
```

## 3. A swatch row (selectable, no button surround)

```
dialog --title "Swatches" --width 640 --height 280 \
  --button '{"name":"accent","title":"Colour","style":"plain","selectable":true,"default":"blue","labelposition":"selected","size":26,
    "items":[
      {"value":"blue","label":"Blue","symbol":"circle.fill,colour=blue","shell":"echo blue > /tmp/swiftdialog-demo-accent"},
      {"value":"red","label":"Red","symbol":"circle.fill,colour=red","shell":"echo red > /tmp/swiftdialog-demo-accent"},
      {"value":"green","label":"Green","symbol":"circle.fill,colour=green","shell":"echo green > /tmp/swiftdialog-demo-accent"}]}'
```

Output includes `"accent" : "blue"` (the selected value) and its exit code.

## 4. Mixed with other inputs and grouped

```
dialog --title "Mixed" --width 700 --height 520 \
  --textfield "Name,name=fullname" \
  --button "label=Open Example,name=example,url=https://example.com" \
  --checkbox "Subscribe,name=subscribe" \
  --vieworder "[Details],fullname,subscribe,[Links],example"
```

## 5. JSON config

```
dialog --jsonfile examples/navigation/buttons-example.json --json
```

## What to look for

- Push buttons are standard bordered buttons; a symbol-only button is round.
- Swatch/appearance rows have no button surround; the selected one has a ring.
- The Actions page: a spinner appears on "Slow" after about half a second, clicking it again is
  ignored, and Apply/Cancel show a "still running" sheet until it finishes.
- Quitting any other way (quit key, timer, `quit:` in the command file) kills a running command:
  `ps aux | grep "sleep 5"` shows nothing afterwards.
- "Fails" reports `"fails" exitcode : "7"`; the dialog's own exit code is unchanged.
