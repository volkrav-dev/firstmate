#!/usr/bin/env bash
# Drives the real fm-procevent.sh + fm-extension.mjs against a disposable lab
# home spelled through macOS's symlinked $TMPDIR (/var -> /private/var).
# Usage: drive-symlink-home.sh <firstmate-root>
set -u
ROOT=$1
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")       # logical spelling (/var/...)
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
PHYS=$(cd -P "$LAB" && pwd -P)
export FM_PROCEVENT_CLAIM_ROOT="$LAB/claims"
trap 'chmod -R u+w "$LAB" 2>/dev/null; rm -rf "$LAB" "${PKGDIR:-}"' EXIT
echo "lab home (symlinked spelling): $LAB"
echo "lab home (physical spelling):  $PHYS"
PKGDIR=$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/fm-pkg.XXXXXX")" && pwd -P); PKG="$PKGDIR/pkg"; cp -R "$ROOT/docs/examples/process-event-extension" "$PKG"
chmod 0755 "$PKG" "$PKG/file-signal.mjs"; chmod 0644 "$PKG/firstmate-extension.json"
export FM_HOME="$LAB"
node "$ROOT/bin/fm-extension.mjs" bind "$PKG" --adapter file-signal --trust-same-user-code --consent artifact-references | tail -1
SIG="$PKGDIR/signal.txt"
"$ROOT/bin/fm-procevent.sh" register-extension file-signal lab-src --config-ref "file:$SIG" | grep -v owner-token
"$ROOT/bin/fm-procevent.sh" start lab-src > "$LAB/start.out" 2>&1 &
pid=$!
for _ in $(seq 1 200); do [ -f "$FM_PROCEVENT_CLAIM_ROOT/lab-src.claim" ] && break; sleep 0.05; done
printf 'build 99 completed successfully\n' > "$SIG"
wait $pid; echo "start exit: $?"; echo "--- start output:"; cat "$LAB/start.out"
echo "--- H3t: source record after terminal result:"
if [ -e "$PHYS/state/procevent/lab-src.source" ]; then echo "STILL PRESENT (not retired)"; else echo "absent (retired)"; fi
res=$(ls "$PHYS"/state/procevent-inbox/lab-src.*.result | head -1)
echo "captured: ${res##*/}: $(cat "$res")"
echo "--- CLS: classify via symlinked spelling:"
"$ROOT/bin/fm-procevent.sh" classify "$LAB/state/procevent-inbox/${res##*/}" 2>&1; echo "exit: $?"
echo "--- CLS: classify via physical spelling:"
"$ROOT/bin/fm-procevent.sh" classify "$res" 2>&1; echo "exit: $?"
echo "--- adversarial: copy of result outside inbox, symlinked spelling:"
mkdir "$LAB/outside"
for s in result adapter extension; do cp "${res%.result}.$s" "$LAB/outside/lab-src.1.$s"; chmod 0600 "$LAB/outside/lab-src.1.$s"; done
"$ROOT/bin/fm-procevent.sh" classify "$LAB/outside/lab-src.1.result" 2>&1; echo "exit: $?"
echo "--- adversarial: inbox entry that is a symlink to the outside copy:"
for s in result adapter extension; do ln -s "$LAB/outside/lab-src.1.$s" "$PHYS/state/procevent-inbox/lab-link.1.$s"; done
"$ROOT/bin/fm-procevent.sh" classify "$LAB/state/procevent-inbox/lab-link.1.result" 2>&1; echo "exit: $?"
