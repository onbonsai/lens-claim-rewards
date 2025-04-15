import yargs from "yargs";
import { hideBin } from "yargs/helpers";

import * as fs from "fs";
import csv from "csv-parser";
import { getAddress, parseEther, solidityPack } from "ethers/lib/utils";
import { LensClient, production, LimitType } from "@lens-protocol/client";
import { groupBy } from "lodash/collection";
import pLimit from 'p-limit'
import { createObjectCsvWriter } from 'csv-writer';

const lensClient = new LensClient({ environment: production });

interface CsvRow {
    address: string;
    score: number;
}

// LENS V2
async function fetchAllProfiles(owners: string[]) {
    const promiseLimit = pLimit(5);
    const BATCH_SIZE = 25;
    const allProfiles: any[] = [];

    for (let i = 0; i < owners.length; i += BATCH_SIZE) {
        const _owners = owners.slice(i, i + BATCH_SIZE);
        let cursor: any | null = null;

        while (true) {
            const result = await promiseLimit(async () => {
                return await lensClient.profile.fetchAll({
                    where: { ownedBy: _owners },
                    cursor
                });
            });

            allProfiles.push(...result.items);

            if (result.pageInfo.next) {
                cursor = result.pageInfo.next;
            } else {
                break;
            }
        }
    }

    return allProfiles;
}

async function processProfileBatch(addresses: string[]) {
    const profiles = await fetchAllProfiles(addresses);
    return groupBy(profiles, p => getAddress(p.ownedBy.address));
}

/*
USAGE: put your rankings csv in the root dir and run

npx ts-node ./ts-scripts/processEigentrustRankings.ts --csvInputFile="eigentrust_rankings.csv" --csvOutputFile="merkle_claim_tree_input.csv"
*/
(async () => {
    const {
        csvInputFile,
        csvOutputFile,
    } = yargs(hideBin(process.argv))
        .option("csvInputFile", { type: "string", demandOption: true })
        .option("csvOutputFile", { type: "string", demandOption: true })
        .parse();

    const csvData: CsvRow[] = [];

    fs.createReadStream(csvInputFile)
        .pipe(csv())
        .on("data", (data: CsvRow) => csvData.push(data))
        .on("end", async () => {
            // Filter out very low scores and get min/max for scaling
            const MIN_SCORE_THRESHOLD = 0.00008; // Filter out scores below 0.08%
            const BONSAI_MULTISIG = "0xff9730b6534087d07692c1262f916521966244e6";
            const filteredData = csvData.filter(row => row.score >= MIN_SCORE_THRESHOLD && row.address !== BONSAI_MULTISIG);

            const maxScore = Math.max(...filteredData.map(row => row.score));
            const minScore = Math.min(...filteredData.map(row => row.score));

            const csvWriter = createObjectCsvWriter({
                path: csvOutputFile,
                header: [
                    { id: 'address', title: 'address' },
                    { id: 'claimScoreBps', title: 'claimScoreBps' },
                    { id: 'handle', title: 'handle' }
                ]
            });

            // Process in larger batches for the main loop
            const BATCH_SIZE = 100;
            const totalBatches = Math.ceil(filteredData.length / BATCH_SIZE);
            const allRecords: any[] = [];
            let totalAmount = 0;

            for (let i = 0; i < filteredData.length; i += BATCH_SIZE) {
                const batch = filteredData.slice(i, i + BATCH_SIZE);
                console.log(`Processing batch ${Math.floor(i/BATCH_SIZE) + 1}/${totalBatches}...`);

                const grouped = await processProfileBatch(batch.map(row => row.address));

                const batchRecords = batch.map(row => {
                    const logScore = Math.log(row.score);
                    const logMin = Math.log(minScore);
                    const logMax = Math.log(maxScore);
                    const normalizedScore = (logScore - logMin) / (logMax - logMin);
                    const scaledScore = Math.round(4000 + (normalizedScore * 6000));

                    const normalizedAddress = getAddress(row.address);
                    totalAmount += scaledScore;

                    return {
                        address: normalizedAddress,
                        claimScoreBps: scaledScore,
                        handle: grouped[normalizedAddress] ?
                            (grouped[normalizedAddress][0]?.handle?.localName ||
                             grouped[normalizedAddress][0]?.metadata?.displayName) : null
                    };
                });

                allRecords.push(...batchRecords);
            }

            console.log(`Processed ${allRecords.length} records. Total claim score: ${totalAmount.toLocaleString()}`);
            await csvWriter.writeRecords(allRecords);
            console.log(`Successfully wrote to ${csvOutputFile}`);
        });
})();
