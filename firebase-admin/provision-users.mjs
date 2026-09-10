import { readFile } from 'node:fs/promises';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const [, , inputPath] = process.argv;
if (!inputPath) {
  throw new Error('Uso: node provision-users.mjs trabajadores.json');
}

const workers = JSON.parse(await readFile(inputPath, 'utf8'));
if (!Array.isArray(workers)) {
  throw new Error('El archivo debe contener una lista JSON de trabajadores.');
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const firestore = getFirestore();
const temporaryPassword = process.env.MURWY_TEMPORARY_PASSWORD;
if (!temporaryPassword || temporaryPassword.length < 8) {
  throw new Error('Define MURWY_TEMPORARY_PASSWORD con al menos 8 caracteres.');
}

let created = 0;
let updated = 0;
for (const worker of workers) {
  const dni = String(worker.dni ?? '').trim();
  if (!/^\d{8}$/.test(dni)) {
    throw new Error(`DNI inválido: ${dni || '(vacío)'}`);
  }
  const email = `${dni}@auth.murwy.local`;
  let user;
  try {
    user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, { disabled: worker.active === false });
    updated++;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({
      email,
      password: temporaryPassword,
      displayName: String(worker.full_name ?? dni),
      disabled: worker.active === false,
    });
    created++;
  }
  await auth.setCustomUserClaims(user.uid, { role: 'WORKER', dni });
  await firestore.collection('users').doc(dni).set({
    uid: user.uid,
    dni,
    full_name: String(worker.full_name ?? ''),
    company: String(worker.company ?? ''),
    area: String(worker.area ?? ''),
    position: String(worker.position ?? ''),
    account_status: worker.active === false ? 'INACTIVO' : 'ACTIVO',
    requires_password_change: true,
    updated_at: FieldValue.serverTimestamp(),
  }, { merge: true });
}

console.log(`Provisionamiento completado: ${created} creados, ${updated} actualizados.`);
