const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

admin.initializeApp({
  credential: admin.credential.cert('../../../Documents/GoogleCerts/daily-lockz-firebase-adminsdk-os684-05417a328a.json'),
  databaseURL: 'https://daily-lockz.firebaseio.com'
});

const db = admin.firestore();
const blogPostsDirectory = '../../../trevorAppsWebsites/daily-lockz/src/blog-posts';
const allowedExtensions = ['.md'];

fs.readdir(blogPostsDirectory, (err, files) => {
  if (err) {
    console.error(err);
    return;
  }

  files.forEach((file) => {
    const fileExtension = path.extname(file);

    if (allowedExtensions.includes(fileExtension)) {
      const filePath = path.join(blogPostsDirectory, file);

      fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
          console.error(err);
          return;
        }

        const blogPostRef = db.collection('blog-posts').doc(file);
        blogPostRef.get().then((doc) => {
          if (doc.exists) {
            if (doc.data().content === data) {
              console.log(`Skipping ${file} (no changes detected)`);
            } else {
              blogPostRef.set({ content: data })
                .then(() => {
                  console.log(`Updated ${file} in Firestore`);
                })
                .catch((error) => {
                  console.error(`Error updating ${file}:`, error);
                });
            }
          } else {
            blogPostRef.set({ content: data })
              .then(() => {
                console.log(`Uploaded ${file} to Firestore`);
              })
              .catch((error) => {
                console.error(`Error uploading ${file}:`, error);
              });
          }
        });
      });
    } else {
      console.log(`Skipping ${file} (not an allowed file extension)`);
    }
  });
});
