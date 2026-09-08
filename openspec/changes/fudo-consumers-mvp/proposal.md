# Fudo Consumers — MVP

## Qué se está construyendo

Una app mobile (Flutter) de fidelización, descubrimiento con IA y regalos para el ecosistema de restaurantes de Fudo, con tres pestañas: **Buscar** (buscador en lenguaje natural sobre menú y precios reales, con resultados en lista y mapa), **Mis Lugares** (perfil gastronómico armado con IA y fidelización por restaurante) y **Regalar** (compra y envío de tarjetas de regalo). Se acompaña de una web en Next.js de menor prioridad, pensada a futuro para SEO.

## Por qué

Fudo es el único actor que está presente en cada venta de un restaurante, sin importar el método de pago (efectivo, tarjeta, transferencia) ni el formato del local. Ni Google Maps, ni las apps de delivery, ni una empresa de gift boxes tienen ese dato. Hoy esa información existe pero está fragmentada por restaurante — no hay un perfil único del comensal. Esa presencia transversal es la ventaja injusta: no es que Fudo ya conozca al consumer, es que es el único que puede llegar a conocerlo.

## Alcance de esta propuesta

- Fidelización por restaurante: el mozo carga el DNI del comensal en una pantalla propia de Fudo al cerrar la cuenta; cada dueño configura y financia sus propias reglas de premio.
- Buscador en lenguaje natural sobre el menú y precio real de cada local.
- Tarjetas de regalo por niveles (classic/gold/black/platinum).
- Web en Next.js (SSR) como iniciativa de baja prioridad, se construye al final si sobra tiempo.

## Fuera de alcance

El detalle completo de lo excluido conscientemente (delivery propio, reservas, ocupación de mesas, crédito compartido entre restaurantes, KYC real, etc.) está documentado en `design.md`, Decisión 12.

## Estado

MVP en desarrollo / demo.
