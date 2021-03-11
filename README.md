
# Dialog

Dialog is a simple app that displays a dialog with specified content passed in from the commandline

![Dialog Logo](/assets/screen1.png)


# Commandline Options
 --title             Set the Dialog title
                        Text over 40 characters gets truncated
                        Default Title is "\(AppVariables.titleDefault)"
    
    --message           Set the dialog message
                        Message length is up to approximately 80 words
    
    --icon              Set the icon to display
                        pass in file path to png or jpg           -  "/file/path/image.[png|jpg]"
                        optionally pass in URL of file resource   -  "https://someurl/file.[png.jpg]"
                        if not specified, default icon will be used
                        Images from either file or URL are displayed as roundrect if no transparancy
    
    --hideicon          hides the icon from view
                        Doing so increases the space available for message text to approximately 100 words

    --button1text       Set the label for Button1
                        Default label is "\(AppVariables.button1Default)"
                        Bound to <Enter> key

    --button1action     Set the action to take.
                        Accepts URL
                        Default action if not specified is no action
                        Return code when actioned is 0

    --button2           Displays button2 with default label of "\(AppVariables.button2Default)"
        OR
    --button2text       Set the label for Button1
                        Bound to <ESC> key

    --button2action     Return code when actioned is 2
                        -- Setting Custon Actions For Button 2 Is Not Implemented at this time --

    --infobutton        Displays button2 with default label of "\(AppVariables.buttonInfoDefault)"
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

1. Hit <Enter> or click the default button (button1)
2. Hit <ESC> or click the Cancel/Other button (button2)
3. Click the More Information button (infobutton) if visible

The following return codes are sent after each action. These can be ignored or used in a calling script for further action
|Button Name|Return Code|
|-|-|
|button1|0|
|button2|2|
|infobutton|3|

