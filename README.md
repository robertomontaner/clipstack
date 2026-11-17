# ClipStack

Gestor de portapapeles para macOS 13+ (texto e imágenes), en la barra de menú.

## Descargar (sin compilar)
En [Releases](https://github.com/robertomontaner/clipstack/releases) está el último **ClipStack.dmg**: ábrelo y arrastra ClipStack a Aplicaciones.
Como no está firmada con cuenta de desarrollador de Apple, la primera vez macOS puede bloquearla: Ajustes del Sistema → Privacidad y seguridad → **Abrir igualmente**, o `xattr -cr /Applications/ClipStack.app`.

## Publicar una versión nueva
```bash
git tag v1.1.0 && git push origin v1.1.0
```
GitHub Actions compila en un Mac y adjunta el DMG a la Release (tarda unos 3 minutos). También se puede lanzar a mano desde la pestaña **Actions** → *Release DMG* → *Run workflow*.

## Compilar tú mismo

### Requisitos
Herramientas de desarrollo de Apple (gratis). Si no las tienes, los scripts abren su instalador; también puedes ejecutar `xcode-select --install`.

### Instalar
```bash
git clone https://github.com/robertomontaner/clipstack.git
cd clipstack
```
Después, en Finder, doble clic en uno de estos scripts:

| Script | Qué hace |
|---|---|
| **Compilar DMG.command** | Compila y abre `build/ClipStack.dmg`. Arrastra ClipStack a Aplicaciones. |
| **Instalar ClipStack.command** | Compila, sustituye la versión instalada y la abre. También deja el DMG en `build/`. |
| **Desinstalar ClipStack.command** | Borra la app, el historial, los ajustes y el permiso de Accesibilidad. |

Para actualizar: `git pull` y vuelve a ejecutar el instalador (o el DMG). No hace falta desinstalar antes.

El DMG de `build/` sirve para pasar la app a otro Mac sin compilar.

#### Si macOS bloquea un script o la app
Si te sale un aviso de seguridad, haz clic derecho → **Abrir**. Si sigue bloqueado:
```bash
xattr -cr ~/ruta/a/clipstack
```
Y si la app instalada no abre:
```bash
xattr -cr /Applications/ClipStack.app && codesign --force --deep --sign - /Applications/ClipStack.app
```

## Permiso de Accesibilidad
Ajustes del Sistema → Privacidad y seguridad → **Accesibilidad** → activa ClipStack (si no aparece, añádelo con **+**).

Hace falta para dos cosas:
- **El atajo global.** macOS 15+ no deja usar atajos con solo ⌥ o ⇧⌥ sin este permiso. La app lo detecta sola en unos segundos, sin reiniciarla.
- **Pegar automáticamente.** Sin el permiso, el elemento elegido queda copiado y lo pegas tú con ⌘V.

Cada vez que recompilas cambia la firma, así que macOS vuelve a pedir el permiso.

## Uso
- **⇧⌥V** (por defecto; cámbialo en el engranaje): abre el selector rápido. El panel se queda abierto: muévete con ← → (o volviendo a pulsar el atajo), pega con 1-9, Intro o clic, y cierra con Esc o la X.
- **Icono de la barra de menú**: lista completa con buscador. Clic en un elemento = copiarlo. Engranaje = ajustes (guardar 5/10/15/20, atajo, pausa, abrir al iniciar sesión).

El historial se guarda en `~/Library/Application Support/ClipStack/`. Se ignoran las copias marcadas como sensibles (gestores de contraseñas).

## Estructura
- `Sources/ClipStack/`: código Swift (SwiftUI + AppKit).
- `build.sh`: compila y genera `build/ClipStack.app` y `build/ClipStack.dmg`.
- `.github/workflows/release.yml`: compila y publica el DMG en Releases al subir un tag.
- `Info.plist`: metadatos de la app (app de barra de menú, sin icono en el Dock).
