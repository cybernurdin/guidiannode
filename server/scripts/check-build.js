const { spawnSync } = require('node:child_process');

const files = [
  'server.js',
  'config/databaseReadiness.js',
  'services/authService.js',
  'services/userService.js',
  'services/whatsappVerificationService.js',
  'controllers/whatsappWebhookController.js',
  'controllers/verificationController.js',
  'middleware/rateLimits.js',
  'routes/verificationRoutes.js',
  'scripts/test-live-verification-flow.js',
  'scripts/test-auth-purpose-flow.js',
  'routes/legalRoutes.js',
];

for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], {
    cwd: __dirname + '/..',
    stdio: 'inherit',
  });

  if (result.status !== 0) {
    process.exit(result.status || 1);
  }
}

console.log('Backend syntax checks passed.');
