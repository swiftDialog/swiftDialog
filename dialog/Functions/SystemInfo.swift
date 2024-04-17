//
//  SystemInfo.swift
//  Dialog
//
//  Created by Bart E Reardon on 17/4/2024.
//

import Foundation
import SystemConfiguration

func getConsoleUserInfo() -> (username: String, userID: String) {
    // We need the console user, not the process owner so NSUserName() won't work for our needs when outset runs as root
    var uid: uid_t = 0
    if let consoleUser = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as? String {
        return (consoleUser, "\(uid)")
    } else {
        return ("", "")
    }
}

func getOSVersion() -> String {
    // Returns the OS version
    let osVersion = ProcessInfo().operatingSystemVersion
    let version = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    return version
}

func getOSBuildVersion() -> String {
    // Returns the current OS build from sysctl
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var osversion = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
    return String(cString: osversion)

}

func getDeviceSerialNumber() -> String {
    // Returns the current devices serial number
    let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
      guard platformExpert > 0 else {
        return "Serial Unknown"
      }
      guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
        return "Serial Unknown"
      }
      IOObjectRelease(platformExpert)
      return serialNumber
}

func getMarketingModel() -> String {
    let appleSiliconProduct = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/AppleARMPE/product")
        let cfKeyValue = IORegistryEntryCreateCFProperty(appleSiliconProduct, "product-description" as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(appleSiliconProduct)
        let keyValue: AnyObject? = cfKeyValue?.takeUnretainedValue()
        if keyValue != nil, let data = keyValue as? Data {
            return String(data: data, encoding: String.Encoding.utf8)?.trimmingCharacters(in: CharacterSet(["\0"])) ?? ""
        }
        return ""
}

func getDeviceHardwareModel() -> String {
    // Returns the current devices hardware model from sysctl
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

public extension ProcessInfo {
    func osName() -> String {
        let version = self.operatingSystemVersion
        switch version.majorVersion {
        case 14: return "Sonoma"
        case 13: return "Ventura"
        case 12: return "Monterey"
        case 11: return "Big Sur"
        case 10: break
        default: return "macOS \(version.majorVersion)"
        }
        return "macOS \(version.majorVersion)"
    }
}

public extension ProcessInfo {
    func osVersionString() -> String {
        let version = self.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
