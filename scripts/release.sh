#!/bin/bash
# 用法:
#   ./scripts/release.sh 1.2.4
#   ./scripts/release.sh --yes        # 自动基于最新 tag 递增 patch
#   ./scripts/release.sh 1.2.4 --yes  # 非交互确认
set -e

PROJECT="JYBToolApp.xcodeproj/project.pbxproj"
ASSUME_YES=false
VERSION=""

for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION=$arg
            else
                echo "错误: 未识别参数 $arg"
                exit 1
            fi
            ;;
    esac
done

next_patch_version() {
    local latest_tag
    latest_tag=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)
    if [ -z "$latest_tag" ]; then
        echo "1.0.0"
        return
    fi

    local latest="${latest_tag#v}"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$latest"
    echo "$major.$minor.$((patch + 1))"
}

# ── 参数校验 ──────────────────────────────────────────────────────────────────
if [ -z "$VERSION" ]; then
    VERSION=$(next_patch_version)
    echo "未指定版本号，自动使用下一个 patch 版本: $VERSION"
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误: 版本号格式应为 x.y.z（如 1.2.3）"
    exit 1
fi

TAG="v$VERSION"
BUILD=$(date +%Y%m%d)
CURRENT_BUILD=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9][0-9]*\);.*/\1/p' "$PROJECT" | head -1)
if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] && [ "$BUILD" -le "$CURRENT_BUILD" ]; then
    BUILD=$((CURRENT_BUILD + 1))
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 版本: $VERSION"
echo " Build: $BUILD"
echo " Tag:   $TAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 仅从干净且与远程同步的 main 发版 ───────────────────────────────────────────
if [ "$(git branch --show-current)" != "main" ]; then
    echo "错误: 请在 main 分支发版"
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "错误: 工作区存在未提交的改动"
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null ||
    git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "错误: Tag $TAG 已存在"
    exit 1
fi

# ── 1. 同步远程（确保基于最新 main 发版） ─────────────────────────────────────
echo ""
echo "▸ [1/5] 同步远程..."
git pull --ff-only origin main

# ── 2. 更新 Xcode 版本号 ──────────────────────────────────────────────────────
echo ""
echo "▸ [2/5] 更新版本号..."
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

# ── 3. 提交 ──────────────────────────────────────────────────────────────────
echo ""
echo "▸ [3/5] 提交版本变更..."
git add "$PROJECT"
git commit -m "feat: 版本更新至 $VERSION"

# ── 4. 推送 main ──────────────────────────────────────────────────────────────
echo ""
echo "▸ [4/5] 推送 main..."
git push origin main

# ── 5. 打 Tag 并推送（触发 GitHub Actions） ───────────────────────────────────
echo ""
echo "▸ [5/5] 创建并推送 Tag $TAG..."
git tag "$TAG"
git push origin "$TAG"

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ 发版完成！GitHub Actions 已触发"
echo "  查看进度: https://github.com/Aaron0927/JYBToolApp/actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
