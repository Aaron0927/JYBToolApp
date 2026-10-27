import Foundation

public struct ConfigFileModification: Identifiable, Codable, Sendable {
    public let id: UUID
    public let fileNamePattern: String
    public let keysToModify: [String]
    
    public init(id: UUID = UUID(), fileNamePattern: String, keysToModify: [String]) {
        self.id = id
        self.fileNamePattern = fileNamePattern
        self.keysToModify = keysToModify
    }
}
