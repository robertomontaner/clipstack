#!/bin/bash
# Doble clic para desinstalar ClipStack por completo.
echo "== Desinstalar ClipStack =="
pkill -x ClipStack 2>/dev/null
sleep 0.5
rm -rf /Applications/ClipStack.app
rm -rf "$HOME/Library/Application Support/ClipStack"
defaults delete com.roberto.clipstack 2>/dev/null
tccutil reset Accessibility com.roberto.clipstack 2>/dev/null
echo ""
echo "ClipStack desinstalado (app, historial, ajustes y permiso de Accesibilidad)."
read -n 1 -s -r -p "Pulsa una tecla para cerrar..."
