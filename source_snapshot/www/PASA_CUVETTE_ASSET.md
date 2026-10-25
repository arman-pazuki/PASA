# Sample-color bench asset

PASA uses static laboratory-bench images and photographic cuvettes to display
spectrum-derived sample colors. The empty-bench asset is
`pasa-cuvette-bench.png`; `pasa-cuvette-photo.png` adds a cuvette with colorless
liquid, glass walls, a meniscus, rim, base, and reflections.
`pasa-cuvette-photo.rds` is the local raster cache used by R's built-in grid
graphics. It includes the neutral scene and photographic glass on a soft
plotting mask for arranging several samples on a continuous bench. The
empty-bench PNG and RDS files provide that background.

No extra R image package or network access is needed at runtime. Each row has
one lamp at the left. `pasa_cuvettes.R` draws the spectrum-derived color inside
the photographic liquid windows, plus sample names and interpretation tags.
The exact hex color is available in the closed-by-default Color details table
below the image. It follows the single sample or all samples currently shown.
All photographic pieces share one plot layer, avoiding hundreds of
independent annotation layers for large sample sets. The responsive desktop
layout reserves approximately 168 px for the lamp and 180 px per sample, giving
five columns at 1,100 px available width. The last row includes only real samples.

Lighting, transparency, and reflections in the scene are illustrative. They
do not change the computed hex color or the exported rendering metadata.

The scene background has Dark and Light options. Dark is the default.
`pasa-cuvette-photo-light.png` provides the light bench and laboratory scene;
`pasa-cuvette-bench-light.png` provides the empty light scene for grids.
`pasa-cuvette-photo-light.rds` caches the light scene with the same crop and mask.
The `cuv_scene_background` radio changes
only the scene asset and label/caption contrast, independently of the app theme.
The chosen scene is used in single/grid image exports. Polygon coordinates,
alpha, calculated hexadecimal values, and Color details are unchanged.
