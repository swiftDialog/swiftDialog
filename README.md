# Dialog
app that displays dialogs

it accepts the following options:
Option                |Description
----------------------|-----------
`--title`             |message title
`--message`           |the message
`--icon`              |optional icon (future version you can set this to non and have no icon at all and have all message)
`--button1text`       |text label of the blue default button - also mapped to the Enter key. Dialog will exit with status 0 if this is selected
`--button1action`     |action for the button to take. Just opens a URL at this stage
`--button2text`       |text label of the 2nd button. Dialog will exit with status 2 . This button is also mapped to the Esc key.
`--infobuttontext`    |you know where this is going right? This one exists Dialog with status 3
`--infobuttonaction`  |same as button1action - Open the specified URL
