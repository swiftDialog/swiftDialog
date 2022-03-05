[![swiftui-version](https://img.shields.io/badge/SwiftUI-2.0-brightgreen)](https://developer.apple.com/documentation/swiftui) ![macos-version](https://img.shields.io/badge/macOS-11+-blue) [![xcode-version](https://img.shields.io/badge/xcode-13-red)](https://developer.apple.com/xcode/)

# swiftDialog

swiftDialog is an [open source](https://github.com/bartreardon/Dialog/blob/main/LICENSE.md) admin utility app for macOS 11+ written in SwiftUI that displays a popup dialog, displaying the content to your users that you want to display.

swiftDialog's purpose is as a tool for Mac Admins to show informative messages via scripts, and relay back the users actions.

The latest version can be found on the [Releases](https://github.com/bartreardon/Dialog/releases) page

Detailed documentation and information can be found in the [Wiki](https://github.com/bartreardon/Dialog/wiki)

![swiftDialog Logo](https://user-images.githubusercontent.com/3598965/125153263-d1baf780-e195-11eb-92ee-9321aa848ffc.png)


# Main Features

## Appearance
Every aspect of swiftDialog's appearance can be modified.

At the most simple level you need only give swiftDialog a [Title](https://github.com/bartreardon/Dialog/wiki/Customising-the-Title) and a [Message](https://github.com/bartreardon/Dialog/wiki/Customising-the-Message-area) to display but there is more utility in modifying other aspects of the appearance:
 * [Pass in an image resource](https://github.com/bartreardon/Dialog/wiki/Customising-the-Icon) to display as the swiftDialog icon, or use an app path or system preference bundle path and swiftDialog will extract the icon for display.
 * [Add extra buttons](https://github.com/bartreardon/Dialog/wiki/Buttons-and-button-behaviour). Change the text to say what you want. Wait for user input or autimatically time out.
 * [Use markdown](https://github.com/bartreardon/Dialog/wiki/Customising-the-Message-area#markdown-support-new-from-v150) in the message to add **bold** or _italics_ or include URL links
 * Change the [colour, size or even the font](https://github.com/bartreardon/Dialog/wiki/Customising-the-Title#customising-title-font-properties) used in the Title and Message areas
 * [Change the size](https://github.com/bartreardon/Dialog/wiki/Window-Size-and-Behaviour) of the swiftDialog window
 * Display [Videos](https://github.com/bartreardon/Dialog/wiki/Customising-the-Message-area#displaying-videos-new-from-v180) or [Images](https://github.com/bartreardon/Dialog/wiki/Customising-the-Message-area#displaying-images-new-from-v160) either locally or pass in a URL
 * and lots more...


## Commandline Options

swiftDialog's interface is fully customised from a set of command line options.

For details on all the available options, please read the [Command Line Options](https://github.com/bartreardon/Dialog/wiki/Command-Line-Options) page on the wiki.


## Getting Feedback
Feedback on how someone interacts with swiftDialog can passed back into the calling script. At a basic level swiftDialog's exit codes will represent what button was pressed. For user input, swiftDialog will output any data to `sdtout` in either plain text or optionally json format for easy parsing.


# Giving Feedback
If there are bugs or ideas, please create an [issue](https://github.com/bartreardon/Dialog/issues/new/choose) so your idea doesn't go missing.

Also come chat in the `#swiftDialog` channel in the [MacAdmins Slack](https://www.macadmins.org)

# Contributing

Please read the [CONTRIBUTING.md](https://github.com/bartreardon/Dialog/blob/main/CONTRIBUTING.md) for details on how you can contribute.

<!--
Author: Bart Reardon
Keywords: swift swiftui swiftDialog Dialog utility macadmins apple macos
-->
