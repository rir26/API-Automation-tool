import { Component, EventEmitter, Output, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-file-import',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './file-import.html',
  styleUrl: './file-import.css'
})
export class FileImportComponent {
  @Output() fileImported = new EventEmitter<string>();
  @Input() label: string = "Import File"; 
  // Optional: require the base filename (without extension) to match this value
  @Input() requiredBasename?: string;
  @Input() validationMessage: string = "Invalid file name.";
  selectedFile: string = '';
  validationError: string = '';

  onFileChange(event: any) {
    const file = event.target.files[0];
    if (file) {
      // Reset previous state
      this.validationError = '';

      const name: string = file.name || '';
      const base = name.replace(/\.[^\.\/]+$/, ''); // strip extension

      // If a specific basename is required (e.g., 'swagger'), enforce it
      if (this.requiredBasename && base.toLowerCase() !== this.requiredBasename.toLowerCase()) {
        this.selectedFile = '';
        this.validationError = this.validationMessage || `File must be named "${this.requiredBasename}"`;
        // Clear the input so user can select again
        try { event.target.value = ''; } catch {}
        return;
      }

      this.selectedFile = name;
      const reader = new FileReader();
      reader.onload = () => this.fileImported.emit(reader.result as string);
      reader.readAsText(file);
    }
  }
}
