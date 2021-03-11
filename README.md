
# Dialog

Dialog is a simple app that displays a dialog with specified content passed in from the commandline

Latest version can be found on the [Releases](https://github.com/bartreardon/Dialog-public/releases) page

![Dialog Logo](/assets/screen1.png)

# Where is the source code?

Releasing the source will need to be cleared with my employer. Initial beta releases are being made public though through this repo. Any issues or feature requests, please feel free to [raise an issue](https://github.com/bartreardon/Dialog-public/issues)

# Features
Universal binary
Supports macOS 11 only (for now - due to swiftUI API's in use backwards compatibility may only extend to 10.15)

## Appearance
Icon display can be from local PNG or JPG or from a specified URL, so you don't need to deploy additional files to display random images, or you can remove it entirely. When specifying square images, Dialog will round the corners a bit, just enough to soften sharp corners
Message length can be quite wordy. Up to 100 words if you don't mind a wall of text. Message supports `\n` newlines. Standard message area is 49 characters x 9 rows.

## Buttons
There are three possible buttons available, **OK**, **Cancel** and **More Information**
**OK** button is the only one that is always shown. Clicking it will exit the app with exit code `0`. It is also mapped to the **Enter** key
**Cancel** button can be optionally shown. Clicking it will exit the app with exit code `2`. It is also mapped to the **ESC** key
**More Information** button can also be optionally shown. Clicking it will exit the app with exit code `3`

Buttons can also display an arbitrary length of characters. Each can be re-named to display any text you desire

The **OK** and **More Information** buttons can also have an options action associated. At this point in time the only supported action is to open a specified URL. With these options enabled, clicking either **OK** or **More Information** will open the URL and close the dialog with the associated exit code. 



# Commandline Options

Dialog is pretty boring by itself. Use the following commandline options to spruce it up a bit.

    --title             Set the Dialog title
                        Text over 40 characters gets truncated
    
    --message           Set the dialog message
                        Message length is up to approximately 80 words
    
    --icon              Set the icon to display
                        pass in file path to png or jpg           -  "/file/path/image.[png|jpg]"
                        optionally pass in URL of file resource   -  "https://someurl/file.[png.jpg]"
                        if not specified, default icon will be used
                        Images from either file or URL are displayed as roundrect if no transparency
    
    --hideicon          hides the icon from view
                        Doing so increases the space available for message text to approximately 100 words

    --button1text       Set the label for Button1
                        Default label is "OK"
                        Bound to <Enter> key

    --button1action     Set the action to take.
                        Accepts URL
                        Default action if not specified is no action
                        Return code when actioned is 0

    --button2           Displays button2 with default label of "Cancel"
        OR
    --button2text       Set the label for Button1
                        Bound to <ESC> key

    --button2action     Return code when actioned is 2
                        -- Setting Custom Actions For Button 2 Is Not Implemented at this time --

    --infobutton        Displays button2 with default label of "More Information"
        OR
    --infobuttontext    Set the label for Information Button
                        If not specified, Info button will not be displayed
                        Return code when actioned is 3

    --infobuttonaction  Set the action to take.
                        Accepts URL
                        Default action if not specified is no action

    --version           Prints the app version
    --help              Prints this text

    --showlicense       Display the Software License Agreement for Dialog

# Return Codes
When displaying a dialog the user can take one of up to three actions, depending on what's available

The following return codes are sent after each action. These can be ignored or used in a calling script for further action
| Button Name | Optional | Hotkey | Return Code |
| ----------- | -------- | ------ | ----------- |
| button1     | No       | Enter  | 0           |
| button2     | Yes      | Esc    | 2           |
| infobutton  | Yes      |        | 3           |
