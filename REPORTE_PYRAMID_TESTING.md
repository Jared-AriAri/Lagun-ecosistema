# Pruebas Pyramid Testing — Lagun

**Alumno:** Jared Ariel González González  
**Docente:** Manuel Contreras Castillo  
**Proyecto:** Lagun, ecosistema de noticias (Angular + Supabase)  
**Fecha:** 29 de octubre de 2026 (hora local de México)

## Fase 1. Diagnóstico inicial

**Funcionalidad crítica:** consulta de noticias publicadas y acceso al detalle por `slug`, mediante `NewsService` y Supabase.

En el frontend Angular, el ZIP original contenía `src/app/app.spec.ts` con dos casos de prueba de componente, ambos desactualizados: importaban `App` cuando la clase exportada se llama `AppComponent`, y uno esperaba el texto de plantilla «Hello, lagun». El primer intento de ejecución de `npm test -- --watch=false` terminó con el error de compilación `TS2305: Module './app' has no exported member 'App'`. Las pruebas no pudieron ejecutarse en ese estado. No había pruebas automatizadas de integración ni E2E en este subproyecto Angular. El ZIP incluye además pruebas `widget_test.dart` de plantillas Flutter, que no corresponden al flujo Angular elegido y no se ejecutaron en esta auditoría.

| Nivel (Angular) | Antes | Ejecución automática inicial | Después |
|---|---:|---|---:|
| Unitaria / componente | 2 | Configurada, pero bloqueada por compilación | 5 |
| Integración | 0 | No | 2 |
| E2E | 0 | No | 0 |
| **Total** | **2** | **No se completaba** | **7** |

## Fase 2. Pruebas unitarias

Archivo: `lagun/src/app/services/news.service.spec.ts`. Se utiliza `TestBed` con un doble de `SupabaseService` para aislar la dependencia de red.

| Caso | Entrada / condición | Esperado | Obtenido |
|---|---|---|---|
| Válido | Lista con una noticia publicada y relaciones en arreglos | Se obtiene una noticia y se normalizan categoría y perfil | Aprobado |
| Límite | Respuesta `data: null`, sin error | Lista vacía `[]` | Aprobado |
| Inválido | `slug` inexistente con espacios | Se limpia el `slug`, se filtra `published` y se lanza error informativo | Aprobado |

Además se corrigieron dos pruebas preexistentes en `app.spec.ts`: creación del componente y navegación de foco mediante teclado. **Resultado: 5 pruebas unitarias/de componente aprobadas.**

## Fase 3. Pruebas de integración

Archivo: `lagun/src/app/services/news.integration.spec.ts`.

**Configuración:** Angular `TestBed`, `NewsService` real y cliente `@supabase/supabase-js` real configurado con URL y clave sintéticas. Únicamente se intercepta `fetch` para producir respuestas HTTP controladas; no se utiliza la base de datos de producción ni se hacen escrituras. Esto comprueba la interacción entre lógica de aplicación, constructor de consultas Supabase y protocolo HTTP REST, aunque **no comprueba una base de datos Postgres real**.

| Caso | Datos de prueba | Esperado | Obtenido |
|---|---|---|---|
| Flujo correcto | JSON de una noticia ficticia, respuesta HTTP 200 | URL `/rest/v1/news_articles`, filtro `status=eq.published`, orden descendente, normalización de categoría | Aprobado |
| Error | HTTP 403 con código sintético `42501` | El servicio propaga el error del repositorio | Aprobado |

**Resultado: 2 pruebas de integración aprobadas.**

## Fase 4. E2E

**Estado: pendiente; no se ejecutó ni automatizó una prueba E2E.** El entorno de esta revisión no dispone de un navegador E2E configurado ni de una instalación de Lagun conectada a datos de prueba para recorrer la interfaz completa. No se cuentan como E2E las pruebas de servicio anteriores.

**Procedimiento manual por ejecutar y registrar:**

1. Iniciar Lagun en un entorno de pruebas con al menos una noticia ficticia en estado `published` y otra en `draft`.
2. Abrir la página de noticias desde un navegador y verificar que aparece únicamente la noticia publicada.
3. Seleccionar la noticia publicada y confirmar que se muestra su título y contenido en la ruta de detalle.
4. Abrir directamente un `slug` inexistente y verificar la respuesta visual de error.
5. Guardar capturas de la lista, detalle y estado de error, anotando los resultados reales.

**Automatización propuesta:** instalar Playwright; iniciar la aplicación contra un entorno Supabase local o de pruebas; utilizar `page.goto`, localizadores accesibles y `expect` para comprobar lista, navegación y detalle. Aislar datos por ejecución y limpiar al finalizar.

| Campo | Registro |
|---|---|
| Resultado esperado | Lista y detalle coherentes; noticia borrador oculta; error ante `slug` inexistente |
| Resultado real | Pendiente de comprobación en navegador |
| Evidencia gráfica | Pendiente de capturar |

## Fase 5. Auditoría y conclusión

### Distribución real de pruebas Angular después de implementar

| Nivel | Casos | Porcentaje |
|---|---:|---:|
| Unitarias/de componente | 5 | 71.43 % |
| Integración | 2 | 28.57 % |
| E2E | 0 | 0.00 % |
| **Total** | **7** | **100 %** |

Antes de implementar, la distribución nominal era 100 % unitarias/de componente (2 de 2), pero **ninguna se ejecutaba** por el defecto de compilación detectado.

**Capa más débil:** E2E, porque no existe una prueba automatizada ni evidencia manual ejecutada del flujo completo en navegador. Una respuesta correcta del servicio no asegura que las rutas, la interfaz y la visualización final funcionen juntas.

**Mejoras priorizadas por riesgo:**

1. **Prioridad alta:** automatizar con Playwright el flujo lista → detalle → manejo de `slug` inexistente, con datos aislados. Riesgo actual: regresiones visibles para el usuario no detectadas.
2. **Prioridad media-alta:** agregar integración contra una instancia Supabase/Postgres de pruebas para validar políticas RLS, esquema, relaciones y filtrado de borradores. Riesgo actual: el contrato HTTP simulado puede diferir de la configuración real de la base de datos.

**Ejecución recomendada:** en cada cambio de código ejecutar las pruebas unitarias y de integración (`npm test -- --watch=false`) mediante CI. Antes de entregar ejecutar además la suite E2E en navegador y una verificación manual del flujo crítico en el entorno de pruebas.

### Evidencia de consola

**Primer intento — defecto original reproducible:**

```text
Application bundle generation failed.
TS2305: Module '"./app"' has no exported member 'App'.
```

**Segundo intento — después de corregir y agregar pruebas:**

```text
RUN  v4.1.10
Test Files  3 passed (3)
Tests       7 passed (7)
Duration    1.24s
```

### Conclusión personal

La práctica permitió identificar un defecto reproducible en las pruebas existentes e incrementar la verificación automática del servicio de noticias. Las pruebas unitarias comprueban resultados válidos, condiciones límite y entradas inválidas; las de integración verifican que la lógica de Lagun construye solicitudes HTTP correctamente y propaga errores relevantes. Sin embargo, la ausencia de E2E y de pruebas contra una base de datos de pruebas deja riesgos en la interfaz, las rutas y las políticas de acceso. La próxima prioridad debe ser automatizar el recorrido real del usuario y comprobar la persistencia y seguridad con infraestructura de pruebas separada de producción.

## Comando para reproducir

Desde la carpeta `lagun`:

```bash
npm ci
npm test -- --watch=false
```

## Espacios para capturas de pantalla

- **Captura 1:** primer error de compilación del test original.
- **Captura 2:** terminal con `7 passed (7)`.
- **Captura 3:** código de las tres pruebas unitarias.
- **Captura 4:** código y resultados de integración.
- **Captura 5:** lista y detalle de noticias en navegador, **pendiente de ejecutar**.
