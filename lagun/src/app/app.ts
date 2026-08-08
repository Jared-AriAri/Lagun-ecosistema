import { Component, HostListener } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent {
  focusedIndex = 0;

  @HostListener('window:keydown', ['$event'])
  handleKeyDown(event: KeyboardEvent) {
    switch (event.key) {
      case 'ArrowRight':
        if (this.focusedIndex % 2 !== 1) this.focusedIndex += 1;
        break;
      case 'ArrowLeft':
        if (this.focusedIndex % 2 !== 0) this.focusedIndex -= 1;
        break;
      case 'ArrowDown':
        if (this.focusedIndex < 2) this.focusedIndex += 2;
        break;
      case 'ArrowUp':
        if (this.focusedIndex >= 2) this.focusedIndex -= 2;
        break;
      case 'Enter':
        this.selectCard(this.focusedIndex);
        break;
    }
  }

  selectCard(index: number) {
    console.log('Tarjeta seleccionada:', index);
  }
}