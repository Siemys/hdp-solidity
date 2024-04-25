setup: 
	@echo "Setting up..."
	chmod +x ./helpers/script/setup.sh
	./helpers/script/setup.sh

cairo-install:
	@echo "Installing cairo..."
	chmod +x ./helpers/script/cairo-install.sh
	./helpers/script/cairo-install.sh