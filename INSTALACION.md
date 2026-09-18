# Instalación y operación de PHELOX

## Instalación existente

El sitio está vinculado al repositorio `pheloxjuan/14-7`. Conservar su configuración de publicación. Los archivos del frontend están en la raíz y no requieren compilación.

Los cambios de código en GitHub no despliegan por sí solos las funciones de Supabase ni el servicio de correo: cada servicio tiene su propio despliegue.

**No ejecutar `database-schema.sql` sobre el proyecto actual.** Incluye una comprobación que detiene la ejecución si ya existe `public.profiles`.

## Proyecto nuevo

1. Crear un proyecto Supabase de prueba. Conservar una copia de seguridad antes de cualquier restauración.
2. Revisar y ejecutar `database-schema.sql` como administrador en ese proyecto vacío. Supabase debe aportar sus esquemas `auth`, `storage`, `extensions`, sus roles y la publicación `supabase_realtime`.
3. La base ya incorpora los cambios históricos disponibles en `supabase/*.sql`; no volver a aplicarlos todos después de esta base.
4. Revisar `database-inventory.json`: las extensiones y automatismos propios de la plataforma son un inventario, no instrucciones para reemplazar la configuración administrada por Supabase.
5. Crear los usuarios mediante Supabase Auth y sus perfiles/asignaciones mediante el flujo administrativo. Esta base no crea cuentas, empresas, vehículos ni stock. El primer superadministrador debe vincularse a un usuario Auth real, con el rol `superadministrador` y activo, por un administrador autorizado.
6. Configurar las URL de Auth, las claves públicas del frontend y los servicios que se detallan debajo. No usar el proyecto de producción para pruebas locales.
7. Probar acceso, permisos y operaciones en el nuevo proyecto antes de usarlo con datos reales.

La base se reconstruyó mediante consultas de solo lectura: tablas, tipos, funciones, restricciones, índices, políticas, permisos, configuración de buckets y membresía Realtime. No reemplaza un respaldo completo de Supabase ni un `pg_dump` validado. No se han restaurado sus objetos en otro servidor durante esta entrega. No contiene archivos del bucket, secretos, datos de Auth ni filas de tablas.

## Frontend

- `index.html` contiene `SUPABASE_URL`, la clave publicable y la clave pública VAPID del proyecto actual. Para otro proyecto deben cambiarse por sus valores públicos correspondientes.
- No colocar claves `service_role`, claves privadas VAPID, secretos OAuth ni `NOTIFY_TOKEN` en el frontend.
- Mantener `sw.js`, el manifest y las imágenes en la raíz. Al modificar el comportamiento de la app, actualizar la versión de caché de `sw.js`.
- Para ver cambios publicados, cerrar y volver a abrir la app o recargar la página. Las operaciones de Supabase requieren conexión.

## Funciones Supabase

| Función | Configuración privada necesaria |
| --- | --- |
| `import-users` | Variables proporcionadas por Supabase: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` |
| `push-repair` | Las anteriores y `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` |
| `google-drive` | Las variables Supabase y `GOOGLE_DRIVE_CLIENT_ID`, `GOOGLE_DRIVE_CLIENT_SECRET`, `GOOGLE_DRIVE_APP_URL`, `GOOGLE_DRIVE_REDIRECT_URI` |

Guardar esos valores en **Edge Functions → Secrets**, nunca en GitHub. No se incluyeron sus valores en este repositorio.

El archivo `supabase/config.toml` conserva la configuración versionada previamente para `push-repair`. Antes de desplegar otras funciones, comprobar también sus ajustes vigentes en el panel: no se exportó la configuración privada ni se cambiaron sus controles de autenticación.

La copia de `google-drive/index.ts` proviene del editor de la función existente. Al principio tiene una plantilla con `withSupabase`, seguida del código de Drive con `Deno.serve`. Se conserva como referencia fiel, sin desplegarla de nuevo. Antes de un despliegue nuevo, revisar esa combinación, el retorno OAuth y las autorizaciones Google. Los tokens almacenados en las tablas de Drive no están en el repositorio.

## Avisos de recuperación por correo

El Worker `password-notifications.mjs` envía un aviso al destinatario fijo configurado; no envía el enlace de recuperación ni modifica contraseñas.

Configuración de Cloudflare:

- Nombre: `phelox-password-notifications`.
- Código de entrada: `password-notifications.mjs`.
- Binding Email: `EMAIL`.
- Destinatario verificado: `juancruz19@hotmail.com`.
- Remitente del dominio: `avisos@pheloxapp.com`.
- Secreto: `NOTIFY_TOKEN`, aleatorio de al menos 32 caracteres, guardado únicamente como secreto.

`wrangler-notifications.jsonc` permite versionar el nombre, la entrada y el binding. La configuración declara explícitamente el único destinatario. Las credenciales de acceso a Cloudflare deben gestionarse fuera del repositorio.

Para desplegar únicamente el servicio de avisos con Wrangler instalado y autenticado, indicar expresamente `wrangler deploy --config wrangler-notifications.jsonc`. El nombre separado evita que una publicación automática del sitio use la configuración del correo por accidente.

En Supabase, instalar Database Webhooks y crear:

| Campo | Valor |
| --- | --- |
| Nombre | `phelox_password_notifications` |
| Tabla | `public.password_reset_requests` |
| Evento | Solo `INSERT` |
| Método | `POST` |
| URL actual | `https://phelox-password-notifications.juancruz19.workers.dev/` |
| Timeout | `10000` ms |
| Content-type | `application/json` |
| Authorization | `Bearer <NOTIFY_TOKEN guardado en Cloudflare>` |

El trigger con su encabezado privado se excluyó intencionalmente de la exportación SQL. No pegar el token real en este archivo ni en consultas que se vayan a publicar. En otro despliegue, sustituir la URL y el secreto por los nuevos valores.

Las pruebas locales simulan el envío. La integración real fue comprobada con una solicitud técnica y respuesta HTTP 200; esas solicitudes quedaron canceladas. El Worker no implementa reintentos automáticos ni deduplicación. Ante un error de entrega, la solicitud permanece en la app para revisión.

## Correo de recuperación para todos los usuarios: pendiente

El aviso al superadministrador y el correo de recuperación de Supabase son envíos diferentes. Cloudflare ya envía el aviso al destinatario verificado. **Falta configurar un proveedor SMTP en Authentication → Emails → SMTP Settings** para que Supabase envíe recuperaciones fuera del equipo del proyecto.

El proveedor, el remitente verificado y sus credenciales deben ser configurados por el titular. No se contrató ningún plan ni se crearon credenciales de un proveedor nuevo. Hasta completar este paso, no considerar terminado el flujo para todos los usuarios.

Documentación oficial: https://supabase.com/docs/guides/auth/auth-smtp

## Verificación antes de una puesta en marcha nueva

- Ejecutar `npm test` con Node.js 22 o superior.
- Probar el esquema en un proyecto vacío y verificar permisos con cada rol, no solo como administrador.
- Confirmar recepción del aviso en el correo del superadministrador.
- Probar **Send password recovery** con un usuario fuera del equipo del proyecto, una vez configurado SMTP.
- Dejar que el propio usuario elija su contraseña y verificar su acceso posterior.
- Verificar notificaciones en la app, funcionamiento móvil y actualización de caché.
- Realizar una prueba separada de Google Drive antes de habilitar sus respaldos.
