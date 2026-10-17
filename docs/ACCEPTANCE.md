# Aceptación pendiente en Docker
- compose config --quiet; hashes preservados sin interpolación y clave secreta configurada.
- App rechaza valores vacíos o hash inválido.
- Editor exige login; API /editor/flows rechaza peticiones sin token.
- Endpoint /api/hefesto/health exige Basic Auth; contraseña del editor no sirve como acceso HTTP salvo que usted las iguale (evitarlo).
- Demo responde JSON y botón manual llega a Debug, sin llamadas externas.
- Reinicio conserva cambios y credenciales de una conexión de prueba.
- Paleta/instalación de módulos cerrada; WebSocket del editor funciona detrás de proxy.
- Copia y restauración con clave original, en modo seguro y red interna.
- Contexto durable verificado y contexto memoria no considerado persistente.
- Monitoreo, límites de recursos, retención y mantenimiento acordados.

Local: sintaxis JS/Python/shell, YAML, estructura de flujo y evaluación de settings con variables sintéticas. No equivale a ejecutar runtime Node-RED ni probar bcrypt/login reales.
