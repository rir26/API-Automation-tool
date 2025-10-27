import { Component } from '@angular/core';
import { FileImportComponent } from './file-import/file-import';
import { ResponseTerminalComponent } from './response-terminal/response-terminal';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FileImportComponent, ResponseTerminalComponent, RouterOutlet],
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

  runTests() {
    let swagger = {};
    let params = {};
    try {
      swagger = JSON.parse(this.swaggerContent || '{}');
    } catch { }
    try {
      params = JSON.parse(this.paramsContent || '{}');
    } catch { }
    // Replace with real API logic. For now, just show confirmation:
    this.apiResponse = {
      status: "done",
      message: "Tests completed",
      swaggerReceived: !!this.swaggerContent,
      paramsReceived: !!this.paramsContent,
      results: { swagger, params }
    };
  }
}
