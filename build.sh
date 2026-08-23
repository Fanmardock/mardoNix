#!/bin/bash
set -ouex pipefail

SCRIPT_DIR="/ctx/scripts"

if [ -d "$SCRIPT_DIR" ]; then
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -x "$script" ] || [ -f "$script" ]; then
            echo "==> Esecuzione modulo: $script"
            bash "$script"
        fi
    done
else
    echo "ERRORE: Directory moduli $SCRIPT_DIR non trovata!"
    exit 1
fi