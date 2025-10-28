import {
  AngularNodeAppEngine,
  createNodeRequestHandler,
  isMainModule,
  writeResponseToNodeResponse,
} from '@angular/ssr/node';
import express from 'express';
import { join, dirname } from 'node:path';
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import fsPromises from 'node:fs/promises';

const browserDistFolder = join(import.meta.dirname, '../browser');

const app = express();
const angularApp = new AngularNodeAppEngine();

// Helper: resolve candidate paths for script and input files
// Resolve candidate paths from several roots so we don't accidentally pick a build-time
// virtual directory (like .angular/vite-root). Prefer project root (process.cwd()),
// then import.meta.dirname (dev/build), and finally fall back to the joined path.
function resolveCandidates(...parts: string[]) {
  // Try to determine the repository root by locating a package.json up the tree.
  function findRepoRoot(start: string | undefined) {
    if (!start) return undefined;
    let cur = start;
    for (let i = 0; i < 10; i++) {
      const candidate = join(cur, 'package.json');
      if (fs.existsSync(candidate)) return cur;
      const parent = join(cur, '..');
      if (parent === cur) break;
      cur = parent;
    }
    return undefined;
  }

  const repoRoot = findRepoRoot(process.cwd()) || findRepoRoot(import.meta.dirname) || process.cwd();

  const candidates = [
    // repo root (best choice)
    join(repoRoot, ...parts),
    // build/dev location
    join(import.meta.dirname, ...parts),
    // fallback to cwd
    join(process.cwd(), ...parts),
  ];

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }

  // If none exists, return the repo-rooted path as a sensible default
  return join(repoRoot, ...parts);
}

/**
 * Run a PowerShell script safely with execFile and return the resulting JSON log.
 *
 * Query parameters (optional):
 * - scriptPath : absolute or project-relative path to the ps1 file
 * - swaggerPath : absolute or project-relative path to swagger.json
 * - parametersPath : absolute or project-relative path to parameters.json
 *
 * Environment variables that override defaults:
 * - SCRIPT_PATH, SWAGGER_PATH, PARAMETERS_PATH, LOG_OUTPUT
 */
app.get('/run-script', async (req, res) => {
  try {
    // const scriptPathQuery = (req.query['scriptPath'] as string) || process.env['SCRIPT_PATH'];
    const swaggerPathQuery = (req.query['swaggerPath'] as string) || process.env['SWAGGER_PATH'];
    const parametersPathQuery = (req.query['parametersPath'] as string) || process.env['PARAMETERS_PATH'];
    const logOutputQuery = (req.query['logOutput'] as string) || process.env['LOG_OUTPUT'];

    // Resolve sensible defaults (project relative). import.meta.dirname points to src/.
  // Prefer the user-provided "Automation - Swagger input" folder when present
  // Use explicit absolute path for the PowerShell script as requested
  const defaultScript = `C:\\tool task\\API-Automation-tool\\Automation - Swagger input\\callapi.ps1`;
  // Use explicit absolute paths for all automation inputs to avoid depending on process.cwd()/build tooling
  const defaultSwagger = `C:\\tool task\\API-Automation-tool\\Automation - Swagger input\\swagger.json`;
  const defaultParameters = `C:\\tool task\\API-Automation-tool\\Automation - Swagger input\\overrides.json`;
  const defaultLogOutput = `C:\\tool task\\API-Automation-tool\\Automation - Swagger input\\get_api_logs.json`;

    const scriptPath =  defaultScript;
    const swaggerPath = swaggerPathQuery || defaultSwagger;
    const parametersPath = parametersPathQuery || defaultParameters;
    const logOutput = logOutputQuery || defaultLogOutput;

    // Ensure the script exists
    if (!fs.existsSync(scriptPath)) {
      return res.status(404).json({ error: `Script not found at ${scriptPath}` });
    }

    // Execute PowerShell script using execFile (no shell interpolation)
    const psExecutable = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, swaggerPath, parametersPath, logOutput];
  const automationDir = dirname(scriptPath);

    // Run PowerShell and wait for it to complete. Wrap execFile into a Promise so we can `await` and
    // keep linear control flow which satisfies the TypeScript analyzer.
    let stdout = '';
    let stderr = '';
    let execError: any = null;
    const execResult = await new Promise<{ stdout: string; stderr: string; error: any }>((resolve) => {
      execFile(psExecutable, args, { windowsHide: true, timeout: 5 * 60 * 1000, cwd: automationDir }, (error, so, se) => {
        resolve({ stdout: so ?? '', stderr: se ?? '', error });
      });
    });
    stdout = execResult.stdout;
    stderr = execResult.stderr;
    execError = execResult.error;

    if (stderr?.trim()) {
      console.error('PowerShell stderr:', stderr);
      // continue — some scripts write warnings to stderr but still produce output
    }

    // If the logOutput file exists, return its parsed JSON. Otherwise return stdout.
    if (fs.existsSync(logOutput)) {
      try {
        const text = await fsPromises.readFile(logOutput, 'utf-8');
        try {
          const json = JSON.parse(text);
          return res.json({
            success: true,
            source: 'logFile',
            log: json,
            rawStdout: stdout,
            rawStderr: stderr,
            scriptExit: execError ? { code: execError.code ?? 1, message: String(execError) } : { code: 0 },
            debugPaths: { scriptPath, swaggerPath, parametersPath, logOutput },
          });
        } catch (error_) {
          console.warn('JSON parse failed for log file, returning raw text', String(error_));
          return res.json({
            success: true,
            source: 'logFile',
            logText: text,
            rawStdout: stdout,
            rawStderr: stderr,
            scriptExit: execError ? { code: execError.code ?? 1, message: String(execError) } : { code: 0 },
            debugPaths: { scriptPath, swaggerPath, parametersPath, logOutput },
          });
        }
      } catch (error_) {
        console.error('File read error', error_);
        return res.status(500).json({
          error: 'Failed to read output file',
          details: String(error_),
          rawStdout: stdout,
          rawStderr: stderr,
          scriptExit: execError ? { code: execError.code ?? 1, message: String(execError) } : { code: 0 },
          debugPaths: { scriptPath, swaggerPath, parametersPath, logOutput },
        });
      }
    }

    // If there is no log file, return stdout/stderr and include error/paths for diagnosis
    if (execError) {
      return res.status(500).json({
        error: String(execError),
        rawStdout: stdout,
        rawStderr: stderr,
        scriptExit: { code: execError.code ?? 1 },
        debugPaths: { scriptPath, swaggerPath, parametersPath, logOutput },
      });
    }

    return res.json({ success: true, source: 'stdout', stdout, rawStderr: stderr, debugPaths: { scriptPath, swaggerPath, parametersPath, logOutput } });
  } catch (err) {
    console.error('Unexpected error in /run-script', err);
    return res.status(500).json({ error: String(err) });
  }
});

// Serve latest log file directly for the frontend to poll or fetch without running the script.
app.get('/api/logs', async (req, res) => {
  try {
    // Use explicit absolute default to avoid CWD-related mis-resolutions
    const absoluteDefaultLog = String.raw`C:\tool task\API-Automation-tool\Automation - Swagger input\get_api_logs.json`;
    const logPath = (req.query['path'] as string) || process.env['LOG_OUTPUT'] || absoluteDefaultLog;

    if (!fs.existsSync(logPath)) {
  return res.status(404).json({ error: `Log file not found at ${logPath}` });
    }

    const text = await fsPromises.readFile(logPath, 'utf-8');
    try {
      const json = JSON.parse(text);
      return res.json(json);
    } catch (error_) {
      console.warn('Log file not JSON; returning raw text', error_);
      return res.type('text').send(text);
    }
  } catch (err) {
    console.error('Error reading logs', err);
    return res.status(500).json({ error: String(err) });
  }
});

/**
 * Example Express Rest API endpoints can be defined here.
 * Uncomment and define endpoints as necessary.
 *
 * Example:
 * ```ts
 * app.get('/api/{*splat}', (req, res) => {
 *   // Handle API request
 * });
 * ```
 */

/**
 * Serve static files from /browser
 */
app.use(
  express.static(browserDistFolder, {
    maxAge: '1y',
    index: false,
    redirect: false,
  }),
);

/**
 * Handle all other requests by rendering the Angular application.
 */
app.use((req, res, next) => {
  angularApp
    .handle(req)
    .then((response) =>
      response ? writeResponseToNodeResponse(response, res) : next(),
    )
    .catch(next);
});

/**
 * Start the server if this module is the main entry point.
 * The server listens on the port defined by the `PORT` environment variable, or defaults to 4000.
 */
if (isMainModule(import.meta.url)) {
  const port = process.env['PORT'] || 4000;
  app.listen(port, (error) => {
    if (error) {
      throw error;
    }

    console.log(`Node Express server listening on http://localhost:${port}`);
  });
}

/**
 * Request handler used by the Angular CLI (for dev-server and during build) or Firebase Cloud Functions.
 */
export const reqHandler = createNodeRequestHandler(app);
