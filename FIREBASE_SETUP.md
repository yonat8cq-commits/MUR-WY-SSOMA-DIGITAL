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

Las cuentas de trabajadores usarán internamente el identificador
`DNI@auth.murwy.local`. Esta dirección técnica no es un correo real ni se muestra
al trabajador. Las cuentas y los claims deben provisionarse mediante Admin SDK;
la aplicación móvil nunca debe contener privilegios administrativos.

La cola offline ya puede enviar hasta 100 operaciones por ciclo a Firestore y
Storage. Las operaciones sin permisos o sin conexión permanecen pendientes con
el detalle del último error para volver a intentarlas posteriormente.

## Despliegue seguro desde GitHub

1. En GitHub abrir `Settings > Secrets and variables > Actions`.
2. Crear el secreto `FIREBASE_SERVICE_ACCOUNT_JSON` con el JSON completo de la
   cuenta de servicio del proyecto. No publicar ni confirmar este archivo.
3. Ejecutar el workflow `DESPLEGAR FIREBASE SEGURO` desde Actions.

El workflow valida que la credencial pertenezca a `mur-wy-ssoma-digital`, usa
Application Default Credentials y elimina el archivo temporal al finalizar.

## Provisionamiento de trabajadores

La herramienta `firebase-admin/provision-users.mjs` crea o actualiza cuentas,
asigna los claims `role: WORKER` y `dni`, y mantiene el documento central del
trabajador. La contraseña temporal se recibe únicamente mediante la variable
`MURWY_TEMPORARY_PASSWORD`; nunca se almacena en el repositorio.

Nunca se debe colocar una clave privada de cuenta de servicio dentro de Flutter o del repositorio.
El rol `SUPER_ADMIN` y el DNI deben asignarse únicamente mediante Admin SDK en un servidor confiable.
