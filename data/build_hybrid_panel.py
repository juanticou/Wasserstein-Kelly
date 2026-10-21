"""
Panel híbrido para R1 (decisión del autor, 2026-10-21).

Toma ene-2010 a nov-2025 del panel de la línea base (data/processed/, cierre
del 30-dic-2025) y SOLO la fila de dic-2025 de la descarga nueva
(data/processed_2026-01-01/, cierre del 31-dic-2025). Las filas se copian como
texto, así que las de la línea base quedan byte a byte iguales.

Motivo: entre las dos descargas, `Close` es idéntico, pero `Adj Close` se
recalculó con un factor casi constante y ruido de precisión de Yahoo (~1e-6
en los retornos). Ver results_finales/r1_comparacion_panel.csv.

Uso (desde la raíz del proyecto):
    py -B data/build_hybrid_panel.py
"""

from pathlib import Path

OLD = Path("data/processed/monthly_panel.csv")
NEW = Path("data/processed_2026-01-01/monthly_panel.csv")
OUT = Path("data/processed_2026-01-01/monthly_panel_hibrido.csv")
LAST_MONTH = "2025-12-31"

old_lines = OLD.read_text(encoding="utf-8").splitlines()
new_lines = NEW.read_text(encoding="utf-8").splitlines()

if old_lines[0] != new_lines[0]:
    raise SystemExit("Los encabezados de los paneles no coinciden.")
if not (old_lines[-1].startswith(LAST_MONTH) and new_lines[-1].startswith(LAST_MONTH)):
    raise SystemExit(f"La última fila de ambos paneles debe ser {LAST_MONTH}.")
if [l.split(",")[0] for l in old_lines] != [l.split(",")[0] for l in new_lines]:
    raise SystemExit("Las fechas de los paneles no coinciden.")
if OUT.exists():
    raise SystemExit(f"{OUT} ya existe; no se sobrescribe.")

OUT.write_text("\n".join(old_lines[:-1] + [new_lines[-1]]) + "\n", encoding="utf-8")
print(f"Panel híbrido: {OUT} ({len(old_lines) - 1} meses; solo {LAST_MONTH} viene de la descarga nueva)")
