# Variables
SCRIPTS_DIR = scripts
PHASES = $(wildcard $(SCRIPTS_DIR)/phase*)
INSTALL_DIR = installed_phases

# Make help the default target
.PHONY: help
help:
	@echo "Usage:"
	@echo "  make help         - Show this help message"
	@echo "  make list         - List all available phases"
	@echo "  make status       - Show installation status of all phases"
	@echo "  make install-X    - Install phase X (e.g., make install-1)"
	@echo "  make install-all  - Install all available phases"
	@echo "  make clean        - Remove all phase installations"
	@echo ""
	@echo "Example usage:"
	@echo "  make install-1    - Installs phase1"
	@echo "  make install-all  - Installs all phases"

.PHONY: all clean list status install-all $(PHASES)

# Change default target to help
all: help

# Install all phases
install-all: $(PHASES)
	@echo "All phases installed successfully"

# List available phases
list:
	@echo "Available phases:"
	@for phase in $(PHASES); do \
		echo "  $$(basename $$phase)"; \
	done

# Status of installed phases
status:
	@echo "Installation status:"
	@for phase in $(PHASES); do \
		phase_name=$$(basename $$phase); \
		if [ -f "$(INSTALL_DIR)/$$phase_name.installed" ]; then \
			echo "  $$phase_name: Installed"; \
		else \
			echo "  $$phase_name: Not installed"; \
		fi \
	done

# Clean all installations
clean:
	@echo "Cleaning all installations..."
	rm -rf $(INSTALL_DIR)

# Pattern rule for installing individual phases
$(SCRIPTS_DIR)/phase%: | $(INSTALL_DIR)
	@echo "Installing $$(basename $@)..."
	@chmod +x $@
	@$@
	@touch $(INSTALL_DIR)/$$(basename $@).installed
	@echo "Installation of $$(basename $@) complete"

# Create installation directory
$(INSTALL_DIR):
	mkdir -p $(INSTALL_DIR)

# Helper target to install specific phase
install-%:
	@if [ -f "$(SCRIPTS_DIR)/phase$*" ]; then \
		make $(SCRIPTS_DIR)/phase$*; \
	else \
		echo "Error: phase$* not found"; \
		exit 1; \
	fi
