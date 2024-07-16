compile: 
	@echo "Cairo Compile..."
	cairo-hash-program --program build/compiled_cairo/hdp.json

hdp-run:
	@echo "Installing hdp binary..."
	chmod +x ./helpers/script/hdp-run.sh
	./helpers/script/hdp-run.sh

cairo-run:
	@echo "Running..."
	chmod +x ./helpers/script/cairo-run.sh
	./helpers/script/cairo-run.sh

cairo-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo-install.sh
	./helpers/script/cairo-install.sh

cairo1-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo1-install.sh
	./helpers/script/cairo1-install.sh