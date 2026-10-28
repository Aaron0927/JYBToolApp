import Foundation

public enum BranchSyncServiceError: Error, LocalizedError, Sendable {
  case notGitRepository(String)
  case missingCurrentBranch
  case missingOrigin(String)
  case missingStableBranch
  case missingRemoteConfig(String)

  public var errorDescription: String? {
    switch self {
    case .notGitRepository(let path): "不是 Git 仓库：\(path)"
    case .missingCurrentBranch: "无法确定主工程当前分支。"
    case .missingOrigin(let path): "仓库没有配置 origin：\(path)"
    case .missingStableBranch: "origin 上没有 master 或 main 分支。"
    case .missingRemoteConfig(let path): "目标分支中未找到 fastlane/repos.yml：\(path)"
    }
  }
}

public final class BranchSyncService: Sendable {
  private let processRunner: ProcessRunner
  private let reposService: ReposYAMLService

  public init(processRunner: ProcessRunner = ProcessRunner()) {
    self.processRunner = processRunner
    reposService = ReposYAMLService(processRunner: processRunner)
  }

  public func loadPreview(atProjectPath projectPath: String) throws -> BranchSyncPreview {
    guard reposService.isGitRepository(at: projectPath) else {
      throw BranchSyncServiceError.notGitRepository(projectPath)
    }

    let sourceProjectBranch = try currentBranch(at: projectPath)
    guard !sourceProjectBranch.isEmpty, sourceProjectBranch != "HEAD" else {
      throw BranchSyncServiceError.missingCurrentBranch
    }

    let sourceConfig = try reposService.loadConfig(atProjectPath: projectPath)
    let configURL = reposService.configURL(forProjectPath: projectPath)
    let sourceRootURL = reposService.rootURL(for: sourceConfig, configURL: configURL)
    let target = try fetchStableConfig(at: projectPath)

    let sourceByPath = Dictionary(sourceConfig.repos.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    let targetByPath = Dictionary(target.config.repos.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    let allPaths = Set(sourceByPath.keys).union(targetByPath.keys).sorted()

    var repositories = [workspaceRepository(
      projectPath: projectPath,
      sourceBranch: sourceProjectBranch,
      targetBranch: target.branch
    )]

    for path in allPaths {
      let source = sourceByPath[path]
      let destination = targetByPath[path]
      let name = source?.name ?? destination?.name ?? path
      let repositoryURL = source.map { reposService.repoURL(for: $0, rootURL: sourceRootURL) }
        ?? sourceRootURL.appending(path: path).standardizedFileURL
      let sourceBranch = source?.branch
      let targetBranch = destination?.branch
      let isCloned = reposService.isGitRepository(at: repositoryURL.path)
      let reason: String?

      if source == nil {
        reason = "当前分支的 repos.yml 未声明此仓库"
      } else if destination == nil {
        reason = "\(target.branch) 分支的 repos.yml 未声明此仓库"
      } else if !isCloned {
        reason = "仓库尚未克隆"
      } else if let sourceBranch, !isValidBranch(sourceBranch, at: repositoryURL.path) {
        reason = "来源分支名无效：\(sourceBranch)"
      } else if let sourceBranch, !localBranchExists(sourceBranch, at: repositoryURL.path) {
        reason = "本地不存在来源分支：\(sourceBranch)"
      } else if let targetBranch, !isValidBranch(targetBranch, at: repositoryURL.path) {
        reason = "目标分支名无效：\(targetBranch)"
      } else {
        reason = nil
      }

      repositories.append(BranchSyncRepository(
        name: name,
        path: path,
        absolutePath: repositoryURL.path,
        sourceBranch: sourceBranch,
        targetBranch: targetBranch,
        isWorkspace: false,
        isSelectable: reason == nil,
        unavailableReason: reason
      ))
    }

    return BranchSyncPreview(
      projectPath: URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.path,
      sourceProjectBranch: sourceProjectBranch,
      targetProjectBranch: target.branch,
      targetConfigBranch: target.branch,
      repositories: repositories
    )
  }

  public func sync(_ repository: BranchSyncRepository) -> BranchSyncResult {
    guard let sourceBranch = repository.sourceBranch,
          let targetBranch = repository.targetBranch
    else {
      return result(repository, status: .skipped, message: repository.unavailableReason ?? "来源或目标分支未配置。")
    }

    let path = repository.absolutePath
    if !repository.isSelectable {
      return result(repository, status: .skipped, message: repository.unavailableReason ?? "仓库当前不可同步。")
    }
    guard reposService.isGitRepository(at: path) else {
      return result(repository, status: .skipped, message: "仓库不存在或不是 Git 仓库。")
    }
    guard sourceBranch != targetBranch else {
      return result(repository, status: .skipped, message: "来源分支与目标分支相同。")
    }

    do {
      guard try processRunner.run("git remote", at: path).split(whereSeparator: \.isNewline).contains("origin") else {
        return result(repository, status: .skipped, message: "仓库没有配置 origin。")
      }

      let initialBranch = try currentBranch(at: path)
      let initialCommit = try processRunner.run("git rev-parse HEAD", at: path).trimmingCharacters(in: .whitespacesAndNewlines)
      let dirtyOutput = try processRunner.run("git status --porcelain --untracked-files=all", at: path)
      guard dirtyOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return result(repository, status: .skipped, message: "工作区有未提交修改。")
      }
      guard localBranchExists(sourceBranch, at: path) else {
        return result(repository, status: .skipped, message: "本地不存在来源分支：\(sourceBranch)")
      }

      _ = try runChecked(
        "git fetch origin \(shellEscaped("+refs/heads/\(targetBranch):refs/remotes/origin/\(targetBranch)"))",
        at: path,
        timeout: 180
      )

      let remoteTarget = "refs/remotes/origin/\(targetBranch)"
      guard referenceExists(remoteTarget, at: path) else {
        return result(repository, status: .skipped, message: "origin 上不存在目标分支：\(targetBranch)")
      }

      let sourceRef = "refs/heads/\(sourceBranch)"
      let targetCommit = try processRunner.run("git rev-parse \(shellEscaped(remoteTarget))", at: path)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let localTargetRef = "refs/heads/\(targetBranch)"
      let hasLocalTarget = referenceExists(localTargetRef, at: path)
      if hasLocalTarget {
        let localTargetCommit = try processRunner.run("git rev-parse \(shellEscaped(localTargetRef))", at: path)
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if localTargetCommit != targetCommit && !isAncestor(localTargetCommit, of: targetCommit, at: path) {
          return result(repository, status: .skipped, message: "本地目標分支與 origin/\(targetBranch) 不一致，為避免覆蓋本地提交已跳過。")
        }
      }

      var operationStatus: BranchSyncStatus = .success
      var operationMessage = "合并成功并已推送到 origin/\(targetBranch)。"

      do {
        if hasLocalTarget {
          _ = try runChecked("git checkout \(shellEscaped(targetBranch))", at: path)
          _ = try runChecked("git merge --ff-only \(shellEscaped(remoteTarget))", at: path)
        } else {
          _ = try runChecked(
            "git checkout -b \(shellEscaped(targetBranch)) --track \(shellEscaped(remoteTarget))",
            at: path
          )
        }

        do {
          _ = try runChecked("git merge --no-edit \(shellEscaped(sourceRef))", at: path, timeout: 180)
        } catch {
          if referenceExists("MERGE_HEAD", at: path, isGitPath: true) {
            _ = try? processRunner.run("git merge --abort", at: path)
          }
          throw error
        }

        do {
          _ = try runChecked("git push origin \(shellEscaped(targetBranch))", at: path, timeout: 180)
        } catch {
          operationStatus = .pushFailed
          operationMessage = "本地已完成合并，但推送失败；本地 \(targetBranch) 分支保留合并结果：\(error.localizedDescription)"
        }
      } catch {
        operationStatus = .failed
        operationMessage = "同步失败：\(error.localizedDescription)"
      }

      do {
        if initialBranch == "HEAD" {
          _ = try runChecked("git checkout --detach \(shellEscaped(initialCommit))", at: path)
        } else if !initialBranch.isEmpty {
          _ = try runChecked("git checkout \(shellEscaped(initialBranch))", at: path)
        }
      } catch {
        let restoreMessage = "已完成目标分支处理，但无法切回原分支：\(error.localizedDescription)"
        if operationStatus == .success {
          operationStatus = .failed
        }
        operationMessage += " \(restoreMessage)"
      }

      return result(repository, status: operationStatus, message: operationMessage)
    } catch {
      return result(repository, status: .failed, message: "同步失败：\(error.localizedDescription)")
    }
  }

  private func fetchStableConfig(at projectPath: String) throws -> (branch: String, config: ReposConfig) {
    let remotes = try processRunner.run("git remote", at: projectPath)
      .split(whereSeparator: \.isNewline)
      .map(String.init)
    guard remotes.contains("origin") else {
      throw BranchSyncServiceError.missingOrigin(projectPath)
    }

    let remoteBranches = try processRunner.run(
      "git ls-remote --heads origin refs/heads/master refs/heads/main",
      at: projectPath,
      timeout: 180
    )
    let available = Set(remoteBranches.split(whereSeparator: \.isNewline).compactMap { line -> String? in
      guard let ref = line.split(whereSeparator: \.isWhitespace).last else { return nil }
      return String(ref).replacing("refs/heads/", with: "")
    })
    guard let targetBranch = ["master", "main"].first(where: available.contains) else {
      throw BranchSyncServiceError.missingStableBranch
    }

    _ = try runChecked(
      "git fetch origin \(shellEscaped("+refs/heads/\(targetBranch):refs/remotes/origin/\(targetBranch)"))",
      at: projectPath,
      timeout: 180
    )

    let remoteConfigPath = "refs/remotes/origin/\(targetBranch):fastlane/repos.yml"
    let configContent: String
    do {
      configContent = try processRunner.run("git show \(shellEscaped(remoteConfigPath))", at: projectPath)
    } catch {
      throw BranchSyncServiceError.missingRemoteConfig("origin/\(targetBranch)")
    }
    return (targetBranch, try reposService.parseConfig(from: configContent))
  }

  private func workspaceRepository(
    projectPath: String,
    sourceBranch: String,
    targetBranch: String
  ) -> BranchSyncRepository {
    let name = URL(fileURLWithPath: projectPath, isDirectory: true).lastPathComponent
    let reason = isValidBranch(sourceBranch, at: projectPath) ? nil : "来源分支名无效：\(sourceBranch)"
    return BranchSyncRepository(
      name: name,
      path: ".",
      absolutePath: URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.path,
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      isWorkspace: true,
      isSelectable: reason == nil,
      unavailableReason: reason
    )
  }

  private func currentBranch(at path: String) throws -> String {
    try processRunner.run("git rev-parse --abbrev-ref HEAD", at: path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func isValidBranch(_ branch: String, at path: String) -> Bool {
    commandSucceeded("git check-ref-format --branch \(shellEscaped(branch))", at: path)
  }

  private func localBranchExists(_ branch: String, at path: String) -> Bool {
    referenceExists("refs/heads/\(branch)", at: path)
  }

  private func referenceExists(_ reference: String, at path: String, isGitPath: Bool = false) -> Bool {
    let command = isGitPath
      ? "git rev-parse --quiet --verify \(shellEscaped(reference))"
      : "git show-ref --verify --quiet \(shellEscaped(reference))"
    return commandSucceeded(command, at: path)
  }

  private func isAncestor(_ first: String, of second: String, at path: String) -> Bool {
    commandSucceeded("git merge-base --is-ancestor \(shellEscaped(first)) \(shellEscaped(second))", at: path)
  }

  private func commandSucceeded(_ command: String, at path: String) -> Bool {
    (try? processRunner.run("if \(command) >/dev/null 2>&1; then printf yes; else printf no; fi", at: path)) == "yes"
  }

  private func runChecked(_ command: String, at path: String, timeout: TimeInterval? = nil) throws -> String {
    try processRunner.run(
      "\(command) || { command_status=$?; printf 'git command failed with status %s\\n' \"$command_status\" >&2; exit \"$command_status\"; }",
      at: path,
      timeout: timeout
    )
  }

  private func result(
    _ repository: BranchSyncRepository,
    status: BranchSyncStatus,
    message: String
  ) -> BranchSyncResult {
    BranchSyncResult(
      repositoryID: repository.id,
      name: repository.name,
      sourceBranch: repository.sourceBranch ?? "—",
      targetBranch: repository.targetBranch ?? "—",
      status: status,
      message: message
    )
  }

  private func shellEscaped(_ value: String) -> String {
    "'\(value.replacing("'", with: "'\\''"))'"
  }
}
