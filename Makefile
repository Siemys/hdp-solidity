compile: 
	@echo "Cairo Compile..."
	cairo-hash-program --program helpers/target/hdp.json

hdp-install:
	@echo "Installing hdp binary..."
	chmod +x ./helpers/script/hdp-install.sh
	./helpers/script/hdp-install.sh

cairo-run:
	@echo "Running..."
	chmod +x ./helpers/script/cairo-run.sh
	./helpers/script/cairo-run.sh

cairo-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo-install.sh
	./helpers/script/cairo-install.sh