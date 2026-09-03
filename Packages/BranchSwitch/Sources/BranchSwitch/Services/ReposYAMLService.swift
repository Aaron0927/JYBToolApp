//
//  ReposYAMLService.swift
//  BranchSwitch
//

import Foundation

public enum ReposYAMLServiceError: Error, LocalizedError, Sendable {
  case configNotFound(String)
  case invalidYAML(line: Int, message: String)
  case missingField(line: Int, field: String)
  case emptyRepos
  case notGitRepository(String)

  public var errorDescription: String? {
    switch self {
    case .configNotFound(let path):
      return "未找到配置文件: \(path)"
    case .invalidYAML(let line, let message):
      return "repos.yml 第 \(line) 行格式错误: \(message)"
    case .missingField(let line, let field):
      return "repos.yml 第 \(line) 行仓库缺少字段: \(field)"
    case .emptyRepos:
      return "repos.yml 未声明任何仓库"
    case .notGitRepository(let path):
      return "路径已存在但不是 Git 仓库: \(path)"
    }
  }
}

public struct RepoSwitchResult: Sendable {
  public let name: String
  public let success: Bool
  public let error: String?

  public init(name: String, success: Bool, error: String? = nil) {
    self.name = name
    self.success = success
    self.error = error
  }
}

public enum RepoPullStatus: Equatable, Sendable {
  case success
  case skipped
  case failed
}

public struct RepoPullResult: Sendable {
  public let name: String
  public let path: String
  public let status: RepoPullStatus
  public let hadAutoStash: Bool
  public let message: String?

  public init(
    name: String,
    path: String,
    status: RepoPullStatus,
    hadAutoStash: Bool = false,
    message: String? = nil
  ) {
    self.name = name
    self.path = path
    self.status = status
    self.hadAutoStash = hadAutoStash
    self.message = message
  }
}

public final class ReposYAMLService: Sendable {
  private let processRunner: ProcessRunner

  public init(processRunner: ProcessRunner = ProcessRunner()) {
    self.processRunner = processRunner
  }

  public func configURL(forProjectPath projectPath: String) -> URL {
    URL(fileURLWithPath: projectPath, isDirectory: true)
      .appending(path: "fastlane")
      .appending(path: "repos.yml")
  }

  public func loadConfig(atProjectPath projectPath: String) throws -> ReposConfig {
    let configURL = configURL(forProjectPath: projectPath)
    guard FileManager.default.fileExists(atPath: configURL.path) else {
      throw ReposYAMLServiceError.configNotFound(configURL.path)
    }

    let content = try String(contentsOf: configURL, encoding: .utf8)
    return try parseConfig(from: content)
  }

  public func parseConfig(from content: String) throws -> ReposConfig {
    var root: String?
    var repos: [DeclaredRepo] = []
    var currentRepo: [String: String] = [:]
    var currentRepoLine = 0
    var isReadingRepos = false
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

    func finishCurrentRepo() throws {
      guard !currentRepo.isEmpty else { return }
      guard let name = currentRepo["name"], !name.isEmpty else {
        throw ReposYAMLServiceError.missingField(line: currentRepoLine, field: "name")
      }
      guard let url = currentRepo["url"], !url.isEmpty else {
        throw ReposYAMLServiceError.missingField(line: currentRepoLine, field: "url")
      }
      guard let path = currentRepo["path"], !path.isEmpty else {
        throw ReposYAMLServiceError.missingField(line: currentRepoLine, field: "path")
      }
      guard let branch = currentRepo["branch"], !branch.isEmpty else {
        throw ReposYAMLServiceError.missingField(line: currentRepoLine, field: "branch")
      }

      repos.append(DeclaredRepo(name: name, url: url, path: path, branch: branch))
      currentRepo = [:]
    }

    for (index, rawLine) in lines.enumerated() {
      let lineNumber = index + 1
      let cleanedLine = stripComment(from: String(rawLine))
      let trimmed = cleanedLine.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      if trimmed == "repos:" {
        isReadingRepos = true
        continue
      }

      if !isReadingRepos {
        if let pair = try parseKeyValue(from: trimmed, line: lineNumber), pair.key == "root" {
          root = pair.value
        }
        continue
      }

      if trimmed.hasPrefix("-") {
        try finishCurrentRepo()
        currentRepoLine = lineNumber
        let rest = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty {
          let pair = try parseRequiredKeyValue(from: rest, line: lineNumber)
          currentRepo[pair.key] = pair.value
        }
      } else {
        guard !currentRepo.isEmpty else {
          throw ReposYAMLServiceError.invalidYAML(line: lineNumber, message: "仓库字段必须写在列表项下面")
        }
        let pair = try parseRequiredKeyValue(from: trimmed, line: lineNumber)
        currentRepo[pair.key] = pair.value
      }
    }

    try finishCurrentRepo()

    guard let root, !root.isEmpty else {
      throw ReposYAMLServiceError.missingField(line: 1, field: "root")
    }
    guard !repos.isEmpty else {
      throw ReposYAMLServiceError.emptyRepos
    }

    return ReposConfig(root: root, repos: repos)
  }

  public func rootURL(for config: ReposConfig, configURL: URL) -> URL {
    if config.root.hasPrefix("/") {
      return URL(fileURLWithPath: config.root, isDirectory: true).standardizedFileURL
    }

    return configURL
      .deletingLastPathComponent()
      .appending(path: config.root)
      .standardizedFileURL
  }

  public func repoURL(for repo: DeclaredRepo, rootURL: URL) -> URL {
    if repo.path.hasPrefix("/") {
      return URL(fileURLWithPath: repo.path, isDirectory: true).standardizedFileURL
    }

    return rootURL.appending(path: repo.path).standardizedFileURL
  }

  public func loadRepoInfos(atProjectPath projectPath: String) throws -> (config: ReposConfig, rootPath: String, infos: [RepoSwitchInfo]) {
    let configURL = configURL(forProjectPath: projectPath)
    let config = try loadConfig(atProjectPath: projectPath)
    let rootURL = rootURL(for: config, configURL: configURL)
    let infos = config.repos.map { repo in
      let repoURL = repoURL(for: repo, rootURL: rootURL)
      let isCloned = isGitRepository(at: repoURL.path)
      return RepoSwitchInfo(
        name: repo.name,
        path: repo.path,
        absolutePath: repoURL.path,
        currentBranch: isCloned ? (getCurrentBranch(at: repoURL.path) ?? "unknown") : "未克隆",
        targetBranch: repo.branch,
        isCloned: isCloned
      )
    }

    return (config, rootURL.path, infos)
  }

  public func pullAllRepositories(
    atProjectPath projectPath: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws -> [RepoPullResult] {
    let configURL = configURL(forProjectPath: projectPath)
    let initialConfig = try loadConfig(atProjectPath: projectPath)
    let initialRootURL = rootURL(for: initialConfig, configURL: configURL)
    var results: [RepoPullResult] = []

    results.append(pullRepository(
      name: initialRootURL.lastPathComponent,
      path: initialRootURL.path,
      logger: logger
    ))

    let updatedConfig = try loadConfig(atProjectPath: projectPath)
    let updatedRootURL = rootURL(for: updatedConfig, configURL: configURL)
    for repo in updatedConfig.repos {
      let repoURL = repoURL(for: repo, rootURL: updatedRootURL)
      results.append(pullRepository(name: repo.name, path: repoURL.path, logger: logger))
    }

    return results
  }

  public func makeWorkspaceRepoInfo(rootPath: String, targetBranch: String) -> RepoSwitchInfo {
    let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
    let isRepo = isGitRepository(at: rootURL.path)
    return RepoSwitchInfo(
      name: rootURL.lastPathComponent,
      path: ".",
      absolutePath: rootURL.path,
      currentBranch: isRepo ? (getCurrentBranch(at: rootURL.path) ?? "unknown") : "非 Git 仓库",
      targetBranch: targetBranch,
      isCloned: isRepo,
      scope: .workspace
    )
  }

  public func parseLocalBranches(from output: String) -> [String] {
    output
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  public func getLocalBranches(at path: String) throws -> [String] {
    let output = try processRunner.run("git branch --format='%(refname:short)'", at: path)
    return parseLocalBranches(from: output)
  }

  public func checkoutLocalBranch(
    _ branch: String,
    at path: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    let hadChanges = hasTrackedChanges(at: path)
    if hadChanges {
      logger("主工程检测到未提交更改，自动暂存")
      try stash(at: path)
    }

    do {
      logger("切换主工程本地分支: \(branch)")
      _ = try processRunner.run("git checkout \(shellEscaped(branch))", at: path)
    } catch {
      if hadChanges {
        logger("主工程切换失败，尝试恢复暂存")
        try? stashPop(at: path)
      }
      throw error
    }

    if hadChanges {
      logger("恢复主工程暂存")
      try stashPop(at: path)
    }
  }

  public func updateRepo(
    _ repo: DeclaredRepo,
    rootURL: URL,
    logger: @escaping @Sendable (String) -> Void
  ) -> RepoSwitchResult {
    do {
      let repoURL = repoURL(for: repo, rootURL: rootURL)
      logger("开始处理 \(repo.name)")
      try ensureRepoExists(repo, at: repoURL, logger: logger)

      guard isGitRepository(at: repoURL.path) else {
        throw ReposYAMLServiceError.notGitRepository(repoURL.path)
      }

      try updateGitRepository(name: repo.name, path: repoURL.path, branch: repo.branch, logger: logger)
      logger("\(repo.name) 完成")
      return RepoSwitchResult(name: repo.name, success: true)
    } catch {
      return RepoSwitchResult(name: repo.name, success: false, error: error.localizedDescription)
    }
  }

  public func updateExistingRepo(
    name: String,
    path: String,
    branch: String,
    logger: @escaping @Sendable (String) -> Void
  ) -> RepoSwitchResult {
    do {
      logger("开始处理 \(name)")
      guard isGitRepository(at: path) else {
        throw ReposYAMLServiceError.notGitRepository(path)
      }

      try updateGitRepository(name: name, path: path, branch: branch, logger: logger)
      logger("\(name) 完成")
      return RepoSwitchResult(name: name, success: true)
    } catch {
      return RepoSwitchResult(name: name, success: false, error: error.localizedDescription)
    }
  }

  public func getCurrentBranch(at path: String) -> String? {
    do {
      let output = try processRunner.run("git rev-parse --abbrev-ref HEAD", at: path)
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }

  private func pullRepository(
    name: String,
    path: String,
    logger: @escaping @Sendable (String) -> Void
  ) -> RepoPullResult {
    guard isGitRepository(at: path) else {
      return RepoPullResult(
        name: name,
        path: path,
        status: .skipped,
        message: "本地仓库不存在或不是 Git 仓库"
      )
    }

    do {
      let branch = try currentBranchForPull(at: path)
      guard !branch.isEmpty else {
        return RepoPullResult(name: name, path: path, status: .skipped, message: "仓库处于 detached HEAD 状态")
      }

      guard let upstream = upstreamBranch(at: path), !upstream.isEmpty else {
        return RepoPullResult(name: name, path: path, status: .skipped, message: "当前分支未配置 upstream")
      }

      guard remoteBranchExists(upstream: upstream, at: path) else {
        return RepoPullResult(name: name, path: path, status: .skipped, message: "远程对应分支不存在")
      }

      logger("开始拉取 \(name) 的 \(branch)")
      let stashReference = try createAutoStashIfNeeded(name: name, at: path, logger: logger)
      var failureMessages: [String] = []

      do {
        _ = try processRunner.run("git pull --ff-only", at: path, timeout: 180)
        logger("\(name) 拉取完成")
      } catch {
        failureMessages.append("拉取失败: \(error.localizedDescription)")
      }

      if let stashReference {
        do {
          try restoreAutoStash(stashReference, name: name, at: path, logger: logger)
        } catch {
          failureMessages.append("恢复暂存失败，已保留 \(stashReference): \(error.localizedDescription)")
        }
      }

      if failureMessages.isEmpty {
        return RepoPullResult(name: name, path: path, status: .success, hadAutoStash: stashReference != nil)
      }

      return RepoPullResult(
        name: name,
        path: path,
        status: .failed,
        hadAutoStash: stashReference != nil,
        message: failureMessages.joined(separator: "；")
      )
    } catch {
      return RepoPullResult(name: name, path: path, status: .failed, message: error.localizedDescription)
    }
  }

  private func currentBranchForPull(at path: String) throws -> String {
    try processRunner.run("git branch --show-current", at: path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func upstreamBranch(at path: String) -> String? {
    (try? processRunner.run("git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'", at: path))?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func remoteBranchExists(upstream: String, at path: String) -> Bool {
    let parts = upstream.split(separator: "/", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return false }

    let output = try? processRunner.run(
      "git ls-remote --heads \(shellEscaped(parts[0])) \(shellEscaped(parts[1]))",
      at: path,
      timeout: 60
    )
    return !(output?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
  }

  private func createAutoStashIfNeeded(
    name: String,
    at path: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws -> String? {
    let status = try processRunner.run("git status --porcelain", at: path)
    guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }

    let previousReference = stashReference(at: path)
    logger("\(name) 检测到未提交改动，自动暂存")
    _ = try processRunner.run(
      "git stash push --include-untracked -m 'JYBToolApp: auto-stash before pull'",
      at: path
    )

    guard let newReference = stashReference(at: path), newReference != previousReference else {
      throw ProcessRunnerError.executionFailed("自动暂存未生成新的 stash")
    }
    return newReference
  }

  private func restoreAutoStash(
    _ reference: String,
    name: String,
    at path: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    logger("恢复 \(name) 的自动暂存")
    _ = try processRunner.run("git stash apply \(shellEscaped(reference))", at: path)
    guard let stashEntry = stashEntry(for: reference, at: path) else {
      throw ProcessRunnerError.executionFailed("未找到需要删除的自动暂存: \(reference)")
    }
    _ = try processRunner.run("git stash drop \(shellEscaped(stashEntry))", at: path)
  }

  private func stashReference(at path: String) -> String? {
    let output = try? processRunner.run("git rev-parse --verify refs/stash", at: path)
    let reference = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return reference.isEmpty ? nil : reference
  }

  private func stashEntry(for reference: String, at path: String) -> String? {
    guard let output = try? processRunner.run("git stash list --format='%H %gd'", at: path) else {
      return nil
    }

    for line in output.split(separator: "\n") {
      let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
      if parts.count == 2, parts[0] == reference {
        return parts[1]
      }
    }
    return nil
  }

  private func ensureRepoExists(
    _ repo: DeclaredRepo,
    at repoURL: URL,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: repoURL.path) {
      return
    }

    let parentURL = repoURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
    logger("\(repo.name) 本地不存在，开始克隆")
    _ = try processRunner.run(
      "git clone \(shellEscaped(repo.url)) \(shellEscaped(repoURL.lastPathComponent))",
      at: parentURL.path,
      timeout: 300
    )
  }

  public func isGitRepository(at path: String) -> Bool {
    let gitPath = URL(fileURLWithPath: path, isDirectory: true).appending(path: ".git").path
    if FileManager.default.fileExists(atPath: gitPath) {
      return true
    }

    return (try? processRunner.run("git rev-parse --is-inside-work-tree", at: path))?
      .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
  }

  private func hasTrackedChanges(at path: String) -> Bool {
    do {
      let output = try processRunner.run("git status --porcelain", at: path)
      return output.split(separator: "\n").contains { !$0.hasPrefix("??") }
    } catch {
      return false
    }
  }

  private func updateGitRepository(
    name: String,
    path: String,
    branch: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    let hadChanges = hasTrackedChanges(at: path)
    if hadChanges {
      logger("\(name) 检测到未提交更改，自动暂存")
      try stash(at: path)
    }

    do {
      try checkout(branch, at: path, logger: logger)
      try pull(branch, at: path, logger: logger)
    } catch {
      if hadChanges {
        logger("\(name) 切换失败，尝试恢复暂存")
        try? stashPop(at: path)
      }
      throw error
    }

    if hadChanges {
      logger("\(name) 恢复暂存")
      try stashPop(at: path)
    }
  }

  private func stash(at path: String) throws {
    _ = try processRunner.run("git stash push -m 'ReposSwitch: auto-stash'", at: path)
  }

  private func stashPop(at path: String) throws {
    _ = try processRunner.run("git stash pop", at: path)
  }

  private func checkout(
    _ branch: String,
    at path: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    let escapedBranch = shellEscaped(branch)
    let localBranchOutput = (try? processRunner.run("git branch --list \(escapedBranch)", at: path)) ?? ""
    let hasLocalBranch = !localBranchOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let remoteBranchOutput = (try? processRunner.run("git ls-remote --heads origin \(escapedBranch)", at: path)) ?? ""
    let hasRemoteBranch = !remoteBranchOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    if hasRemoteBranch {
      logger("拉取 origin 分支信息: \(branch)")
      _ = try? processRunner.run("git fetch origin", at: path, timeout: 180)
    }

    if hasLocalBranch {
      logger("切换本地分支: \(branch)")
      _ = try processRunner.run("git checkout \(escapedBranch)", at: path)
      return
    }

    if hasRemoteBranch {
      logger("创建本地分支并跟踪 origin/\(branch)")
      _ = try processRunner.run("git checkout -b \(escapedBranch) \(shellEscaped("origin/\(branch)"))", at: path)
      return
    }

    logger("远程分支不存在，创建本地分支: \(branch)")
    _ = try processRunner.run("git checkout -b \(escapedBranch)", at: path)
  }

  private func pull(
    _ branch: String,
    at path: String,
    logger: @escaping @Sendable (String) -> Void
  ) throws {
    let escapedBranch = shellEscaped(branch)
    let remoteBranchOutput = (try? processRunner.run("git ls-remote --heads origin \(escapedBranch)", at: path)) ?? ""
    guard !remoteBranchOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      logger("远程分支不存在，跳过 pull: \(branch)")
      return
    }

    logger("拉取远程分支: \(branch)")
    _ = try processRunner.run("git pull origin \(escapedBranch)", at: path, timeout: 180)
  }

  private func parseKeyValue(from line: String, line lineNumber: Int) throws -> (key: String, value: String)? {
    guard line.contains(":") else { return nil }
    return try parseRequiredKeyValue(from: line, line: lineNumber)
  }

  private func parseRequiredKeyValue(from line: String, line lineNumber: Int) throws -> (key: String, value: String) {
    guard let colonIndex = line.firstIndex(of: ":") else {
      throw ReposYAMLServiceError.invalidYAML(line: lineNumber, message: "缺少冒号")
    }

    let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
    let rawValue = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else {
      throw ReposYAMLServiceError.invalidYAML(line: lineNumber, message: "字段名为空")
    }

    return (key, unquote(rawValue))
  }

  private func stripComment(from line: String) -> String {
    var result = ""
    var isReadingSingleQuote = false
    var isReadingDoubleQuote = false

    for character in line {
      if character == "'", !isReadingDoubleQuote {
        isReadingSingleQuote.toggle()
      } else if character == "\"", !isReadingSingleQuote {
        isReadingDoubleQuote.toggle()
      } else if character == "#", !isReadingSingleQuote, !isReadingDoubleQuote {
        break
      }

      result.append(character)
    }

    return result
  }

  private func unquote(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2,
          let first = trimmed.first,
          let last = trimmed.last,
          (first == "\"" && last == "\"") || (first == "'" && last == "'") else {
      return trimmed
    }

    return String(trimmed.dropFirst().dropLast())
  }

  private func shellEscaped(_ value: String) -> String {
    let parts = value.split(separator: "'", omittingEmptySubsequences: false)
    return "'" + parts.joined(separator: "'\\''") + "'"
  }
}
