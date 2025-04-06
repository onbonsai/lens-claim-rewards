import yargs from "yargs";
import { hideBin } from "yargs/helpers";

import * as fs from "fs";
import csv from "csv-parser";
import { keccak256, toBuffer } from "ethereumjs-util";
import { MerkleTree } from "merkletreejs";
import { parseUnits, solidityPack } from "ethers/lib/utils";

interface CsvRow {
  eoa: string;
  claimScoreBbps: number;
}

const MERKLE_CLAIM_AMOUNT_MAX = 10_000; // 10k bonsai

/*
USAGE: put your csv in the root dir and run

npx ts-node ./ts-scripts/merkleClaimTree.ts --csvInputFile="merkle_claim_tree_input.csv" --jsonOutputFile="merkle_claim_tree_output.json"
*/
(async () => {
  const {
    csvInputFile,
    jsonOutputFile,
    includeLeaves = false, // optionally include the leaves in the output
    includeLayers = false, // optionally include the layers in the output
  } = yargs(hideBin(process.argv))
    .option("csvInputFile", { type: "string", demandOption: true })
    .option("jsonOutputFile", { type: "string", demandOption: true })
    .option("includeLeaves", { type: "boolean" })
    .option("includeLayers", { type: "boolean" })
    .parse();

  const csvData: CsvRow[] = [];

  fs.createReadStream(csvInputFile)
    .pipe(csv())
    .on("data", (data: CsvRow) => csvData.push(data))
    .on("end", () => {
      const leaves = csvData.map((row, index) => {
        return keccak256(
          toBuffer(
            solidityPack(
              ["address", "uint16"],
              [row.eoa, row.claimScoreBbps]
            )
          )
        );
      });

      const tree = new MerkleTree(leaves, keccak256, { sort: true });
      const root = tree.getHexRoot();

      const userData = {};
      csvData.forEach((row, index) => {
        userData[row.eoa] = {
          proof: tree.getHexProof(leaves[index]),
          eoa: row.eoa,
          claimScoreBbps: row.claimScoreBbps,
          claimableAmount: parseUnits((MERKLE_CLAIM_AMOUNT_MAX * (row.claimScoreBbps / 10000)).toString(), 18).toString()
        };
      });

      const treeJson = {
        root,
        userData,
        ...(includeLeaves
          ? { leaves: leaves.map((leaf) => "0x" + leaf.toString("hex")) }
          : {}),
        ...(includeLayers
          ? {
              layers: tree
                .getLayers()
                .map((layer) => layer.map((buf) => "0x" + buf.toString("hex"))),
            }
          : {}),
      };

      fs.writeFileSync(jsonOutputFile, JSON.stringify(treeJson, null, 2));
    });
})();
