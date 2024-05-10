#!/bin/bash

prepare_cairo_enviroment() {
    # Activate the virtual environment
    source ./venv/bin/activate 
    # Check if cairo-run is installed
    cairo-run --version
    local status=$?
        if [ $status -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully prepared"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to prepared"
            return $status
        fi
}
# Call the function to ensure the virtual environment is activated
prepare_cairo_enviroment

cairo-run \
  --program=helpers/target/hdp.json \
  --layout=starknet_with_keccak \
  --program_input=helpers/target/bs_cached_input.json \
  --cairo_pie_output helpers/target/bs_hdp_pie.zip \
  --print_output

cairo-run \
  --program=helpers/target/hdp.json \
  --layout=starknet_with_keccak \
  --program_input=helpers/target/tx_cached_input.json \
  --cairo_pie_output helpers/target/tx_hdp_pie.zip \
  --print_output