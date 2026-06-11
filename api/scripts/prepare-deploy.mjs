import { access, cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import process from 'node:process';

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function sha256File(filePath) {
  const buf = await readFile(filePath);
  return createHash('sha256').update(buf).digest('hex');
}

async function assertPrismaSchemaSynced(sourceDir, targetDir) {
  const sourceSchema = path.resolve(sourceDir, 'schema.prisma');
  const targetSchema = path.resolve(targetDir, 'schema.prisma');
  const sourceMigrations = path.resolve(sourceDir, 'migrations');
  const targetMigrations = path.resolve(targetDir, 'migrations');

  if (!(await exists(sourceSchema))) {
    throw new Error('api/prisma/schema.prisma tidak ditemukan');
  }

  const [srcHash, dstHash] = await Promise.all([
    sha256File(sourceSchema),
    sha256File(targetSchema),
  ]);

  if (srcHash !== dstHash) {
    throw new Error(
      'Deploy prisma/schema.prisma tidak sinkron dengan api/prisma (hash berbeda setelah copy)',
    );
  }

  if (!(await exists(sourceMigrations)) || !(await exists(targetMigrations))) {
    throw new Error('Folder prisma/migrations hilang di source atau target deploy');
  }
}

async function main() {
  const apiRoot = path.resolve(process.cwd());
  const repoRoot = path.resolve(apiRoot, '..');
  const target = path.resolve(repoRoot, 'deploy', 'backend');

  const distDir = path.resolve(apiRoot, 'dist');
  const prismaDir = path.resolve(apiRoot, 'prisma');
  const envExample = path.resolve(apiRoot, '.env.example');
  const pkgJson = path.resolve(apiRoot, 'package.json');
  const pkgLock = path.resolve(apiRoot, 'package-lock.json');

  // ensure dist exists (build first)
  const distExists = await exists(distDir);
  if (!distExists) {
    throw new Error('dist/ not found. Run `npm run build` first.');
  }

  await rm(target, { recursive: true, force: true });
  await mkdir(target, { recursive: true });

  await cp(distDir, path.resolve(target, 'dist'), { recursive: true });
  const targetPrisma = path.resolve(target, 'prisma');
  await cp(prismaDir, targetPrisma, { recursive: true });
  await assertPrismaSchemaSynced(prismaDir, targetPrisma);
  await cp(pkgJson, path.resolve(target, 'package.json'));
  await cp(pkgLock, path.resolve(target, 'package-lock.json'));
  await cp(envExample, path.resolve(target, '.env.example'));

  const readme = `# Backend deploy bundle

Folder ini hasil generate dari \`api/\`.

## Cara pakai di server

\`\`\`bash
# 1) copy folder ini ke server (mis. /opt/apotikflow-backend)
cd /opt/apotikflow-backend

# 2) siapkan env
cp .env.example .env
# edit DATABASE_URL, JWT_SECRET, dll

# 3) install deps (production only)
npm ci --omit=dev

# 4) jalankan
node dist/main
\`\`\`

> Catatan: untuk production sebaiknya pakai Prisma Migrate (\`prisma migrate deploy\`).
`;

  const schemaHash = await sha256File(path.resolve(targetPrisma, 'schema.prisma'));
  const manifest = {
    generated_at: new Date().toISOString(),
    source: 'api/',
    prisma_schema_sha256: schemaHash,
  };
  await writeFile(
    path.resolve(target, 'deploy-manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );
  await writeFile(path.resolve(target, 'README.md'), readme, 'utf8');
  // eslint-disable-next-line no-console
  console.log(`Deploy bundle ready at: ${target}`);
  // eslint-disable-next-line no-console
  console.log(`Prisma schema verified (sha256: ${schemaHash.slice(0, 12)}…)`);
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});

