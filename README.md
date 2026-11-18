# ClipStack

Gestor de portapapeles para macOS 13+ (texto e imágenes), en la barra de menú.

## Descargar (sin compilar)
En [Releases](https://github.com/robertomontaner/clipstack/releases) está el último **ClipStack.dmg**: ábrelo y arrastra ClipStack a Aplicaciones.
Como no está firmada con cuenta de desarrollador de Apple, la primera vez macOS puede bloquearla: Ajustes del Sistema → Privacidad y seguridad → **Abrir igualmente**, o `xattr -cr /Applications/ClipStack.app`.

## Publicar una versión nueva
Sube la versión en `Info.plist` y haz push a `main`:
- `CFBundleShortVersionString`, por ejemplo de `2.0.0` a `2.1.0`;
- `CFBundleVersion`, +1.

GitHub Actions lo detecta y, si esa versión no estaba publicada, compila en un Mac, crea el tag `v2.1.0` y publica la Release con el DMG (tarda unos 3 minutos). Los push que no cambian la versión no publican nada. Detalles para IAs y personas en [AGENTS.md](AGENTS.md).

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

### Selector rápido (⇧⌥V)
El atajo se cambia en el engranaje. El panel se queda abierto hasta que pegas o lo cierras.

| Tecla | Acción |
|---|---|
| ← → o el atajo otra vez | Moverse |
| 1-9 / Intro / clic | Pegar |
| ⇧ + 1-9 / ⇧ + Intro / ⇧ + clic | Pegar **sin formato** |
| Escribir | Filtrar (⌫ borra) |
| Espacio | Vista previa grande |
| ⌘P | Fijar / desfijar |
| Esc o la X | Cerrar (o borrar la búsqueda) |

### Menú de la barra superior
- Lista completa con buscador. Clic copia; ⇧ + clic copia sin formato.
- Al pasar el ratón: 👁 vista previa (también con una pulsación larga), 📌 fijar y 🗑 eliminar.
- Engranaje → ajustes:
  - cuántos guardar (5/10/15/20);
  - atajo;
  - apps excluidas;
  - pausar la captura;
  - abrir al iniciar sesión;
  - buscar actualizaciones.

### Qué guarda
- **Texto**, con su formato original (se pega con formato, o sin él usando ⇧).
- **Enlaces**: muestran el dominio.
- **Colores** (`#hex`, `rgb()`): muestran una muestra del color.
- **Imágenes**.
- **Archivos** copiados en Finder: se pegan como archivos.

Los elementos **fijados** salen primero, no cuentan para el límite y se conservan al borrar el historial.

### Privacidad
- No se guarda nada copiado en las **apps excluidas**: por defecto Llavero, Contraseñas, 1Password, Bitwarden, LastPass y Dashlane. La lista se edita en ajustes.
- También se ignoran las copias que otras apps marcan como sensibles.
- El historial se guarda en `~/Library/Application Support/ClipStack/`.

### Actualizaciones
La app consulta las Releases de GitHub al arrancar y cada 24 h. Si hay una versión nueva, el icono de la barra cambia y aparece un aviso.

Al pulsar **Actualizar ahora**, ClipStack hace todo solo:
1. descarga el DMG;
2. sustituye la app;
3. quita la cuarentena de macOS;
4. se vuelve a abrir.

Después se abre el **asistente de permisos**, porque cada versión cambia la firma y macOS pide otra vez la Accesibilidad.

### Asistente de permisos
Se abre solo la primera vez, si falta el permiso de Accesibilidad, y tras cada actualización. También está en Engranaje → **Configurar**/**Asistente**. Abre el panel correcto de Ajustes, explica qué activar y detecta solo cuándo has dado el permiso.

Solo la **primera instalación** desde el navegador necesita desbloquear la app a mano (Ajustes del Sistema → Privacidad y seguridad → **Abrir igualmente**). Las actualizaciones posteriores, hechas desde la propia app, ya no.

## Estructura
- `Sources/ClipStack/`: código Swift (SwiftUI + AppKit).
- `build.sh`: compila y genera `build/ClipStack.app` y `build/ClipStack.dmg`.
- `.github/workflows/build.yml`: compila en cada push (comprobación).
- `.github/workflows/release.yml`: publica la Release con el DMG cuando cambia la versión de `Info.plist` en `main`.
- `Resources/AppIcon.png`: icono de la app.
- `Info.plist`: metadatos de la app, incluida la versión (app de barra de menú, sin icono en el Dock).
- `AGENTS.md`: reglas para IAs y personas: cómo versionar, publicar y hacer commits.
