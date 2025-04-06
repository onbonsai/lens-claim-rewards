import dotenv from 'dotenv';
import { join } from 'path';
dotenv.config({ path: join(__dirname, '../.env') });
import { MongoClient } from 'mongodb';

import merkleJson from '../merkle_claim_tree_output.json'

const _client = async () => {
    if (!process.env.MONGO_URI) throw new Error("missing env: MONGO_URI");
    const client = new MongoClient(process.env.MONGO_URI as string);
    await client.connect();
    return client;
};

const getMongoCollection = async (__client?: any) => {
    if (!process.env.MONGO_DB) throw new Error("missing env: MONGO_DB");
    if (!process.env.MONGO_COLLECTION) throw new Error("missing env: MONGO_COLLECTION");
    const client = __client || await _client();
    const database = client.db(process.env.MONGO_DB as string);
    const collection = database.collection(process.env.MONGO_COLLECTION as string);

    return { client, collection };
};

/*
USAGE: after generating your tree, upload the output json to mongon collection

npx ts-node ./ts-scripts/uploadMongo.ts
*/
(async () => {
    try {
        const { client, collection } = await getMongoCollection();

        console.log(`merkle leaves: ${Object.keys(merkleJson.userData).length}`);
        const bulkOps = Object.entries(merkleJson.userData).map(([accountAddress, data]) => ({
            insertOne: {
                document: {
                    root: merkleJson.root,
                    eoa: data.eoa,
                    accountAddress,
                    createdAt: Math.floor(Date.now() / 1000),
                    proof: data.proof.join(".")
                }
            }
        }));

        const result = await collection.bulkWrite(bulkOps);
        console.log('Inserted records:', result.insertedCount);

        await client.close();
    } catch (error) {
        console.log(error);
        throw new Error();
    }
})();