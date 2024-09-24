#!/usr/bin/env bash
set -e
set -x

echo "Current working directory: $(pwd)"

# Check if running inside Docker
if [ -f /.dockerenv ]; then
    echo "Running inside Docker container"
    PROJECT_ROOT="/app"
    TEST_DIR="/app/app/tests"
else
    echo "Running in local environment"
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    TEST_DIR="$PROJECT_ROOT/app/tests"
fi

echo "Project root: $PROJECT_ROOT"
echo "Test directory: $TEST_DIR"

# 테스트 디렉토리 내용 출력
echo "Contents of test directory:"
ls -R "$TEST_DIR"

echo "Attempting to run tests_pre_start.py"
python "$PROJECT_ROOT/app/tests_pre_start.py"

echo "Running pytest"
python -m pytest "$TEST_DIR" -v -s --durations=0

echo "Running pytest with coverage"
coverage run -m pytest "$TEST_DIR" -v -s --durations=0

echo "Generating coverage reports"
coverage report -m
coverage xml -o "$PROJECT_ROOT/coverage.xml"
coverage html -d "$PROJECT_ROOT/htmlcov"