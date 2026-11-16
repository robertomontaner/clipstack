# ClipStack

Gestor de portapapeles para macOS 13+ (texto e imágenes), en la barra de menú.

## Instalar
1. Descomprime el zip.
2. Clic derecho en **Instalar ClipStack.command** → **Abrir** → **Abrir** (la primera vez macOS lo pide así).
3. Si faltan las herramientas de Apple, se abre su instalador; cuando acabe, repite el paso 2.

### Desbloqueo rápido (si macOS bloquea el instalador o la app)
Pega esto en la Terminal (ajusta la ruta si no descomprimiste en Descargas):
```bash
xattr -cr ~/Downloads/ClipStack && ~/Downloads/ClipStack/"Instalar ClipStack.command"
```
Y si la app ya instalada no abre:
```bash
xattr -cr /Applications/ClipStack.app && codesign --force --deep --sign - /Applications/ClipStack.app
```

El instalador compila, copia la app a Aplicaciones y la abre. Además deja `build/ClipStack.dmg`: ábrelo y arrastra ClipStack a Aplicaciones (sirve para reinstalar o pasarla a otro Mac).

La primera vez, macOS pide permiso de **Accesibilidad** (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad). Sirve solo para pegar automáticamente; sin él, el elemento queda copiado y pegas tú con ⌘V.

## Uso
> El atajo funciona con el permiso de **Accesibilidad**. Sin él, macOS 15+ no deja usar atajos solo con ⌥ o ⇧⌥.

- **⇧⌥V** (por defecto; cámbialo en el engranaje, es libre): abre el selector rápido. El panel se queda abierto: muévete con ← → (o volviendo a pulsar el atajo), pega con 1-9, Intro o clic, y cierra con Esc o la X.
- **Icono de la barra de menú**: lista completa con buscador. Clic en un elemento = copiarlo. Engranaje = ajustes (5/10/15/20, atajo, pausa, abrir al iniciar).

Historial guardado en `~/Library/Application Support/ClipStack/`. Se ignoran copias marcadas como sensibles (gestores de contraseñas).

## Desinstalar
Doble clic (o clic derecho → Abrir) en **Desinstalar ClipStack.command**. Borra la app, el historial, los ajustes y el permiso de Accesibilidad.
Para actualizar no hace falta: el instalador ya sustituye la versión anterior.
