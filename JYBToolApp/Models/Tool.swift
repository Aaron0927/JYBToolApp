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

    static let switchTool = Tool(id: "switch", name: "券商仓库切换", category: "私版", icon: "arrow.triangle.branch")
    static let copyTool = Tool(id: "copy", name: "项目复制", category: "私版", icon: "doc.on.doc")
    static let branchTool = Tool(id: "branch", name: "主仓库子模块切换", category: "公版", icon: "arrow.triangle.branch")
    static let reposBranchTool = Tool(id: "reposBranch", name: "依赖仓库同步", category: "公版", icon: "shippingbox")
}
