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

hdp encode -a -c helpers/target/bs_cached_input.json -o helpers/target/bs_cached_output.json -p helpers/target/bs_hdp_pie.zip slr none.10000000 -b 5858987 5858997 header.excess_blob_gas 2
hdp encode -a -c helpers/target/tx_cached_input.json -o helpers/target/tx_cached_output.json -p helpers/target/tx_hdp_pie.zip slr none.50 -t 5605816 tx_receipt.success 12 53 1 0,0,1,1