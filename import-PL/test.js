const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

db.listCollections()
  .then(cols => {
    console.log("Collections:", cols.map(c => c.id));
  })
  .catch(err => {
    console.error("ERROR:", err);
  });