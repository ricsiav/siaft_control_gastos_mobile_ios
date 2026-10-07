# SIAFT para iOS

Aplicación nativa en Swift y SwiftUI para iPhone y iPad, con iOS 17 como mínimo. Replica el alcance funcional de `siaft_control_gastos_mobile_android` y consume exclusivamente el BFF. Esta carpeta es independiente y se puede copiar completa a un Mac.

## Abrir y ejecutar

1. En macOS con Xcode 16 o posterior, abre `Siaft.xcodeproj`.
2. Selecciona el esquema compartido **Siaft** y un simulador de iPhone o iPad instalado.
3. Ejecuta con **Product → Run**. Para las pruebas, usa **Product → Test**.
4. Para un dispositivo físico, selecciona tu equipo en **Signing & Capabilities** del target Siaft y ajusta el identificador si tu cuenta lo necesita.

El proyecto está incluido: no requiere generar archivos, CocoaPods, paquetes Swift externos ni tener la carpeta Android al lado. Si agregas o retiras archivos Swift o recursos, regenera el proyecto con `python3 scripts/generate_project.py`; los identificadores son deterministas. Conserva las preferencias locales de firma en `Config/Local.xcconfig` para que sobrevivan a una regeneración.

```sh
xcodebuild -list -project Siaft.xcodeproj
xcodebuild -showdestinations -project Siaft.xcodeproj -scheme Siaft
xcodebuild -project Siaft.xcodeproj -scheme Siaft \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
# Sustituye el UUID por un simulador instalado de la lista anterior.
xcodebuild -project Siaft.xcodeproj -scheme Siaft \
  -destination 'platform=iOS Simulator,id=UUID_DEL_SIMULADOR' \
  -derivedDataPath build/DerivedData test
```

## Funcionalidad implementada

- Acceso, registro y cierre de sesión con confirmación.
- Inicio: saldos por moneda, ingresos/gastos del mes, gastos principales, movimientos recientes compactos y accesos directos.
- Billeteras: listado y creación de efectivo/cuentas bancarias con catálogo de monedas del BFF.
- Categorías: listado de personales y compartidas, creación de categorías personales.
- Movimientos: ingresos, gastos, transferencias, filtros locales de fecha/billetera y anulación con confirmación.
- Reportes: filtros enviados al BFF, resumen por moneda, desglose por categoría y evolución mensual.
- Perfil: consulta y actualización de nombres, apellidos y correo; cambio de contraseña.
- Navegación inferior, formularios desplazables, modo claro/oscuro, tipografía dinámica y bloqueo de controles durante solicitudes.

Como en Android, no se incluyen edición/desactivación de billeteras o categorías, exportaciones, recurrencias, administración, modo offline ni sincronización en segundo plano. El período del resumen de inicio es el calculado por el backend.

## Estructura

```text
Siaft/
  SiaftApp.swift          Entrada y presentación de sesión
  Domain/Models.swift    Contratos, Decimal y validaciones financieras
  Data/                  URLSession, repositorio y Keychain
  UI/                    Estado, pantallas, formularios y tema
  Resources/             Imagen, fuentes y licencia
Config/                  Configuración pública de compilación
SiaftTests/              XCTest: dominio, contratos, transporte y Keychain
scripts/                 Generación y revisión estructural portátil
```

El flujo es `SwiftUI → SiaftModel → SiaftRepository → BffClient → HTTPS /bff/v1`. Los modelos de dominio no dependen de SwiftUI. El estado de presentación está aislado en el actor principal.

## BFF e identidad

La URL predeterminada es `https://control-gastos.siaft.net/bff/v1`. Puedes copiar `Config/Local.xcconfig.example` a `Config/Local.xcconfig` para cambiar entorno y equipo de firma. Es configuración pública; no añadas tokens, contraseñas ni claves privadas.

```xcconfig
SIAFT_BFF_BASE_URL = https:/$()/tu-servidor/bff/v1
DEVELOPMENT_TEAM = TU_EQUIPO
```

La expansión vacía `$()` evita que `//` se interprete como un comentario de xcconfig. El cliente exige HTTPS, conserva `/bff/v1`, rechaza redirecciones y no usa cookies ni caché HTTP persistentes. La app no envía `userId`: el servidor determina la identidad mediante el JWT.

La sesión se almacena en Keychain con `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, sin sincronización de iCloud. Las contraseñas solo viven en el estado temporal de los formularios. El contenido se cubre al pasar la escena a estado inactivo para proteger la vista del selector de aplicaciones. Un `401` autenticado elimina los datos visibles y la sesión guardada; `403` y fallos de red conservan la sesión. Si Keychain falla, se muestra el error.

No hay reintentos automáticos de escrituras. Ante un fallo de conexión después de guardar, actualiza el listado antes de repetir. Si el servidor confirma una escritura pero falla la recarga, el formulario se cierra y se informa que la operación ya se guardó.

Los importes usan `Decimal` y JSON numérico. Los formularios aceptan punto o coma decimal, hasta dos decimales. Las fechas se transportan como `YYYY-MM-DD` en el calendario local. Las transferencias requieren billeteras activas, distintas y de la misma moneda; ingresos/gastos requieren una categoría activa de la naturaleza correspondiente.

## Identidad visual

El tema conserva los colores de la web y Android: primario `#185B55`, acceso `#0B3335`, acento `#9FC879`, texto `#183033`, superficies `#FFFFFF` / `#F7FAF8` y bordes `#DFE8E4`. El modo oscuro adapta los contrastes. Los controles e iconos de navegación son nativos de iOS (SF Symbols).

DM Sans 400–800 está incluida con su licencia SIL OFL y registrada en `Info.plist`. La imagen `LoginFinances` es una copia sin modificaciones del recurso Android/web, con SHA-256 `4f29052a2f63789df1494722a931329a33bbaf62124353d257860908588ce70f`. No se descargan recursos visuales en ejecución.

## Estado de validación

Preparado el 2 de octubre de 2026 desde Windows. Se verificaron la estructura del proyecto, referencias de archivos y targets, esquema compartido, plist, recursos, nombres internos de fuentes y hash de la imagen con:

```sh
python3 scripts/validate_project.py
```

Hay 14 pruebas XCTest declaradas: importes, fechas, transferencias inválidas, categorías/monedas, rangos, contratos dashboard/perfil/reportes, JSON de movimientos, HTTPS, rutas/autorización/query, `401`, `PATCH`/`204`, respuestas de escritura y ausencia de reintentos de aplicación, y guardado/actualización/borrado aislado en Keychain. Las pruebas HTTP usan un `URLProtocol` simulado y Keychain usa un servicio aleatorio, sin alterar la sesión real.

Los 15 archivos Swift también se analizaron con Tree-sitter Swift sin errores sintácticos. Este análisis no comprueba tipos ni disponibilidad de APIs de Apple; las herramientas temporales quedaron en `build/validation-tools`, ignorado por Git y ajeno al proyecto de Xcode.

**No se ha compilado ni ejecutado XCTest o un simulador:** este entorno no tiene Swift, Xcode ni SDK de iOS. La revisión estructural no prueba compilación, apariencia o funcionamiento en un dispositivo. Tampoco se han realizado operaciones autenticadas contra producción.

En macOS, completar compilación y pruebas; revisar acceso, registro, modo oscuro, tamaños de texto, iPhone/iPad, filtros, cancelaciones y pérdida de conexión. Con una cuenta de pruebas, verificar el ciclo completo de ingreso/gasto/transferencia/anulación, reportes y cambios de perfil/contraseña. La publicación requiere equipo y firma propios, un catálogo de iconos de aplicación y la configuración de distribución/privacidad de App Store Connect; no se incluyen certificados ni un archivo IPA.

Referencias de Apple: [Keychain y accesibilidad](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly), [fuentes personalizadas en SwiftUI](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text).
