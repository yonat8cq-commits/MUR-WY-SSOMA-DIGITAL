# Configuración central Firebase

Proyecto: MUR WY SSOMA DIGITAL

1. ~~Crear el proyecto en Firebase Console.~~ Completado.
2. ~~Registrar Android con `com.murwy.ssoma.digital`.~~ Completado.
3. ~~Descargar `google-services.json` y colocarlo en `android/app/`.~~ Completado.
4. Habilitar Authentication con el proveedor Correo electrónico/Contraseña.
5. Crear Cloud Firestore en modo producción.
6. Crear Cloud Storage. El bucket configurado es `mur-wy-ssoma-digital.firebasestorage.app`.
7. Implementar asignación de custom claims `role` y `dni` desde un entorno administrativo seguro.
8. Desplegar reglas e índices con `firebase deploy --only firestore,storage`.
9. Probar las reglas con Firebase Emulator Suite antes del entorno productivo.

La aplicación ya inicializa Firebase y Firebase Cloud Messaging al arrancar. Si no
hay conexión, conserva el funcionamiento local y la cola de sincronización.

Nunca se debe colocar una clave privada de cuenta de servicio dentro de Flutter o del repositorio.
El rol `SUPER_ADMIN` y el DNI deben asignarse únicamente mediante Admin SDK en un servidor confiable.
