#!/usr/bin/env python3

from starkware.cairo.bootloaders.generate_fact import get_cairo_pie_fact_info
from starkware.cairo.sharp.client_lib import CairoPie
from starkware.cairo.bootloaders.hash_program import compute_program_hash_chain
import argparse


def get_fact(cairo_pie: CairoPie) -> str:
        """
        Returns the fact that uniquely representing the statement.
        The verification is trust worthy when this fact is registered
        on the Verifier Fact-Registry.
        """
        program_hash = compute_program_hash_chain(cairo_pie.program, use_poseidon=False)
        return get_cairo_pie_fact_info(cairo_pie, program_hash).fact

parser = argparse.ArgumentParser(
        description="Submits a Cairo job to SHARP. "
        "You can provide (1) the source code and the program input OR (2) the compiled program and "
        "the program input OR (3) the Cairo PIE."
    )

parser.add_argument(
        "--cairo_pie", type=str, required=False, help="A path to the Cairo PIE."
    )

args = parser.parse_args()
cairo_pie = CairoPie.from_file(args.cairo_pie)
fact = get_fact(cairo_pie)
print(fact)