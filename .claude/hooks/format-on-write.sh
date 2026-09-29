#!/usr/bin/env bash
# PostToolUse (Write): pasa Prettier y ESLint --fix por el archivo recién creado.
f=$(jq -r '.tool_response.filePath // .tool_input.file_path')
[ -f "$f" ] || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
case "$f" in "$CLAUDE_PROJECT_DIR"/*) ;; *) exit 0 ;; esac
case "$f" in */node_modules/*|*/.next/*|*/.git/*) exit 0 ;; esac

npx --no-install prettier --write --ignore-unknown "$f" >/dev/null 2>&1

case "$f" in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs)
    out=$(npx --no-install eslint --fix "$f" 2>&1) || {
      printf '%s\n' "$out" >&2
      exit 2
    }
    ;;
esac
exit 0
