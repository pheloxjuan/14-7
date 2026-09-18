# PHELOX LTDA / Transportes El Avión

Aplicación de gestión de flota, stock, mantenimiento, gastos, personal y documentación. Sitio: https://pheloxapp.com/.

## Contenido

| Archivo o carpeta | Uso |
| --- | --- |
| `index.html` | Aplicación web y conexión con Supabase |
| `sw.js`, `manifest.webmanifest`, imágenes | Instalación de la app y caché |
| `supabase/functions/import-users/index.ts` | Gestión de usuarios y cierre de solicitudes de recuperación |
| `supabase/functions/push-repair/index.ts` | Notificaciones de reparaciones |
| `supabase/functions/google-drive/index.ts` | Copia del código encontrado en la función de Google Drive |
| `supabase/*.sql` | Cambios históricos de la base de datos |
| `database-schema.sql` | Estructura de la aplicación recuperada de Supabase, sin datos |
| `database-inventory.json` | Inventario y configuración de plataforma observada |
| `password-notifications.mjs`, `wrangler.jsonc` | Servicio de avisos por correo en Cloudflare |
| `repo-tests.mjs`, `package.json` | Pruebas locales sin correos reales |
| `INSTALACION.md` | Configuración, publicación, recuperación y pendientes |

## Verificación local

Con Node.js 22 o superior, desde esta carpeta:

```sh
npm test
```

No hace falta instalar dependencias para estas pruebas. Verifican la sintaxis de la aplicación, la confirmación de envío manual, el rechazo de solicitudes y las reglas del servicio de avisos.

## Recuperación de contraseña

1. El usuario solicita ayuda desde «Olvidé mi contraseña».
2. El superadministrador recibe la solicitud en la app y un aviso por correo.
3. El superadministrador busca al usuario en Supabase y pulsa **Send password recovery**.
4. El usuario abre el enlace recibido y elige su contraseña.
5. El superadministrador confirma en la app que envió el correo y marca la solicitud como atendida.

La app no pide al superadministrador una contraseña nueva para resolver una solicitud.

## Estado y límites

- La pantalla de recuperación y la función `import-users` fueron publicadas; el aviso Cloudflare–Supabase respondió correctamente en una prueba real.
- **Pendiente: configurar SMTP en Supabase para enviar recuperaciones a usuarios fuera del equipo del proyecto.** El correo predeterminado de Supabase no cubre esos destinatarios.
- La estructura de base de datos incluye 36 tablas, 13 funciones y 73 políticas. Se reconstruyó desde los catálogos del proyecto el 18/09/2026; todavía no se ensayó su instalación en un proyecto vacío.
- Google Drive conserva exactamente el código recuperado. Contiene una plantilla inicial junto al controlador de Drive: requiere revisión antes de volver a desplegarlo. Esta incorporación al repositorio no modifica la función en producción.
- El repositorio contiene código y estructura. No contiene registros de negocio, usuarios de Auth, documentos subidos, claves privadas ni tokens de conexión.

Consultar [INSTALACION.md](INSTALACION.md) antes de instalar o restaurar.
