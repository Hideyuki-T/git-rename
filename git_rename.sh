#!/usr/bin/env bash
set -euo pipefail

# git_rename.sh - Git リモート URL の一括リネームスクリプト
# Usage: git_rename.sh [--dry-run] <old> <new> [base_dir]
#   --dry-run  : 実際には変更せず、動作確認のみ実施
#   <old>      : 置換前文字列
#   <new>      : 置換後文字列
#   [base_dir] : 対象ディレクトリ（省略時はスクリプト配置ディレクトリの親）

# オプション解析
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

# 引数チェック
if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $(basename "$0") [--dry-run] <old> <new> [base_dir]" >&2
  exit 1
fi

OLD="$1"
NEW="$2"

# ベースディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BASE_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="${3:-$DEFAULT_BASE_DIR}"

# モード表示
MODE_LABEL=""
if [[ "$DRY_RUN" == true ]]; then
  MODE_LABEL=" (dry-run mode)"
fi

echo "[INFO] Starting git_rename: '$OLD' -> '$NEW' in '$BASE_DIR'$MODE_LABEL"

# カウンタ初期化
total_updated=0
total_skipped=0

echo "[DEBUG] Searching .git directories..."
# 一括検出 & 置換処理（プロセス置換で subshell を防止）
while IFS= read -r -d '' git_dir; do
  repo_dir="$(dirname "$git_dir")"
  repo_name="$(basename "$repo_dir")"

  # リモートURL取得
  current_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")"
  new_url="${current_url//$OLD/$NEW}"

  if [[ -z "$current_url" ]]; then
    echo "[SKIPPED] $repo_name (no origin remote)"
    ((total_skipped++))
  elif [[ "$current_url" != "$new_url" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] $repo_name would be updated"
      echo "  Before: $current_url"
      echo "  After : $new_url"
    else
      git -C "$repo_dir" remote set-url origin "$new_url"
      echo "[UPDATED] $repo_name"
      echo "  Before: $current_url"
      echo "  After : $new_url"
    fi
    ((total_updated++))
  else
    echo "[SKIPPED] $repo_name (already updated)"
    ((total_skipped++))
  fi

done < <(find "$BASE_DIR" -type d -name .git -print0)

# サマリ出力
echo -e "\n[SUMMARY]"
echo "  Total checked : $((total_updated + total_skipped))"
echo "  Total updated : $total_updated"
echo "  Total skipped : $total_skipped"

# 検出したリポジトリの現在のリモート URL 一覧表示
echo -e "\n[REPOSITORY URL LIST]"
while IFS= read -r -d '' git_dir; do
  repo_dir="$(dirname "$git_dir")"
  repo_name="$(basename "$repo_dir")"
  current_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "<no remote>")"
  echo "  $repo_name: $current_url"
done < <(find "$BASE_DIR" -type d -name .git -print0)

echo "Completed git_rename.sh."
