# Guardado confirmado de stock

Los movimientos directos, ingresos y consumos ahora esperan confirmación de Supabase antes de cambiar la pantalla o mostrar éxito. La nueva RPC `commit_stock_action` actualiza existencias e inserta el historial en una transacción. Valida sesión, rol, ubicaciones, cantidad, moneda y versión del origen. Los ingresos calculan el costo promedio en el servidor. Los traslados crean el saldo de destino con sus identificadores propios.

Un identificador persistente por operación permite reintentar una respuesta interrumpida sin aplicar nuevamente el movimiento. Ante errores de validación del servidor la transacción se revierte; ante errores de conexión se conserva el identificador para reintentar. La pantalla ofrece el reintento y también lo recupera al volver a ingresar con el mismo usuario.

El historial se obtiene mediante `stock_movement_history` en cada carga de stock y se limpia de memoria al cerrar sesión. Se conservan los movimientos preexistentes. Las nuevas funciones privadas validan permisos explícitamente; sus envoltorios públicos usan `security invoker` y no permiten llamadas anónimas. No se habilitaron escrituras directas sobre el historial ni se ampliaron las políticas RLS existentes.

Las decisiones de solicitudes evitan envíos simultáneos. Las decisiones y despachos distinguen un guardado confirmado de un fallo posterior al refrescar la pantalla. La confirmación del modal espera callbacks asíncronos. Se actualizó la caché y el paquete público para incluir el nuevo módulo.

## Estado de instalación

La migración aditiva `supabase/016_confirmed_stock_actions.sql` se aplicó al proyecto existente Gestion Phelox durante esta corrección. No volver a ejecutar `database-schema.sql` sobre ese proyecto. Para otra instalación, aplicar esta migración después de disponer del esquema y las funciones privadas de stock anteriores.

El frontend requiere publicar los archivos de esta rama. El cambio en Supabase por sí solo no reemplaza los manejadores antiguos del sitio. El despliegue de Cloudflare conserva su configuración actual y usa `node prepare-static.mjs`. La actualización de la app instalada debe tomar la nueva versión de `sw.js`.

## Verificación

- Diez escenarios de JavaScript: espera de confirmación sin cambiar stock, reintento después de reabrir con el mismo ID, error de servidor sin falso éxito, doble confirmación, cantidades decimales, fallo de refresco después del guardado, recarga de historial, rechazo del guardado sin sesión, modal asíncrono y decisiones de solicitudes.
- Pruebas de regresión existentes y preparación del paquete estático.
- Pruebas en Supabase con el rol `authenticated`, revertidas al finalizar: traslado atómico, reintentos idempotentes, payload cambiado, versión desactualizada, stock insuficiente, ingreso, consumo, costo promedio y rechazo de escrituras de un chofer.
- Fallo forzado después de descontar el origen: la cantidad, versión e historial se revierten juntos. La preparación de esa prueba también se revirtió.
- Verificación final: permanecen los cuatro movimientos anteriores y no quedan recibos de operaciones de prueba.

La auditoría de Supabase conserva avisos sobre funciones y configuración anteriores a este cambio. La tabla privada de recibos tiene RLS sin políticas y permisos directos revocados deliberadamente; solo la función controlada accede a ella.

No se realizó una prueba manual en el navegador con una cuenta real ni se publicó el frontend durante la preparación. El resto de las acciones de la aplicación requiere una revisión independiente; este cambio cubre el flujo de stock indicado arriba, no afirma que todos los módulos ya guarden en la nube.
