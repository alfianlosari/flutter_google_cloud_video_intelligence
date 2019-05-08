# Flutter App using Google Cloud Video Intelligence API

![Alt text](./promo.png?raw=true "iOS & Android")

## Description
Google Cloud Video Intelligence API has pre-trained machine learning models that automatically recognize a vast number of objects, places, and actions in stored and streaming video.
- Client upload video to Google Cloud Storage
- A serveless function is triggered after a file uploaded that invokes the Video Intelligence API passing the bucket URI and bucket output URI
- The function also updates the status to a firestore collection
- The client listens in realtime the changes in the document, then retrieve the results when it finishes and display it in UI.


## Requirements
Firebase Account(https://firebase.google.com)
Flutter SDK (https://www.flutter.dev)
Firebase SDK (npm install -g firebase-tools)

## Getting Started
- Register for Firebase and create new project, set account to Blaze plan
- Initialize Firebase project in directory using SDK
- Go to functions folder and run npm install
- Go to root path and run firebase deploy --only functions to develop your functions trigger
- Create google-services-info.plist (iOS) and google-services.json (android) for a firebase app then copy to the flutter project
