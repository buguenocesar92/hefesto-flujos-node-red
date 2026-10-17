# Próximos flujos de negocio
- Recibir un evento autorizado y transformar datos para Odoo.
- Consultar estado de una tarea y notificar vía Hefesto Alertas.
- Validar payload antes de llamar una API de cliente.

Estos casos son propuestas: solo se incluye demo local. Node-RED puede ejecutar código con permisos del contenedor; la cuenta de editor es de confianza, no se entrega a usuarios finales de un portal.

Supabase puede ser un sistema externo futuro mediante API o nodo PostgreSQL revisado, pero no se usa como base interna de Node-RED. Nunca usar service_role en navegador ni mezclar datos de clientes sin permisos. No se incluye un nodo PostgreSQL adicional ni conexión configurada.

La autenticación HTTP global básica sirve para demo o una integración controlada. Para múltiples consumidores con scopes, revocación y límites individuales, incorporar gateway/autenticación de aplicación antes de exponer operaciones CRUD. No confundir token de API administrativa (permite gestionar flujos) con token de negocio.

Diseñar errores y reintentos para que un timeout no duplique pagos/pedidos. No conectar cobros o mensajes reales hasta validar destinatarios y permisos. Guardar contraseñas en campos de credenciales o gestores de secretos, nunca en nodos Function/Debug.
