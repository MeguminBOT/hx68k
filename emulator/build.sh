#!/usr/bin/env bash
#
# Builds the emulator's window and says where it put it.
#
#   ./emulator/build.sh          the release build, which is the one run-window.sh runs
#   ./emulator/build.sh debug    the same with lime's debug flags, for a stack trace on a crash
#
# Nothing else here needs lime: every check builds with plain haxe to neko or to C. This is only
# the window, and it is the only part of the repository that needs a working lime install.
#
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

BUILT="bin/window/windows/bin/hx68k.exe"

FLAG="-release"
if [ "${1:-}" = "debug" ]; then
	FLAG="-debug"
fi

# Windows holds a running executable open, so a link over one fails and lime does not call that an
# error. The build then looks like it worked and hands back the binary from last time, which is a
# very good way to spend an afternoon fixing something that was already fixed.
taskkill //F //IM hx68k.exe > /dev/null 2>&1 || true
rm -f "$BUILT"

haxelib run lime build windows "$FLAG"

# lime puts a debug build somewhere else on some versions, so what is reported is what was found
if [ ! -f "$BUILT" ]; then
	BUILT="$(find bin/window -name hx68k.exe -newer project.xml 2>/dev/null | head -1)"
fi

if [ -z "$BUILT" ] || [ ! -f "$BUILT" ]; then
	echo "the link produced nothing: something still had the binary open"
	exit 1
fi

echo ""
echo "  $HERE/$BUILT"
echo "  $(du -h "$BUILT" | cut -f1), built $(date '+%H:%M:%S')"
echo ""
echo "  ./emulator/run-window.sh <rom.bin>   builds it again and runs it"
