
# Dialog

Dialog is a simple app that displays a dialog with specified content passed in from the commandline.

Dialog's purpose is to act as a way to show an informative message to an end user, called via script, and relay back the users actions.

Latest version can be found on the [Releases](https://github.com/bartreardon/Dialog-public/releases) page

More info in the [Wiki](https://github.com/bartreardon/Dialog-public/wiki)

![Dialog Logo](/assets/screen1.png)


# Features
Universal binary
Supports macOS 11 only (for now - due to swiftUI API's in use backwards compatibility may only extend to 10.15)


## Appearance
Icon display can be from local PNG or JPG or from a specified URL, so you don't need to deploy additional files to display random images, or you can remove it entirely. When specifying square images, Dialog will round the corners a bit, just enough to soften sharp corners
Message length can be quite wordy. Up to 100 words if you don't mind a wall of text. Message supports `\n` newlines. Standard message area is 49 characters x 9 rows.

## Buttons
There are three possible buttons available, **OK**, **Cancel** and **More Information**

Buttons can also display an arbitrary length of characters. Each can be re-named to display any text you desire

For more details, please read the [Buttons and button behaviour](https://github.com/bartreardon/Dialog-public/wiki/Buttons-and-button-behaviour) page on the wiki


## Commandline Options

Dialog's interface is fully customised from a set of command line options.

For more details, please read the [Command Line Options](https://github.com/bartreardon/Dialog-public/wiki/Command-Line-Options) page on the wiki.


# Return Codes
When displaying a dialog the user can take one of up to three actions, depending on what's available

The following return codes are sent after each action. These can be ignored or used in a calling script for further action
| Button Name | Optional | Hotkey | Return Code |
| ----------- | -------- | ------ | ----------- |
| button1     | No       | Enter  | 0           |
| button2     | Yes      | Esc    | 2           |
| infobutton  | Yes      |        | 3           |

# Displaying Images in the Icon area
The icon display area on the left hand portion of the dialog can be configured in a number of ways.

Details can be found on the [Customising the Icon](https://github.com/bartreardon/Dialog-public/wiki/Customising-the-Icon) page on the wiki.

