const { AbiCoder } = require("ethers");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree") ;
const bs_cached = require("./target/bs_cached_output.json");
const tx_cached = require("./target/tx_cached_output.json");

function padToBytes32(hexStr) {
    if (hexStr.startsWith("0x")) {
        hexStr = hexStr.slice(2);
    }
    while (hexStr.length < 64) {
        hexStr = '0' + hexStr;
    }
    return "0x" + hexStr;
}

async function main() {
    const datalakeType = process.argv[2];
    let cached;
  
    if (datalakeType === "bs") {
      cached = bs_cached;
    } else if (datalakeType === "tx") {
      cached = tx_cached;
    } else {
      process.exit(1);
    }
    const encoder =  new AbiCoder();
    usedMMRs = cached["mmr_metas"];
    mmrIds = usedMMRs.map((mmr) => mmr["id"]);
    mmrSizes = usedMMRs.map((mmr) => mmr["size"]);
    mmrRoots = usedMMRs.map((mmr) => padToBytes32(mmr["root"]));
    resultsMerkleRoot = cached["results_root"];
    tasksMerkleRoot = cached["tasks_root"];
    tasksCommitments = cached["tasks_commitments"];
    resultsCommitments = cached["results_commitments"];
    rawResults = cached["raw_results"];
    const tasksMerkleTree = StandardMerkleTree.of([tasksCommitments], ["bytes32"], { sortLeaves: false });
    const resultsMerkleTree = StandardMerkleTree.of([resultsCommitments], ["bytes32"], { sortLeaves: false });
    tasksInclusionProofs = tasksCommitments.map(commit => tasksMerkleTree.getProof(tasksCommitments.indexOf(commit)));
    resultsInclusionProofs = resultsCommitments.map(commit => resultsMerkleTree.getProof(resultsCommitments.indexOf(commit)));


    const abiEncodedResult = encoder.encode(
        ["uint256[]", "uint256[]", "bytes32[]", "bytes32", "bytes32", "bytes32[][]", "bytes32[][]", "bytes32[]", "bytes32[]"],
        [   mmrIds,
            mmrSizes,
            mmrRoots,
            tasksMerkleRoot,
            resultsMerkleRoot,
            tasksInclusionProofs,
            resultsInclusionProofs,
            tasksCommitments,
            rawResults,
        ]
      );
      console.log(abiEncodedResult);
}

main();