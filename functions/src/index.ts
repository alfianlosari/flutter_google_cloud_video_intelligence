import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const runtimeOpts = {
    timeoutSeconds: 360,
}

const resultsCollection = admin.firestore().collection('results');

exports.storage = functions.runWith(runtimeOpts).storage.object().onFinalize(async (object) => {

    const video = require('@google-cloud/video-intelligence').v1;
    const client = new video.VideoIntelligenceServiceClient();

    const gcsUri = getGSURL(object);

    if (gcsUri.includes('.json')) {
        let filenameJSON = object.name!.replace('.json', '');

        try {
            const userRef = resultsCollection.doc(filenameJSON);
            await userRef.set({
                status: 'finished',
                location: gcsUri
            });
        } catch (error) {
            throw error;
        }
        return true;

    }

    if (!gcsUri.includes('.mp4')) {
        return true;
    }

    const request = {
        inputUri: gcsUri,
        outputUri: gcsUri.replace('.mp4', '.json'),
        features: ['LABEL_DETECTION'],
    };

    let filename = object.name!.replace('.mp4', '');

    try {
        const userRef = resultsCollection.doc(filename);
        await userRef.set({
            status: 'starting'
        });
    } catch (error) {
        throw error;
    }

    return client.annotateVideo(request);
})

function getGSURL(object: functions.storage.ObjectMetadata): string {
    let arr = object.id.split('/');
    arr.pop();
    return `gs://${arr.join('/')}`
}
