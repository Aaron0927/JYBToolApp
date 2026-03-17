import Foundation

public enum Constants {
    public static let excludedDirectories: Set<String> = [
        ".git",
        "xcuserdata",
        "GDCASDK"
    ]
    
    public static let protectedKeywords: [String] = [
        "GDCASDK"
    ]

    public static let sourceFileExtensions: Set<String> = [
        "h",
        "m",
        "swift",
        "pch",
        "entitlements"
    ]

    public static let plistExtensions: Set<String> = [
        "plist"
    ]

    public static let xcodeFileNames: Set<String> = [
        "project.pbxproj"
    ]

    public static let xcodeFileExtensions: Set<String> = [
        "xcworkspacedata",
        "xcscheme"
    ]

    public static let podFileNames: Set<String> = [
        "Podfile",
        "Podfile.lock"
    ]

    public static let pbxprojJsonExtensions: Set<String> = [
        "pbxproj.json"
    ]
    
    public static let defaultConfigModifications: [ConfigFileModification] = [
        ConfigFileModification(
            fileNamePattern: "TGOrgConfig.plist",
            keysToModify: ["org", "broker", "market_org"]
        ),
        ConfigFileModification(
            fileNamePattern: "UserSettings.plist",
            keysToModify: ["券商标志"]
        ),
        ConfigFileModification(
            fileNamePattern: "UserSettings.json",
            keysToModify: ["券商标志"]
        ),
    ]
}
