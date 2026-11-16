#!/bin/bash
# Doble clic: compila y abre el DMG para arrastrar ClipStack a Aplicaciones.
cd "$(dirname "$0")"
echo "== Compilando ClipStack =="
if bash ./build.sh; then
  echo ""; echo "OK. Abriendo el DMG: arrastra ClipStack a Aplicaciones."
  open build/ClipStack.dmg
else
  echo ""; echo "ERROR DE COMPILACIÓN (arriba)."
fi
