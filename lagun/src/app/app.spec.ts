import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app';
import { provideRouter } from '@angular/router';

describe('App', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent],
      providers: [provideRouter([])],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should move keyboard focus to the next card', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.componentInstance.handleKeyDown({ key: 'ArrowRight' } as KeyboardEvent);
    expect(fixture.componentInstance.focusedIndex).toBe(1);
  });
});
