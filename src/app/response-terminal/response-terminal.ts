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
}
