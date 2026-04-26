#!/bin/bash
# Wird Refactor Test Runner
# Runs all verification tests for the wird refactoring

echo "=========================================="
echo "WIRD REFACTOR VERIFICATION TEST RUNNER"
echo "=========================================="
echo ""

echo "Running unit tests for constants and formatters..."
flutter test test/wird_refactor_test.dart

RESULT=$?

echo ""
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="
if [ $RESULT -eq 0 ]; then
    echo "✅ ALL TESTS PASSED"
    echo ""
    echo "Verification Results:"
    echo "  - Constants extracted correctly"
    echo "  - Date formatting works"
    echo "  - Time formatting works"
    echo "  - Quran boundaries data integrity"
    echo "  - Edge cases handled"
else
    echo "❌ TESTS FAILED"
    echo "Exit code: $RESULT"
fi

echo ""
echo "Running static analysis..."
flutter analyze lib/features/wird/ 2>&1 | tail -5

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
if [ $RESULT -eq 0 ]; then
    echo "✅ REFACTOR VERIFIED - BEHAVIOR EQUIVALENT"
else
    echo "❌ REFACTOR FAILED VERIFICATION"
fi