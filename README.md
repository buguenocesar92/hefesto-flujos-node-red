# Hefesto Flujos · Node-RED 5.0.8

Automatizaciones visuales y endpoints HTTP usando Node-RED nativo. Kit para Coolify/VPS con editor autenticado, demo local, datos persistentes, respaldos y restauración en modo seguro. No es una instancia ya desplegada ni conecta sistemas reales.

## Stack
Imagen oficial fijada por digest; datos en /data. No requiere Supabase ni otra base externa. Las credenciales configuradas en nodos se cifran en flows_cred.json usando NR_CREDENTIAL_SECRET del entorno; conservar esa clave. Los flujos/contexts pueden contener información sin cifrar: no escribir secretos como texto dentro de funciones o mensajes.

La carpeta persistente contiene flujos, credenciales, contexto durable y configuración de ejecución. No se monta Docker socket ni carpetas del host para ejecutar administración de servidores. Una instancia por cliente recomendada.

## Preparar credenciales
1. `python3 scripts/configure.py` crea .env0600 y clave de cifrado única. No regenerar NR_CREDENTIAL_SECRET en una instalación existente.
2. Generar dos hashes con el comando oficial (uno por contraseña, distintas entre sí):
```
docker run --rm -it --entrypoint node-red nodered/node-red:5.0.8@sha256:b5adb6c9dd29ab80c852d82bc87daed84e729dcff9b00ca1bf958e6de470f2c1 admin hash-pw
```
3. Copiar solo cada hash a NR_ADMIN_HASH y NR_HTTP_HASH, conservando comillas simples en .env para que Compose no interprete los signos $. Usar bcrypt coste8–16 (el comando nativo normalmente genera coste adecuado). Nunca pegar contraseña plana como hash ni usar ejemplos públicos.
4. En Coolify, si introduce variables en su interfaz, colocar valor literal completo del hash sin comillas de .env y comprobar que los signos $ se conservan al arrancar. No publicar la salida de docker compose config, porque incluye secretos. La app rechaza hashes/secreto inválidos.

NR_ADMIN_USER accede a editor/API administrativa; NR_HTTP_USER protege endpoints creados por nodos HTTP. Son accesos separados. HTTP usa Basic Auth, siempre sobre HTTPS cuando no sea túnel privado. El kit no implementa JWT ni tokens por cliente para esos endpoints.

## Arranque privado y Coolify
Requisitos: Docker + Compose v2 y Python3.11+; comenzar con 1CPU/1GB y dimensionar según flujos reales.

1. `docker compose -f compose.yaml -f compose.bootstrap.yaml up -d`. La inicialización copia demo solo en volumen vacío; no pisa flujos existentes. PropietarioUID1000.
2. Abrir http://localhost:8106/editor/. Remoto: `ssh -L 8106:127.0.0.1:8106 usuario@servidor`. Autenticarse con cuenta de editor.
3. Probar botón manual y consultar `/api/hefesto/health` con credencial HTTP. Sin credencial debe devolver401. Ejemplo: `curl -u integracion-demo http://localhost:8106/api/hefesto/health` pide la contraseña interactivamente. La demo no hace solicitudes externas y no se dispara por temporizador.
4. Detener override: `docker compose -f compose.yaml -f compose.bootstrap.yaml down` sin -v.
5. Coolify: importar compose.yaml con ops y examples; variables .env; dominio HTTPS al servicio app1880. No publicar override bootstrap. Editor en /editor/, endpoints en /api/. Proxy con WebSocket y límites de cuerpo/tiempo acordes al flujo.
6. Restringir /editor por VPN/IP en proxy si los clientes solo consumen /api. Mantener autenticación de Node-RED. No exponer1880 directamente. Probar rechazo a /editor/flows sin token y a endpoint HTTP sin credenciales.

No hay instalación de paquetes desde paleta ni módulos externos en Function habilitada. Para agregar nodos revisar licencia/seguridad y construir imagen propia con versiones bloqueadas; no activar instalación arbitraria en producción. Proyectos Git deshabilitados inicialmente.

## Contexto, operación y respaldo
Contexto por defecto en memoria; elegir store durable explícitamente cuando necesite persistencia. El store localfilesystem puede tener escrituras diferidas: no es una transacción financiera ni garantía de entrega. Detener de forma ordenada antes del backup.

`python3 scripts/backup.py` pausa app, copia todo /data y configuración/secreto, genera hashes y reinicia si estaba activa. Usar modo producción base, no durante bootstrap. Programar ventana para no interrumpir trabajos y diseñar reintentos/idempotencia en integraciones reales.

Ver docs/RESTORE.md y docs/ACCEPTANCE.md. Cifrar backups fuera del servidor: incluyen clave que descifra credenciales. Estado: configuración/ejemplos revisados localmente; sin Docker ni ejecución real de Node-RED en este entorno.
