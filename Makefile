compile: 
	@echo "Setting up..."
	chmod +x ./helpers/script/compile-program.sh
	./helpers/script/compile-program.sh

cairo-run:
	@echo "Running..."
	chmod +x ./helpers/script/cairo-run.sh
	./helpers/script/cairo-run.sh

cairo-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo-install.sh
	./helpers/script/cairo-install.sh