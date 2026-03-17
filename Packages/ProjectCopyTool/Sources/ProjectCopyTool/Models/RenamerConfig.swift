import Foundation

public struct SourceTargetPair: Identifiable {
    public let id: UUID
    public var sourcePath: String
    public var targetPath: String
    
    public init(id: UUID = UUID(), sourcePath: String = "", targetPath: String = "") {
        self.id = id
        self.sourcePath = sourcePath
        self.targetPath = targetPath
    }
}

public struct RenamerConfig {
    public let sourceTargetPairs: [SourceTargetPair]
    public let oldPrefix: String
    public let newPrefix: String
    public let autoOpenProject: Bool
    public let modifyConfigFiles: Bool
    public let configModifications: [ConfigFileModification]

    public var sourceURLs: [URL] {
        sourceTargetPairs.map { URL(fileURLWithPath: $0.sourcePath) }
    }
    
    public var targetURLs: [URL] {
        sourceTargetPairs.map { URL(fileURLWithPath: $0.targetPath) }
    }
    
    public var projectURLs: [URL] {
        targetURLs.compactMap { targetURL in
            let xcworkspace = targetURL.appendingPathExtension("xcworkspace")
            let xcodeproj = targetURL.appendingPathExtension("xcodeproj")
            
            if FileManager.default.fileExists(atPath: xcworkspace.path) {
                return xcworkspace
            } else if FileManager.default.fileExists(atPath: xcodeproj.path) {
                return xcodeproj
            }
            return nil
        }
    }

    public func validate() throws {
        let fileManager = FileManager.default
        
        guard !sourceTargetPairs.isEmpty else {
            throw RenamerError.sourceNotFound("")
        }

        for pair in sourceTargetPairs {
            let sourcePath = pair.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetPath = pair.targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !sourcePath.isEmpty else {
                throw RenamerError.sourceNotFound(sourcePath)
            }
            
            guard fileManager.fileExists(atPath: sourcePath) else {
                throw RenamerError.sourceNotFound(sourcePath)
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                throw RenamerError.sourceNotDirectory(sourcePath)
            }
        }

        guard !oldPrefix.isEmpty else {
            throw RenamerError.emptyPrefix("旧前缀")
        }

        guard !newPrefix.isEmpty else {
            throw RenamerError.emptyPrefix("新前缀")
        }

        guard oldPrefix != newPrefix else {
            throw RenamerError.prefixesIdentical
        }
    }
    
    public init(sourceTargetPairs: [SourceTargetPair], oldPrefix: String, newPrefix: String, autoOpenProject: Bool = false, modifyConfigFiles: Bool = true, configModifications: [ConfigFileModification] = []) {
        self.sourceTargetPairs = sourceTargetPairs
        self.oldPrefix = oldPrefix
        self.newPrefix = newPrefix
        self.autoOpenProject = autoOpenProject
        self.modifyConfigFiles = modifyConfigFiles
        self.configModifications = configModifications.isEmpty ? Constants.defaultConfigModifications : configModifications
    }
}
