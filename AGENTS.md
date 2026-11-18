# Instrucciones para agentes de IA (y personas)

Este archivo lo leen Claude, Codex, Copilot, Cursor y otras IAs. Síguelo al tocar el repositorio.

## Qué es
ClipStack: gestor de portapapeles para macOS 13+, app de barra de menú en Swift (SwiftUI + AppKit), compilada con Swift Package Manager. No hay proyecto de Xcode.

- `Sources/ClipStack/`: código.
- `Info.plist`: metadatos de la app, **incluida la versión**.
- `build.sh`: compila y genera `build/ClipStack.app` y `build/ClipStack.dmg`.
- `.github/workflows/build.yml`: compila en cada push (no publica nada).
- `.github/workflows/release.yml`: publica sola la Release con el DMG cuando llega a `main` una versión nueva en `Info.plist`.

## Versiones y actualizaciones (OBLIGATORIO)

La app comprueba sola si hay versión nueva (`UpdateChecker.swift`): compara su versión, `CFBundleShortVersionString` de `Info.plist`, con el tag de la última Release de GitHub. Para que el aviso funcione:

1. **Publicar una versión = subir la versión en `Info.plist` y hacer push a `main`.** Nada más.
   - `CFBundleShortVersionString`: versión semántica sin "v" (ej. `2.1.0`).
   - `CFBundleVersion`: entero que siempre sube en 1 (ej. de `2` a `3`).
2. El workflow *Release DMG* ve el cambio en `Info.plist`. Si el tag `v<versión>` no existe, compila, **crea el tag él mismo** y publica la Release con `ClipStack.dmg`. Tarda unos 3 minutos.
3. **No crees tags a mano.** Si la versión de `Info.plist` ya está publicada, el workflow no hace nada. Así, los push sin cambio de versión nunca publican.
4. Versionado semántico:
   - `X.0.0`: cambios grandes o que rompen algo.
   - `x.Y.0`: funciones nuevas.
   - `x.y.Z`: arreglos.
5. Nunca bajes la versión ni reutilices una publicada: si algo sale mal, sube el siguiente parche.
6. Sube la versión **en el mismo push** que trae los cambios que la justifican, no antes. En cuanto llega a `main`, se publica.
7. Al añadir funciones, actualiza también el `README.md`.

Checklist para sacar una versión:
- [ ] Cambios hechos y compilando (`bash ./build.sh` o el workflow *Compilar* en verde en tu rama).
- [ ] `README.md` al día si hay cambios visibles.
- [ ] `Info.plist`: `CFBundleShortVersionString` y `CFBundleVersion` subidos.
- [ ] Push a `main`. Comprueba en *Actions* que *Release DMG* termina en verde y que la Release aparece.

Si quieres acumular cambios sin publicar, haz push a `main` sin tocar la versión: no se publica nada hasta que la subas.

## Commits
- Autor: **solo el dueño del repositorio** (Roberto Montaner, con su identidad de git configurada).
- **No** añadas líneas `Co-Authored-By`, "Generated with…", firmas de IA ni enlaces a sesiones en commits, PRs ni tags.
- Mensajes en español, en presente y breves (ej. "Añade vista previa en el selector").

## Notas técnicas
- **Atajo global:** se escucha con `CGEventTap` (`EventTapHotKey`), que necesita el permiso de Accesibilidad. No lo sustituyas solo por Carbon `RegisterEventHotKey`: desde macOS 15 Carbon rechaza los atajos con solo ⌥ o ⇧⌥, como el ⇧⌥V por defecto. Carbon solo sirve de reserva mientras no hay permiso.
- **Historial:** se guarda en `~/Library/Application Support/ClipStack/history.json` (las imágenes, en `images/`). Los campos nuevos de `ClipItem` deben decodificarse con `decodeIfPresent` y un valor por defecto, para no romper el historial de versiones anteriores.
- **Auto-actualización** (`UpdateChecker.installUpdate`): descarga el primer asset `.dmg` de la última Release, lo monta y copia `ClipStack.app` sobre la app instalada. Después quita la cuarentena, resetea el permiso de Accesibilidad y relanza la app con `--updated`, que abre `PermissionGuide`. Por eso el DMG debe tener `ClipStack.app` en su raíz y llamarse `*.dmg`. No cambies `build.sh` sin mantener eso.
- **Firma:** la app no está firmada con cuenta de desarrollador; `build.sh` firma ad-hoc. Cada compilación cambia la firma y macOS vuelve a pedir el permiso de Accesibilidad.
- **Icono:** `Resources/AppIcon.png` (1024 px); `build.sh` genera el `.icns`.
- **Idioma:** textos de la interfaz en español.
