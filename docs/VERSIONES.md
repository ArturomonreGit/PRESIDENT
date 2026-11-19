# Control de versiones

## Esquema actual
- **Fase:** Alpha. Línea actual: **Alpha 0.2.x**.
- **Formato:** `Alpha 0.<línea>.<entrega>`. Cada entrega validada por el responsable del proyecto sube el último número.
- **Definitiva:** cuando el responsable dé por terminada la alpha se pasará a la numeración definitiva (se anotará aquí).
- **Código:** `Rules.GAME_STAGE` + `Rules.GAME_VERSION`; texto para mostrar: `Rules.version_label()`.
- **Git:** una etiqueta por versión (`v0.2.0-alpha`, `v0.2.1-alpha`…) sobre el commit que se entregó.

## Plan de entregas de la línea Alpha 0.2
Ruta: documento «Especificación de negociación, formación de Gobierno e investidura» (entregas A–G).

| Versión | Entrega | Contenido | Estado |
|---|---|---|---|
| Alpha 0.2.0 | B (antes 2.15.0) | Perfiles de la IA, poder negociador, modalidades y mesa ampliada (10 categorías) | Validada |
| Alpha 0.2.1 | C | Campos de compromisos, reclamaciones de cartera, vicepresidencias, límite 8–20, seguimiento de objetivos; rediseño de la interfaz de negociación | Entregada |
| Alpha 0.2.2 | D | Cinco candidatos por cartera, perfiles y selección por titular | Entregada; probada por el usuario, botones corregidos en 0.2.3 |
| Alpha 0.2.3 | E | Capital político normalizado (+ corrección de las pestañas de la ficha de cartera) | Entregada, pendiente de validar |
| Alpha 0.2.4 | F | Capa de diputados (350 votos con disciplina) y pantalla de investidura | Entregada, pendiente de validar |
| Alpha 0.2.5 | G | QA y migraciones | Pendiente |

## Equivalencia con la numeración anterior
| Antes | Ahora |
|---|---|
| 2.12.0 | (histórica, anterior a la Alpha) |
| 2.13.0 | (histórica, anterior a la Alpha) |
| 2.14.0 | (histórica, anterior a la Alpha) |
| 2.15.0 | Alpha 0.2.0 |
