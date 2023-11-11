//
//  Font+Additions.swift
//  Dialog
//
//  Created by Matthew L. Judy on 2023/11/10.
//

import SwiftUI


extension Font.Weight
{
    init(argument: String)
    {
        switch argument {
            case "ultraLight" : self = .ultraLight
            case "thin"       : self = .thin
            case "light"      : self = .light
            case "regular"    : self = .regular
            case "medium"     : self = .medium
            case "semibold"   : self = .semibold
            case "bold"       : self = .bold
            case "heavy"      : self = .heavy
            case "black"      : self = .black
            default           : self = .regular
        }
    }
}


