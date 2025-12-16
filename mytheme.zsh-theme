# ~/.oh-my-zsh/custom/themes/window-term.zsh-theme

setopt prompt_subst

# ─────────────────────────────────────
# 시간 (01-02 15:04:05)  - 
# ─────────────────────────────────────
function _wt_time_segment() {
  local now
  now=$(date +'%m-%d %H:%M:%S')
  print -r -- "%F{#7E8BA3}%f %F{#FFFFFF}${now}%f"
}

# ─────────────────────────────────────
# 메모리 사용률 -   대략적인 사용률(%)
# Linux: free, macOS: memory_pressure → vm_stat 순
# ─────────────────────────────────────
function _wt_mem_segment() {
  local percent="?"

  if command -v free >/dev/null 2>&1; then
    # Linux
    local used total
    read used total <<<"$(free -m | awk '/Mem:/ {print $3, $2}')"
    if [[ -n "$total" && "$total" -gt 0 ]]; then
      percent=$(( used * 100 / total ))
    fi

  elif command -v memory_pressure >/dev/null 2>&1; then
    # macOS: 가장 안정적인 방법 - free percentage 사용
    # 예: "System-wide memory free percentage: 21%"
    local free_pct
    free_pct=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ {gsub("%","",$2); print $2}')
    if [[ -n "$free_pct" ]]; then
      percent=$(( 100 - free_pct ))
    fi

  elif [[ "$OSTYPE" == darwin* ]] && command -v vm_stat >/dev/null 2>&1; then
    # 예전 macOS 버전용 fallback (대략적인 계산)
    local free active inactive speculative wired compressed
    free=$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')
    active=$(vm_stat | awk '/Pages active/ {gsub("\\.","",$3); print $3}')
    inactive=$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')
    speculative=$(vm_stat | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')
    wired=$(vm_stat | awk '/Pages wired/ {gsub("\\.","",$4); print $4}')
    compressed=$(vm_stat | awk '/Pages occupied by compressor/ {gsub("\\.","",$5); print $5}')

    local used_pages=$(( active + inactive + speculative + wired + compressed ))
    local total_pages=$(( used_pages + free ))
    if [[ "$total_pages" -gt 0 ]]; then
      percent=$(( used_pages * 100 / total_pages ))
    fi
  fi

  print -r -- "%F{#FF9E64}%f %F{#FFFFFF}${percent}%%%f"
}

# ─────────────────────────────────────
# TAG -   {{ .Env.OMZ_TAG }}
# ─────────────────────────────────────
function _wt_tag_segment() {
  [[ -z "$OMZ_TAG" ]] && return
  print -r -- "%F{#17d7a0}%f %F{#FFFFFF}${OMZ_TAG}%f"
}

# ─────────────────────────────────────
# 배터리 (첫 줄 메모리 옆)
# macOS: pmset, Linux: acpi
# ─────────────────────────────────────
function _wt_battery_segment() {
  local p icon

  if command -v pmset >/dev/null 2>&1; then
    # macOS:
    #   Now drawing from 'Battery Power'
    #    -InternalBattery-0  79%; discharging; ...
    p=$(pmset -g batt 2>/dev/null | awk 'NR==2 {gsub("%","",$3); gsub(";","",$3); print $3}')
  elif command -v acpi >/dev/null 2>&1; then
    # Linux: "Battery 0: Discharging, 79%, 02:12:34 remaining"
    p=$(acpi -b 2>/dev/null | awk -F', ' 'NR==1 {gsub("%","",$2); print $2}')
  else
    return
  fi

  [[ -z "$p" ]] && return

  if (( p >= 80 )); then
    icon=""
  elif (( p >= 60 )); then
    icon=""
  elif (( p >= 40 )); then
    icon=""
  elif (( p >= 20 )); then
    icon=""
  else
    icon=""
  fi

  print -r -- "%F{#9AFF87}${icon}%f %F{#FFFFFF}${p}%%%f"
}

# ─────────────────────────────────────
# 경로 -  [ {{ .Path }} ]  (마지막 세그먼트만 #4CC9F0)
# ─────────────────────────────────────
function _wt_path_segment() {
  local p="$PWD"
  p=${p/#$HOME/~}

  local raw="$p"
  local formatted

  if [[ "$raw" == "/" || "$raw" == "~" ]]; then
    formatted="%F{#FFFFFF}${raw}%f"
  else
    local base="${raw%/*}"
    local leaf="${raw##*/}"

    if [[ -z "$base" || "$base" == "$raw" ]]; then
      formatted="%F{#FFFFFF}${raw}%f"
    else
      formatted="%F{#FFFFFF}${base}/%f%F{#4CC9F0}${leaf}%f"
    fi
  fi

  print -r -- " %F{#0092FF}%f  %F{#3A86FF}[%f ${formatted} %F{#3A86FF}]%f  "
}

# ─────────────────────────────────────
# git 상태 표시 (브랜치 + A/M/D/U 갯수 + stash)
# ─────────────────────────────────────
function _wt_git_segment() {
  git rev-parse --is-inside-work-tree &>/dev/null || return

  local head
  head=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

  local porcelain line
  local added=0 modified=0 deleted=0 untracked=0

  porcelain=$(git status --porcelain 2>/dev/null)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == \?\?* ]]; then
      ((untracked++))
      continue
    fi
    local x=${line:0:1}
    local y=${line:1:1}
    [[ "$x" == "A" || "$y" == "A" ]] && ((added++))
    [[ "$x" == "M" || "$y" == "M" ]] && ((modified++))
    [[ "$x" == "D" || "$y" == "D" ]] && ((deleted++))
  done <<< "$porcelain"

  local stash_count
  stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  [[ "$stash_count" == "0" ]] && stash_count=""

  local branch_status=""
  local ab_line
  ab_line=$(git status --porcelain=2 --branch 2>/dev/null | awk '/^# branch.ab/ {print $0}')
  if [[ -n "$ab_line" ]]; then
    local ahead behind
    ahead=$(awk '{for(i=1;i<=NF;i++) if($i ~ /\+/){gsub("\\+","",$i); print $i}}' <<< "$ab_line")
    behind=$(awk '{for(i=1;i<=NF;i++) if($i ~ /-/){gsub("-","",$i); print $i}}' <<< "$ab_line")
    if [[ -n "$ahead" && "$ahead" != "0" ]]; then
      branch_status+="↑${ahead}"
    fi
    if [[ -n "$behind" && "$behind" != "0" ]]; then
      [[ -n "$branch_status" ]] && branch_status+=" "
      branch_status+="↓${behind}"
    fi
  fi

  local changes=""
  [[ -n "$branch_status" ]] && changes+="${branch_status} "

  (( added > 0 ))    && changes+="%F{#9AFF87} ${added}%f "
  (( modified > 0 )) && changes+="%F{#FF6B6B} ${modified}%f "
  (( deleted > 0 ))  && changes+="%F{#FF2740} ${deleted}%f "
  (( untracked > 0 ))&& changes+="%F{#7E8BA3} ${untracked}%f "

  if [[ -n "$stash_count" ]]; then
    changes+="stash: ${stash_count} "
  fi

  local seg=" on %F{#1A921C}%f %F{#FFFFFF}${head}%f"
  if [[ -n "$changes" ]]; then
    seg+=" %F{#FFFFFF}(%f ${changes}%F{#FFFFFF})%f"
  fi

  print -r -- "${seg}"
}

# ─────────────────────────────────────
# 마지막 줄 - 애플 아이콘 () + | +  zsh
# ─────────────────────────────────────
function _wt_footer_segment() {
  local apple="%F{#FFFFFF}%f"
  local bar="%F{#444444}|%f"
  local shell_seg="%F{#2EC4B6}%f %F{#FFFFFF}zsh%f"
  print -r -- " ${apple}  ${bar}  ${shell_seg} "
}

# ─────────────────────────────────────
# 프롬프트 조립
# 1줄: 시간 | 메모리 | 배터리 | TAG(OMZ_TAG)
# 2줄: 경로 + git
# 3줄: 애플 아이콘 | zsh
# ─────────────────────────────────────
function _wt_build_prompt() {
  local sep="%F{#444444}|%f"

  local time_seg mem_seg batt_seg tag_seg
  time_seg="$(_wt_time_segment)"
  mem_seg="$(_wt_mem_segment)"
  batt_seg="$(_wt_battery_segment)"
  tag_seg="$(_wt_tag_segment)"

  local line1=" ${time_seg}  ${sep}  ${mem_seg}"
  if [[ -n "$batt_seg" ]]; then
    line1+="  ${sep}  ${batt_seg}"
  fi
  if [[ -n "$tag_seg" ]]; then
    line1+="  ${sep}  ${tag_seg}"
  fi

  local path_seg git_seg
  path_seg="$(_wt_path_segment)"
  git_seg="$(_wt_git_segment)"

  local line2="${path_seg}${git_seg}"
  local line3
  line3="$(_wt_footer_segment)"

  PROMPT=$'\n'"${line1}
${line2}
${line3}%f "

  RPROMPT=""
}

function _wt_precmd() {
  _wt_build_prompt
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _wt_precmd

