# LAGUN — Ecosistema Multiplataforma

Ecosistema integral multiplataforma para el monitoreo biométrico en tiempo real y consumo de contenidos *edutainment*, diseñado para funcionar de manera sincrónica en dispositivos móviles, wearables y Smart TVs.

---

## 📁 Estructura del Repositorio

El proyecto está dividido en tres componentes principales:

* `/lagun_mobile`: Aplicación móvil desarrollada en **Flutter** (iOS / Android).
* `/lagun_wear`: Aplicación para Smartwatch en **Wear OS** (Flutter).
* `/lagun`: Aplicación web progresiva (PWA) optimizada para **Smart TV** en **Angular** bajo el estándar *10-foot UI*.

---

## 🛠️ Requisitos Previos

Asegúrate de contar con las siguientes herramientas instaladas en tu entorno de desarrollo:

* **Flutter SDK** (v3.x / canal estable) y **Dart SDK**
* **Node.js** (v20.x o superior) y **npm**
* **Angular CLI** (v21.x):
  ```bash
  npm install -g @angular/cli
📦 Instalación y Configuración1. Clonar el RepositorioBashgit clone [https://github.com/Jared-AriAri/Lagun-ecosistema.git](https://github.com/Jared-AriAri/Lagun-ecosistema.git)
cd Lagun-ecosistema
2. App Móvil (lagun_mobile)Bashcd lagun_mobile
flutter pub get
Crea un archivo .env en la raíz de lagun_mobile/ a partir de .env.example:Fragmento de códigoSUPABASE_URL=tu_supabase_url
SUPABASE_ANON_KEY=tu_supabase_anon_key
Ejecutar en emulador o dispositivo físico:Bashflutter run
3. App Wearable (lagun_wear)Bashcd ../lagun_wear
flutter pub get
flutter run
Nota: Transmite telemetría en tiempo real vía Socket TCP (puerto 7777) y servicio GATT / BLE.4. PWA Smart TV (lagun)Bashcd ../lagun
npm install
Servidor de desarrollo local:Bashng serve
Abre http://localhost:4200 en tu navegador (se recomienda simular resolución $1920 \times 1080$ para evaluar el layout 10-foot UI).Compilación para producción:Bashng build
Ejecución de pruebas unitarias:Bashng test
🤖 Declaración de Uso de Inteligencia ArtificialNota de Transparencia y Asistencia:Este proyecto contó con la asistencia y apoyo de herramientas de Inteligencia Artificial Generativa (Gemini / ChatGPT) durante su ciclo de desarrollo. La IA fue utilizada como colaboradora técnica para la optimización y escalado del diseño responsive en Smart TV (10-foot UI / Safe Zone), la depuración y unificación de estilos CSS, la resolución de conflictos de versión en Git y la estructuración de la documentación técnica del ecosistema.