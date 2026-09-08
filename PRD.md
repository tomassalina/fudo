# PRD.md — Fudo Consumers

## El problema

Fudo está parado en la caja registradora de cada venta, en cualquier restaurante, bar, cafetería o dark kitchen, sin importar cómo se paga (efectivo, tarjeta, transferencia). Ni Google Maps, ni Rappi/PedidosYa/Uber Eats, ni una empresa de gift boxes tienen ese dato. Hoy esa información existe pero está separada por restaurante — no hay un perfil único del comensal. Fudo aún no conoce al consumer, pero puede conocerlo, y eso es lo más valioso.

Nuestro desafío principal: unir la oferta que ya manejamos con una demanda un poco desconocida, para fidelizarla.

## La ventaja injusta

Ningún competidor puede ver lo que pasa adentro de un restaurante cuando no hay delivery de por medio. Fudo es el único presente en cada venta — esa presencia, para todos los métodos de pago y todos los formatos de local, es la ventaja real. No es "Fudo ya te conoce", es "Fudo es el único que puede llegar a conocerte".

## La idea

- El mozo carga el DNI del comensal al cerrar la cuenta, en una pantalla del propio sistema de Fudo (no tocamos el QR de pedidos/pago existente, que es producto de otro equipo).
- Eso arma la fidelización **por restaurante** — cada dueño configura sus propias reglas (cada 2da visita, cada 4ta, premio permanente al llegar a X visitas). No hay crédito compartido entre restaurantes.
- Arriba de esa base, una capa de descubrimiento con IA: buscador en lenguaje natural sobre el menú y precio real de cada local (algo que Morfy y Google no pueden ofrecer, porque no tienen ese dato).
- Posibilidad de regalar comida a otra persona (tarjetas de regalo por niveles: classic/gold/black/platinum).

## Producto: 3 pestañas (mobile) + web (fase final)

**Buscar** — pantalla estilo Roomix, buscador en lenguaje natural con placeholders rotando, resultados en lista y en mapa (OpenStreetMap, tiles CartoDB Dark Matter).
**Mis Lugares** — perfil gastronómico con IA (armado con historial real), fidelización por restaurante visitado.
**Regalar** — comprar y enviar un regalo a otra persona.

**Web (Next.js, SSR)** — versión pública del buscador, pensada a futuro para SEO (que Google indexe cada restaurante). Se construye al final, no bloquea el resto.

## Modelo de datos

Ver `db/schema.sql` (fuente de verdad ejecutable) y `docs/database-schema.drawio` (diagrama visual). 17 tablas + 6 enums. La pieza central: `consumers` es una identidad global, `visit_summaries`/`visits`/`loyalty_rules` resuelven el vínculo entre esa identidad global y la plataforma multi-tenant existente de Fudo (un tenant = un merchant).

## Negocio

- Fudo no regala el crédito de fidelización — lo financia cada restaurante, como ya haría con cualquier promoción propia.
- Fudo monetiza por el volumen de pago que procesa (ya existe, vía Fudo Pagos), por el "breakage" de tarjetas de regalo no usadas, y por herramientas de fidelización/CRM vendidas al restaurante como suscripción.
- Feature flags, A/B testing y analytics de producto: todo con PostHog Cloud (nunca self-hosteado).

## Fuera de alcance (decidido explícitamente, no es un olvido)

- Delivery propio (Fudo ya es socio de Uber Eats/PedidosYa — no se compite con eso).
- Reservas de mesa (TheFork ya se fue de Argentina con este modelo).
- Ocupación de mesas en vivo/predictiva.
- Crédito de fidelización compartido entre restaurantes distintos.
- Tocar el QR de pedidos/pago de Fudo Comensal / Fudo Pay.
- Login con Google (para el MVP, solo email + contraseña).
- KYC real sobre el DNI (se guarda el dato, no se verifica contra RENAPER — igual que una tarjeta de fidelidad de supermercado).
- Saldo parcial en tarjetas de regalo (todo o nada).
- `merchants.timezone` (la demo entera vive en Buenos Aires, una sola zona horaria).

## Riesgos y supuestos abiertos

- El mecanismo de carga de DNI depende de que el mozo lo haga siempre — mitigado por forzarlo como paso obligatorio en la pantalla de cierre de cuenta del propio sistema Fudo, no por buena voluntad humana.
- Cross-restaurant demand (que a alguien le importe un perfil único) sigue sin validar a gran escala — este proyecto es el primer experimento barato para probarlo.
- Datos de la demo: 100% de mentira (30 merchants ficticios en Palermo, ubicación simulada fija).
