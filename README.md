[![swiftui-version](https://img.shields.io/badge/swiftui-2.0-brightgreen)](https://developer.apple.com/documentation/swiftui) ![macos-version](https://img.shields.io/badge/macOS-11+-blue) [![xcode-version](https://img.shields.io/badge/xcode-12.5.1-red)](https://developer.apple.com/xcode/)

# Dialog

Dialog is a simple app that displays a dialog with specified content passed in from the commandline.

Dialog's purpose is to act as a way to show an informative message to an end user, called via script, and relay back the users actions.

Latest version can be found on the [Releases](https://github.com/bartreardon/Dialog-public/releases) page

More info in the [Wiki](https://github.com/bartreardon/Dialog-public/wiki)

![Dialog Logo](https://user-images.githubusercontent.com/3598965/125153263-d1baf780-e195-11eb-92ee-9321aa848ffc.png)


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

