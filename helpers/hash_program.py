import argparse
import json

from starkware.cairo.common.hash_chain import compute_hash_chain
from starkware.cairo.lang.compiler.program import Program, ProgramBase
from starkware.cairo.lang.version import __version__
from starkware.cairo.lang.vm.crypto import (
    get_crypto_lib_context_manager,
    poseidon_hash_many,
)
from starkware.python.utils import from_bytes


def compute_program_hash_chain(
    program: ProgramBase, use_poseidon: bool, bootloader_version=0
):
    """
    Computes a hash chain over a program, including the length of the data chain.
    """
    builtin_list = [from_bytes(builtin.encode("ascii")) for builtin in program.builtins]
    # The program header below is missing the data length, which is later added to the data_chain.
    program_header = [
        bootloader_version,
        program.main,
        len(program.builtins),
    ] + builtin_list
    data_chain = program_header + program.data

    if use_poseidon:
        return poseidon_hash_many(data_chain)
    return compute_hash_chain([len(data_chain)] + data_chain)


def pad_to_bytes32(hex_str):
    if hex_str.startswith("0x"):
        hex_str = hex_str[2:]

    padded_hex = hex_str.zfill(64)

    return "0x" + padded_hex


parser = argparse.ArgumentParser(
    description="A tool to compute the hash of a cairo program"
)
parser.add_argument(
    "-v", "--version", action="version", version=f"%(prog)s {__version__}"
)
parser.add_argument(
    "--program",
    type=argparse.FileType("r"),
    required=True,
    help="The name of the program json file.",
)
parser.add_argument(
    "--flavor",
    type=str,
    default="Release",
    choices=["Debug", "Release", "RelWithDebInfo"],
    help="Build flavor",
)
parser.add_argument(
    "--use_poseidon",
    type=bool,
    default=False,
    help="Use Poseidon hash.",
)
args = parser.parse_args()

with get_crypto_lib_context_manager(args.flavor):
    program = Program.Schema().load(json.load(args.program))
    raw_hash = hex(
        compute_program_hash_chain(program=program, use_poseidon=args.use_poseidon)
    )

    print(pad_to_bytes32(raw_hash))
