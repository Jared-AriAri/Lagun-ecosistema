
import { describe, expect, it, vi, afterEach } from 'vitest';
import { AppComponent } from './app';

describe('White Box - Navegación de AppComponent', () => {
    afterEach(() => {
        vi.restoreAllMocks();
    });

    const press = (app: AppComponent, key: string) => {
        app.handleKeyDown(new KeyboardEvent('keydown', { key }));
    };

    it('WEB-WB-01: inicia en la primera tarjeta', () => {
        const app = new AppComponent();
        expect(app.focusedIndex).toBe(0);
    });

    it('WEB-WB-02: ArrowRight avanza solamente desde la columna izquierda', () => {
        const app = new AppComponent();

        press(app, 'ArrowRight');
        expect(app.focusedIndex).toBe(1);

        press(app, 'ArrowRight');
        expect(app.focusedIndex).toBe(1);

        app.focusedIndex = 2;
        press(app, 'ArrowRight');
        expect(app.focusedIndex).toBe(3);
    });

    it('WEB-WB-03: ArrowLeft retrocede solamente desde la columna derecha', () => {
        const app = new AppComponent();

        press(app, 'ArrowLeft');
        expect(app.focusedIndex).toBe(0);

        app.focusedIndex = 1;
        press(app, 'ArrowLeft');
        expect(app.focusedIndex).toBe(0);

        app.focusedIndex = 3;
        press(app, 'ArrowLeft');
        expect(app.focusedIndex).toBe(2);
    });

    it('WEB-WB-04: ArrowDown respeta el límite inferior', () => {
        const app = new AppComponent();

        press(app, 'ArrowDown');
        expect(app.focusedIndex).toBe(2);

        press(app, 'ArrowDown');
        expect(app.focusedIndex).toBe(2);

        app.focusedIndex = 1;
        press(app, 'ArrowDown');
        expect(app.focusedIndex).toBe(3);
    });

    it('WEB-WB-05: ArrowUp respeta el límite superior', () => {
        const app = new AppComponent();

        press(app, 'ArrowUp');
        expect(app.focusedIndex).toBe(0);

        app.focusedIndex = 2;
        press(app, 'ArrowUp');
        expect(app.focusedIndex).toBe(0);

        app.focusedIndex = 3;
        press(app, 'ArrowUp');
        expect(app.focusedIndex).toBe(1);
    });

    it('WEB-WB-06: Enter selecciona la tarjeta enfocada', () => {
        const app = new AppComponent();
        const select = vi.spyOn(app, 'selectCard');

        app.focusedIndex = 3;
        press(app, 'Enter');

        expect(select).toHaveBeenCalledExactlyOnceWith(3);
    });

    it('WEB-WB-07: las teclas desconocidas no modifican el foco', () => {
        const app = new AppComponent();

        app.focusedIndex = 2;
        press(app, 'Escape');
        press(app, 'a');
        press(app, 'Tab');

        expect(app.focusedIndex).toBe(2);
    });

    it('WEB-WB-08: selectCard registra la selección', () => {
        const app = new AppComponent();
        const log = vi.spyOn(console, 'log').mockImplementation(() => { });

        app.selectCard(2);

        expect(log).toHaveBeenCalledWith('Tarjeta seleccionada:', 2);
    });
});
