# Restauración y traspaso
1. Destino nuevo, misma imagen5.0.8 y VOLUME_PREFIX diferente. No iniciar initialize ni app sobre el volumen nuevo antes de restaurar.
2. Recuperar .env y ops de respaldo confiable; conservar exactamente NR_CREDENTIAL_SECRET. Revisar hashes de configuración. Cambiar nombres/dominio según destino, no la clave de cifrado. Sin ella los nodos no podrán leer credenciales existentes.
3. `python3 scripts/restore.py /ruta/respaldo`. Exige volumen vacío/app detenida, valida hash y rutas y restauraUID1000. No sobrescribe datos.
4. Primer arranque: `docker compose -f compose.yaml -f compose.bootstrap.yaml -f compose.rehearsal.yaml up -d`. Modo seguro no ejecuta flujos; red interna impide salidas a Internet. Mantener ambos controles en ensayo.
5. Inspeccionar editor, nodos, credenciales disponibles, contextos y destinos externos. En safe mode, pulsar Deploy puede habilitar flujos: no hacerlo hasta revisar y desactivar conexiones reales. Red aislada evita llamadas externas, pero no acciones sobre otros servicios que conecte a la misma red.
6. Corte: detener origen/escritores, backup final, repetir en destino limpio, ajustar DNS/proxy y reactivar solo flujos verificados. Evitar dos copias activas: duplicarían cron, webhooks y efectos externos.

No usar contexto de memoria como dato respaldado. Restaurar a misma versión, luego ensayar actualización por separado. Si falla una extracción parcial, usar un volumen nuevo. Hashes detectan corrupción, no autentican el origen del backup.

Traspaso a Odoo/n8n: lógica y nodos no son portables automáticamente. Exportar JSON del flujo, documentar disparadores, entradas/salidas, credenciales, reintentos e idempotencia y reimplementar integración. No se instala módulo Odoo en este kit.
