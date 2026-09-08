# Design — Fudo Consumers MVP

Registro de decisiones técnicas (decision log) para el proyecto Fudo Consumers. Cada entrada documenta qué se decidió, cuándo, y el razonamiento completo (incluyendo alternativas descartadas) para que cualquier agente o persona que entre al proyecto sin contexto previo pueda entender el porqué sin tener que reconstruir la discusión.

## Decisión 1: Mecanismo de fidelización — carga de DNI en cierre de cuenta

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El mozo carga el DNI del comensal en una pantalla propia de Fudo al cerrar la cuenta.

**Por qué:** Se evaluó agregar un segundo QR en la mesa dedicado a fidelización, pero se descartó porque en la práctica nadie escanea un QR extra además del que ya usa para pedir o pagar — sumar fricción de escaneo mata la adopción. También se descartó modificar el QR de pedidos/pago existente de Fudo Comensal, porque es producto de otro equipo y está fuera del límite de responsabilidad de este proyecto. La alternativa elegida integra la carga de DNI como paso del flujo que el mozo ya ejecuta al cerrar la cuenta, lo que la convierte en un paso obligatorio del sistema en vez de depender de la buena voluntad o iniciativa del comensal.

## Decisión 2: Fidelización por restaurante, no compartida entre restaurantes

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El crédito y las reglas de fidelización son propias de cada restaurante — no hay un pool ni crédito compartido entre comercios distintos.

**Por qué:** Cada dueño de restaurante financia y configura su propio premio (por ejemplo, cada 2da visita, cada 4ta visita, premio permanente al llegar a X visitas), de la misma forma en que ya financiaría cualquier promoción propia. Compartir fidelización entre restaurantes generaría dos problemas: (1) el miedo del dueño de que "Fudo me comparte mis clientes" con la competencia, lo cual dañaría la confianza en la plataforma; y (2) la complejidad operativa y contable de liquidar crédito consumido en un comercio pero generado en otro. Mantener la fidelización aislada por restaurante evita ambos problemas y es más simple de vender e implementar en el MVP.

## Decisión 3: Modelo de identidad — consumers global, resolución vía visit_summaries/visits

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** `consumers` es una tabla global (una identidad única por comensal). El vínculo entre esa identidad global y la plataforma multi-tenant existente de Fudo se resuelve a través de `visit_summaries` y `visits`.

**Por qué:** La plataforma actual de Fudo es multi-tenant (un tenant = un merchant) y, según la política de privacidad pública de Fudo, hoy no existe una base de datos compartida entre "Comercios". Para poder ofrecer un perfil único del comensal (la ventaja injusta del proyecto) sin reescribir el modelo multi-tenant existente, se necesita una capa de identidad global nueva (`consumers`) que se conecte al mundo multi-tenant a través de tablas puente pensadas para ese propósito, en vez de forzar el modelo existente a ser algo que no es.

## Decisión 4: Backend — Ruby on Rails (API mode), no Cuba+Sequel

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada (revertida desde una decisión previa)

**Decisión:** El backend se construye en Ruby on Rails en modo API. Se descarta la opción previamente considerada de Cuba + Sequel.

**Por qué:** Esta decisión fue revertida después de investigar los números reales de adopción: Cuba tiene aproximadamente 524.000 descargas históricas contra aproximadamente 21.000.000 de Rails — es un framework genuinamente nicho. Como quien construye el prototipo nunca escribió Ruby antes y depende de agentes de IA para generar buena parte del código, el volumen de código de referencia disponible en el mundo es un factor determinante: Rails, al tener órdenes de magnitud más código público, documentación y ejemplos, da resultados mucho mejores cuando el código lo genera un agente de IA que cuando se usa un framework nicho con poco corpus de referencia.

## Decisión 5: Mapa — OpenStreetMap (flutter_map + CartoDB Dark Matter), no Google Maps

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El mapa de la app usa OpenStreetMap vía el paquete `flutter_map`, con tiles de estilo CartoDB Dark Matter. Se descarta Google Maps.

**Por qué:** Google eliminó el crédito mensual pooled de USD 200 en marzo de 2025 y ahora exige una cuenta de facturación con tarjeta cargada incluso para quedarse dentro del nivel gratuito — una barrera de entrada innecesaria para un prototipo/demo. OpenStreetMap, en cambio, no pide API key ni configuración de facturación para arrancar. Como beneficio adicional, el estilo oscuro de CartoDB Dark Matter combina directamente con la estética visual ya elegida para la app, sin necesidad de personalizar un estilo de mapa desde cero.

## Decisión 6: Cifrado del DNI — gema Lockbox (AES + índice ciego HMAC)

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El DNI se cifra con la gema Lockbox (AES), con un índice ciego calculado vía HMAC almacenado en una columna separada `dni_bidx` para permitir búsquedas exactas sin exponer el valor en claro.

**Por qué:** El DNI es un dato que necesita ser recuperable (a diferencia de una contraseña, que se guarda como `password_hash` vía bcrypt, de una sola vía y jamás recuperable) porque el negocio necesita poder mostrarlo o usarlo operativamente. Lockbox resuelve esto con cifrado reversible más un índice ciego separado que permite buscar por DNI sin descifrar cada fila. Se consideró como alternativa nativa `ActiveRecord::Encryption` de Rails 7+, que soporta cifrado determinístico y no requeriría una columna de índice aparte — pero se descartó en favor de Lockbox porque el schema ya está construido sobre el patrón de dos columnas (valor cifrado + índice ciego) y cambiarlo implicaría re-trabajar el modelo de datos sin un beneficio claro en esta etapa.

## Decisión 7: Feature flags, A/B testing y analytics — PostHog Cloud, nunca self-hosteado

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** Feature flags, A/B testing y analytics de producto se manejan exclusivamente con PostHog Cloud. No se self-hostea PostHog bajo ninguna circunstancia.

**Por qué:** Self-hostear PostHog implica levantar y mantener su propio stack de infraestructura (ClickHouse + Kafka), lo cual es una carga operativa completamente desproporcionada para el tiempo disponible en este proyecto. PostHog Cloud da la misma funcionalidad sin ese costo de infraestructura.

## Decisión 8: Parser de búsqueda en lenguaje natural — Gemini API con structured output, desde el backend

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El parser de búsqueda en lenguaje natural usa la API de Gemini con structured output (`responseSchema`), invocado desde un service object del lado del backend Rails. Nunca se llama directo desde el cliente Flutter.

**Por qué:** Llamar a la API de Gemini desde el cliente móvil expondría la API key dentro del binario de la app, un riesgo de seguridad inaceptable. Centralizar la llamada en un service object del backend mantiene la key protegida y permite auditar/loguear las consultas. Se evaluó `ai-sdk` de Vercel como posible herramienta, pero no aplica a este caso: es una librería exclusiva del ecosistema JavaScript/TypeScript y no tiene equivalente directo para Flutter/Dart ni para el lado del cliente móvil de este proyecto.

## Decisión 9: Login — solo email + contraseña para el MVP

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El MVP soporta únicamente login con email y contraseña. No hay Google OAuth ni integración con Resend para email transaccional.

**Por qué:** Para una demo no hace falta un flujo real de envío de mails transaccionales (verificación, recuperación de contraseña, etc.) — la demo arranca directamente con un usuario precargado. Agregar Google OAuth o Resend en esta etapa sumaría complejidad de configuración e integración sin aportar valor demostrable dentro del alcance del MVP.

## Decisión 10: Web en Next.js — menor prioridad, se construye al final

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** La web en Next.js (SSR) es la iniciativa de menor prioridad del proyecto. Se construye al final, solo si sobra tiempo después de mobile y backend.

**Por qué:** El puesto que se está evaluando con este proyecto (Consumers Founding Engineer) pide explícitamente mobile + backend, no web. Priorizar la web por sobre esas dos áreas iría en contra de lo que el puesto realmente necesita demostrar. La web queda planificada a futuro principalmente para SEO (que Google indexe cada restaurante), pero no es crítica para el objetivo actual.

## Decisión 11: Esquema de base de datos — 17 tablas + 6 enums

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** El modelo de datos completo se compone de 17 tablas y 6 enums. El detalle ejecutable vive en `db/schema.sql` y el diagrama visual en `docs/database-schema.drawio` — ninguno de los dos existe todavía en el repo al momento de escribir este documento.

**Por qué:** Durante la revisión del schema se aplicaron las siguientes correcciones respecto de un borrador anterior:

- `gifts.amount`: corregido de tipo boolean a decimal (un monto no puede ser un booleano).
- `gifts.message`: corregido de tipo timestamp a string (un mensaje de regalo es texto, no una fecha).
- Nombres de tablas puente: corregidos, por ejemplo `menu_items_tags` (convención de nombre de tabla de unión).
- `currencies_enum`: corregido de "arg" a "ars" (código ISO 4217 real de la moneda argentina).
- Estado de regalo: corregido de "redeem" a "redeemed" (consistencia de tiempo verbal en los valores de enum de estado).
- Agregado `visits.visited_at`: falta de un campo de fecha/hora explícito para la visita.
- Agregado `merchants.neighborhood`: todos los merchants de la demo comparten el mismo `city` (Buenos Aires), así que ese campo solo no alcanza para filtrar o diferenciar geográficamente dentro de la demo.
- Agregado `loyalty_rules.is_permanent`: necesario para distinguir un premio de una sola vez de un beneficio permanente.
- Agregadas `consumer_settings` y `search_history`: esta última con una columna `structured_output: jsonb` pensada para auditar qué interpretó la IA en cada búsqueda en lenguaje natural.
- Corregido el índice único de `business_hours`: el índice original no permitía múltiples turnos por día; se corrigió para soportar casos como almuerzo y cena como turnos separados del mismo día.

## Decisión 12: Fuera de alcance del MVP (explícito, no un olvido)

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** Quedan explícitamente fuera del alcance del MVP:

- Delivery propio.
- Reservas de mesa.
- Ocupación de mesas en vivo.
- Crédito de fidelización compartido entre restaurantes.
- Tocar el QR de pago/pedidos existente de Fudo Comensal.
- KYC real sobre el DNI.
- Saldo parcial en tarjetas de regalo.
- `merchants.timezone`.
- `price_alerts`.
- `visits.source` y `visits.loyalty_rule_id`.
- Tabla de staff del merchant (queda como mock de frontend únicamente, sin modelo de datos real).

**Por qué:** Cada uno de estos puntos es una decisión consciente de foco, no una omisión por falta de tiempo. Delivery propio se descarta porque Fudo ya es socio de Uber Eats y PedidosYa — no tiene sentido competir con los propios socios. Reservas de mesa se descarta citando el precedente de TheFork, que se retiró de Argentina con ese modelo de negocio. Ocupación de mesas en vivo/predictiva, crédito compartido entre restaurantes, y tocar el QR existente de Fudo Comensal exceden el alcance definido en las Decisiones 1 y 2. KYC real sobre el DNI no es necesario porque el dato se guarda sin verificar contra RENAPER, de forma equivalente a como funciona cualquier tarjeta de fidelidad de supermercado. Saldo parcial en tarjetas de regalo se simplifica a todo-o-nada para reducir la lógica de negocio del MVP. Los campos y tablas técnicas listados (`merchants.timezone`, `price_alerts`, `visits.source`, `visits.loyalty_rule_id`, staff del merchant) se posponen porque no son necesarios para demostrar el valor central del producto en esta etapa — la demo entera vive en una sola zona horaria (Buenos Aires), por ejemplo, lo que hace innecesario modelar `timezone` ahora.

## Decisión 13: Datos de la demo

**Fecha:** 2026-09-08 (aproximada)
**Estado:** Aceptada

**Decisión:** La demo usa 30 merchants ficticios ubicados en el barrio de Palermo (Buenos Aires). La ubicación del dispositivo se simula en un punto fijo dentro de esa zona. Las tarjetas de regalo son aproximadamente 90% frontend para esta demo.

**Por qué:** Los datos de la demo son 100% ficticios por diseño — el objetivo es demostrar el producto, no operar con datos reales de restaurantes ni de comensales. Concentrar los 30 merchants en una sola zona geográfica (Palermo) simplifica la generación de datos de prueba y hace que el mapa y el buscador tengan resultados relevantes sin necesidad de cubrir una ciudad entera. Que las tarjetas de regalo sean mayormente frontend refleja que, para esta etapa, el objetivo es mostrar el flujo de compra/envío de un regalo más que construir toda la lógica de negocio de backend detrás (liquidación, breakage, etc.), que queda para una iteración posterior.

## Decisiones pendientes / abiertas

El esquema definitivo de base de datos (`db/schema.sql`) y su diagrama visual (`docs/database-schema.drawio`), así como el plan de fases del proyecto (`PLAN.md`), se están redactando en paralelo por otro agente al momento de escribir este documento y todavía no existen en el repo. Este `design.md` refleja el estado de las decisiones tomadas hasta la fecha (2026-09-08) y debería revisarse y actualizarse cuando esos tres archivos existan, para confirmar que el detalle ejecutable coincide con lo documentado acá (en particular la Decisión 11).
