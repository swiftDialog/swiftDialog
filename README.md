
# Dialog

Dialog is a simple app that displays a dialog with specified content passed in from the commandline

![Dialog Logo](/assets/screen1.png)


# Commandline Options
it accepts the following options:
Option                |Description
----------------------|-----------
--title             |message title
--message           |the message
--icon              |optional icon (future version you can set this to non and have no icon at all and have all message)
--button1text       |text label of the blue default button - also mapped to the Enter key. Dialog will exit with status 0 if this is selected
--button1action     |action for the button to take. Just opens a URL at this stage
--button2text       |text label of the 2nd button. Dialog will exit with status 2 . This button is also mapped to the Esc key.
--infobuttontext    |you know where this is going right? This one exists Dialog with status 3
--infobuttonaction  |same as button1action - Open the specified URL
--version           |printsthe app version string
--hideicon          |hides the dialog icon and expands the text to fill the fill width
--version           |Prints the current version
--help              |Prints help text (also printed if no options are present
--demo              |Run Dialog with default options (not very intersting though)

# Return Codes
When displaying a dialog the user can take one of up to three actions, depending on what's available

1. Hit <Enter> or click the default button (button1)
2. Hit <ESC> or click the Cancel/Other button (button2)
3. Click the More Information button (infobutton) if visible

The following return codes are sent after each action. These can be ignored or used in a calling script for further action
|Button Name|Return Code|
|-|-|
|button1|0|
|button2|2|
|infobutton|3|

