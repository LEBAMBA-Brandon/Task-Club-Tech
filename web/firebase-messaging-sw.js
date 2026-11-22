/*
 * C-Tech Tasks — notifications web (Web Push) quand l'onglet est fermé ou en arrière-plan.
 *
 * Ce fichier doit rester à la racine du site publié (dossier web/ du projet Flutter,
 * copié tel quel dans build/web/). Firebase l'utilise automatiquement.
 * Les valeurs ci-dessous sont la configuration PUBLIQUE de l'application web Firebase
 * (les mêmes que dans lib/core/firebase/firebase_setup.dart).
 */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBTpWjnWAcA48zyn7jgWvJbqeUS4DqT1OY',
  authDomain: 'task-ctech.firebaseapp.com',
  projectId: 'task-ctech',
  storageBucket: 'task-ctech.firebasestorage.app',
  messagingSenderId: '755413969568',
  appId: '1:755413969568:web:53bebe56025735f096f7c5',
});

// Les messages avec titre/texte (nouvelle tâche, message, demande d'inscription)
// sont affichés automatiquement par Firebase ; un clic ouvre l'application.
firebase.messaging();
