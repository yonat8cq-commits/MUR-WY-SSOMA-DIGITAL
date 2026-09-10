# Configuración central Firebase

Proyecto: MUR WY SSOMA DIGITAL

1. Crear el proyecto en Firebase Console.
2. Registrar Android con `com.murwy.ssoma.digital`.
3. Descargar `google-services.json` y colocarlo en `android/app/`.
4. Habilitar Authentication, Cloud Firestore y Cloud Storage.
5. Implementar asignación de custom claims `role` y `dni` desde un entorno administrativo seguro.
6. Desplegar reglas e índices con `firebase deploy --only firestore,storage`.
7. Probar las reglas con Firebase Emulator Suite antes del entorno productivo.

Nunca se debe colocar una clave privada de cuenta de servicio dentro de Flutter o del repositorio.
El rol `SUPER_ADMIN` y el DNI deben asignarse únicamente mediante Admin SDK en un servidor confiable.
