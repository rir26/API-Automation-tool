import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FileImportComponent } from './file-import/file-import';
import { ResponseTerminalComponent } from './response-terminal/response-terminal';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FileImportComponent, ResponseTerminalComponent],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  swaggerContent?: string;
  paramsContent?: string;
  apiResponse?: any;

  onSwaggerImported(content: string) {
    this.swaggerContent = content;
  }

  onParamsImported(content: string) {
    this.paramsContent = content;
  }

  async runTests() {
    // Call backend /run-script, then always try to load the saved logs from /api/logs
    try {
      const runResp = await fetch('/run-script');
      const runJson = await runResp.json();
      const debugPaths = runJson?.debugPaths ?? null;

      // After running, prefer loading the saved log file for consistent display
      try {
        const logsResp = await fetch('/api/logs');
        if (logsResp.ok) {
          const logsJson = await logsResp.json();
          this.apiResponse = { log: logsJson, debugPaths, source: 'logFile' };
          return;
        }
      } catch (e) {
        console.debug('logs fetch failed; falling back to runJson', e);
      }

      // Fallback to whatever /run-script returned
      if (runJson?.success && runJson?.source === 'logFile' && runJson?.log) {
        this.apiResponse = { log: runJson.log, debugPaths, source: runJson.source };
      } else if (runJson?.success && runJson?.stdout) {
        this.apiResponse = { status: 'done', raw: runJson.stdout, debugPaths };
      } else {
        this.apiResponse = { payload: runJson, debugPaths };
      }
    } catch (err) {
      this.apiResponse = { status: 'error', error: String(err) };
    }
  }

  async fetchLogs() {
    try {
      const resp = await fetch('/api/logs');
      if (!resp.ok) throw new Error(`Failed to fetch logs (${resp.status})`);
      const json = await resp.json();
      this.apiResponse = { log: json, debugPaths: null, source: 'logFile' };
    } catch (err) {
      this.apiResponse = { status: 'error', error: String(err) };
    }
  }
}
