#!/usr/bin/env bash
# Harness checks that do not need the server (determinism). Plain JVM: these do
# not exercise TeaVM, which is what tests/e2e.sh is for.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD=build/harness-test
rm -rf "$BUILD"
mkdir -p "$BUILD/src"

# Main instantiates Submission, so the harness needs one to compile against.
cp examples/attack/Submission.java "$BUILD/src/"
cp harness/*.java tests/HarnessTest.java "$BUILD/src/"
mkdir -p "$BUILD/src/dsagame/api"
cp api/dsagame/api/*.java "$BUILD/src/dsagame/api/"

find "$BUILD/src" -name '*.java' -print0 | xargs -0 javac --release 21 -d "$BUILD/classes"
java -cp "$BUILD/classes" HarnessTest
