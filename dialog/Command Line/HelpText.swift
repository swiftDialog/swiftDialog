//
//  helpText.swift
//  dialog
//
//  Created by Bart Reardon on 17/9/21.
//

//import Foundation

struct SDHelp {
    var argument: CommandLineArguments

    public func printHelpShort() {
        writeLog("Printing short help")
        print("swiftDialog v\(getVersionString())")
        print("©2024 Bart Reardon\n")
        print("\n use --help <option> for more details\n")
        let mirror = Mirror(reflecting: argument)
        for child in mirror.children {
            if let arg = child.value as? CommandlineArgument {
                var helpArgs = " --\(arg.long) \(arg.helpUsage)"
                if arg.short != "" {
                    helpArgs = " -\(arg.short), \(helpArgs)"
                }
                if arg.helpShort != "" {
                    print("  \(helpArgs)\n")
                    print("\t\(arg.helpShort)\n")
                }
            }
        }
    }

    public func printHelpLong(for selectedArg: String) {
        writeLog("Printing long help for \(selectedArg)")
        let mirror = Mirror(reflecting: argument)
        for child in mirror.children {
            if let arg = child.value as? CommandlineArgument, arg.long == selectedArg || arg.short == selectedArg {
                var helpArgs = " --\(arg.long) \(arg.helpUsage)"
                if arg.short != "" {
                    helpArgs = " -\(arg.short), \(helpArgs)"
                }
                if arg.helpShort != "" {
                    print("\n  \(helpArgs)\n")
                }
                print("\t\(arg.helpShort)\n")
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
        Default Title is \"\(appDefaults.titleDefault)\"
        Use keyword "none" to disable the title area entirely
"""

        argument.subTitleOption.helpShort = "Text to use as subtitle when sending a system notification"
        argument.subTitleOption.helpLong = "\tFor additional information see --\(appArguments.notification.long))"

        argument.titleFont.helpShort = "Lets you modify the title text of the dialog"
        argument.titleFont.helpLong = """
        Can accept up to three parameters, in a comma separated list, to modify font properties.

            color,colour=<text><hex>  - accepts any of the following color specifiers:
                                        * A standard macOS system color:
                                            [black | blue | gray | green | orange | pink | purple | red | white | yellow]
                                        * The user's preferred "Accent Color", specified with the string 'accent'
                                        * A custom color specified in hex format, e.g. #00A4C7
                                        Default: macOS system 'primary' color.

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
        Messages can be plain text or can include Markdown.

        Markdown is compatible with the GitHub Flavored Markdown Spec (https://github.github.com/gfm/)
        and can display images (URL only. Inline local resources are not supported), headings,
        lists (including task lists), blockquotes, code blocks, tables, thematic breaks, styled text and links.

        The message can be of any length. If it is larger than the viewable area
        the message contents will be presented in a scrollable area.

        Specifying a path to a markdown document will use the contents of the document as the message content.
        The source can be a local file or URL, e.g. --\(argument.messageOption.long) /path/to/markdown.md
"""

        argument.messageAlignment.helpShort = "Set the message alignment"
        argument.messageAlignment.helpUsage = "[left | centre | center | right]"
        argument.messageAlignment.helpLong = """
        Positions the message within the dialog window
        Default is 'left' aligned
"""

        argument.messageVerticalAlignment.helpShort = "Set the message position"
        argument.messageVerticalAlignment.helpUsage = "[top | centre | center | bottom]"
        argument.messageVerticalAlignment.helpLong = """
        Positions the message content with the specified vertical positioning.

        Content is affected as a block, and includes all items present in the content area, including:
            Message
            Web Content
            Lists
            Checkboxs
            Text entry fields
            Dropdown lists
"""

        argument.messageFont.helpShort = "Set the message font of the dialog"
        argument.messageFont.helpLong = """
        Can accept up to three parameters, in a comma separated list, to modify font properties.

            color,colour=<text><hex>  - accepts any of the following color specifiers:
                                        * A standard macOS system color:
                                            [black | blue | gray | green | orange | pink | purple | red | white | yellow]
                                        * The user's preferred "Accent Color", specified with the string 'accent'
                                        * A custom color specified in hex format, e.g. #00A4C7
                                        Default: macOS system 'primary' color.

            size=<float>              - accepts any float value.

        example: \"colour=#00A4C7,size=60\"

        ## NOTE: swiftDialog 2.3 and later do not support changes to font name or weight
"""

        argument.notification.helpShort = "Send a system notification"
        argument.notification.helpLong = """
        Accepts the following arguments:
          --\(appArguments.titleOption.long) <text>
          --\(appArguments.subTitleOption.long) <text>
          --\(appArguments.messageOption.long) <text> (as plain text. newlines supported as \\n)
          --\(appArguments.iconOption.long) <image> *
          --\(appArguments.notificationIdentifier.long) <text>
          --\(appArguments.removeNotification.long)

        * <image> must refer to a local file or app bundle. Remote images sources are not supported.
"""

        argument.notificationIdentifier.helpShort = "Set the notification identifier"
        argument.notificationIdentifier.helpLong = """
        Identifier is used to uniquely identify the notification.
        If not specified, a random identifier will be generated.

        Use this identifier to remove the notification with the --\(appArguments.removeNotification.long) option

        If the identifier is not unique, the previous notification will be replaced by the new one.
        """

        argument.removeNotification.helpShort = "Remove a system notification"
        argument.removeNotification.helpLong = """
        Removes the notification with the specified identifier.
        If no identifier is specified, all notifications will be removed.
        """

        argument.dialogStyle.helpShort = "Configure a pre-set window style"
        argument.dialogStyle.helpUsage = "presentation | mini | centered | alert | caution | warning"
        argument.dialogStyle.helpLong = """
        Displays the dialog in one of the defined styles by adjusting window defaults

        "presentation" is functionally equivalent to --\(argument.presentationMode.long)
        "mini" is functionally equivalent to --\(argument.miniMode.long)
        "centered" will set all the options for centered content
        "alert" sets a pre-configured dialog window 300x300 and centered content
        "caution" and "warning" are the same as "alert" with the icon configured

        Style defaults other than mini and presentation can be overridden. e.g:
            --\(argument.dialogStyle.long) alert --\(argument.windowWidth.long) 400
        will use the alert style with 400 width instead of the default 300
"""

        argument.buttonStyle.helpShort = "Configure how the button area is displayed"
        argument.buttonStyle.helpUsage = "center|centre|stack"
        argument.buttonStyle.helpLong = """
        Displays the buttons the bottom of the window, in style indicated.

        "center|centre" will display the buttons at the bottom center.
        "stack" will display full width buttons in a vertical stack with additional padding.

        When using this mode, --\(argument.timerBar.long) and --\(argument.infoButtonOption.long) are not available
        In "stack" mode, Info button is not available.
"""
        argument.buttonSize.helpShort = "Configure how large the buttons are"
        argument.buttonSize.helpUsage = "mini|small|regular|large"
        argument.buttonSize.helpLong = """
        Adjusts the size of the buttons at the bottom of the window.
        Default: regular
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

        Multiple --\(appArguments.mainImage.long) arguments can be used which will display the images as a carousel in argument order
"""

        argument.mainImageCaption.helpShort = "Display a caption underneath an image"
        argument.mainImageCaption.helpLong = ""

        argument.video.helpShort = "Display a video"
        argument.video.helpUsage = "<file> | <url>"
        argument.video.helpLong = """
        Videos will be resized to fit the available display area without clipping the video
        Default dialog window size is changed to \(appvars.videoWindowWidth) x \(appvars.videoWindowHeight)

        Optionally use 'youtube=<id>' or 'vimeo=<id>' in place of <url> as shortcuts to youtube and vimeo services

        --\(appArguments.videoCaption.long) <text>
            Text that will appear underneath the displayed video.

        --\(appArguments.autoPlay.long)
            Will force the video to start playing automatically.
"""

        argument.videoCaption.helpShort = "Display a caption underneath a video"
        argument.videoCaption.helpLong = ""

        argument.autoPlay.helpShort = "Enable video autoplay"
        argument.autoPlay.helpLong = ""

        let iconCommon = """
        Acceptable Values:
            file path to png or jpg           -  "/file/path/image.[png|jpg]"
            file path to Application          -  "/Applications/Chess.app"
            URL of file resource              -  "https://someurl/file.[png|jpg]"
            SF Symbol                         -  "SF=sf.symbol.name"
            QR Code                           -  "qr=text/url to be represented as a QR code"
            builtin                           -  info | caution | warning

        You can optionally specify an alternate resource value for use in dark mode using the following syntax:

            <value>:dark=<alternate_value>

        When Specifying SF Symbols for icon or overlay icon, additional parameters for colour and weight are available.
        Additional parameters are separated by comma

        "SF=sf.symbol.name,colour=<text><hex>,weight=<text>"

        SF Symbols - visit https://developer.apple.com/sf-symbols/ for details on over 3,100 symbols

        color,colour=<text><hex>          - accepts any of the following color specifiers:
        bgcolor,bgcolour=<text><hex>        * A standard macOS system color:
                                                [black | blue | gray | green | orange | pink | purple | red | white | yellow]
                                            * 'auto' to use the prefered colour on supported SF Symbols
                                            * 'accent' to use the user's preferred "Accent Color"
                                            * A custom color specified in hex format, e.g. #00A4C7
                                            Default: macOS system 'primary' color.
        palette=<text><hex>               - palette accepts up to three colours for use in multicolour
                                            SF Symbols
                                            Use comma separated values, e.g. palette=red,green,blue

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

        animation=<keyword>  *(macOS 14)* - Uses animated SF symbols. Accepts one of the following keywords:
                                           variable, variable.reversing, variable.iterative, variable.iterative.reversing
                                           variable.cumulative, pulse, pulse.bylayer
        """

        argument.iconOption.helpShort = "Set the dialog icon"
        argument.iconOption.helpUsage = "<file> | <url>"
        argument.iconOption.helpLong = """
        "none" can be specified to not display an icon but maintain layout (see also --\(appArguments.hideIcon.long))

        When used in conjunction with --\(argument.centreIcon.long), you can specify
        --\(appArguments.iconOption.long) multiple times to show multiple icons at once

        \(iconCommon)
"""

        argument.iconSize.helpShort = "Set the dialog icon size"
        argument.iconSize.helpUsage = "<num>"
        argument.iconSize.helpLong = "Default size is 150"

        argument.iconAlpha.helpShort = "Set the dialog icon transparancy"
        argument.iconAlpha.helpUsage = "<num>"
        argument.iconAlpha.helpLong = """
        Accepts values from 0.0 to 1.0
        Where 0.0 is completely transparant and 1.0 is completely opaque

        The default value is 1.0

"""

        argument.centreIcon.helpShort = "Set icon to be in the centre"
        argument.centreIcon.helpLong = """
        re-positions the icon to be in the centre, between the title and message areas
"""

        argument.overlayIconOption.helpShort = "Set an image to display as an overlay to --icon"
        argument.overlayIconOption.helpUsage = "<file> | <url>"
        argument.overlayIconOption.helpLong = """
        Icon overlays are displayed at 1/2 resolution to the main icon and positioned to the bottom right

        \(iconCommon)
"""

        argument.hideIcon.helpShort = "Hides the icon from view"
        argument.hideIcon.helpLong = """
        Doing so increases the space available for message text
"""

        argument.button1TextOption.helpShort = "Set the label for Button1"
        argument.button1TextOption.helpLong = """
        Default label is "\(appDefaults.button1Default)"
        Bound to <Enter> key

        If the text \"none\" is used, the button will be hidden.
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
        Default label is "\(appDefaults.button2Default)"
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
        Default label is "\(appDefaults.buttonInfoDefault)"
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

        argument.helpMessage.helpShort = "Enable help button with content <text>"
        argument.helpMessage.helpLong = """
        Will display a help icon to the right of the the default button
        When clicked, contents of the help message will be displayed as a popover
        Supports markdown for formatting.

"""

        argument.helpImage.helpShort = "Add an image to the help message"
        argument.helpImage.helpLong = """
        Will display an image or icon to the right of any specified help message
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

        Sending commands:
            echo "<command>" >> [<file>]

        Available commands:
            title: <text>
            message: (+)<text>
            image: <path/url>
            imagecaption: <text>
            progress: <int>/<text>
            progress: hide/show
            progresstext: <text>
            list: <text/csv>
            list: clear
            listitem: <item>: [<text>/wait]
            listitem: add, title: <text>[, status: <status>, statustext: <text>]
            listitem: delete, title: <text>
            listitem: delete, index: <index>
            button1: [disable/enable]
            button2: [disable/enable]
            button1text: (+)<text>
            button2text: (+)<text>
            infobuttontext: <text>
            infobox: <text>
            icon: <path/url/SF Symbol>
            icon: <centre/center/left/default>
            icon: size: <num>
            width: <num>
            height: <num>
            position: <position>
            webcontent: <url>
            video: <path/url>
            blurscreen: [enable/disable]
            activate:
            quit:
"""

        argument.bannerImage.helpShort = "Enable banner image"
        argument.bannerImage.helpUsage = "<file> | <url>"
        argument.bannerImage.helpLong = """
        Shows a banner image at the top of the dialog
        Banner images fill the entire top width of the window and are resized to fill, positioned from
        the top left corner of the image.
        Specifying this option will imply --\(appArguments.hideIcon.long)

        An image size of 850x150 will suit the default dialog window size
"""

        argument.bannerTitle.helpShort = "Enable title within banner area"
        argument.bannerTitle.helpLong = """
        Title is displayed on top of the banner image.
        Title font color is set to "white" by default.

        Additional --\(appArguments.titleFont.long) parameter "shadow=<bool>". When set to true,
        displays a drop shadow underneath the text
"""

        argument.bannerText.helpShort = "Set text to display in banner area"
        argument.bannerText.helpLong = """
        Using this argument is the equivalent of \(argument.bannerTitle.long) and \(argument.titleOption.long)
"""

        argument.dropdownTitle.helpShort = "Select list name"
        argument.dropdownTitle.helpUsage = "<text>(,radio|required,name=\"<text>\")"
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

        Use the additional option "required" to make that item a required input:
            on the command line
                --\(argument.dropdownTitle.long) "<name>",required
            in JSON
                "selectitems" : [{"title" : "Select 1", "values" : ["one","two","three"], "required" : true}]

        Modifiers:
            name       - Output will use this value as the key instead of the title
            radio      - Change the select list to display a group with radio buttons. When using radio with no default
                         item specified, the first entry in the list will become the default selected item.
            required   - Make that particular list a required item that must have a value before swiftDialog will exit
"""

        argument.dropdownValues.helpShort = "Select list values"
        argument.dropdownValues.helpUsage = "<csv>"
        argument.dropdownValues.helpLong = """
        List of values to be displayed in an associated --\(argument.dropdownTitle.long)

        Argument values are in CSV format
        e.g. "Option 1,Option 2,Option 3"

        Add three or more hyphens "---" into your list to insert a divider in that location

        NOTE: each "---" will count in the index even though the divider itself is not selectable

        see also --\(argument.dropdownTitle.long) and --\(argument.dropdownDefault.long)
"""

        argument.dropdownDefault.helpShort = "Default select list value"
        argument.dropdownDefault.helpLong = """
        Default option to be selected (must match one of the items in the list)
"""

        argument.textField.helpShort = "Enable a textfield with the specified label"
        argument.textField.helpUsage = "<text>[,required,secure,prompt=\"<text>\",name=\"<text>\"]"
        argument.textField.helpLong = """
        When swiftDialog exits the contents of the textfield will be presented as <text> : <user_input>
        in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
        Multiple textfields can be specified as required.

        Modifiers available to text fields are:
            name       - Output will use this value as the key instead of the title
            secure     - Presents a secure input area. Contents of the textfield will not be shown on screen
            required   - swiftDialog will not exit until the field is populated
            prompt     - Pre-fill the field with some prompt text
            value      - Pre-fill the field with a specific value
            regex      - Specify a regular expression that the field must satisfy for the content to be accepted.
            confirm    - Will display a duplicate of the textfield who's content needs to match to validate
            regexerror - Specify a custom error to display if regex conditions are not met
            fileselect - Adds a "Select" button and presents a file picker
            path       - Used with fileselect. Sets initial path for file select dialog
            filetype   - Limits fileselect to the named file extensions. Presented in space separated values

        modifiers can be combined e.g. --\(appArguments.textField.long) <text>,secure,required
                                       --\(appArguments.textField.long) <text>,required,prompt="<text>"
                                       --\(appArguments.textField.long) <text>,fileselect,filetype="jpeg jpg png"
                                       --\(appArguments.textField.long) <text>,regex="\\d{6}",prompt="000000",regexerror="Enter 6 digits"
        (secure fields cannot have the prompt modifier applied)
"""

        argument.checkbox.helpShort = "Enable a checkbox with the specified label"
        argument.checkbox.helpLong = """
        When swiftDialog exits the status of the checkbox will be presented as <text> : [true|false]
        in plain or as json using [-\(appArguments.jsonOutPut.short), --\(appArguments.jsonOutPut.long)] option
        Multiple checkboxes can be specified as required.

        Use --\(appArguments.checkboxStyle.long) to change appearance

        Modifiers:
            name       - Output will use this value as the key instead of the title
"""

        argument.checkboxStyle.helpShort = "Change the appearance of checkboxes"
        argument.checkboxStyle.helpUsage = "default|checkbox|switch[,<size>]"
        argument.checkboxStyle.helpLong = """
        Changes the appearance of checkboxes to be either checkbox style or switch style.

        Argument is one of:
            checkbox (default)
            switch

        switch style allows the following properties to set the size:
            mini
            small
            regular
            large

        Additionally in switch style, you can specify an image on (appArguments.checkboxStyle.long):
            --\(appArguments.checkboxStyle.long) "<text>",icon=<path>

"""

        argument.preferredViewOrder.helpShort = "Change the order in which some items are displayed"
        argument.preferredViewOrder.helpUsage = "<csv>"
        argument.preferredViewOrder.helpLong = """
        The view order of particular item types can be re-arranged from their default values.

        The default order is as follows:
            - textfile
            - webcontent
            - listitem
            - checkbox
            - textfield
            - radiobutton
            - dropdown

        To re-arrange the order, specify the preferred order as a comma separated list.
        Only the items being displayed need to be specified.
        e.g.
        --\(argument.preferredViewOrder.long) \"textfield,checkbox,dropdown\"

"""

        argument.listItem.helpShort = "Enable a list item with the specified label"
        argument.listItem.helpLong = """
        Multiple items can be added by specifying --\(appArguments.listItem.long) multiple times

        Alternatly, specify a list item with either of the following JSON formats (in conjunction with --\(appArguments.jsonFile.long) or \(appArguments.jsonString.long):
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
        and will display an appropriate icon in the status area.

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

        argument.position.helpShort = "Position the dialog window to the defined location on the screen"
        argument.position.helpUsage = "[topleft | left | bottomleft | top | center/centre | bottom | topright | right | bottomright | x,y]"
        argument.position.helpLong = """
        Supply one of the defined keywords or a precise position in x,y format e.g. "100,200"
          Position is calculated with the screen origin 0,0 and window position anchor at top left

        There is a default edge offset value of \(appvars.windowPositionOffset). This can be adjusted using the --\(arguments.positionOffset.long) argument

        Default is centred with a visually appealing vertical position slightly towards the top of centre, not dead centre.
"""

        argument.positionOffset.helpShort = "Set dialog window position offset"
        argument.positionOffset.helpUsage = "<int>"
        argument.positionOffset.helpLong = """
        When used in conjunction with --\(argument.position.long) sets the offset from the edge of the display

        Default is 16
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

        argument.logFileToTail.helpShort = "Open a file and display the contents as it is being written"
        argument.logFileToTail.helpUsage = "<file>"
        argument.logFileToTail.helpLong = """
        Open a file and display the contents as it is being written
"""


        argument.hideTimerBar.helpShort = "Hide countdown timer if enabled"
        argument.hideTimerBar.helpLong = """
        Will hide the timer bar. swiftDialog will close after time specified by --\(appArguments.timerBar.long)
        Default OK button is displayed. This is to prevent persistent or unclosable dialogs of unknown duration.
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
        Button 1 and 2 with modifications are available.
        When used with --progress, buttons are replaced by progress bar and progress text.
            * In this presentation, quitting the dialog is achieved with use of the command file.
"""

        argument.presentationMode.helpShort = "Enable presentation mode"
        argument.presentationMode.helpUsage = ""
        argument.presentationMode.helpLong = """
        Presentation mode is an output only (no user input) mode of swiftDialog intended for displaying
        an ongoing process or task.

        Updating the display will require the use of a command file and appropriate commands

        The view is split into two main areas with a progress bar underneath
        The left 1/3 of the window contains an information area and can show _one_ of the following:

        Default:
            A background colour representing the users highlight colour preference.
            You can optionally make the following modifiers:
            --\(argument.infoBox.long) <text> to display text (markdown format supported)
            --\(argument.watermarkImage.long) color=<color|hex> to set the background colour
            --\(argument.iconOption.long) <image> to display an icon in the top left
            --\(argument.iconSize.long) <int> to set the icon size.

        Image:
            Specify one or more --\(argument.mainImage.long) to fill this area with an image
            Multiple images will stack as an image carousel
            include --\(argument.autoPlay.long) <sec> to have the images rotate
            * Use images with portrait orientation for best results
            * Images will be scaled to fill the area and cropping may occur
              Run presentation mode with --\(argument.debug.long) and a recommended image size
                for the current window will be included in debug log output.

        Web content:
            Specify --\(argument.webcontent.long) <url> to display the contents of a html source.
            * If using a local file, reference the file using 'file:///path/to/file.html'

        The right 2/3 of the window is dedicated to content in one of the following forms:

        Default:
            Any --\(argument.messageOption.long) <text> in any of the supported forms.

        List:
            One or more --\(argument.listItem.long) <item> in any of the supported forms.

        The footer of the window is always visible and dedicated to a full width progress bar and buttons.
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

        "\(appArguments.textField.long)" can specify multiple values as a simple array:
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
        Use the specified character as the Command ⇧ + <key> combination for quitting instead of "q".

        Capital letters can be used in which case Command ⇧ + Shift ⇧ + <key> will be required
"""

        argument.windowButtonsEnabled.helpShort = "Enables window buttons"
        argument.windowButtonsEnabled.helpUsage = "[close,min,max]"
        argument.windowButtonsEnabled.helpLong = """
        Enables window buttons, close, minimize and maximise(zoom)

        You can optionally specify one or more of "close", "min" or "max" as comma separated values.
        e.g. to enable only the min and max(zoom) buttons:
            --\(argument.windowButtonsEnabled.long) min,max
"""

        argument.hideDefaultKeyboardAction.helpShort = "Hides the default behaviour of Return ↵ and Esc ⎋ keys"
        argument.hideDefaultKeyboardAction.helpUsage = ""
        argument.hideDefaultKeyboardAction.helpLong = """
        When specified, the behaviour to action the default button (Return ↵) or secondary button (Esc ⎋) will be modified
        to require Command ⌘ + Shift ⇧ in order to action.

        This effectively disables unintentional activation of either of these buttons. They can still be activated
        with the keyboard, but it is harder to do so without intent.
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
        argument.authkey.helpShort = "Use the specified authentication key to allow dialog to launch"
        argument.authkey.helpUsage = "<string>"
        argument.authkey.helpLong = """
        The authentication key is a way to prevent unauthorised use of swiftDialog
        the string value will be hashed with the SHA256 hash function and compared against a stored value

        swiftDialog will check the au.csiro.dialog domain for the key name \"AuthorisationKey\"
        The key value should be a SHA256 hash of a secret keyphrase
        If this value is present, then it must match or swiftDialog will not launch.

        e.g. if the secret phrase to be used is \"password\" then the store the SHA256 hash of this
        phrase in the au.csiro.dialog domain:
          \"AuthorisationKey\" = \"5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8\"
        launch dialog and specify the secret phrase:
          dialog --\(argument.authkey.long) \"password\"

        Valid key names that can store this value are:
          AuthorisationKey
          AuthorizationKey
          AuthKey
          Key

        If multiple key names are present, only the first one found will be used, following the order
        specified above.

        Failure to specify the correct key will cause dialog to exit with code 30
"""
        argument.hash.helpShort = "Generate a SHA256 value"
        argument.hash.helpUsage = "<string>"
        argument.hash.helpLong = """
        For use with --\(argument.authkey.long)

        Equivalent of running:
          echo -n <string> | shasum -a 256
"""

        argument.windowResizable.helpShort = "Enable the dialog window to be resizable"
        argument.windowResizable.helpUsage = ""
        argument.windowResizable.helpLong = """
        Enables the dialog window to be resizable.

        This option also implies the --\(argument.movableWindow.long) flag
"""

        argument.preferredAppearance.helpShort = "Set the preferred window appearance"
        argument.preferredAppearance.helpUsage = "[dark|light]"
        argument.preferredAppearance.helpLong = """
        Sets the window appearance to either dark or light regardless what appearance setting
        the user currently has selected.

"""

        argument.showOnAllScreens.helpShort = "Enable the dialog window to appear on all screens"
        argument.showOnAllScreens.helpUsage = ""
        argument.showOnAllScreens.helpLong = """
        Dialog windows will appear on all screens, even on top of fullscreen applications

        This property is implied when using --\(argument.forceOnTop.long)
"""

        argument.loginWindow.helpShort = "Enable the dialog window to be shown at login"
        argument.loginWindow.helpUsage = ""
        argument.loginWindow.helpLong = """
        Login window support requires an appropriate LaunchAgent to launch swiftDialog
        in the appropriate context. This should be acheived with a standard LaunchAgent
        that includes the following key:

        <key>LimitLoadToSessionType</key>
        <string>LoginWindow</string>

        Both the LaunchAgent and --\(argument.loginWindow.long) argument are required.

        Supports standard dialogs with or without --\(argument.blurScreen.long)

        This option also implies the --\(argument.forceOnTop.long) flag
"""

        argument.debug.helpShort = "Enable debug mode"
        argument.debug.helpUsage = "(<colour>)"
        argument.debug.helpLong = """
        Enables debug mode. This increases the level of log output on stdout and
        displays additional window properties along the title bar area for reference.

        Optionally supply a <colour> argument as either a named colour or hex value.
        This will enable content area boundary highlights.

        Used in conjunction with \(argument.windowResizable.long) this is a good way to evaluate dialog
        look and feel.
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
