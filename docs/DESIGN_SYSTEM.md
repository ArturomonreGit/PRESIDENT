# Sistema de diseño

Todos los colores, tamaños y fábricas de controles están en `scripts/ui/ui.gd`.

| Token | Valor | Uso |
|---|---|---|
| `BG` / `SIDE` / `TOP` | #EEF1F6 / #1C2636 / #FFFFFF | fondo, menú lateral (oscuro), cabecera |
| `PANEL` / `PANEL2` / `PANEL3` | #FFFFFF / #F4F6FA / #E8ECF3 | tarjetas, hover, botones |
| `BORDER` | #D8DEE8 | bordes |
| `TEXT` / `MUTED` / `FAINT` | #1A2332 / #5A6679 / #8792A4 | texto |
| `SIDE_TEXT` / `SIDE_MUTED` | #E8EEF7 / #9AA8BD | texto sobre el menú lateral |
| `ACCENT` / `GOOD` / `WARN` / `BAD` / `GOLD` | #2563EB / #12875A / #B7791F / #D0384A / #C99A12 | estados |

Tamaños de letra: 10 (etiquetas) · 11 · 13 (cuerpo) · 15 · 18 (título) · 26 (cabecera).
Componentes: `card`, `hero`, `kpi`, `chip`, `button` (primary/good/warn/danger/ghost), `meter`, `party_tag`, `party_emblem`.
Los escudos son genéricos (círculo, motivo y siglas); no se usan logotipos reales.
