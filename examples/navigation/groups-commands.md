# vieworder grouping — things to paste

Run from the repo root. Replace `dialog` with `dialogcli` / the path to your build.

## 1. Command line, comma separated

```
dialog --title "Groups (CSV)" --message "Mixed types, two groups" --width 700 --height 560 \
  --textfield "Full Name,name=fullname,detail=As shown to colleagues" \
  --textfield "Email,name=email" \
  --checkbox "Newsletter,name=newsletter,detail=Monthly and no spam" \
  --selecttitle "Country,name=country,detail=Where you work" --selectvalues "Australia,New Zealand,United Kingdom" \
  --vieworder "[Account],fullname,email,[Preferences],newsletter,country"
```

Type name mixed with names (the textfield block holds whatever isn't placed individually):

```
dialog --title "Groups (types + names)" --width 700 --height 520 \
  --textfield "Full Name,name=fullname" --textfield "Email,name=email" --textfield "Phone,name=phone" \
  --checkbox "Newsletter,name=newsletter" \
  --vieworder "newsletter,email,textfield"
```

No group, no names: unchanged type ordering (control case):

```
dialog --title "Type order only" --textfield "Name" --checkbox "Tick" --vieworder "checkbox,textfield"
```

## 2. Command line with a JSON object (group descriptions and footers)

```
dialog --title "Groups (JSON object)" --width 700 --height 600 \
  --textfield "Full Name,name=fullname" --textfield "Email,name=email" \
  --checkbox "Newsletter,name=newsletter" \
  --selecttitle "Country,name=country" --selectvalues "Australia,New Zealand,United Kingdom" \
  --vieworder '{"groups":[
    {"title":"Account","description":"Used to sign in","items":["fullname","email"]},
    {"title":"Preferences","footer":"You can change these later.","items":["newsletter","country"]}
  ]}'
```

## 3. JSON config files

Standard dialog with groups, `detail` and mixed types:

```
dialog --jsonfile examples/navigation/groups-example.json --json
```

Navigation style, grouping per page (page 3 has no vieworder):

```
dialog --jsonfile examples/navigation/groups-navigation-example.json --json
```

## What to look for

- Rows from different types sit in one rounded box per group, with dividers between rows.
- `detail` text is grey under the title; inputs without it look unchanged.
- Inputs not listed in a vieworder appear in an untitled group at the end.
- A bad name logs a warning (run with `--verbose`) and is skipped.
- Output (stdout after pressing OK) is the same as without vieworder.
