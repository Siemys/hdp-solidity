source venv/bin/activate
hdp encode -a -c ./helpers/target/cached_input.json -o ./helpers/target/cached_output.json "max" -b 5515000 5515029 "header.blob_gas_used" 1
cairo-run \
  --program=helpers/target/hdp.json \
  --layout=starknet_with_keccak \
  --program_input=helpers/target/cached_input.json \
  --cairo_pie_output helpers/target/hdp_pie.zip \
  --print_output