/** Env default sebelum AppModule di-import oleh file e2e. */
process.env.DEPLOYMENT_MODE = process.env.DEPLOYMENT_MODE ?? 'on_prem';
process.env.LICENSE_SECRET =
  process.env.LICENSE_SECRET ?? 'test-license-secret-e2e';
process.env.ENABLE_PLATFORM = process.env.ENABLE_PLATFORM ?? 'true';
process.env.API_PREFIX = process.env.API_PREFIX ?? 'api/v1';
