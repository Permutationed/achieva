#!/usr/bin/env node

/**
 * Generate Apple Sign-In Client Secret for Supabase
 * 
 * Usage:
 *   1. Download your .p8 key file from Apple Developer
 *   2. Update the variables below with your credentials
 *   3. Run: node generate-apple-secret.js
 *   4. Copy the output JWT token to Supabase as "Client Secret"
 */

const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

// ============================================
// CONFIGURATION - UPDATE THESE VALUES
// ============================================

// Get Team ID from command line argument or use placeholder
const TEAM_ID = process.argv[2] || 'YOUR_TEAM_ID'; // Pass as: node generate-apple-secret.js YOUR_TEAM_ID
const KEY_ID = 'CWJ7DDABZ2'; // Key ID from filename
const SERVICE_ID = 'io.bucketlist.app.service'; // Your Services ID
const PRIVATE_KEY_PATH = './AuthKey_CWJ7DDABZ2.p8'; // Path to your downloaded .p8 file

// ============================================
// GENERATE CLIENT SECRET
// ============================================

try {
  // Read the private key file
  const privateKeyPath = path.resolve(PRIVATE_KEY_PATH);
  
  if (!fs.existsSync(privateKeyPath)) {
    console.error('❌ Error: Private key file not found!');
    console.error(`   Looking for: ${privateKeyPath}`);
    console.error('\n   Please:');
    console.error('   1. Download your .p8 key file from Apple Developer');
    console.error('   2. Place it in the project root');
    console.error('   3. Update PRIVATE_KEY_PATH in this script');
    process.exit(1);
  }

  const privateKey = fs.readFileSync(privateKeyPath);

  // Validate configuration
  if (TEAM_ID === 'YOUR_TEAM_ID') {
    console.error('❌ Error: Team ID is required!');
    console.error('\n   Usage: node generate-apple-secret.js YOUR_TEAM_ID');
    console.error('   Example: node generate-apple-secret.js ABC123DEF4');
    console.error('\n   Get your Team ID from: Apple Developer → Membership section');
    process.exit(1);
  }

  // Generate JWT token (valid for 6 months)
  const now = Math.floor(Date.now() / 1000);
  const token = jwt.sign(
    {
      iss: TEAM_ID,
      iat: now,
      exp: now + (86400 * 180), // 6 months expiration
      aud: 'https://appleid.apple.com',
      sub: SERVICE_ID,
    },
    privateKey,
    {
      algorithm: 'ES256',
      header: {
        alg: 'ES256',
        kid: KEY_ID,
      },
    }
  );

  // Output the client secret
  console.log('\n✅ Client Secret Generated Successfully!\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Copy this JWT token to Supabase Dashboard → Authentication → Providers → Apple');
  console.log('as the "Client Secret" field:\n');
  console.log(token);
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  console.log('📋 Configuration Summary:');
  console.log(`   Team ID: ${TEAM_ID}`);
  console.log(`   Key ID: ${KEY_ID}`);
  console.log(`   Service ID: ${SERVICE_ID}`);
  console.log(`   Expires: ${new Date((now + (86400 * 180)) * 1000).toLocaleString()}\n`);

} catch (error) {
  console.error('\n❌ Error generating client secret:');
  console.error(error.message);
  
  if (error.message.includes('PEM')) {
    console.error('\n   The .p8 file might be corrupted or in the wrong format.');
    console.error('   Make sure you downloaded the correct file from Apple Developer.');
  }
  
  process.exit(1);
}

