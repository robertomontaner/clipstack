#!/bin/bash
# Doble clic para compilar e instalar ClipStack en /Applications.
cd "$(dirname "$0")"
xattr -cr . 2>/dev/null   # quita la cuarentena de la carpeta descargada
echo "== Instalador de ClipStack =="

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
    echo ""
    echo "Faltan las herramientas de desarrollo de Apple (gratis)."
    echo "Se abrirá una ventana para instalarlas. Cuando terminen, vuelve a abrir este instalador."
    xcode-select --install 2>/dev/null
    read -n 1 -s -r -p "Pulsa una tecla para cerrar..."
    exit 1
fi

pkill -x ClipStack 2>/dev/null

if ! bash ./build.sh; then
    echo ""
    echo "La compilación ha fallado. Copia el texto de arriba (líneas con 'error:') y pásaselo a Claude."
    read -n 1 -s -r -p "Pulsa una tecla para cerrar..."
    exit 1
fi

rm -rf /Applications/ClipStack.app
tccutil reset Accessibility com.roberto.clipstack 2>/dev/null   # la firma cambia al recompilar
cp -R build/ClipStack.app /Applications/
xattr -cr /Applications/ClipStack.app 2>/dev/null
codesign --force --deep --sign - /Applications/ClipStack.app
open /Applications/ClipStack.app

echo ""
echo "ClipStack instalado en Aplicaciones y abierto. Busca el icono en la barra de menú."
echo "Atajo por defecto: ⇧⌥V (Mayús + Opción + V)."
echo "También tienes build/ClipStack.dmg para instalarla arrastrando (o pasarla a otro Mac)."
open build
read -n 1 -s -r -p "Pulsa una tecla para cerrar..."
