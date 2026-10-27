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
    let isDeprecated: Bool

    init(id: String, name: String, category: String, icon: String, isDeprecated: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.isDeprecated = isDeprecated
    }

    static let switchTool = Tool(id: "switch", name: "券商仓库切换", category: "私版", icon: "arrow.triangle.branch")
    static let copyTool = Tool(id: "copy", name: "项目复制", category: "私版", icon: "doc.on.doc")
    static let branchTool = Tool(id: "branch", name: "分支切换（已过时）", category: "公版", icon: "arrow.triangle.branch", isDeprecated: true)
    static let reposBranchTool = Tool(id: "reposBranch", name: "分支切换", category: "公版", icon: "arrow.triangle.branch")
    static let reposPullTool = Tool(id: "reposPull", name: "仓库更新", category: "公版", icon: "arrow.down.to.line.compact")
    static let reposTagTool = Tool(id: "reposTag", name: "Tag 管理", category: "公版", icon: "tag")
}
