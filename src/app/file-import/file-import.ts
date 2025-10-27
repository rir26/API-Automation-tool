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
  selectedFile: string = '';

  onFileChange(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.selectedFile = file.name;
      const reader = new FileReader();
      reader.onload = () => this.fileImported.emit(reader.result as string);
      reader.readAsText(file);
    }
  }
}
