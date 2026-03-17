import Foundation

public final class FileProcessor {
    private let config: RenamerConfig
    private let fileManager = FileManager.default
    private var errors: [String] = []
    private var warnings: [String] = []
    public var filesReplaced: Int = 0
    public var directoriesRenamed: Int = 0
    public var filesRenamed: Int = 0

    public init(config: RenamerConfig) {
        self.config = config
    }

    private func shouldExclude(path: String) -> Bool {
        for excluded in Constants.excludedDirectories {
            if path.contains("/\(excluded)/") || path.hasSuffix("/\(excluded)") {
                return true
            }
        }
        return false
    }

    private func replaceWithProtection(_ text: String, oldPrefix: String, newPrefix: String) -> String {
        guard !Constants.protectedKeywords.isEmpty else {
            return text.replacingOccurrences(of: oldPrefix, with: newPrefix, options: .literal)
        }
        
        var protectedRanges: [(Int, Int, String)] = []
        
        for keyword in Constants.protectedKeywords {
            var searchStart = text.startIndex
            while let range = text.range(of: keyword, options: .literal, range: searchStart..<text.endIndex) {
                let startOffset = range.lowerBound.utf16Offset(in: text)
                let endOffset = range.upperBound.utf16Offset(in: text)
                protectedRanges.append((startOffset, endOffset, keyword))
                searchStart = range.upperBound
            }
        }
        
        protectedRanges.sort { $0.0 < $1.0 }
        
        var result = text
        var offset = 0
        for (start, end, keyword) in protectedRanges {
            let placeholder = "___PROTECTED_\(keyword.hashValue)___"
            let adjustedStart = result.index(result.startIndex, offsetBy: start + offset)
            let adjustedEnd = result.index(result.startIndex, offsetBy: end + offset)
            result.replaceSubrange(adjustedStart..<adjustedEnd, with: placeholder)
            offset += placeholder.count - keyword.count
        }
        
        result = result.replacingOccurrences(of: oldPrefix, with: newPrefix, options: .literal)
        
        for keyword in Constants.protectedKeywords {
            let placeholder = "___PROTECTED_\(keyword.hashValue)___"
            result = result.replacingOccurrences(of: placeholder, with: keyword)
        }
        
        return result
    }

    public func copyProject() throws {
        do {
            for pair in config.sourceTargetPairs {
                let sourceURL = URL(fileURLWithPath: pair.sourcePath)
                let targetURL = URL(fileURLWithPath: pair.targetPath)
                
                if !fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                }
                
                try copyContents(from: sourceURL, to: targetURL)
                
                if config.modifyConfigFiles {
                    try modifyConfigFiles(in: targetURL)
                }
            }
        } catch let error as RenamerError {
            throw error
        } catch {
            throw RenamerError.copyFailed(error.localizedDescription)
        }
    }
    
    private func modifyConfigFiles(in targetURL: URL) throws {
        guard config.modifyConfigFiles else { return }
        
        let oldPrefix = config.oldPrefix
        let newPrefix = config.newPrefix
        
        for modification in config.configModifications {
            let enumerator = fileManager.enumerator(
                at: targetURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.lastPathComponent == modification.fileNamePattern else { continue }
                
                do {
                    if fileURL.pathExtension.lowercased() == "json" {
                        try modifyJsonFile(at: fileURL, keysToModify: modification.keysToModify, oldPrefix: oldPrefix, newPrefix: newPrefix)
                    } else {
                        try modifyPlistFile(at: fileURL, keysToModify: modification.keysToModify, oldPrefix: oldPrefix, newPrefix: newPrefix)
                    }
                } catch {
                    warnings.append("修改配置文件失败: \(fileURL.path)")
                }
            }
        }
    }
    
    private func modifyJsonFile(at fileURL: URL, keysToModify: [String], oldPrefix: String, newPrefix: String) throws {
        let data = try Data(contentsOf: fileURL)
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            return
        }
        
        var modifiedJson = json
        let oldPrefixLower = oldPrefix.lowercased()
        
        for key in keysToModify {
            if let value = modifiedJson[key] as? String {
                let modifiedValue = replacePrefixPreservingCase(in: value, oldPrefix: oldPrefix, newPrefix: newPrefix, oldPrefixLower: oldPrefixLower)
                modifiedJson[key] = modifiedValue
            }
        }
        
        let modifiedData = try JSONSerialization.data(withJSONObject: modifiedJson, options: [.prettyPrinted, .sortedKeys])
        try modifiedData.write(to: fileURL)
    }
    
    private func modifyPlistFile(at fileURL: URL, keysToModify: [String], oldPrefix: String, newPrefix: String) throws {
        let data = try Data(contentsOf: fileURL)
        
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }
        
        var modifiedPlist = plist
        let oldPrefixLower = oldPrefix.lowercased()
        
        for key in keysToModify {
            if let value = modifiedPlist[key] as? String {
                let modifiedValue = replacePrefixPreservingCase(in: value, oldPrefix: oldPrefix, newPrefix: newPrefix, oldPrefixLower: oldPrefixLower)
                modifiedPlist[key] = modifiedValue
            }
        }
        
        let modifiedData = try PropertyListSerialization.data(fromPropertyList: modifiedPlist, format: .xml, options: 0)
        try modifiedData.write(to: fileURL)
    }
    
    private func replacePrefixPreservingCase(in value: String, oldPrefix: String, newPrefix: String, oldPrefixLower: String) -> String {
        let valueLower = value.lowercased()
        
        guard valueLower.contains(oldPrefixLower) else {
            return value
        }
        
        var result = value
        var offset = 0
        
        var searchStart = valueLower.startIndex
        while let matchRange = valueLower.range(of: oldPrefixLower, range: searchStart..<valueLower.endIndex) {
            let originalInValue = String(value[matchRange])
            
            var newPrefixAdjusted = ""
            let newPrefixChars = Array(newPrefix)
            for (index, origChar) in originalInValue.enumerated() {
                if index < newPrefixChars.count {
                    let newChar = String(newPrefixChars[index])
                    if origChar.isUppercase {
                        newPrefixAdjusted += newChar.uppercased()
                    } else if origChar.isLowercase {
                        newPrefixAdjusted += newChar.lowercased()
                    } else {
                        newPrefixAdjusted += newChar
                    }
                }
            }
            if newPrefix.count > originalInValue.count {
                newPrefixAdjusted += String(newPrefix.suffix(newPrefix.count - originalInValue.count))
            }
            
            let adjustedStart = value.index(value.startIndex, offsetBy: matchRange.lowerBound.utf16Offset(in: valueLower) + offset)
            let adjustedEnd = value.index(value.startIndex, offsetBy: matchRange.upperBound.utf16Offset(in: valueLower) + offset)
            
            result.replaceSubrange(adjustedStart..<adjustedEnd, with: newPrefixAdjusted)
            offset += newPrefixAdjusted.count - originalInValue.count
            
            searchStart = matchRange.upperBound
        }
        
        return result
    }

    private func copyContents(from sourceURL: URL, to targetURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)
        for item in contents {
            let itemName = item.lastPathComponent
            if Constants.excludedDirectories.contains(itemName) {
                continue
            }
            let destination = targetURL.appendingPathComponent(itemName)
            
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: item, to: destination)
        }
    }

    public func replaceSourceContent() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix
            let newPrefix = config.newPrefix

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                if shouldExclude(path: fileURL.path) { continue }
                
                let ext = fileURL.pathExtension.lowercased()
                guard Constants.sourceFileExtensions.contains(ext) else { continue }

                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let newContent = replaceWithProtection(content, oldPrefix: oldPrefix, newPrefix: newPrefix)
                    if content != newContent {
                        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                        filesReplaced += 1
                    }
                } catch {
                    warnings.append("替换文件失败: \(fileURL.path)")
                }
            }
        }
    }

    public func replacePlistContent() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix
            let newPrefix = config.newPrefix

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                if shouldExclude(path: fileURL.path) { continue }
                
                let ext = fileURL.pathExtension.lowercased()
                guard Constants.plistExtensions.contains(ext) else { continue }

                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let newContent = replaceWithProtection(content, oldPrefix: oldPrefix, newPrefix: newPrefix)
                    if content != newContent {
                        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                        filesReplaced += 1
                    }
                } catch {
                    warnings.append("替换 plist 失败: \(fileURL.path)")
                }
            }
        }
    }

    public func replaceXcodeProjectFiles() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath

            let pbxprojFiles = findFiles(in: targetPath, matching: { url in url.lastPathComponent == "project.pbxproj" })
            for file in pbxprojFiles {
                try replaceContent(in: file)
            }

            let xcworkspaceFiles = findFiles(in: targetPath, matching: { url in
                url.pathExtension == "xcworkspacedata"
            })
            for file in xcworkspaceFiles {
                try replaceContent(in: file)
            }

            let xcschemeFiles = findFiles(in: targetPath, matching: { url in
                url.pathExtension == "xcscheme"
            })
            for file in xcschemeFiles {
                try replaceContent(in: file)
            }
        }
    }

    public func replacePodfileContent() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath

            for fileName in Constants.podFileNames {
                let fileURL = URL(fileURLWithPath: targetPath).appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try replaceContent(in: fileURL)
                }
            }
        }
    }

    public func replacePbxprojJson() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "pbxproj.json" else { continue }
                if shouldExclude(path: fileURL.path) { continue }

                do {
                    try replaceContent(in: fileURL)
                } catch {
                    warnings.append("替换 pbxproj.json 失败: \(fileURL.path)")
                }
            }
        }
    }

    public func fixPermissions() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension == "xcscheme" {
                    try? fileManager.setAttributes(
                        [.posixPermissions: 0o644],
                        ofItemAtPath: fileURL.path
                    )
                }
            }
        }
    }

    public func renameDirectories() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix
            let newPrefix = config.newPrefix

            var directories: [URL] = []
            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            while let url = enumerator?.nextObject() as? URL {
                if shouldExclude(path: url.path) { continue }
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    directories.append(url)
                }
            }

            directories.sort { $0.pathComponents.count > $1.pathComponents.count }

            for dir in directories {
                let dirName = dir.lastPathComponent
                guard dirName.contains(oldPrefix) else { continue }

                let newDirName = replaceWithProtection(dirName, oldPrefix: oldPrefix, newPrefix: newPrefix)
                let newDir = dir.deletingLastPathComponent().appendingPathComponent(newDirName)

                if dir.path != newDir.path {
                    try fileManager.moveItem(at: dir, to: newDir)
                    directoriesRenamed += 1
                }
            }
        }
    }

    public func renameFiles() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix
            let newPrefix = config.newPrefix

            var files: [URL] = []
            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            while let url = enumerator?.nextObject() as? URL {
                if shouldExclude(path: url.path) { continue }
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   !isDirectory.boolValue {
                    files.append(url)
                }
            }

            for file in files {
                let fileName = file.lastPathComponent
                guard fileName.contains(oldPrefix) else { continue }

                let newFileName = replaceWithProtection(fileName, oldPrefix: oldPrefix, newPrefix: newPrefix)
                let newFile = file.deletingLastPathComponent().appendingPathComponent(newFileName)

                if file.path != newFile.path {
                    try fileManager.moveItem(at: file, to: newFile)
                    filesRenamed += 1
                }
            }
        }
    }

    public func cleanPods() throws {
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix
            let podsTargetDir = URL(fileURLWithPath: targetPath)
                .appendingPathComponent("Pods")
                .appendingPathComponent("Target Support Files")
                .appendingPathComponent("Pods-\(oldPrefix)_TradeBook")

            if fileManager.fileExists(atPath: podsTargetDir.path) {
                try fileManager.removeItem(at: podsTargetDir)
            }
        }
    }

    public func cleanDerivedData() throws {
        let derivedDataPath = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData"
        let newPrefix = config.newPrefix

        guard fileManager.fileExists(atPath: derivedDataPath) else { return }

        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: derivedDataPath),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        while let dirURL = enumerator?.nextObject() as? URL {
            let dirName = dirURL.lastPathComponent
            if dirName.contains("\(newPrefix)_TradeBook") {
                try? fileManager.removeItem(at: dirURL)
            }
        }
    }

    public func verify() throws -> [String] {
        var unhandledFiles: [String] = []
        
        for pair in config.sourceTargetPairs {
            let targetPath = pair.targetPath
            let oldPrefix = config.oldPrefix

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: targetPath),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let path = fileURL.path
                if path.contains(oldPrefix) && !path.contains("xcuserdata") {
                    unhandledFiles.append(path)
                }
            }
        }

        return unhandledFiles
    }

    private func findFiles(in path: String, matching matcher: (URL) -> Bool) -> [URL] {
        var results: [URL] = []

        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if matcher(fileURL) {
                results.append(fileURL)
            }
        }

        return results
    }

    private func replaceContent(in fileURL: URL) throws {
        if shouldExclude(path: fileURL.path) { return }
        
        let oldPrefix = config.oldPrefix
        let newPrefix = config.newPrefix

        do {
            let originalContent = try String(contentsOf: fileURL, encoding: .utf8)
            let newContent = replaceWithProtection(originalContent, oldPrefix: oldPrefix, newPrefix: newPrefix)
            
            if originalContent != newContent {
                try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                filesReplaced += 1
            }
        } catch {
            throw RenamerError.replacementFailed(fileURL.path)
        }
    }
}
