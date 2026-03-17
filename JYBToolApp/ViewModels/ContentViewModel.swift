//
//  ContentViewModel.swift
//  JYBToolApp
//
//  Created by kim on 2026/3/13.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class ContentViewModel {
    var selectedToolId: String?
    
    let tools: [Tool] = [
        Tool(id: "switch", name: "切换券商", category: "项目"),
        Tool(id: "copy", name: "复制项目", category: "项目"),
    ]
    
    var groupedTools: [String: [Tool]] {
        Dictionary(grouping: tools, by: { $0.category })
    }
    
    var sortedCategories: [String] {
        groupedTools.keys.sorted()
    }
    
    var selectedTool: Tool? {
        guard let toolId = selectedToolId else { return nil }
        return tools.first(where: { $0.id == toolId })
    }
}
