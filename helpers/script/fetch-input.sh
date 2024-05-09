source venv/bin/activate
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