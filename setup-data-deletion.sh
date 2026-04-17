#!/bin/bash

# Quick Setup Guide for Data Deletion System
# دليل الإعداد السريع لنظام حذف البيانات

echo "==============================================="
echo "نظام حذف البيانات - دليل الإعداد"
echo "Data Deletion System - Setup Guide"
echo "==============================================="
echo ""

# Check Node.js
echo "[1/5] Checking Node.js installation..."
if ! command -v node &> /dev/null
then
    echo "❌ Node.js is not installed"
    echo "   Download from: https://nodejs.org/"
    exit 1
fi
echo "✓ Node.js $(node --version) found"
echo ""

# Check Firebase CLI
echo "[2/5] Checking Firebase CLI..."
if ! command -v firebase &> /dev/null
then
    echo "❌ Firebase CLI is not installed"
    echo "   Install with: npm install -g firebase-tools"
    exit 1
fi
echo "✓ Firebase CLI found"
echo ""

# Check .env.local
echo "[3/5] Checking environment configuration..."
if [ ! -f "functions/.env.local" ]; then
    echo "⚠️  functions/.env.local not found"
    echo "   Creating from template..."
    cp functions/.env.example functions/.env.local
    echo "✓ Template created at: functions/.env.local"
    echo "   📝 Edit this file with your Gmail credentials"
else
    echo "✓ functions/.env.local exists"
fi
echo ""

# Install dependencies
echo "[4/5] Installing dependencies..."
cd functions
if [ ! -d "node_modules" ]; then
    npm install
    echo "✓ Dependencies installed"
else
    echo "✓ Dependencies already installed"
fi
cd ..
echo ""

# Verify Firestore setup
echo "[5/5] Verifying Firestore configuration..."
firebase firestore:describe \
    data_deletion_requests \
    --project=quraan-dd543 \
    2>/dev/null && \
    echo "✓ Firestore collection 'data_deletion_requests' ready" || \
    echo "⚠️  Collection will be created on first request"
echo ""

echo "==============================================="
echo "✓ Setup Complete!"
echo "==============================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Edit functions/.env.local with your Gmail credentials:"
echo "   ADMIN_EMAIL=your-email@gmail.com"
echo "   ADMIN_EMAIL_PASSWORD=your-16-char-app-password"
echo ""
echo "2. Test locally (optional):"
echo "   firebase emulators:start --only functions"
echo ""
echo "3. Deploy to production:"
echo "   firebase deploy --only functions"
echo ""
echo "4. Verify deployment:"
echo "   firebase functions:log"
echo ""
echo "Documentation:"
echo "   See DATA_DELETION_SYSTEM_DOCUMENTATION.md"
echo ""
