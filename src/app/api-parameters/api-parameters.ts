import { Component, Input, Output, EventEmitter } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-api-parameters',
  standalone: true,
  imports: [FormsModule, CommonModule],
  templateUrl: './api-parameters.html',
  styleUrl: './api-parameters.css'
})
export class ApiParametersComponent {
  @Input() fileContent?: string;
  @Output() send = new EventEmitter<any>();

  apiUrl: string = '';
  method: string = 'GET';
  requestBody: string = '';
  headers: string = '';

  onSend() {
    this.send.emit({
      url: this.apiUrl,
      method: this.method,
      body: this.requestBody,
      headers: this.headers,
      fileContent: this.fileContent
    });
  }
}
