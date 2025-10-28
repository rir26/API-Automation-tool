const express = require('express');
const { execFile } = require('child_process');
const fs = require('fs');
const fsPromises = require('fs').promises;
const path = require('path');

const app = express();
const port = 3000;

const automationDir = path.join(__dirname, 'Automation - Swagger input');
const scriptPath = 'C:\\tool task\\API-Automation-tool\\Automation - Swagger input\\callapi.ps1';
const swaggerPath = path.join(automationDir, 'swagger.json');
const paramsPath = path.join(automationDir, 'overrides.json');
const logPath = path.join(automationDir, 'get_api_logs.json');

app.get('/run-script', (req, res) => {
  if (!fs.existsSync(scriptPath)) {
    return res.status(404).json({ error: `Script not found at ${scriptPath}` });
  }

  const ps = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, swaggerPath, paramsPath, logPath];

  console.log('Executing', ps, args.join(' '));

  execFile(ps, args, { windowsHide: true, timeout: 5 * 60 * 1000, cwd: path.dirname(scriptPath) }, async (error, stdout, stderr) => {
    const debugPaths = { scriptPath, swaggerPath, parametersPath: paramsPath, logOutput: logPath };

    // Regardless of error, if the log file exists try to return it
    if (fs.existsSync(logPath)) {
      try {
        const text = await fsPromises.readFile(logPath, 'utf8');
        try {
          const json = JSON.parse(text);
          return res.json({
            success: true,
            source: 'logFile',
            log: json,
            rawStdout: stdout,
            rawStderr: stderr,
            scriptExit: error ? { code: error.code ?? 1, message: String(error) } : { code: 0 },
            debugPaths,
          });
        } catch (e) {
          return res.json({
            success: true,
            source: 'logFile',
            logText: text,
            rawStdout: stdout,
            rawStderr: stderr,
            scriptExit: error ? { code: error.code ?? 1, message: String(error) } : { code: 0 },
            debugPaths,
          });
        }
      } catch (e) {
        // If reading log failed, continue to error/STDOUT handling below
        console.error('Failed to read log file', e);
      }
    }

    if (error) {
      console.error('Script error', error, stderr);
      return res.status(500).json({
        error: String(error),
        rawStdout: stdout,
        rawStderr: stderr,
        scriptExit: { code: error.code ?? 1 },
        debugPaths,
      });
    }

    return res.json({ success: true, source: 'stdout', stdout, rawStderr: stderr, debugPaths });
  });
});

app.get('/api/logs', async (req, res) => {
  if (!fs.existsSync(logPath)) return res.status(404).json({ error: `log not found at ${logPath}` });
  try {
    const text = await fsPromises.readFile(logPath, 'utf8');
    try {
      const json = JSON.parse(text);
      return res.json(json);
    } catch {
      return res.type('text').send(text);
    }
  } catch (e) {
    return res.status(500).json({ error: String(e) });
  }
});

app.listen(port, () => console.log(`Demo server listening on http://localhost:${port}`));
