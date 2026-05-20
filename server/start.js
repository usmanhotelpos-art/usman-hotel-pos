import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const clientDir = join(__dirname, '../client');
const clientDistIndex = join(clientDir, 'dist', 'index.html');

function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'inherit', shell: true, ...options });
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
      }
    });
    child.on('error', reject);
  });
}

async function buildClientIfNeeded() {
  if (existsSync(clientDistIndex)) {
    console.log('Client build already exists. Skipping rebuild.');
    return;
  }

  console.log('Client build not found. Building frontend...');
  await runCommand('npm', ['install'], { cwd: clientDir });
  await runCommand('npm', ['run', 'build'], { cwd: clientDir });
  console.log('Client build completed successfully.');
}

async function startServer() {
  try {
    await buildClientIfNeeded();
    const serverProcess = spawn('node', ['index.js'], { cwd: __dirname, stdio: 'inherit', shell: true });
    serverProcess.on('close', (code) => {
      process.exit(code);
    });
  } catch (error) {
    console.error('Failed to build client or start server:', error);
    process.exit(1);
  }
}

startServer();
