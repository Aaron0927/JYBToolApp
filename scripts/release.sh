#!/bin/bash
# 用法: ./scripts/release.sh 1.2.3
set -e

VERSION=$1
PROJECT="JYBToolApp.xcodeproj/project.pbxproj"

# ── 参数校验 ──────────────────────────────────────────────────────────────────
if [ -z "$VERSION" ]; then
    echo "用法: $0 <版本号>   例: $0 1.2.3"
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误: 版本号格式应为 x.y.z（如 1.2.3）"
    exit 1
fi

TAG="v$VERSION"
BUILD=$(date +%Y%m%d)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 版本: $VERSION"
echo " Build: $BUILD"
echo " Tag:   $TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 检查工作区是否干净（version bump 以外） ───────────────────────────────────
UNSTAGED=$(git status --porcelain | grep -v "$PROJECT" || true)
if [ -n "$UNSTAGED" ]; then
    echo ""
    echo "警告: 存在未提交的改动:"
    echo "$UNSTAGED"
    echo ""
    read -r -p "继续发版? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
fi

# ── 1. 更新 Xcode 版本号 ──────────────────────────────────────────────────────
echo ""
echo "▸ [1/5] 更新版本号..."
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" "$PROJECT"
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PROJECT"

# 校验更新结果
COUNT=$(grep -c "MARKETING_VERSION = $VERSION;" "$PROJECT" || true)
if [ "$COUNT" -eq 0 ]; then
    echo "错误: 版本号写入失败，请检查 $PROJECT"
    exit 1
fi
echo "  MARKETING_VERSION  → $VERSION"
echo "  CURRENT_PROJECT_VERSION → $BUILD"

# ── 2. 提交 ──────────────────────────────────────────────────────────────────
echo ""
echo "▸ [2/5] 提交版本变更..."
git add "$PROJECT"
git commit -m "feat: 版本更新至 $VERSION"

# ── 3. 同步远程（处理远程有新提交的情况） ─────────────────────────────────────
echo ""
echo "▸ [3/5] 同步远程..."
# 暂存任何残留的未暂存改动（如 build 产物删除标记）
STASHED=false
if ! git diff --quiet; then
    git stash push -m "release-script: temp stash"
    STASHED=true
fi

git pull --rebase origin main

if [ "$STASHED" = true ]; then
    git stash pop || true
fi

# ── 4. 推送 main ──────────────────────────────────────────────────────────────
echo ""
echo "▸ [4/5] 推送 main..."
git push origin main

# ── 5. 打 Tag 并推送（触发 GitHub Actions） ───────────────────────────────────
echo ""
echo "▸ [5/5] 创建并推送 Tag $TAG..."
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "  Tag $TAG 已存在，删除后重建"
    git tag -d "$TAG"
    git push origin ":refs/tags/$TAG"
fi
git tag "$TAG"
git push origin "$TAG"

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ 发版完成！GitHub Actions 已触发"
echo "  查看进度: https://github.com/Aaron0927/JYBToolApp/actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
