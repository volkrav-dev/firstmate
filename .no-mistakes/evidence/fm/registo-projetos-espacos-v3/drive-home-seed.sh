#!/usr/bin/env bash
# Drives bin/fm-home-seed.sh in disposable lab homes for a project named "foo bar",
# at a given firstmate root (base or target commit).
# Usage: drive-home-seed.sh <label> <firstmate-root> <lab-helper-root>
set -u
label=$1 root=$2 helper=$3
unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$helper/bin/fm-lab-home.sh" create "$LAB" >/dev/null
SUB="$LAB-sub"
mkdir -p "$LAB/projects" "$LAB/remotes"
git init -q --bare "$LAB/remotes/foo-bar.git"
git init -q "$LAB/projects/foo bar"
git -C "$LAB/projects/foo bar" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$LAB/projects/foo bar" remote add origin "$LAB/remotes/foo-bar.git"
printf '%s\n' '- foo [direct-PR] - decoy single-word project (added 2026-09-28)' \
  '- foo bar [direct-PR +yolo branch=me/] - spaced project (added 2026-09-28)' > "$LAB/data/projects.md"
echo "===== [$label] parent data/projects.md"
cat "$LAB/data/projects.md"
echo "\$ FM_HOME=<lab> bin/fm-home-seed.sh design <sub> 'foo bar'"
( cd "$root" && FM_HOME="$LAB" FM_SECONDMATE_CHARTER='design for foo bar' FM_SECONDMATE_SCOPE='design for foo bar' \
    bin/fm-home-seed.sh design "$SUB" 'foo bar' > "$LAB.out" 2>&1; echo "exit=$?" )
tail -3 "$LAB.out"
echo "--- secondmate data/projects.md:"
cat "$SUB/data/projects.md" 2>&1
echo "--- fm-project-mode.sh 'foo bar' in secondmate home:"
FM_HOME="$SUB" "$root/bin/fm-project-mode.sh" 'foo bar' 2>&1
echo "--- fm-project-mode.sh --branch-prefix 'foo bar' in secondmate home:"
FM_HOME="$SUB" "$root/bin/fm-project-mode.sh" --branch-prefix 'foo bar' 2>&1
echo "--- no-mistakes remote on direct-PR clone (expect none):"
git -C "$SUB/projects/foo bar" remote 2>&1 | tr '\n' ' '; echo
echo "--- charter project list:"
grep -E '^- ' "$SUB/data/charter.md" 2>&1 | head -5
echo "--- reseed after a stale '- foo bar [no-mistakes]' line is appended:"
printf '%s\n' '- foo bar [no-mistakes] - stale entry (added 2026-01-01)' >> "$SUB/data/projects.md"
( cd "$root" && FM_HOME="$LAB" FM_SECONDMATE_CHARTER='design for foo bar' FM_SECONDMATE_SCOPE='design for foo bar' \
    bin/fm-home-seed.sh design "$SUB" 'foo bar' > "$LAB.out2" 2>&1; echo "exit=$?" )
cat "$SUB/data/projects.md"
rm -rf "$LAB" "$SUB" "$LAB.out" "$LAB.out2"
