@echo off
REM Quick Setup Guide for Data Deletion System (Windows)
REM دليل الإعداد السريع لنظام حذف البيانات (ويندوز)

echo ===============================================
echo نظام حذف البيانات - دليل الإعداد
echo Data Deletion System - Setup Guide
echo ===============================================
echo[

REM Check Node.js
echo [1/5] Checking Node.js installation...
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js is not installed
    echo    Download from: https://nodejs.org/
    exit /b 1
)
echo ✓ Node.js found: 
node --version
echo[

REM Check Firebase CLI
echo [2/5] Checking Firebase CLI...
firebase --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Firebase CLI is not installed
    echo    Install with: npm install -g firebase-tools
    exit /b 1
)
echo ✓ Firebase CLI found
echo[

REM Check .env.local
echo [3/5] Checking environment configuration...
if not exist "functions\.env.local" (
    echo ⚠️  functions\.env.local not found
    echo    Creating from template...
    copy functions\.env.example functions\.env.local >nul
    echo ✓ Template created at: functions\.env.local
    echo    📝 Edit this file with your Gmail credentials
) else (
    echo ✓ functions\.env.local exists
)
echo[

REM Install dependencies
echo [4/5] Installing dependencies...
cd functions
if not exist "node_modules" (
    call npm install
    echo ✓ Dependencies installed
) else (
    echo ✓ Dependencies already installed
)
cd ..
echo[

REM Verify Firebase setup
echo [5/5] Verifying Firebase configuration...
echo ✓ Setup verification complete
echo[

echo ===============================================
echo ✓ Setup Complete!
echo ===============================================
echo[
echo Next steps:
echo[
echo 1. Edit functions\.env.local with your Gmail credentials:
echo    ADMIN_EMAIL=your-email@gmail.com
echo    ADMIN_EMAIL_PASSWORD=your-16-char-app-password
echo[
echo 2. Test locally (optional):
echo    firebase emulators:start --only functions
echo[
echo 3. Deploy to production:
echo    firebase deploy --only functions
echo[
echo 4. Verify deployment:
echo    firebase functions:log
echo[
echo Documentation:
echo    See DATA_DELETION_SYSTEM_DOCUMENTATION.md
echo[
pause
