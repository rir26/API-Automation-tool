import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-response-terminal',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './response-terminal.html',
  styleUrl: './response-terminal.css'
})
export class ResponseTerminalComponent {
  @Input() response: any;

  getStatusClass(): string {
    if (!this.response?.status) return 'status-default';
    
    const status = this.response.status;
    if (status >= 200 && status < 300) return 'status-success';
    if (status >= 400) return 'status-error';
    return 'status-default';
  }

  hasLog(): boolean {
    return !!(this.response && (this.response.log || this.response.payload?.log || this.response?.log));
  }

  getLogEntries(): any[] {
    const maybeLog = this.response?.log ?? this.response?.payload?.log ?? this.response;
    if (!maybeLog) return [];
    // If the log is directly the parsed file (object or array), normalize to array
    if (Array.isArray(maybeLog)) return maybeLog;
    if (maybeLog.entries && Array.isArray(maybeLog.entries)) return maybeLog.entries;
    if (typeof maybeLog === 'object') return [maybeLog];
    return [];
  }
}
