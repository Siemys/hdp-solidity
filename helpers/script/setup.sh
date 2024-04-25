source venv/bin/activate
hdp compiled-cairo ./helpers/target/hdp.json
hdp encode -a -c ./helpers/target/cached_input.json -o ./helpers/target/cached_output.json "max" -b 4952200 4952229 "account.0x7f2c6f930306d3aa736b3a6c6a98f512f74036d4.balance" 1
cairo-run \
  --program=helpers/target/hdp.json \
  --layout=starknet_with_keccak \
  --program_input=helpers/target/cached_input.json \
  --cairo_pie_output helpers/target/hdp_pie.zip \
  --print_output