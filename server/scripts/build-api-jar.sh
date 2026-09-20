#!/usr/bin/env bash
# Builds dsagame-api.jar from api/. Students compile their Submission against it.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR=build/api-classes
JAR=dsagame-api.jar

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

find api -name '*.java' -print0 | xargs -0 javac --release 17 -d "$OUT_DIR"
jar cf "$JAR" -C "$OUT_DIR" .

echo "built $JAR"
