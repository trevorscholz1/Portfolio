const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert('../../../Documents/GoogleCerts/daily-lockz-firebase-adminsdk-os684-05417a328a.json'),
  databaseURL: 'https://daily-lockz.firebaseio.com'
});

const db = admin.firestore();

// Specify the directory containing your blog posts
const blogPostsDirectory = '../../../trevorAppsWebsites/daily-lockz/src/blog-posts';

// Specify the file extensions to upload (e.g., .txt, .md, .html)
const allowedExtensions = ['.txt', '.md', '.html'];

// Read all files in the directory
fs.readdir(blogPostsDirectory, (err, files) => {
  if (err) {
    console.error(err);
    return;
  }

  files.forEach((file) => {
    // Get the file extension
    const fileExtension = path.extname(file);

    // Check if the file has an allowed extension
    if (allowedExtensions.includes(fileExtension)) {
      // Construct the full path to the file
      const filePath = path.join(blogPostsDirectory, file);

      // Read the file contents
      fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
          console.error(err);
          return;
        }

        // Upload the file contents to Firestore
        const blogPostRef = db.collection('blog-posts').doc(file);
        blogPostRef.set({ content: data })
          .then(() => {
            console.log(`Uploaded ${file} to Firestore`);
          })
          .catch((error) => {
            console.error(`Error uploading ${file}:`, error);
          });
      });
    } else {
      console.log(`Skipping ${file} (not an allowed file extension)`);
    }
  });
});
