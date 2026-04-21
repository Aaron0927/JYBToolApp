//
//  GitService.swift
//  GitSwitcher
//
//  Created by kim on 2026/3/13.
//

import Foundation
import JYBLog

public final class GitService {
    private let stashDir = ".gitswitcher-stash"

    public init() {}

    public func readCurrentBranch(repo: Repo) -> String {
        do {
            let result = try ProcessRunner.run("git rev-parse --abbrev-ref HEAD", at: repo.path)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("读取 \(repo.name) 当前分支失败: \(error)")
            return "unknown"
        }
    }

    @MainActor
    public func fetchBranches(repo: Repo) -> [String] {
        do {
            // 先 fetch 远程
            _ = try? ProcessRunner.run("git fetch --all", at: repo.path)
            // 获取远程分支
            let result = try ProcessRunner.run("git branch -r --format '%(refname:short)'", at: repo.path)
            let branches = result
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.contains("HEAD") }
            return Array(Set(branches)).sorted()
        } catch {
            LogManager.shared.error("获取 \(repo.name) 分支列表失败: \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    public func readGitmodules(repo: Repo) -> [Submodule] {
        let gitmodulesPath = (repo.path as NSString).appendingPathComponent(".gitmodules")
        guard FileManager.default.fileExists(atPath: gitmodulesPath) else {
            return []
        }

        do {
            let content = try String(contentsOfFile: gitmodulesPath, encoding: .utf8)
            return parseGitmodules(content: content, repoPath: repo.path)
        } catch {
            LogManager.shared.error("读取 .gitmodules 失败: \(error.localizedDescription)")
            return []
        }
    }

    private func parseGitmodules(content: String, repoPath: String) -> [Submodule] {
        var submodules: [Submodule] = []
        let lines = content.components(separatedBy: "\n")
        var currentSubmodule: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[submodule") {
                if !currentSubmodule.isEmpty, let name = currentSubmodule["name"], let path = currentSubmodule["path"] {
                    let targetBranch = currentSubmodule["branch"] ?? "main"
                    let submodulePath = (repoPath as NSString).appendingPathComponent(path)
                    let currentBranch = getSubmoduleCurrentBranch(path: submodulePath)
                    submodules.append(Submodule(
                        name: name,
                        path: path,
                        currentBranch: currentBranch,
                        targetBranch: targetBranch
                    ))
                }
                currentSubmodule = [:]
            } else if trimmed.hasPrefix("path") {
                currentSubmodule["path"] = extractValue(trimmed)
            } else if trimmed.hasPrefix("url") {
                currentSubmodule["url"] = extractValue(trimmed)
            } else if trimmed.hasPrefix("branch") {
                currentSubmodule["branch"] = extractValue(trimmed)
            }
        }

        if !currentSubmodule.isEmpty, let name = currentSubmodule["name"], let path = currentSubmodule["path"] {
            let targetBranch = currentSubmodule["branch"] ?? "main"
            let submodulePath = (repoPath as NSString).appendingPathComponent(path)
            let currentBranch = getSubmoduleCurrentBranch(path: submodulePath)
            submodules.append(Submodule(
                name: name,
                path: path,
                currentBranch: currentBranch,
                targetBranch: targetBranch
            ))
        }

        return submodules
    }

    private func extractValue(_ line: String) -> String {
        guard let equalIndex = line.firstIndex(of: "=") else { return "" }
        return String(line[line.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
    }

    private func getSubmoduleCurrentBranch(path: String) -> String {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitPath) else { return "unknown" }

        do {
            let result = try ProcessRunner.run("git rev-parse --abbrev-ref HEAD", at: path)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "unknown"
        }
    }

    @MainActor
    public func checkoutSubmodule(repo: Repo, submodule: Submodule) throws {
        let submodulePath = (repo.path as NSString).appendingPathComponent(submodule.path)

        // 1. 先在子模块内部切换到目标分支
        let submoduleGitPath = (submodulePath as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: submoduleGitPath) {
            // 子模块已初始化，直接在子模块目录切换分支
            _ = try? ProcessRunner.run("git checkout \(submodule.targetBranch)", at: submodulePath)
        } else {
            // 子模块未初始化，先设置跟踪分支再更新
            try ProcessRunner.run("git submodule set-branch --branch \(submodule.targetBranch) \(submodule.path)", at: repo.path)
            try ProcessRunner.run("git submodule update --init \(submodule.path)", at: repo.path)
            // 更新完后再切换到目标分支（因为 update --init 可能不会切到最新分支）
            _ = try? ProcessRunner.run("git checkout \(submodule.targetBranch)", at: submodulePath)
        }
        LogManager.shared.success("子模块 \(submodule.name) 切换到 \(submodule.targetBranch)")
    }

    public func hasChanges(repo: Repo) -> Bool {
        let result = try? ProcessRunner.run("git status --porcelain", at: repo.path)
        return !(result?.isEmpty ?? true)
    }

    public func stash(repo: Repo) throws {
        _ = try ProcessRunner.run("git stash push -u", at: repo.path)
    }

    public func checkout(repo: Repo, branch: String) throws {
        // 先尝试切换（分支可能已存在）
        _ = try ProcessRunner.run("git checkout \(branch)", at: repo.path)
        // 检查是否切换成功
        let currentBranch = readCurrentBranch(repo: repo)
        if currentBranch == branch {
            return
        }
        // 分支不存在，尝试创建并切换
        _ = try ProcessRunner.run("git checkout -b \(branch)", at: repo.path)
    }

    @MainActor
    public func pull(repo: Repo) throws {
        // 获取当前分支名
        let currentBranch = readCurrentBranch(repo: repo)

        // 检查远程是否存在该分支
        let remoteExists = try? ProcessRunner.run("git ls-remote --heads origin \(repo.targetBranch)", at: repo.path)
        if remoteExists?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            LogManager.shared.info("\(repo.name) 是本地分支（远程不存在），跳过 pull")
            return
        }

        // 设置上游分支（如果还没有设置）
        let trackingInfo = try? ProcessRunner.run("git rev-parse --abbrev-ref \(currentBranch)@{upstream}", at: repo.path)
        if trackingInfo?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            // 当前分支没有上游跟踪，设置它
            _ = try? ProcessRunner.run("git branch --set-upstream-to=origin/\(repo.targetBranch)", at: repo.path)
        }

        // 显式指定远程和分支进行 pull，避免 "no tracking information" 错误
        _ = try ProcessRunner.run("git pull origin \(repo.targetBranch)", at: repo.path)
    }

    // MARK: - Stash 持久化

    public func hasSavedStash(repo: Repo) -> Bool {
        let stashPath = (repo.path as NSString).appendingPathComponent(stashDir)
        return FileManager.default.fileExists(atPath: stashPath)
    }

    @MainActor
    public func saveStash(repo: Repo) throws {
        guard hasChanges(repo: repo) else { return }

        let currentBranch = readCurrentBranch(repo: repo)
        let stashPath = (repo.path as NSString).appendingPathComponent(stashDir)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: stashPath) {
            try fileManager.createDirectory(atPath: stashPath, withIntermediateDirectories: true)
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let stashFileName = "\(currentBranch)_\(timestamp).stash"
        let stashFilePath = (stashPath as NSString).appendingPathComponent(stashFileName)

        // 创建 stash 并获取 stash 引用
        let stashRef = try ProcessRunner.run("git stash push -u -m \"\(currentBranch)_\(timestamp)\"", at: repo.path)

        // 获取 stash 内容并保存
        let stashList = try ProcessRunner.run("git stash list", at: repo.path)
        if let firstStash = stashList.components(separatedBy: "\n").first, firstStash.contains("stash@{") {
            let stashContent = try ProcessRunner.run("git stash show -p", at: repo.path)
            try stashContent.write(toFile: stashFilePath, atomically: true, encoding: .utf8)
            // 删除最新的 stash
            _ = try ProcessRunner.run("git stash drop", at: repo.path)
            LogManager.shared.info("未提交的修改已保存到本地: \(stashFileName)")
        }
    }

    @MainActor
    public func restoreStash(repo: Repo) throws {
        let stashPath = (repo.path as NSString).appendingPathComponent(stashDir)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: stashPath) else { return }

        let currentBranch = readCurrentBranch(repo: repo)
        let entries = try fileManager.contentsOfDirectory(atPath: stashPath)

        for entry in entries where entry.hasPrefix(currentBranch) && entry.hasSuffix(".stash") {
            let stashFilePath = (stashPath as NSString).appendingPathComponent(entry)
            let stashContent = try String(contentsOfFile: stashFilePath, encoding: .utf8)

            // 使用 git apply 恢复stash内容
            let process = Process()
            let pipe = Pipe()
            process.standardInput = pipe
            process.standardOutput = pipe
            process.standardError = pipe
            process.currentDirectoryURL = URL(fileURLWithPath: repo.path)
            process.launchPath = "/bin/zsh"
            process.arguments = ["-c", "git apply"]
            process.launch()

            if let data = stashContent.data(using: .utf8) {
                pipe.fileHandleForWriting.write(data)
            }
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            // 删除 stash 文件
            try fileManager.removeItem(atPath: stashFilePath)
            LogManager.shared.success("已恢复保存的修改: \(entry)")
            break
        }
    }

    public func getSavedStashFiles(repo: Repo) -> [String] {
        let stashPath = (repo.path as NSString).appendingPathComponent(stashDir)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: stashPath) else { return [] }

        do {
            let entries = try fileManager.contentsOfDirectory(atPath: stashPath)
            return entries.filter { $0.hasSuffix(".stash") }
        } catch {
            return []
        }
    }
}
