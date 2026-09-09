# Índice de decisiones — Fudo Consumers MVP

Este documento es **solo un índice de navegación**. No reemplaza a `design.md` ni a `learnings.md`: el razonamiento completo de cada decisión (qué se decidió, por qué, qué alternativas se descartaron y por qué) vive exclusivamente en esos dos archivos. Acá solo hay un resumen de una línea por entrada, agrupado por tema, con un puntero a dónde leer el detalle completo. Usalo para ubicar rápido qué decisión buscás antes de ir al archivo fuente correspondiente.

Nota sobre numeración: `learnings.md` tiene tres números de decisión repetidos en el archivo original (38, 39 y 46 aparecen cada uno dos veces, en entradas de contenido distinto). Ese documento no fue modificado — la repetición está tal cual en la fuente. Acá se distinguen como "(a)" y "(b)" solo para poder referenciarlas sin ambigüedad.

---

## 1. Modelo de identidad y fidelización (`design.md`)

- **1** — El mozo carga el DNI del comensal al cerrar la cuenta, en vez de un segundo QR de fidelización en la mesa. *(`design.md`, "Decisión 1")*
- **2** — La fidelización es propia de cada restaurante, sin pool ni crédito compartido entre comercios. *(`design.md`, "Decisión 2")*
- **3** — `consumers` es una identidad global única, resuelta hacia el modelo multi-tenant existente vía `visit_summaries`/`visits`. *(`design.md`, "Decisión 3")*

## 2. Decisiones de stack y herramientas (`design.md`)

- **4** — Backend en Ruby on Rails (API mode); se descarta Cuba + Sequel por volumen de corpus disponible para generación de código con IA. *(`design.md`, "Decisión 4")*
- **5** — Mapa con OpenStreetMap (`flutter_map` + CartoDB Dark Matter) en vez de Google Maps, para evitar la barrera de facturación de Google. *(`design.md`, "Decisión 5")*
- **6** — El DNI se cifra con la gema Lockbox (AES + índice ciego HMAC en `dni_bidx`) en vez de `ActiveRecord::Encryption`. *(`design.md`, "Decisión 6")*
- **7** — Feature flags, A/B testing y analytics van por PostHog Cloud, nunca self-hosteado. *(`design.md`, "Decisión 7")*
- **8** — El parser de búsqueda en lenguaje natural usa Gemini con structured output, invocado siempre desde el backend (nunca desde el cliente). *(`design.md`, "Decisión 8")*
- **9** — El MVP solo soporta login con email + contraseña; sin Google OAuth ni Resend. *(`design.md`, "Decisión 9")*
- **10** — La web en Next.js es la iniciativa de menor prioridad; se construye al final si sobra tiempo. *(`design.md`, "Decisión 10")*

## 3. Modelo de datos (`design.md`)

- **11** — Esquema final: 14 tablas + 7 enums, con el detalle de correcciones aplicadas sobre un borrador anterior (tipos de columna, nombres de tabla puente, índice de `business_hours`, campos agregados). *(`design.md`, "Decisión 11")*

## 4. Alcance del MVP y datos de demo (`design.md`)

- **12** — Lista explícita de lo que queda fuera del MVP (delivery propio, reservas, ocupación en vivo, crédito compartido, KYC real, etc.) y el motivo de negocio detrás de cada exclusión. *(`design.md`, "Decisión 12")*
- **13** — La demo usa 30 merchants ficticios en Palermo, ubicación simulada, y tarjetas de regalo ~90% frontend. *(`design.md`, "Decisión 13")*

## 5. Diseño de referencia (`.dc.html`) y breakpoints

- **14** — `Fudo Customers.dc.html` es la referencia wide/desktop (vw≥900); `Fudo App.dc.html` sigue siendo la referencia canónica para phone (vw<900) — cualquier cambio de layout mobile se edita en `Fudo App.dc.html`. *(`learnings.md`, "Decisión 14")*

## 6. Decisiones de producto que pisan el diseño original

- **19** — El dueño de producto pidió, con capturas reales, un nav inferior web plano (sin FAB de QR elevado), el ítem de Perfil siempre visible, y un Home hero-only sin "Lugares destacados". *(`learnings.md`, "Decisión 19")*
- **25** — La pill de horarios pasa a ser un accordion real que colapsa/expande la sección "Horarios", con default distinto por viewport (abierto en desktop, cerrado en mobile) — pedido explícito que diverge del estado inicial fijo del `.dc.html`. *(`learnings.md`, "Decisión 25")*
- **35** — La fila "Apto para" pasa de single-select a multi-select por pedido explícito del dueño de producto, más un fix de datos (tag `economico` faltante). *(`learnings.md`, "Decisión 35")*
- **36** — Se agrega un badge de conteo de filtros activos por categoría en los tabs de escritorio, sin precedente en el `.dc.html`, reusando el estilo del badge numérico ya existente. *(`learnings.md`, "Decisión 36")*
- **37** — Mobile (Flutter) gatea la pantalla de Buscar y sus filtros detrás de login, a diferencia de web que los dejó públicos — divergencia intencional pedida explícitamente por el dueño de producto. *(`learnings.md`, "Decisión 37")*

## 7. Autenticación y seguridad

- **15** — El JWT de sesión en web se persiste en `localStorage` (no cookie `httpOnly`), tradeoff aceptado y documentado; en Flutter se usa `flutter_secure_storage`, una postura más fuerte — asimetría intencional entre plataformas. *(`learnings.md`, "Decisión 15")*
- **16** — Fix: `Consumer#dni` pasa a opcional en el registro, porque el flujo real de carga de DNI es del mozo al cierre de cuenta (implementa `design.md` Decisión 1), no un requisito de autoregistro. *(`learnings.md`, "Decisión 16")*
- **26** — Fix de bug: `POST /api/v1/search` exigía autenticación por una decisión de diseño previa mal alineada con la regla de negocio real ("la búsqueda es gratis"); se sacó el `before_action` de auth del controller. *(`learnings.md`, "Decisión 26")*

## 8. Arquitectura de datos en clientes (mock↔real)

- **17** — Patrón de facade mock↔real en ambas plataformas cliente (`isApiConfigured()` en web, `CONNECTION_MODE`/`DataSource` en Flutter) para desarrollar UI sin bloquear en el avance del backend. *(`learnings.md`, "Decisión 17")*

## 9. Búsqueda por IA (Gemini)

- **30** — El schema de Gemini gana los campos `query`/`result_mode` para cubrir búsquedas de texto libre (plato/comercio específico); el parser sigue siendo solo un extractor de filtros, nunca hace matching de texto él mismo. *(`learnings.md`, "Decisión 30")*
- **33** — Fix de bug: `Merchant.search` matcheaba `neighborhood` con exact-match case-sensitive; se normalizó a `LOWER(...)` porque el casing puede llegar no confiable desde Gemini, la URL o los seeds. *(`learnings.md`, "Decisión 33")*
- **41** — Bug demo-crítico: el buscador con IA del Home de Flutter nunca llamó al backend real, filtraba localmente por substring; se implementó el flujo real 1:1 con el de web. *(`learnings.md`, "Decisión 41")*
- **47** — Investigación de un bug reportado ("algo picante" no aplicó filtros): dos causas raíz reales — `CONNECTION_MODE=local` por defecto en Flutter, y el backend real devolviendo 502 por un problema de conectividad de salida del container Docker hacia Gemini. No hubo cambios de código en `mobile/`. *(`learnings.md`, "Decisión 47")*

## 10. Bugs de UI/CSS en web

- **23** — Los skeletons de `loadingMore` en el grid de escritorio leen `gridTemplateColumns` calculado por el browser (vía `ResizeObserver`) en vez de recalcular columnas a mano, para completar exactamente la fila incompleta. *(`learnings.md`, "Decisión 23")*
- **24** — Gotcha CSS: un `aspect-ratio` en un ítem flex directo necesita su propio `overflow-hidden` (no alcanza con el del contenedor) para que `min-height: auto` no se resuelva al tamaño natural de la imagen — bug real en `MerchantCard.tsx`. *(`learnings.md`, "Decisión 24")*
- **27** — Fix de bug: `AiSearchResolver.tsx` quedaba trabado en el skeleton para siempre en dev porque el guard anti-doble-llamada de React StrictMode también bloqueaba el `.then`/`.catch` de la llamada real. *(`learnings.md`, "Decisión 27")*
- **29** — `CardSkeleton.tsx` se extrae como componente compartido propio (en vez de exportarse desde `SearchResultsGrid.tsx`), reusando el primitivo `Card` y el shimmer ya existente. *(`learnings.md`, "Decisión 29")*
- **32** — Gotcha de fuentes: la sintaxis `@valor,valor,valor,valor` (punto fijo) de la API CSS2 de Google Fonts descarga una instancia estática, no la fuente variable — causaba que el ícono de favorito no se viera relleno. *(`learnings.md`, "Decisión 32")*

## 11. Mapa y layout de Buscar (desktop/mobile web)

- **21** — El pin card del mapa (`MerchantMapCard`) quedaba tapado por el nav inferior porque un `position: fixed` con z-index propio crea su propio stacking context; la solución fue elevar el layer del mapa entero condicionalmente, no portalear la card. *(`learnings.md`, "Decisión 21")*
- **31** — La tab de fidelización se divide en 2 sub-columnas para desktop (`LoyaltyHeroCard`/`LoyaltyRoadmap` extraídos), siguiendo el grid ya especificado en el `.dc.html`; el gate logueado/no-logueado no se tocó. *(`learnings.md`, "Decisión 31")*
- **34** — `/buscar` en viewport mobile: mapa full-bleed con header flotante, fix del reload duro al buscar (formulario nativo sin interceptar), sincronización de `tab=map` en la URL, y marcador de ubicación propia. *(`learnings.md`, "Decisión 34")*
- **40** — `DesktopMapSplit` tenía un scope-leak (search bar + toggle "Lugares/Platos" filtrándose sobre el mapa de escritorio, contra su propio doc comment); se reconstruyó como buscador flotando encima del mapa vía un prop `overlay` genérico. *(`learnings.md`, "Decisión 40")*
- **42** — `DesktopMapSplit` no llenaba la altura real del viewport; el intento de reemplazar el alto hardcodeado por una cadena `flex-1`/`h-full` rompió la página (el `<body>` solo tiene `min-height`, no `height`), así que se ancló a un `calc(100vh-101px)` compuesto por constantes reales del layout. *(`learnings.md`, "Decisión 42")*
- **43** — Cierre de la saga del buscador flotante: posición final alineada exacto con el header de la columna izquierda, usando `top-0` (el offset real correcto era cero por construcción del grid, no un valor a adivinar). *(`learnings.md`, "Decisión 43")*

## 12. Paridad Flutter/mobile

- **20** — Se agrega el toggle "Lugares"/"Platos" (búsqueda cross-merchant de platos) en Next.js y se lleva a paridad en Flutter, reemplazando un placeholder explícito. *(`learnings.md`, "Decisión 20")*
- **38 (a)** — El skeleton de `SearchLoadingView` en mobile se reconstruye contra la forma real de `_MerchantCard` (no contra el patrón de fila del `.dc.html`), documentando una divergencia preexistente entre diseño y componente implementado. *(`learnings.md`, "Decisión 38", primera aparición — buscar "Skeleton de `SearchLoadingView`")*
- **38 (b)** — El bottom nav de Flutter (`MainShell`) porta el QR plano y el auto-hide por scroll desde web, pero NO el 5to ítem Perfil/Login, bloqueado porque esa pantalla/ruta no existe todavía. *(`learnings.md`, "Decisión 38", segunda aparición — buscar "Bottom nav de Flutter")*
- **39 (a)** — `SearchMapView` de Flutter porta 2 de 3 mejoras del mapa de web (marcador "you are here", filtrado en vivo sin perder pan/zoom); la 3ra (mapa full-bleed con overlay) queda bloqueada por estar fuera del archivo en alcance. *(`learnings.md`, "Decisión 39", primera aparición — buscar "`SearchMapView` de Flutter")*
- **39 (b)** — Port a Flutter de las Decisiones 35/36: el multi-select en `filters_sheet.dart` ya estaba bien implementado: el bug real era el catálogo de tags (`economico` faltante); se agrega también el badge de conteo por categoría, aunque en web es "solo desktop". *(`learnings.md`, "Decisión 39", segunda aparición — buscar "Port a Flutter de las Decisiones 35/36")*
- **45** — Wiring de app icon (`flutter_launcher_icons`) y splash screen (`flutter_native_splash`): color de fondo verificado contra el token real del tema, logo pre-escalado manualmente para evitar upscaling, y variante Android 12+ generada. *(`learnings.md`, "Decisión 45")*
- **46 (a)** — Rebuild del chrome del filter sheet de mobile (título, pill de conteo, tabs con ícono, badge de variante correcta, proporción de botones del footer) para alinearlo con web; el contenido por categoría (lógica de negocio) no se tocó. *(`learnings.md`, "Decisión 46", primera aparición — buscar "Rebuild del filter sheet de mobile")*

## 13. Proceso y tooling

- **18** — 3 lecciones de git en working tree compartido sin worktrees aislados: nunca `isolation: worktree` en este proyecto (colisión de puertos Docker), nunca `git stash`, y siempre `git add <archivos específicos>` en vez de `git add .`/`git commit -a`. Incluye la nota operativa sobre colisión de puertos de Docker Compose entre worktrees, generalizada como parte de esta misma regla. *(`learnings.md`, "Decisión 18"; nota operativa relacionada: "Nota operativa: colisión de puertos entre worktrees de Docker Compose")*
- **22** — Refinamiento de la regla anterior: `git commit -- <pathspec>` re-stagea desde el working tree y puede pisar silenciosamente un staging parcial; preferir `git add <pathspec>` + `git commit` en dos pasos separados. *(`learnings.md`, "Decisión 22")*
- **28** — Gotcha de tooling: correr `bundle exec rspec` dentro del contenedor Docker de `development` corre contra ese entorno (no `test`) si no se fuerza `RAILS_ENV=test` explícito, porque `rails_helper.rb` usa `||=`. *(`learnings.md`, "Decisión 28")*
- **48** — Diff pendiente de `mobile/ios/` tras el trabajo de app icon/splash: verificado y comiteado por ser sync legítimo de tooling (CocoaPods + Swift Package Manager), no ruido ni cambio a medio terminar. *(`learnings.md`, "Decisión 48")*

## 14. Deploy e infraestructura

- **44** — Deploy inicial en Dokploy (backend + web + Postgres) vía API real y CI en `.github/workflows/ci.yml`, con 5 aprendizajes específicos de la API de Dokploy (ubicación real de la documentación, validación Zod con campos `nonoptional`, monorepo build path, repo privado en GitHub, y criterio de qué secretos generar vs. dejar como placeholder). *(`learnings.md`, "Decisión 44")*
- **46 (b)** — CORS del backend deployado: el origen del web permitido se configura vía la env var `CORS_ALLOWED_ORIGINS` (comma-separated), no hardcodeado en `cors.rb`, para no requerir un redeploy de código si el dominio cambia. *(`learnings.md`, "Decisión 46", segunda aparición — buscar "CORS del backend deployado")*
