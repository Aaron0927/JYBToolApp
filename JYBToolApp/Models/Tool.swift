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

    static let switchTool = Tool(id: "switch", name: "私版券商切换", category: "Git", icon: "folder")
    static let copyTool = Tool(id: "copy", name: "私版项目复制", category: "工具", icon: "doc.on.doc")
    static let branchTool = Tool(id: "branch", name: "主仓库子模块切换", category: "Git", icon: "arrow.triangle.branch")
    static let reposBranchTool = Tool(id: "reposBranch", name: "公版依赖仓库切换", category: "Git", icon: "list.bullet.rectangle")
}
