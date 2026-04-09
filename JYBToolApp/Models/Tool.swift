//
//  Tool.swift
//  JYBToolApp
//
//  Created by kim on 2026/3/13.
//

import Foundation
import SwiftUI

struct Tool: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let icon: String

    static let switchTool = Tool(id: "switch", name: "切换券商", category: "Git", icon: "folder")
    static let copyTool = Tool(id: "copy", name: "复制项目", category: "工具", icon: "doc.on.doc")
    static let branchTool = Tool(id: "branch", name: "公版切换", category: "Git", icon: "arrow.triangle.branch")
}
