"""geoMap v2 Python mirror — pre-validation instrument.

One owner per kernel: kernels.py owns the projection mathematics, oracle.py
wraps the independent authority (pyproj/PROJ). Nothing else re-derives a
formula. Where MATLAB and this mirror disagree, MATLAB is right by
definition; the mirror's job is to find the disagreement, not to win it.
"""
__version__ = "0.1.0"
