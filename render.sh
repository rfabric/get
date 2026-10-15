#!/usr/bin/env bash
# Renders the get.rfabric.io site into <out-dir>: cli.sh and agent.sh from the one
# install.sh template, plus index.html.
#
#   GET_URL=https://get.rfabric.io LINUX_URL=https://linux.rfabric.io ./render.sh _site
set -euo pipefail

out="${1:?usage: render.sh <out-dir>}"
: "${GET_URL:?GET_URL is required}" "${LINUX_URL:?LINUX_URL is required}"
here="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$out"
mkdir -p "$out"

# render <script> <product> <binary> <releases> <next-step>
render() {
  sed -e "s|@SCRIPT@|$1|g" -e "s|@PRODUCT@|$2|g" -e "s|@BINARY@|$3|g" -e "s|@RELEASES@|$4|g" \
    -e "s|@NEXT_STEP@|$5|g" -e "s|@GET_URL@|$GET_URL|g" -e "s|@LINUX_URL@|$LINUX_URL|g" \
    "$here/install.sh" > "$out/$1"
  if grep -n '@[A-Z_]*@' "$out/$1"; then
    echo "render.sh: unfilled placeholder in $1" >&2
    exit 1
  fi
}

render cli.sh CLI rfabric rfabric/cli "rfabric config init"
render agent.sh "robot agent" rfabric-agent rfabric/agent "rfabric-agent provision <token> (the command on the robot's page in rFabric)"

sed "s|@GET_URL@|$GET_URL|g" "$here/index.html" > "$out/index.html"
