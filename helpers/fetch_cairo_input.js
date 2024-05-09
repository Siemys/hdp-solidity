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
    usedMmrId =cached["mmr"]["id"];
    usedMmrSize = cached["mmr"]["size"];
    usedMmrRoot = padToBytes32(cached["mmr"]["root"]);
    resultsMerkleRoot = cached["results_root"];
    tasksMerkleRoot = cached["tasks_root"];
    tasks_list = cached["tasks"]
    tasksCommitments = tasks_list.map((task) => task["task_commitment"]);
    results = tasks_list.map((task) => {
        const bigIntValue = BigInt(task["compiled_result"]);
        const hexString = "0x" + bigIntValue.toString(16).padStart(64, "0");
        return hexString;
    });
    const tasksMerkleTree = StandardMerkleTree.of([tasksCommitments], ["bytes32"], { sortLeaves: false });
    const resultsMerkleTree = StandardMerkleTree.of([results], ["bytes32"], { sortLeaves: false });
    tasksInclusionProofs = tasksCommitments.map(commit => tasksMerkleTree.getProof(tasksCommitments.indexOf(commit)));
    resultsInclusionProofs = results.map(commit => resultsMerkleTree.getProof(results.indexOf(commit)));

    const abiEncodedResult = encoder.encode(
        ["uint256", "uint256", "bytes32", "bytes32", "bytes32", "bytes32[][]", "bytes32[][]", "bytes32[]", "bytes32[]"],
        [   usedMmrId,
            usedMmrSize,
            usedMmrRoot,
            tasksMerkleRoot,
            resultsMerkleRoot,
            tasksInclusionProofs,
            resultsInclusionProofs,
            tasksCommitments,
            results,
        ]
      );
      console.log(abiEncodedResult);
}

main();