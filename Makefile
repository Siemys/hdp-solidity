compile: 
	@echo "Setting up..."
	chmod +x ./helpers/script/compile-program.sh
	./helpers/script/compile-program.sh

fetch-input:
	@echo "Fetching..."
	chmod +x ./helpers/script/fetch-input.sh
	./helpers/script/fetch-input.sh

cairo-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo-install.sh
	./helpers/script/cairo-install.sh