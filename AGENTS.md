# Instrucciones para agentes de IA (y personas)

Este archivo lo leen Claude, Codex, Copilot, Cursor y otras IAs. Síguelo al tocar el repositorio.

## Qué es
ClipStack: gestor de portapapeles para macOS 13+, app de barra de menú en Swift (SwiftUI + AppKit), compilada con Swift Package Manager. No hay proyecto de Xcode.

- `Sources/ClipStack/`: código.
- `Info.plist`: metadatos de la app, **incluida la versión**.
- `build.sh`: compila y genera `build/ClipStack.app` y `build/ClipStack.dmg`.
- `.github/workflows/build.yml`: compila en cada push (no publica nada).
- `.github/workflows/release.yml`: publica el DMG en Releases al subir un tag `vX.Y.Z`.

## Versiones y actualizaciones (OBLIGATORIO)

La app comprueba sola si hay versión nueva (`UpdateChecker.swift`): compara su versión, `CFBundleShortVersionString` de `Info.plist`, con el tag de la última Release de GitHub. Para que el aviso funcione:

1. **Toda versión nueva actualiza `Info.plist`** en el mismo commit que la prepara:
   - `CFBundleShortVersionString`: versión semántica sin "v" (ej. `2.1.0`).
   - `CFBundleVersion`: entero que siempre sube en 1 (ej. de `2` a `3`).
2. **El tag es la misma versión con "v"**: `CFBundleShortVersionString = 2.1.0` → tag `v2.1.0`.
3. Publicar = subir el tag **después** del commit del cambio de versión:
   ```bash
   git tag v2.1.0 && git push origin v2.1.0
   ```
   Hacer push a `main` no publica nada; solo el tag crea la Release con el DMG.
4. Versionado semántico:
   - `X.0.0`: cambios grandes o que rompen algo.
   - `x.Y.0`: funciones nuevas.
   - `x.y.Z`: arreglos.
5. Nunca reutilices ni muevas un tag ya publicado: si algo sale mal, sube el siguiente parche.
6. El workflow de Release fuerza en la app compilada la versión del tag. Si no coincide con `Info.plist`, avisa en el log. Aun así, mantén siempre `Info.plist` al día, porque es la versión que usan las compilaciones locales.
7. Al añadir funciones, actualiza también el `README.md`.

Checklist para sacar una versión:
- [ ] `Info.plist`: `CFBundleShortVersionString` y `CFBundleVersion` subidos.
- [ ] `README.md` al día si hay cambios visibles.
- [ ] Compila (`bash ./build.sh` o el workflow *Compilar* en verde).
- [ ] Commit en `main`, luego tag `vX.Y.Z` igual a `Info.plist`, y push del tag.

## Commits
- Autor: **solo el dueño del repositorio** (Roberto Montaner, con su identidad de git configurada).
- **No** añadas líneas `Co-Authored-By`, "Generated with…", firmas de IA ni enlaces a sesiones en commits, PRs ni tags.
- Mensajes en español, en presente y breves (ej. "Añade vista previa en el selector").

## Notas técnicas
- **Atajo global:** se escucha con `CGEventTap` (`EventTapHotKey`), que necesita el permiso de Accesibilidad. No lo sustituyas solo por Carbon `RegisterEventHotKey`: desde macOS 15 Carbon rechaza los atajos con solo ⌥ o ⇧⌥, como el ⇧⌥V por defecto. Carbon solo sirve de reserva mientras no hay permiso.
- **Historial:** se guarda en `~/Library/Application Support/ClipStack/history.json` (las imágenes, en `images/`). Los campos nuevos de `ClipItem` deben decodificarse con `decodeIfPresent` y un valor por defecto, para no romper el historial de versiones anteriores.
- **Firma:** la app no está firmada con cuenta de desarrollador; `build.sh` firma ad-hoc. Cada compilación cambia la firma y macOS vuelve a pedir el permiso de Accesibilidad.
- **Icono:** `Resources/AppIcon.png` (1024 px); `build.sh` genera el `.icns`.
- **Idioma:** textos de la interfaz en español.
