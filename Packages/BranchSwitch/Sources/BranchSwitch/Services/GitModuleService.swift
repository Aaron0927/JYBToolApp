//
//  GitModuleService.swift
//  BranchSwitch
//

import Foundation

public enum GitModuleServiceError: Error, LocalizedError, Sendable {
    case executionFailed(String)
    case submoduleNotFound(String)
    case checkoutFailed(String)
    case pullFailed(String)
    case stashFailed(String)
    case stashPopFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .submoduleNotFound(let name):
            return "未找到子模块: \(name)"
        case .checkoutFailed(let message):
            return "切换分支失败: \(message)"
        case .pullFailed(let message):
            return "拉取失败: \(message)"
        case .stashFailed(let message):
            return "暂存失败: \(message)"
        case .stashPopFailed(let message):
            return "恢复暂存失败: \(message)"
        }
    }
}

public struct UpdateResult: Sendable {
    public let submodule: Submodule
    public let success: Bool
    public let hadChanges: Bool
    public let error: String?

    public init(submodule: Submodule, success: Bool, hadChanges: Bool, error: String? = nil) {
        self.submodule = submodule
        self.success = success
        self.hadChanges = hadChanges
        self.error = error
    }
}

public final class GitModuleService: Sendable {

    public init() {}

    // MARK: - Parsing Methods (for testing)

    public func parseSubmodules(from output: String) -> [Submodule] {
        var submodules: [Submodule] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(separator: " ")
            guard parts.count == 2 else { continue }

            let keyParts = parts[0].split(separator: ".")
            guard keyParts.count >= 3, keyParts[0] == "submodule" else { continue }

            let name = String(keyParts[1])
            let path = String(parts[1])

            submodules.append(Submodule(name: name, path: path, branch: "master"))
        }

        return submodules
    }

    public func parseSubmoduleBranch(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "master" : trimmed
    }

    public func hasChanges(output: String) -> Bool {
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Update Flow (for testing)

    public func simulateUpdateFlow(for submodule: Submodule) -> [String] {
        return ["stash", "checkout \(submodule.branch)", "pull", "stash pop"]
    }

    // MARK: - Actual Git Operations

    public func getSubmodules(at repoPath: String) throws -> [Submodule] {
        let processRunner = ProcessRunner()
        let output = try processRunner.run(
            "git config --file .gitmodules --get-regexp path",
            at: repoPath
        )

        var submodules: [Submodule] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(separator: " ")
            guard parts.count == 2 else { continue }

            let keyParts = parts[0].split(separator: ".")
            guard keyParts.count >= 3, keyParts[0] == "submodule" else { continue }

            let name = String(keyParts[1])
            let path = String(parts[1])
            let branch = try getSubmoduleBranch(name: name, at: repoPath)

            submodules.append(Submodule(name: name, path: path, branch: branch))
        }

        return submodules
    }

    public func getSubmoduleBranch(name: String, at repoPath: String) throws -> String {
        let processRunner = ProcessRunner()
        let output = try processRunner.run(
            "git config --file .gitmodules submodule.\(name).branch",
            at: repoPath
        )
        return parseSubmoduleBranch(from: output)
    }

    public func hasChanges(at submodulePath: String) -> Bool {
        let processRunner = ProcessRunner()
        do {
            let output = try processRunner.run("git status --porcelain", at: submodulePath)
            return hasChanges(output: output)
        } catch {
            return false
        }
    }

    // MARK: - Main Repo Operations

    public func getBranches(at repoPath: String) throws -> [String] {
        let processRunner = ProcessRunner()
        let output = try processRunner.run("git branch", at: repoPath)

        var branches: [String] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // 移除 "* " 前缀（当前分支）
            let branch = trimmed.hasPrefix("* ") ? String(trimmed.dropFirst(2)) : trimmed
            branches.append(branch)
        }
        return branches
    }

    public func getCurrentBranch(at path: String) -> String? {
        let processRunner = ProcessRunner()
        do {
            let output = try processRunner.run("git rev-parse --abbrev-ref HEAD", at: path)
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    public func checkoutMainRepo(branch: String, at repoPath: String) throws {
        let processRunner = ProcessRunner()
        _ = try processRunner.run("git checkout \(branch)", at: repoPath)
        _ = try processRunner.run("git pull", at: repoPath)
    }

    public func updateSubmodule(_ submodule: Submodule, at repoPath: String) -> UpdateResult {
        let submodulePath = (repoPath as NSString).appendingPathComponent(submodule.path)

        // Check for changes
        let hadChanges = hasChanges(at: submodulePath)

        // Stash if needed
        if hadChanges {
            let stashResult = stash(at: submodulePath)
            if !stashResult {
                return UpdateResult(
                    submodule: submodule,
                    success: false,
                    hadChanges: true,
                    error: "暂存更改失败"
                )
            }
        }

        // Checkout branch
        let checkoutResult = checkout(branch: submodule.branch, at: submodulePath)
        if !checkoutResult {
            return UpdateResult(
                submodule: submodule,
                success: false,
                hadChanges: hadChanges,
                error: "切换分支 \(submodule.branch) 失败"
            )
        }

        // Pull
        let pullResult = pull(at: submodulePath)
        if !pullResult {
            return UpdateResult(
                submodule: submodule,
                success: false,
                hadChanges: hadChanges,
                error: "拉取失败"
            )
        }

        // Restore stash if needed
        if hadChanges {
            let stashPopResult = stashPop(at: submodulePath)
            if !stashPopResult {
                return UpdateResult(
                    submodule: submodule,
                    success: true,
                    hadChanges: true,
                    error: "恢复暂存失败"
                )
            }
        }

        return UpdateResult(
            submodule: submodule,
            success: true,
            hadChanges: hadChanges
        )
    }

    private func stash(at path: String) -> Bool {
        let processRunner = ProcessRunner()
        do {
            _ = try processRunner.run("git stash", at: path)
            return true
        } catch {
            return false
        }
    }

    private func checkout(branch: String, at path: String) -> Bool {
        let processRunner = ProcessRunner()
        do {
            _ = try processRunner.run("git checkout \(branch)", at: path)
            return true
        } catch {
            return false
        }
    }

    private func pull(at path: String) -> Bool {
        let processRunner = ProcessRunner()
        do {
            _ = try processRunner.run("git pull", at: path)
            return true
        } catch {
            return false
        }
    }

    private func stashPop(at path: String) -> Bool {
        let processRunner = ProcessRunner()
        do {
            _ = try processRunner.run("git stash pop", at: path)
            return true
        } catch {
            return false
        }
    }
}
