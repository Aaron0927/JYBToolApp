import Foundation

public enum BranchSyncServiceError: Error, LocalizedError, Sendable {
  case notGitRepository(String)
  case missingCurrentBranch
  case missingOrigin(String)
  case missingTargetBranches(String)
  case invalidTargetBranch(String)
  case missingRemoteConfig(String)
  case mergeConflict(String)

  public var errorDescription: String? {
    switch self {
    case .notGitRepository(let path): "不是 Git 仓库：\(path)"
    case .missingCurrentBranch: "无法确定主工程当前分支。"
    case .missingOrigin(let path): "仓库没有配置 origin：\(path)"
    case .missingTargetBranches(let path): "主工程 origin 上没有可用分支：\(path)"
    case .invalidTargetBranch(let branch): "目标分支不在主工程 origin 分支列表中：\(branch)"
    case .missingRemoteConfig(let path): "目标分支中未找到 fastlane/repos.yml：\(path)"
    case .mergeConflict(let paths): "合并存在未解决冲突：\(paths)"
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

  public func loadProjectContext(atProjectPath projectPath: String) throws -> BranchSyncProjectContext {
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
    let targetBranches = try getRemoteBranches(at: projectPath)
    guard !targetBranches.isEmpty else {
      throw BranchSyncServiceError.missingTargetBranches(projectPath)
    }
    let defaultTargetBranch = ["master", "main"].first(where: targetBranches.contains)

    return BranchSyncProjectContext(
      projectPath: URL(fileURLWithPath: projectPath, isDirectory: true).standardizedFileURL.path,
      sourceProjectBranch: sourceProjectBranch,
      sourceConfig: sourceConfig,
      sourceRootPath: sourceRootURL.path,
      targetBranches: targetBranches,
      defaultTargetBranch: defaultTargetBranch
    )
  }

  public func loadPreview(
    for context: BranchSyncProjectContext,
    targetProjectBranch: String
  ) throws -> BranchSyncPreview {
    guard context.targetBranches.contains(targetProjectBranch) else {
      throw BranchSyncServiceError.invalidTargetBranch(targetProjectBranch)
    }

    let targetConfig = try loadRemoteConfig(
      branch: targetProjectBranch,
      atProjectPath: context.projectPath
    )

    let sourceByPath = Dictionary(context.sourceConfig.repos.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    let targetByPath = Dictionary(targetConfig.repos.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    let allPaths = Set(sourceByPath.keys).union(targetByPath.keys).sorted()
    let sourceRootURL = URL(fileURLWithPath: context.sourceRootPath, isDirectory: true)

    let workspaceReason = context.sourceProjectBranch == targetProjectBranch
      ? "主工程来源分支与目标分支相同"
      : nil
    var repositories = [BranchSyncRepository(
      name: URL(fileURLWithPath: context.projectPath, isDirectory: true).lastPathComponent,
      path: ".",
      absolutePath: context.projectPath,
      sourceBranch: context.sourceProjectBranch,
      targetBranch: targetProjectBranch,
      isWorkspace: true,
      isSelectable: workspaceReason == nil,
      unavailableReason: workspaceReason
    )]

    for path in allPaths {
      let source = sourceByPath[path]
      let destination = targetByPath[path]
      let name = source?.name ?? destination?.name ?? path
      let repositoryURL = source.map { reposService.repoURL(for: $0, rootURL: sourceRootURL) }
        ?? sourceRootURL.appending(path: path).standardizedFileURL
      let configuredSourceBranch = source?.branch
      let configuredTargetBranch = destination?.branch
      let isCloned = reposService.isGitRepository(at: repositoryURL.path)
      let reason: String?

      if source == nil {
        reason = "当前分支的 repos.yml 未声明此仓库"
      } else if destination == nil {
        reason = "\(targetProjectBranch) 分支的 repos.yml 未声明此仓库"
      } else if !isCloned {
        reason = "仓库尚未克隆"
      } else if configuredSourceBranch == configuredTargetBranch {
        reason = "来源分支与目标分支相同"
      } else {
        reason = nil
      }

      repositories.append(BranchSyncRepository(
        name: name,
        path: path,
        absolutePath: repositoryURL.path,
        sourceBranch: configuredSourceBranch,
        targetBranch: configuredTargetBranch,
        isWorkspace: false,
        isSelectable: reason == nil,
        unavailableReason: reason
      ))
    }

    return BranchSyncPreview(
      projectPath: context.projectPath,
      sourceProjectBranch: context.sourceProjectBranch,
      targetProjectBranch: targetProjectBranch,
      targetConfigBranch: targetProjectBranch,
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
      var operationMessage = "合并成功，已保留目标分支的 fastlane/repos.yml，并推送到 origin/\(targetBranch)。"

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
          do {
            _ = try runChecked(
              "git merge --no-ff --no-commit \(shellEscaped(sourceRef))",
              at: path,
              timeout: 180
            )
          } catch {
            guard referenceExists("MERGE_HEAD", at: path, isGitPath: true) else {
              throw error
            }
          }

          if referenceExists("MERGE_HEAD", at: path, isGitPath: true) {
            do {
              try restoreTargetReposConfig(at: path)
              let unresolvedPaths = try processRunner.run(
                "git diff --name-only --diff-filter=U",
                at: path
              ).trimmingCharacters(in: .whitespacesAndNewlines)
              guard unresolvedPaths.isEmpty else {
                throw BranchSyncServiceError.mergeConflict(unresolvedPaths)
              }
              _ = try runChecked("git commit --no-edit", at: path, timeout: 180)
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
          } else {
            operationMessage = "目标分支已包含来源分支，无需合并。"
          }
        } catch {
          if referenceExists("MERGE_HEAD", at: path, isGitPath: true) {
            _ = try? processRunner.run("git merge --abort", at: path)
          }
          throw error
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

  private func loadRemoteConfig(branch: String, atProjectPath projectPath: String) throws -> ReposConfig {
    let remotes = try processRunner.run("git remote", at: projectPath)
      .split(whereSeparator: \.isNewline)
      .map(String.init)
    guard remotes.contains("origin") else {
      throw BranchSyncServiceError.missingOrigin(projectPath)
    }

    _ = try runChecked(
      "git fetch origin \(shellEscaped("+refs/heads/\(branch):refs/remotes/origin/\(branch)"))",
      at: projectPath,
      timeout: 180
    )

    let remoteConfigPath = "refs/remotes/origin/\(branch):fastlane/repos.yml"
    let configContent: String
    do {
      configContent = try processRunner.run("git show \(shellEscaped(remoteConfigPath))", at: projectPath)
    } catch {
      throw BranchSyncServiceError.missingRemoteConfig("origin/\(branch)")
    }
    return try reposService.parseConfig(from: configContent)
  }

  private func currentBranch(at path: String) throws -> String {
    try processRunner.run("git rev-parse --abbrev-ref HEAD", at: path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func getRemoteBranches(at path: String) throws -> [String] {
    let remotes = try processRunner.run("git remote", at: path)
      .split(whereSeparator: \.isNewline)
      .map(String.init)
    guard remotes.contains("origin") else {
      throw BranchSyncServiceError.missingOrigin(path)
    }

    let output = try processRunner.run("git ls-remote --heads origin", at: path, timeout: 90)
    return output.split(whereSeparator: \.isNewline).compactMap { line in
      guard let reference = line.split(whereSeparator: \.isWhitespace).last else { return nil }
      let prefix = "refs/heads/"
      guard reference.hasPrefix(prefix) else { return nil }
      return String(reference.dropFirst(prefix.count))
    }
    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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

  private func restoreTargetReposConfig(at path: String) throws {
    if commandSucceeded("git cat-file -e HEAD:fastlane/repos.yml", at: path) {
      _ = try runChecked(
        "git restore --source=HEAD --staged --worktree -- fastlane/repos.yml",
        at: path
      )
    } else {
      _ = try runChecked(
        "git rm --force --ignore-unmatch -- fastlane/repos.yml",
        at: path
      )
    }
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
