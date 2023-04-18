//
//  helpText.swift
//  dialog
//
//  Created by Bart Reardon on 17/9/21.
//

//import Foundation

struct swiftDialogHelp {
    var argument : CommandLineArguments
    
    public func printHelpShort() {
        print("swiftDialog v\(getVersionString())")
        print("©2023 Bart Reardon\n")
        let mirror = Mirror(reflecting: argument)
        for child in mirror.children {
            if let arg = child.value as? CLArgument {
                if arg.helpShort != "" {
                    if arg.short != "" {
                        print("  -\(arg.short), --\(arg.long) \(arg.helpUsage)")
                    } else {
                        print("  --\(arg.long) \(arg.helpUsage)")
                    }
                    print("      \(arg.helpShort)\n")
                }
            }
        }
    }
    
    public func printHelpLong(for selectedArg: String) {
        print("swiftDialog v\(getVersionString())\n")
        let mirror = Mirror(reflecting: argument)
        for child in mirror.children {
            if let arg = child.value as? CLArgument, arg.long == selectedArg {
                if arg.short != "" {
                    print("  -\(arg.short), --\(arg.long) \(arg.helpUsage)")
                } else {
                    print("  --\(arg.long) \(arg.helpUsage)")
                }
                print("      \(arg.helpShort)\n")
                print("\(arg.helpLong)\n")
                return
            }
        }
        print("No argument found with the given name: \(selectedArg)")
    }
    
    init(arguments: CommandLineArguments) {
        argument = arguments
        
        argument.titleOption.helpShort = "Set the Dialog title"
        argument.titleOption.helpLong = """
        Text beyond the length of the title area will get truncated
        Default Title is \"\(appvars.titleDefault)\"
        Use keyword "none" to disable the title area entirely
"""
        
        argument.subTitleOption.helpShort = "Text to use as subtitle when sending a system notification"
        argument.subTitleOption.helpLong = "\tFor additional information see --\(appArguments.notification.long))"
        
        argument.titleFont.helpShort = "Lets you modify the title text of the dialog"
        argument.titleFont.helpLong = """
        Can accept up to three parameters, in a comma seperated list, to modify font properties.

            color,colour=<text><hex>  - specified in hex format, e.g. #00A4C7
                                        Also accepts any of the standard Apple colours
                                        black, blue, gray, green, orange, pink, purple, red, white, yellow
                                        default if option is invalid is system primary colour

            size=<float>              - accepts any float value.

            name=<fontname>           - accepts a font name or family
                                        list of available names can be determined with --\(appArguments.listFonts.long)

            weight=[thin | light | regular | medium | heavy | bold]
                default is bold

        Example1: \"colour=#00A4C7,weight=light,size=60\"
        Example2: \"name=Chalkboard,colour=#FFD012,size=40\"
"""
        
        argument.messageOption.helpShort = "Set the dialog message"
        argument.messageOption.helpLong = """
        Messages can be plain text or can include Markdown
        Markdown follows the CommonMark Spec https://spec.commonmark.org/current/
        The message can be of any length. If it is larger than the viewable area
        The message contents will be presented in  scrolable area.
"""
        
        argument.messageAlignment.helpShort = "Set the message alignment"
        argument.messageAlignment.helpUsage = "[left | centre | center | right]"
        argument.messageAlignment.helpLong = """
        Positions the message within the dialog window
        Default is 'left' aligned
"""
        
        argument.messageVerticalAlignment.helpShort = "Set the message position"
        argument.messageVerticalAlignment.helpUsage = "[top* | centre | center | bottom*]"
        argument.messageVerticalAlignment.helpLong = """
        * the only supported option at this time is [center]
"""
        
        argument.messageFont.helpShort = "Set the message font of the dialog"
        argument.messageFont.helpLong = """
        Can accept up to three parameters, in a comma seperated list, to modify font properties.

            color,colour=<text><hex>  - specified in hex format, e.g. #00A4C7
                                        Also accepts any of the standard Apple colours
                                        black, blue, gray, green, orange, pink, purple, red, white, yellow
                                        default if option is invalid is system primary colour

            size=<float>              - accepts any float value.

            name=<fontname>           - accepts a font name or family
                                        list of available names can be determined with --\(appArguments.listFonts.long)

            weight=[thin | light | regular | medium | heavy | bold]
                default is regular

        Example1: \"colour=#00A4C7,weight=light,size=60\"
        Example2: \"name=Chalkboard,colour=#FFD012,size=40\"

        ## CAUTION : Results may be unexpected when mixing font names and weights with markdown
"""
        
        argument.notification.helpShort = "Send a system notification"
        argument.notification.helpLong = """
        Accepts the following arguments:
          --\(appArguments.titleOption.long) <text>
          --\(appArguments.subTitleOption.long) <text>
          --\(appArguments.messageOption.long) <text> (as plain text. newlines supported as \\n)
          --\(appArguments.iconOption.long) <image> *

        * <image> must refer to a local file or app bundle. remote images sources are not supported.
"""
        
        argument.webcontent.helpShort = "Display a web page"
        argument.webcontent.helpUsage = "<url>"
        argument.webcontent.helpLong = """
        Will render a web view within the dialog message area
"""
        
        argument.mainImage.helpShort = "Display an image"
        argument.mainImage.helpUsage = "<file> | <url>"
        argument.mainImage.helpLong = """
        Images will be resized to fit the available display area

        --\(appArguments.mainImageCaption.long) <text>
            Text that will appear underneath the displayed image.

        Multiple --\(appArguments.mainImage.long) arguments can be used which will display the images as a carosel in argument order
"""
        
        argument.mainImageCaption.helpShort = "Display a caption underneath an image"
        argument.mainImageCaption.helpLong = ""
        
        argument.video.helpShort = "Display a video"
        argument.video.helpUsage = "<file> | <url>"
        argument.video.helpLong = """
        Videos will be resized to fit the available display area without clipping the video
        Default dialog window size is changed to \(appvars.videoWindowWidth) x \(appvars.videoWindowHeight)
        
        --\(appArguments.videoCaption.long) <text>
            Text that will appear underneath the displayed video.

        --\(appArguments.autoPlay.long)
            Will force the video to start playing automatically.
"""
        
        argument.videoCaption.helpShort = "Display a caption underneath a video"
        argument.videoCaption.helpLong = ""
        
        argument.autoPlay.helpShort = "Enable video autoplay"
        argument.autoPlay.helpLong = ""
        
        argument.iconOption.helpShort = "Set the dialog icon"
        argument.iconOption.helpUsage = "<file> | <url>"
        argument.iconOption.helpLong = """
        Acceptable Values:
        file path to png or jpg           -  "/file/path/image.[png|jpg]"
        file path to Application          -  "/Applications/Chess.app"
        URL of file resource              -  "https://someurl/file.[png|jpg]"
        SF Symbol                         -  "SF=sf.symbol.name"
        builtin                           -  info | caution | warning

        if not specified, default icon will be used
        Images from either file or URL are displayed as roundrect if no transparancy

        "none" can also be specified to not display an icon but maintain layout (see also --\(appArguments.hideIcon.long))
"""
        
        argument.iconSize.helpShort = "Set the dialog icon size"
        argument.iconSize.helpLong = "Default size is 150"
        
        argument.centreIcon.helpShort = "Set icon to be in the centre"
        argument.centreIcon.helpLong = """
        re-positions the icon to be in the centre, between the title and message areas
"""
        
        argument.overlayIconOption.helpShort = "Set an image to display as an overlay to --icon"
        argument.overlayIconOption.helpUsage = "<file> | <url>"
        argument.overlayIconOption.helpLong = """
        Icon overlays are displayed at 1/2 resolution to the main icon and positioned to the bottom right
        
        Acceptable Values:
            file path to png or jpg           -  "/file/path/image.[png|jpg]"
            file path to Application          -  "/Applications/Chess.app"
            URL of file resource              -  "https://someurl/file.[png|jpg]"
            SF Symbol                         -  "SF=sf.symbol.name"
            builtin                           -  info | caution | warning

        When Specifying SF Symbols for icon or overlay icon, additional parameters for colour and weight are available.
        Additionl parameters are seperated by comma

        "SF=sf.symbol.name,colour=<text><hex>,weight=<text>"

        SF Symbols - visit https://developer.apple.com/sf-symbols/ for details on over 3,100 symbols

        color,colour=<text><hex>          - specified in hex format, e.g. #00A4C7
        bgcolor,bgcolour=<text><hex>
        palette=<text><hex>               - palette accepts up to three colours for use in multicolour
                                            SF Symbols
                                            Use comma seperated values, e.g. palette=red,green,blue

              Also accepts any of the standard Apple colours
              black, blue, gray, green, orange, pink, purple, red, white,
              yellow, mint, cyan, indigo or teal

              default if option is invalid is system primary colour

              bgcolour, bgcolor will set the background colour of the icon overlay
                when SF Symbols are used

              - Special colour "auto".
              When used with a multicolor SF Symbol, the symbols
                default colour scheem will be used
              ** If used with a monochrome SF Symbol **
              ** it will default to black and will not respect dark mode **

        weight=<text>                     - accepts any of the following values:
                                           thin (default), light, regular, medium, heavy, bold
"""
        
        argument.hideIcon.helpShort = "Hides the icon from view"
        argument.hideIcon.helpLong = """
        Doing so increases the space available for message text
"""
        
        argument.button1TextOption.helpShort = "Set the label for Button1"
        argument.button1TextOption.helpLong = """
        Default label is "\(appvars.button1Default)"
        Bound to <Enter> key
"""
        
        argument.button1ActionOption.helpShort = "Set the Button1 action"
        argument.button1ActionOption.helpUsage = "<url>"
        argument.button1ActionOption.helpLong = """
        Accepts URL
        Default action if not specified is no action
        Return code when actioned is 0
"""
        
        argument.button1Disabled.helpShort = "Disable Button1"
        argument.button1Disabled.helpLong = """
        Launches swiftDialog with button1 disabled
        To re-enable, send `buton1: enable` to the dialog command file.
"""
        
        argument.button2Option.helpShort = "Displays Button2"
        argument.button2Option.helpUsage = ""
        argument.button2Option.helpLong = """
        Use \(argument.button2TextOption.long) to modify the button label
        Default label is "\(appvars.button2Default)"
        Bound to <ESC> key
        Return code when actioned is 2
"""
        
        argument.button2TextOption.helpShort = "Displays Button2 with <text>"
        argument.button2TextOption.helpLong = """
        Set the label for Button2
        Bound to <ESC> key
        Return code when actioned is 2
"""
        
        argument.button2ActionOption.helpShort = "Custom Actions For Button 2 Is Not Implemented"
        argument.button2ActionOption.helpLong = """
        -- Setting Custon Actions For Button 2 Is Not Implemented at this time --
"""
        
        argument.button2Disabled.helpShort = "Disable Button2"
        argument.button2Disabled.helpLong = """
        Launches swiftDialog with button2 disabled
        To re-enable, send `buton2: enable` to the dialog command file.
"""
        
        argument.infoButtonOption.helpShort = "Displays info button"
        argument.infoButtonOption.helpUsage = ""
        argument.infoButtonOption.helpLong = """
        Default label is "\(appvars.buttonInfoDefault)"
"""
        
        argument.buttonInfoTextOption.helpShort = "Displays info button with <text>"
        argument.buttonInfoTextOption.helpLong = """
        Set the label for the info button
        If not specified, Info button will not be displayed
        Return code when actioned is 3
"""
        
        argument.buttonInfoActionOption.helpShort = "Set the info button action"
        argument.buttonInfoActionOption.helpUsage = "<url>"
        argument.buttonInfoActionOption.helpLong = """
        Set the action to take when clicking \(appArguments.infoButtonOption.long). Setting this option prevents the info
        button from triggering a dialog exit
        Default action if not specified is to exit with return code 3
"""
        
        
        argument.infoText.helpShort = "Display <text> in place of info button"
        argument.infoText.helpLong = """
        Will display the specified text in place of the info button
        If no text is supplied, will display the current swiftDialog version
"""
        
        argument.infoBox.helpShort = "Display <text> in info box"
        argument.infoBox.helpLong = """
        Will display the specified text in the area underneath the icon when icon is being displayed on the left.
        If icon is hidden or displayed centered, \(appArguments.infoBox.long) will not show
        Markdown is supported
"""
        
        argument.helpMessage.helpShort = "Enable help button with contect <text>"
        argument.helpMessage.helpLong = """
        Will display a help icon to the right of the the default button
        When clicked, contents of the help message will be displayed as a popover
        Supports markdown for formatting.

"""
        
        argument.quitOnInfo.helpShort = "Quit when info button is selected"
        argument.quitOnInfo.helpUsage = ""
        argument.quitOnInfo.helpLong = """
        Will tell swiftDialog to quit when the info button is selected
        Return code when actioned is 3
"""
        
        argument.fullScreenWindow.helpShort = "Enable full screen view"
        argument.fullScreenWindow.helpUsage = ""
        argument.fullScreenWindow.helpLong = """
        Full screen view takes up the entire display area

        In this view, only banner, title, icon and the message area are visible.
        
        No buttons are available but swiftDialog will respond to [Enter], [Esc] and cmd+q keyboard events
"""
        
        argument.blurScreen.helpShort = "Blur screen content behind dialog window"
        argument.blurScreen.helpUsage = ""
        argument.blurScreen.helpLong = """
        This mode will blur the entire screen except for the dialog window.

        All other functions are available but the user is prevented from interacting with any other app until swiftDialog is exited.
"""
        
        argument.progressBar.helpShort = "Enable interactive progress bar"
        argument.progressBar.helpUsage = "[<int>]"
        argument.progressBar.helpLong = """
        Makes an interactive progress bar visible with <int> steps.
        To increment the progress bar send "progress: <int>" command to the dialog command file

        If no valid argument is passed, steps defaults to 10
"""
        
        argument.progressText.helpShort = "Enable the progress text with <text>"
        argument.progressText.helpLong = """
        Initiate the progress text are with some useful content.
        To update progress text send "progresstext: <text>" command to the dialog command file

        Progress text is displayed underneath the progress bar
"""
        
        argument.statusLogFile.helpShort = "Set command file path"
        argument.statusLogFile.helpUsage = "[<file>]"
        argument.statusLogFile.helpLong = """
        Sets the path to the command file swiftDialog will read from to receive updates
        Default file is /var/tmp/dialog.log
"""
        
        argument.bannerImage.helpShort = "Enable banner image"
        argument.bannerImage.helpUsage = "<file> | <url>"
        argument.bannerImage.helpLong = """
        Shows a banner image at the top of the dialog
        Banners images fill the entire top width of the window and are resized to fill, positioned from
        the top left corner of the image.
        Specifying this option will imply --\(appArguments.hideIcon.long)
        
        An image size of 850x150 will suit the default dialog window size
"""
        
        argument.bannerTitle.helpShort = "Enable title within banner area"
        argument.bannerTitle.helpLong = """
        Title is displayed on top of the banner image.
        Title font color is set to "white" by default.
        
        Additional --\(appArguments.titleFont.long) paramater "shadow=<bool>". When set to true,
        displays a drop shadow underneath the text
"""
        
        argument.bannerText.helpShort = "Set text to display in banner area"
        argument.bannerText.helpLong = """
        Using this argument is the equavelent of \(argument.bannerTitle.long) and \(argument.titleOption.long)
"""
        
        argument.dropdownTitle.helpShort = "Select list name"
        argument.dropdownTitle.helpLong = """
        Sets the name for a dropdown select list.

        This name will appear in swiftDialog output on STDOUT with the value of the selected item.
        For a single select list, standard output format will be:
            "SelectedOption" : "<value>"
            "SelectedIndex" : <index>
            "<name>" : "<value>"
            "<name>" index : "<index>"

        Multiple --\(argument.dropdownTitle.long) arguments may be specified. Related --\(argument.dropdownValues.long) and --\(argument.dropdownDefault.long) arguments can be specified and are associated to a select list in the order they are presented

        If multiple select lists are used, "SelectedOption" and "SelectedIndex" are not represented.

        Output of select items is only shown if swiftDialog's exit code is 0

        JSON formatting is available for more direct control. for example:

        "selectitems" : [
            {"title" : "Select 1", "values" : ["one","two","three"]},
            {"title" : "Select 2", "values" : ["red","green","blue"], "default" : "red"}
        ]
"""
        
        argument.dropdownValues.helpShort = "Select list values"
        argument.dropdownValues.helpUsage = "<csv>"
        argument.dropdownValues.helpLong = """
        List of values to be displayed in an associated --\(argument.dropdownTitle.long)

        Argument values are in CSV format
        e.g. "Option 1,Option 2,Option 3"

        see also --\(argument.dropdownTitle.long) and --\(argument.dropdownDefault.long)
"""
        
        argument.dropdownDefault.helpShort = "Default select list value"
        argument.dropdownDefault.helpLong = """
        Default option to be selected (must match one of the items in the list)
"""
        
        argument.textField.helpShort = "Enable a textfield with the specified label"
        argument.textField.helpUsage = "<text>[,required,secure,prompt=\"<text>\"]"
        argument.textField.helpLong = """
        When swiftDialog exits the contents of the textfield will be presented as <text> : <user_input>
        in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
        Multiple textfields can be specified as required.

        Modifiers available to text fields are:
            secure     - Presends a secure input area. Contents of the textfield will not be shown on screen
            required   - swiftDialog will not exit until the field is populated
            prompt     - Pre-fill the field with some prompt text
            regex      - Specify a regular expression that the field must satisfy for the content to be accepted.
            regexerror - Specify a custom error to display if regex conditions are not met

        modifiers can be combined e.g. --\(appArguments.textField.long) <text>,secure,required
                                       --\(appArguments.textField.long) <text>,required,prompt="<text>"
                                       --\(appArguments.textField.long) <text>,regex="\\d{6}",prompt="000000",regexerror="Enter 6 digits"
        (secure fields cannot have the prompt modifier applied)
"""
        
        argument.checkbox.helpShort = "Enable a checkbox with the specified label"
        argument.checkbox.helpLong = """
        When swiftDialog exits the status of the checkbox will be presented as <text> : [true|false]
        in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
        Multiple checkboxes can be specified as required.
"""
        
        argument.listItem.helpShort = "Enable a list item with the specified label"
        argument.listItem.helpLong = """
        Multiple items can be added by specifying --\(appArguments.listItem.long) multiple times

        Alternatly, specify a list item with either of the follwoing JSON formats (in conjunction with --\(appArguments.jsonFile.long) or \(appArguments.jsonString.long):
        Simple:
        {
          "listitem" : ["Item One", "Item Two", "Item Three", "Item Four", "Item Five"]
        }

        Advanced:
        {
          "listitem" : [
            {"title" : "<text>", "status" : "<status>", "statustext" : "<text>"},
            {"title" : "<text>", "status" : "<status>", "statustext" : "<text>"}
          ]
        }

        <status> can be one of "wait", "success", "fail", "error" or "pending"
        and will display an apropriate icon in the status area.

        Updates to items in the list can be sent to the command file specified by --\(appArguments.statusLogFile.long):
        Clear an existing list:
            list: clear
        Create a new list:
            list: <csv>
        Update a list item (simple):
            listitem: <title>: [<text>|<status>]
        Update a list item (advanced):
            listitem: [title: <title>|index: <index>], status: <status>, statustext: <text>
        Add an item to the end of the current list:
            listitem: add: , title: <text>, status: <status>, statustext: <text>
        Delete an item (one of):
            listitem: index: <index>, delete:
            listitem: title: <text>, delete:

        <index> starts at 0

"""
        
        argument.listStyle.helpShort = "Set list style [expanded|compact]"
        argument.listStyle.helpLong = """
        When presenting a list, use of this argument will adjust the vertical spacing between each row.
"""
        
        argument.watermarkImage.helpShort = "Set a dialog background image"
        argument.watermarkImage.helpUsage = "<file>"
        argument.watermarkImage.helpLong = """
        If the image is larger than the default dialog size (820x380) and no window size options are given (specifically window height),
        the dialog window height will be adjusted so the image fills the entire window width, 820 by default or if specified using --\(appArguments.windowWidth.long)
"""
        
        argument.watermarkAlpha.helpShort = "Set background image transparancy"
        argument.watermarkAlpha.helpUsage = "<number>"
        argument.watermarkAlpha.helpLong = """
        Number between 0 and 1
        0 is fully transparant
        1 is fully opaque
        Default is 0.5
"""
        
        argument.watermarkPosition.helpShort = "Set background image position"
        argument.watermarkPosition.helpUsage = "[topleft | left | bottomleft | top | center/cetre | bottom | topright | right | bottomright]"
        argument.watermarkPosition.helpLong = """
        Positions the background image in the window.
        Default is center
"""
        
        argument.watermarkFill.helpShort = "Set background image fill type"
        argument.watermarkFill.helpUsage = "[fill | fit]"
        argument.watermarkFill.helpLong = """
        fill - resizes the image to fill the entire window. Image will be truncated if necessary
        fit  - resizes the image to fit the window but will not truncate
        Default is none which will display the image at its native resolution
"""
        
        argument.watermarkScale.helpShort = "Enable background image scaling"
        argument.watermarkScale.helpUsage = argument.watermarkFill.helpUsage
        argument.watermarkScale.helpLong = argument.watermarkFill.helpLong
        
        argument.windowWidth.helpShort = "Set dialog window width"
        argument.windowWidth.helpUsage = "<number>"
        argument.windowWidth.helpLong = """
        Sets the width of the dialog window to the specified width in points
"""
        
        argument.windowHeight.helpShort = "Set dialog window width"
        argument.windowHeight.helpUsage = "<number>"
        argument.windowHeight.helpLong = """
        Sets the height of the dialog window to the specified height in points
"""
        
        argument.position.helpShort = "Set dialog window position"
        argument.position.helpUsage = "[topleft | left | bottomleft | top | center/centre | bottom | topright | right | bottomright]"
        argument.position.helpLong = """
        Poitions the dialog window a the the defined location on the screen

        Default is a visually appealing position slightly towards the top of centre, not dead centre.
"""
        
        argument.timerBar.helpShort = "Enable countdown timer (with <seconds>)"
        argument.timerBar.helpUsage = "[<seconds>]"
        argument.timerBar.helpLong = """
        Replaces default button with a timer countdown after which swiftDialog will close with exit code 4
        Default timer value is 10 seconds
        Optional value <seconds> can be specified to the desired value

        If used in conjuction with --\(appArguments.button1TextOption.long) the default button
        will be displayed but will be disabled for the first 3 seconds of the timer, after which it
        becomes active and can be used to dismiss swiftDialog with the standard button 1 exit code of 0
"""
        
        argument.hideTimerBar.helpShort = "Hide countdown timer if enabled"
        argument.hideTimerBar.helpLong = """
        Will hide the timer bar. swiftDialog will close after time specified by --\(appArguments.timerBar.long)
        Default OK button is displayed. This is to prevent persistant or unclosable dialogs of unknown duration.
"""
        
        argument.movableWindow.helpShort = "Enable dialog to be moveable"
        argument.movableWindow.helpUsage = ""
        argument.movableWindow.helpLong = """
        Let window me moved around the screen. Default is not moveable
"""
        
        argument.forceOnTop.helpShort = "Enable dialog to be always positioned on top of other windows"
        argument.forceOnTop.helpUsage = ""
        argument.forceOnTop.helpLong = """
        Make the window appear above all other windows even when not active
"""
        
        argument.bigWindow.helpShort = "Enable 25% increase in default window size"
        argument.bigWindow.helpUsage = ""
        argument.bigWindow.helpLong = ""
        
        argument.smallWindow.helpShort = "Enable 25% decrease in default window size"
        argument.smallWindow.helpUsage = ""
        argument.smallWindow.helpLong = ""
        
        argument.miniMode.helpShort = "Enable mini mode"
        argument.miniMode.helpUsage = ""
        argument.miniMode.helpLong = """
        Presents a mini mode dialog of fixed size, presenting title, icon and message, limited to two lines.
        Button 1 and 2 with modofocations are available.
        When used with --progress, buttons are replaced by progress bar and progress text.
            * In this presentation, quitting the dialog is acheived with use of the command file.
"""
        
        argument.jsonOutPut.helpShort = "Enable JSON output"
        argument.jsonOutPut.helpUsage = ""
        argument.jsonOutPut.helpLong = """
        Outputs any results in json format for easier processing
        (for dropdown item selections, textfield and checbox responses)
"""
        
        argument.jsonFile.helpShort = "Read dialog settings from JSON formatted <file>"
        argument.jsonFile.helpUsage = "<file>"
        argument.jsonFile.helpLong = """
        Use JSON formatted data file as input instead of command line paramaters

        Uses the same naming convention as the long form command line options
        e.g.
        {
            "\(appArguments.titleOption.long)" : "Title here",
            "\(appArguments.messageOption.long)" : "Message here"
        }

        "\(appArguments.mainImage.long)" and "\(appArguments.checkbox.long)" can accept an array of multiple values
        e.g.
        {
            "checkbox" : [{
                "label" : "Option 1",
                "checked" : true,
                "disabled" : true
            },
            ...]
            "image": [{
                "imagename": "<image>",
                "caption": "<caption>"
            },
            ...]
        }

        "\(appArguments.textField.long)" can specify multiple valuse as a simple array:
        e.g.
        {
            "textfield": ["Text Entry 1", "Text Entry 2", "Text Entry 3"]
        }
"""
        
        argument.jsonString.helpShort = "Read dialog settings from JSON formatted <string>"
        argument.jsonString.helpLong = """
        Same data format as --\(appArguments.jsonFile.long) but passed in as a string on the command line without
        requiring an intermediate file.
"""
        
        argument.quitKey.helpShort = "Set dialog quit key"
        argument.quitKey.helpUsage = "<char>"
        argument.quitKey.helpLong = """
        Use the specified character as the command+ key combination for quitting instead of "q".
        Capitol letters can be used in which case command+shift+<key> will be required
"""
        
        argument.ignoreDND.helpShort = "Ignore user do-not-disturb settings"
        argument.ignoreDND.helpUsage = ""
        argument.ignoreDND.helpLong = """
        Will ignore user Do Not Disturb setting
            (Do Not Disturb detection only works in macOS 11)
"""
        
        argument.jamfHelperMode.helpShort = "Enable jamfHelper mode"
        argument.jamfHelperMode.helpUsage = ""
        argument.jamfHelperMode.helpLong = """
        Switches all command line options to accept jamfHelper style options
        Useful for using as a drop in replacement for jamfHelper in existing scripts
            replace "/path/to/jamfHelper" with \"/path/to/dialog -\(appArguments.jamfHelperMode.short)\"
        Does not (yet) support the following:
            -windowType hud
            -showDelayOptions
            -alignDescription, -alignHeading, -alignCountdown
            -iconSize
        swiftDialog will do its best to display jamfHelper content in a swiftDialog-esque way.
        Any unsupported display options will be ignored.
"""
        
        argument.getVersion.helpShort = "Print version string"
        argument.getVersion.helpUsage = ""
        argument.getVersion.helpLong = ""
        
        argument.licence.helpShort = "Print license"
        argument.licence.helpUsage = ""
        argument.licence.helpLong = ""
        
        argument.helpOption.helpShort = "Print help"
        argument.helpOption.helpUsage = "[<argument>]"
        argument.helpOption.helpLong = """
        Prints list of command line options and any arguments

        Use with an option name as the argument to get detailed information about that argument
"""
    }
    
}


var helpText = """
    swiftDialog version \(getVersionString()) ©2022 Bart Reardon

    OPTIONS:

    ** Basic Options - - - - - - - - - - - - - - - -
    
        -\(appArguments.titleOption.short), --\(appArguments.titleOption.long) <text>
                    Set the Dialog title
                    Text beyond the length of the title area will get truncated
                    Default Title is "\(appvars.titleDefault)"
                    Use keyword "none" to disable the title area entirely
    
        --\(appArguments.subTitleOption.long) <text>
                    Text to use as subtitle when sending a system notification (see --\(appArguments.notification.long))

        --\(appArguments.titleFont.long) <text>
                    Lets you modify the title text of the dialog.

                    Can accept up to three parameters, in a comma seperated list, to modify font properties.

                        color,colour=<text><hex>  - specified in hex format, e.g. #00A4C7
                                                    Also accepts any of the standard Apple colours
                                                    black, blue, gray, green, orange, pink, purple, red, white, yellow
                                                    default if option is invalid is system primary colour

                        size=<float>              - accepts any float value.

                        name=<fontname>           - accepts a font name or family
                                                    list of available names can be determined with --\(appArguments.listFonts.long)

                        weight=[thin | light | regular | medium | heavy | bold]
                            default is bold

                    Example1: \"colour=#00A4C7,weight=light,size=60\"
                    Example2: \"name=Chalkboard,colour=#FFD012,size=40\"
        
        -\(appArguments.messageOption.short), --\(appArguments.messageOption.long) <text>
                    Set the dialog message
                    Messages can be plain text or can include Markdown
                    Markdown follows the CommonMark Spec https://spec.commonmark.org/current/
                    The message can be of any length. If it is larger than the viewable area
                    The message contents will be presented in  scrolable area.
    
        --\(appArguments.messageAlignment.long) [left | centre | center | right]
                    Set the message alignment.
                    Default is 'left'
    
        --\(appArguments.messageVerticalAlignment.long) [top* | centre | center | bottom*]
                    Set the message position.
                    
                    * the only supported option at this time is [center]
                    
        --\(appArguments.messageFont.long) <text>
                    Lets you modify the message text of the dialog.

                    Can accept up to three parameters, in a comma seperated list, to modify font properties.

                        color,colour=<text><hex>  - specified in hex format, e.g. #00A4C7
                                                    Also accepts any of the standard Apple colours
                                                    black, blue, gray, green, orange, pink, purple, red, white, yellow
                                                    default if option is invalid is system primary colour

                        size=<float>              - accepts any float value.

                        name=<fontname>           - accepts a font name or family
                                                    list of available names can be determined with --\(appArguments.listFonts.long)

                        weight=[thin | light | regular | medium | heavy | bold]
                            default is regular

                    Example1: \"colour=#00A4C7,weight=light,size=60\"
                    Example2: \"name=Chalkboard,colour=#FFD012,size=40\"

                    ## CAUTION : Results may be unexpected when mixing font names and weights with markdown
    
        --\(appArguments.notification.long)
                    Send a system notification
                    Accepts the following arguments:
                      --\(appArguments.titleOption.long) <text>
                      --\(appArguments.subTitleOption.long) <text>
                      --\(appArguments.messageOption.long) <text> (as plain text. newlines supported as \\n)
                      --\(appArguments.iconOption.long) <image> *
    
                    * <image> must refer to a local file or app bundle. remote images sources are not supported.
    
        --\(appArguments.webcontent.long)
                    Display a web page
        
        -\(appArguments.mainImage.short), --\(appArguments.mainImage.long)  <file> | <url>
                    Display an image instead of a message.
                    Images will be resized to fit the available display area
    
                    --\(appArguments.mainImageCaption.long) <text>
                        Text that will appear underneath the displayed image.
    
        --\(appArguments.video.long)  <file> | <url>
                    Display a video instead of a message.
                    Videos will be resized to fit the available display area without clipping the video
                    Default dialog window size is changed to \(appvars.videoWindowWidth) x \(appvars.videoWindowHeight)
                    
    
                    --\(appArguments.videoCaption.long) <text>
                        Text that will appear underneath the displayed video.
    
                    --\(appArguments.autoPlay.long)
                        Will force the video to start playing automatically.
        
        -\(appArguments.iconOption.short), --\(appArguments.iconOption.long) <file> | <url>
                    Set the icon to display
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    SF Symbol                         -  "SF=sf.symbol.name"
                    builtin                           -  info | caution | warning

                    if not specified, default icon will be used
                    Images from either file or URL are displayed as roundrect if no transparancy
    
                    "none" can also be specified to not display an icon but maintain layout (see also --\(appArguments.hideIcon.long))
    
        --\(appArguments.iconSize.long)
                    Will render the icon with the specified size.
                    Default size is 150
    
        --\(appArguments.centreIcon.long)
                    re-positions the icon to be in the centre, between the title and message areas
    
        -\(appArguments.overlayIconOption.short), --\(appArguments.overlayIconOption.long) <file> | <url>
                    Set an image to display as an overlay to --icon
                    image is displayed at 1/2 resolution to the main image and positioned to the bottom right
                    Acceptable Values:
                    file path to png or jpg           -  "/file/path/image.[png|jpg]"
                    file path to Application          -  "/Applications/Chess.app"
                    URL of file resource              -  "https://someurl/file.[png|jpg]"
                    SF Symbol                         -  "SF=sf.symbol.name"
                    builtin                           -  info | caution | warning

                When Specifying SF Symbols for icon or overlay icon, additional parameters for colour and weight are available:
                additionl parameters are seperated by comma

                    "SF=sf.symbol.name,colour=<text><hex>,weight=<text>"

                    SF Symbols - visit https://developer.apple.com/sf-symbols/ for details on over 3,100 symbols

                    color,colour=<text><hex>          - specified in hex format, e.g. #00A4C7
                    bgcolor,bgcolour=<text><hex>
                    palette=<text><hex>               - palette accepts up to three colours for use in multicolour
                                                        SF Symbols
                                                        Use comma seperated values, e.g. palette=red,green,blue

                                                      Also accepts any of the standard Apple colours
                                                      black, blue, gray, green, orange, pink, purple, red, white,
                                                      yellow, mint, cyan, indigo or teal

                                                      default if option is invalid is system primary colour

                                                      bgcolour, bgcolor will set the background colour of the icon overlay
                                                        when SF Symbols are used

                                                      - Special colour "auto".
                                                      When used with a multicolor SF Symbol, the symbols
                                                        default colour scheem will be used
                                                      ** If used with a monochrome SF Symbol **
                                                      ** it will default to black and will not respect dark mode **

                    weight=<text>                     - accepts any of the following values:
                                                       thin (default), light, regular, medium, heavy, bold
    
        -\(appArguments.hideIcon.short), --\(appArguments.hideIcon.long)
                    Hides the icon from view
                    Doing so increases the space available for message text
        
        --\(appArguments.button1TextOption.long) <text>
                    Set the label for Button1
                    Default label is "\(appvars.button1Default)"
                    Bound to <Enter> key

        --\(appArguments.button1ActionOption.long) <url>
                    Set the action to take.
                    Accepts URL
                    Default action if not specified is no action
                    Return code when actioned is 0
    
        --\(appArguments.button1ShellActionOption.long) <command>
                    << EXPERIMENTAL >>
                    Runs the specified shell command using zsh
                    Command input and output is not sanitised or checked.
                    If your command fails, swiftDialog still exits 0
    
        --\(appArguments.button1Disabled.long)
                    Launches swiftDialog with button1 disabled
                    To re-enable, send `buton1: enable` to the dialog command file.

        -\(appArguments.button2Option.short), --\(appArguments.button2Option.long)
                    Displays button2 with default label of "\(appvars.button2Default)"
            OR

        --\(appArguments.button2TextOption.long) <text>
                    Set the label for Button1
                    Bound to <ESC> key

        --\(appArguments.button2ActionOption.long) <url>
                    Return code when actioned is 2
                    -- Setting Custon Actions For Button 2 Is Not Implemented at this time --
    
        --\(appArguments.button2Disabled.long)
                    Launches swiftDialog with button2 disabled
                    To re-enable, send `buton2: enable` to the dialog command file.

        -\(appArguments.infoButtonOption.short), --\(appArguments.infoButtonOption.long)
                    Displays info button with default label of "\(appvars.buttonInfoDefault)"

            OR

        --\(appArguments.buttonInfoTextOption.long) <text>
                    Set the label for Information Button
                    If not specified, Info button will not be displayed
    
        --\(appArguments.buttonInfoActionOption.long)  <url>
                    Set the action to take when clicking \(appArguments.infoButtonOption.long). Setting this option prevents the info
                    button from triggering a dialog exit
                    Default action if not specified is to exit with return code 3
    
        --\(appArguments.infoText.long) (<text>)
                    Will display the specified text in place of the info button
                    If no text is supplied, will display the current swiftDialog version
    
        --\(appArguments.infoBox.long) (<text>)
                    Will display the specified text in the area underneath the icon when icon is being displayed on the left.
                    If icon is hidden or displayed centered, \(appArguments.infoBox.long) will not show
                    Markdown is supported
    
        --\(appArguments.helpMessage.long) (<text>)
                    Will display a help icon to the right of the the default button
                    When clicked, contents of the help message will be displayed as a popover
                    Supports markdown for formatting.

        --\(appArguments.quitOnInfo.long)
                    Will tell swiftDialog to quit when the info button is selected
                    Return code when actioned is 3

    ** Advanced Options - - - - - - - - - - - - - - - -
        
        -\(appArguments.fullScreenWindow.short), --\(appArguments.fullScreenWindow.long)
                    Uses full screen view.
                    In this view, only banner, title, icon and the message area are visible.
    
        --\(appArguments.blurScreen.long)
                    Will blur the background of the display while swiftDialog is showing
    
        --\(appArguments.progressBar.long) <int>
                    Makes an interactive progress bar visible with <int> steps.
                    To increment the progress bar send "progress: <int>" command to the dialog command file
    
        --\(appArguments.progressText.long) <text>
                    Initiate the progress text are with some useful content.
                    To update progress text send "progresstext: <text>" command to the dialog command file
    
        --\(appArguments.statusLogFile.long) <file>
                    Sets the path to the command file swiftDialog will read from to receive updates
                    Default file is /var/tmp/dialog.log

        -\(appArguments.bannerImage.short), --\(appArguments.bannerImage.long) <file> | <url>
                    Shows a banner image at the top of the dialog
                    Banners images fill the entire top width of the window and are resized to fill, positioned from
                    the top left corner of the image.
                    Specifying this option will imply --\(appArguments.hideIcon.long)
                    Recommended Banner Image size is 850x150.
    
        --\(appArguments.bannerTitle.long) (<text>)
                    Title is displayed on top of the banner image.
                    Title font color is set to "white" by default.
                    
                    Additional --\(appArguments.titleFont.long) paramater "shadow=<bool>". When set to true,
                    displays a drop shadow underneath the text
    
        --\(appArguments.dropdownTitle.long) <text>
                    Title for dropdown selection
    
        --\(appArguments.dropdownValues.long) <text><csv>
                    List of values to be displayed in the dropdown, specivied in CSV format
                    e.g. "Option 1,Option 2,Option 3"
    
        --\(appArguments.dropdownDefault.long) <text>
                    Default option to be selected (must match one of the items in the list)

                    If specified, the selected option will be sent to stdout in two forms:
                      SelectedOption - Outputs the text of the option seelcted
                      SelectedIndex  - Outputs the index of the option selected, starting at 0

                      example output b:
                        SelectedOption: Option 1
                        SelectedIndex: 0

                    Output of select items is only shown if swiftDialog's exit code is 0

                    Multiple dropdown caluse, titles and default selections can be specified as required.
                    Associations are made in the order they are presented on the command line
                    Or use json formatting for more direct control. for example:

                    "selectitems" : [
                        {"title" : "Select 1", "values" : ["one","two","three"]},
                        {"title" : "Select 2", "values" : ["red","green","blue"], "default" : "red"}
                    ]

                    When using multiple dropdown lists, output will be in the form:
                    <title> : <value>
                    <title> index : <index_value>
    
        --\(appArguments.textField.long) <text>(,required,secure,prompt="<text>")
                    Present a textfield with the specified label
                    When swiftDialog exits the contents of the textfield will be presented as <text> : <user_input>
                    in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
                    Multiple textfields can be specified as required.

                    Modifiers available to text fields are:
                        secure     - Presends a secure input area. Contents of the textfield will not be shown on screen
                        required   - swiftDialog will not exit until the field is populated
                        prompt     - Pre-fill the field with some prompt text (prompt text will not be returned, macOS 12+ only, macOS 11 safe)
                        regex      - Specify a regular expression that the field must satisfy for the content to be accepted.
                        regexerror - Specify a custom error to display if regex conditions are not met
    
                    modifiers can be combined e.g. --\(appArguments.textField.long) <text>,secure,required
                                                   --\(appArguments.textField.long) <text>,required,prompt="<text>"
                                                   --\(appArguments.textField.long) <text>,regex="\\d{6}",prompt="000000",regexerror="Enter 6 digits"
                    (secure fields cannot have the prompt modifier applied)
    
        --\(appArguments.checkbox.long) <text>
                    Present a checkbox with the specified label
                    When swiftDialog exits the status of the checkbox will be presented as <text> : [true|false]
                    in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
                    Multiple checkboxes can be specified as required.
    
        --\(appArguments.listItem.long) <text>
                    Creates a list item with the specified text as the item title.
                    Multiple items can be added by specifying --\(appArguments.listItem.long) multiple times
    
                    Alternatly, specify a list item with either of the follwoing JSON formats (in conjunction with --\(appArguments.jsonFile.long) or \(appArguments.jsonString.long):
                    Simple:
                    {
                      "listitem" : ["Item One", "Item Two", "Item Three", "Item Four", "Item Five"]
                    }

                    Advanced:
                    {
                      "listitem" : [
                        {"title" : "<text>", "status" : "<status>", "statustext" : "<text>"},
                        {"title" : "<text>", "status" : "<status>", "statustext" : "<text>"}
                      ]
                    }

                    <status> can be one of "wait", "success", "fail", "error" or "pending"
                    and will display an apropriate icon in the status area.
    
                    Updates to items in the list can be sent to the command file specified by --\(appArguments.statusLogFile.long):
                    Clear an existing list:
                        list: clear
                    Create a new list:
                        list: <csv>
                    Update a list item (simple):
                        listitem: <title>: [<text>|<status>]
                    Update a list item (advanced):
                        listitem: [title: <title>|index: <index>], status: <status>, statustext: <text>
                    Add an item to the end of the current list:
                        listitem: add: , title: <text>, status: <status>, statustext: <text>
                    Delete an item (one of):
                        listitem: index: <index>, delete:
                        listitem: title: <text>, delete:

                    <index> starts at 0
    
        -\(appArguments.watermarkImage.short), --\(appArguments.watermarkImage.long) <file>
                    Displays the selected file as a background image.
                    If the image is larger than the default dialog size (820x380) and no window size options are given (specifically window height),
                    the dialog window height will be adjusted so the image fills the entire window width, 820 by default or if specified using --\(appArguments.windowWidth.long)
    
        -\(appArguments.watermarkAlpha.short), --\(appArguments.watermarkAlpha.long) <number>
                    Number between 0 and 1
                    0 is fully transparant
                    1 is fully opaque
                    Default is 0.5
                    
        -\(appArguments.watermarkPosition.short), --\(appArguments.watermarkPosition.long) [topleft | left | bottomleft | top | center/cetre | bottom | topright | right | bottomright]
                    Positions the background image in the window.
                    Default is center
    
        -\(appArguments.watermarkFill.short), --\(appArguments.watermarkFill.long) [fill | fit]
        -\(appArguments.watermarkScale.short), --\(appArguments.watermarkScale.long) [fill | fit]
                    fill - resizes the image to fill the entire window. Image will be truncated if necessary
                    fit  - resizes the image to fit the window but will not truncate
                    Default is none which will display the image at its native resolution
    
    
        --\(appArguments.windowWidth.long) <number>
                    Sets the width of the dialog window to the specified width in points
    
        --\(appArguments.windowHeight.long) <number>
                    Sets the height of the dialog window to the specified height in points
    
        --\(appArguments.position.long) [topleft | left | bottomleft | top | center/centre | bottom | topright | right | bottomright]
                    Poitions the dialog window a the the defined location on the screen
    
        --\(appArguments.timerBar.long) (<seconds>)
                    Replaces default button with a timer countdown after which swiftDialog will close with exit code 4
                    Default timer value is 10 seconds
                    Optional value <seconds> can be specified to the desired value
    
                    If used in conjuction with --\(appArguments.button1TextOption.long) the default button
                    will be displayed but will be disabled for the first 3 seconds of the timer, after which it
                    becomes active and can be used to dismiss swiftDialog with the standard button 1 exit code of 0
    
        --\(appArguments.hideTimerBar.long)
                    Will hide the timer bar. swiftDialog will close after time specified by --\(appArguments.timerBar.long)
                    Default OK button is displayed. This is to prevent persistant or unclosable dialogs of unknown duration.
    
        -\(appArguments.movableWindow.short), --\(appArguments.movableWindow.long)
                    Let window me moved around the screen. Default is not moveable

        -\(appArguments.forceOnTop.short), --\(appArguments.forceOnTop.long)
                    Make the window appear above all other windows even when not active

        -\(appArguments.bigWindow.short), --\(appArguments.bigWindow.long)
                    Makes the dialog 25% bigger than normal. More room for message text

        -\(appArguments.smallWindow.short), --\(appArguments.smallWindow.long)
                    Makes the dialog 25% smaller. Less room for message text.
    
        --\(appArguments.miniMode.long)
                    Presents a mini mode dialog of fixed size, presenting title, icon and message, limited to two lines.
                    Button 1 and 2 with modofocations are available.
                    When used with --progress, buttons are replaced by progress bar and progress text.
                        * In this presentation, quitting the dialog is acheived with use of the command file.
    
        -\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)
                    Outputs any results in json format for easier processing
                    (for dropdown item selections and textfield responses)
    
        --\(appArguments.jsonFile.long) <file>
                    Use JSON formatted data file as input instead of command line paramaters

                    Uses the same naming convention as the long form command line options
                    e.g.
                    {
                        "\(appArguments.titleOption.long)" : "Title here",
                        "\(appArguments.messageOption.long)" : "Message here"
                    }
    
                    "\(appArguments.mainImage.long)" and "\(appArguments.checkbox.long)" can accept an array of multiple values
                    e.g.
                    {
                        "checkbox" : [{
                            "label" : "Option 1",
                            "checked" : true,
                            "disabled" : true
                        },
                        ...]
                        "image": [{
                            "imagename": "<image>",
                            "caption": "<caption>"
                        },
                        ...]
                    }
    
                    "\(appArguments.textField.long)" can specify multiple valuse as a simple array:
                    e.g.
                    {
                        "textfield": ["Text Entry 1", "Text Entry 2", "Text Entry 3"]
                    }
    
        --\(appArguments.jsonString.long) <text>
                    Same data format as --\(appArguments.jsonFile.long) but passed in as a string on the command line without
                    requiring an intermediate file.
    
        --\(appArguments.quitKey.long) <char>
                    Use the specified character as the command+ key combination for quitting instead of "q".
                    Capitol letters can be used in which case command+shift+<key> will be required


        -\(appArguments.ignoreDND.short), --\(appArguments.ignoreDND.long)
                    Will ignore user Do Not Disturb setting
                        (Do Not Disturb detection only works in macOS 11)
    
    
        -\(appArguments.jamfHelperMode.short), --\(appArguments.jamfHelperMode.long)
                    Switches all command line options to accept jamfHelper style options
                    Useful for using as a drop in replacement for jamfHelper in existing scripts
                        replace "/path/to/jamfHelper" with \"/path/to/dialog -\(appArguments.jamfHelperMode.short)\"
                    Does not (yet) support the following:
                        -windowType hud
                        -showDelayOptions
                        -alignDescription, -alignHeading, -alignCountdown
                        -iconSize
                    swiftDialog will do its best to display jamfHelper content in a swiftDialog-esque way.
                    Any unsupported display options will be ignored.
                        
        -\(appArguments.getVersion.short), --\(appArguments.getVersion.long)
                    Prints the app version

        -\(appArguments.licence.short), --\(appArguments.licence.long)
                    Display the Software Licence Agreement for swiftDialog

        --\(appArguments.helpOption.long)
                    Prints this text
    """
