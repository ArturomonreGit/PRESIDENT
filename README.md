# Political Simulator (Demockracy) — Alpha 0.2

> Versión actual: **Alpha 0.2.0**. Numeración y plan de entregas en `docs/VERSIONES.md`.

# Rediseño «Football Manager»

Simulador de gestión política en Godot 4.5.1 (GDScript, renderer GL Compatibility).
Diriges un partido desde la campaña hasta la legislatura: programa y agenda, encuestas, noche electoral,
negociación de la investidura, reparto del Consejo de Ministros y cuatro años de gobierno u oposición.

## Cómo abrirlo
1. Abre la carpeta con **Godot 4.5.1** (o superior 4.5.x) y pulsa *Importar y editar*.
2. Ejecuta (F5). La escena principal es `res://scenes/startup.tscn`.
3. Las partidas se guardan en `user://saves/`. Las partidas de la v0.8/v0.9 se migran automáticamente al abrirlas.

## Qué hay de nuevo respecto a la v0.9.2
- **Interfaz nueva estilo gestor deportivo**: menú lateral por fase, cabecera con el botón único **CONTINUAR**,
  panel derecho contextual (encuestas, objetivo, próximos actos), tema oscuro y diálogos modales.
- **Núcleo separado de la interfaz** (`scripts/core`): ninguna regla depende de nodos; se puede probar sin pantalla.
- **Encuestas vivas** con volatilidad diaria, tendencias, forma reciente y proyección de escaños (D'Hondt).
- **Agenda semanal** (máx. 3 actos al día), entrevistas y debates jugables, delegación en el portavoz.
- **Mapa por circunscripciones**, hemiciclo y noche electoral animada.
- **Investidura con negociación real**: demandas que concedes o exiges, apoyo externo o entrada en el Gobierno,
  vetos, dos votaciones y hasta tres intentos antes de la disolución.
- **Legislatura trimestral (16 turnos)** con motor macroeconómico dinámico (PIB, paro, inflación, tipos, crisis y shocks) y sección País jerárquica con gráficas interactivas, con eventos con decisiones, leyes, socios, compromisos y acciones de oposición.
- **Nuevo ciclo electoral** al terminar la legislatura o disolverse las Cortes.

## Pruebas
```
tests/run_all.sh          # todo (necesita Godot en $GODOT o en el PATH)
```
- `tests/sim_full_game.gd` — partida completa sin interfaz (cualquiera de los 15 partidos o partido propio).
- `tests/migrate_v2.gd` — migración de guardados antiguos.
- `tests/ui_flow.gd` — juega con la interfaz real usando solo CONTINUAR y los diálogos.
- `tests/ui_shots.gd` — capturas de todas las pantallas (requiere renderizado, p. ej. `xvfb-run`).
- `tests/parliament.gd` — Parlamento: iniciativas (ley, PNL, interpelación), enmiendas bidireccionales, voto de arrastre y retirada.
- `tests/parliament_shots.gd` — capturas del Taller (módulos y ventanas) y del Pleno interactivo, con la ventana de enmiendas libres, a 1920×1080.
- `tests/encounters_match.gd` — comprueba que cada pregunta de debates y entrevistas tiene respuestas compatibles (subtipos).
- `tests/table.gd` — mesa de negociación: agenda, vetos, estancamiento, ultimátum, eventos y dilemas.
- `tests/party_roster.gd` — plantilla de 15 partidos (encuestas, territorios, ideologías).
- `tests/wizard_worst.gd` — peor caso del asistente de partida sin desbordes.
- `tests/check_dataset.py`, `tests/test_dhondt_reference.py` — datos y reparto de escaños.

## Aviso
Escenario ficticio inspirado en las elecciones de 2023. Las encuestas, la financiación y la conducta de los
partidos son simulaciones, no datos oficiales. Ver `docs/SOURCES.md`.
