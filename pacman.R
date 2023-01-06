# Check whether pacman itself has been installed
pacman_installed = "pacman" %in% rownames(installed.packages())

# If not, install it
if (!pacman_installed) 
    install.packages("pacman")

# Load pacman
require(pacman)