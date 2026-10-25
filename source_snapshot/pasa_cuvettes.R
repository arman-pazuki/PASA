# Approved photographic cuvette renderer. Calculated sample colors are vector
# overlays; neutral glass/background are local assets. Only sample names and
# applicable interpretation tags are shown beneath the cuvettes.
# The same ggplot is used by Shiny and scientific image exports. The decorative
# liquid height is fixed by the photograph, not a measurement or path length.
.pasa_cuvette_photo_assets <- local({
  assets <- list()
  function(scene_background = "dark") {
    scene_background <- if (identical(scene_background, "light")) "light" else "dark"
    if (is.null(assets[[scene_background]])) {
      filename <- if (identical(scene_background, "light")) "pasa-cuvette-photo-light.rds" else "pasa-cuvette-photo.rds"
      loaded <- readRDS(file.path(.pasa_source_root(), "www", filename))
      # Decode character glass pixels once, preserving their exact RGBA values.
      if (!inherits(loaded$glass, "nativeRaster")) {
        rgba <- grDevices::col2rgb(loaded$glass, alpha = TRUE)
        # Pack in doubles: bitwShiftL(128,24) is R's NA-integer sentinel and
        # would otherwise destroy the RGB channels of half-transparent pixels.
        packed <- rgba[1L, ] + 256 * rgba[2L, ] + 65536 * rgba[3L, ] + 16777216 * rgba[4L, ]
        packed[packed >= 2147483648] <- packed[packed >= 2147483648] - 4294967296
        packed <- suppressWarnings(as.integer(packed))
        dim(packed) <- dim(loaded$glass); class(packed) <- "nativeRaster"
        loaded$glass <- packed
      }
      assets[[scene_background]] <<- loaded
    }
    assets[[scene_background]]
  }
})

# Batch all photographic pieces in one plot layer. Hundreds of independent
# annotation layers otherwise spend far more time rebuilding ggplot metadata
# than drawing the actual sample colors.
.GeomPasaCuvetteRaster <- ggplot2::ggproto("GeomPasaCuvetteRaster", ggplot2::Geom,
  required_aes = c("xmin", "xmax", "ymin", "ymax"),
  draw_key = ggplot2::draw_key_blank,
  draw_panel = function(data, panel_params, coord, assets, scene_names) {
    count <- nrow(data)
    corners <- coord$transform(data.frame(x = c(data$xmin, data$xmax),
      y = c(data$ymin, data$ymax)), panel_params)
    pieces <- lapply(seq_len(count), function(i) {
      grid::rasterGrob(assets[[scene_names[[i]]]],
        x = grid::unit((corners$x[i] + corners$x[i + count]) / 2, "npc"),
        y = grid::unit((corners$y[i] + corners$y[i + count]) / 2, "npc"),
        width = grid::unit(abs(corners$x[i + count] - corners$x[i]), "npc"),
        height = grid::unit(abs(corners$y[i + count] - corners$y[i]), "npc"),
        interpolate = TRUE, gp = grid::gpar(col = NA))
    })
    grid::gTree(children = do.call(grid::gList, pieces))
  })

.pasa_cuvette_scene <- function(items, ncol = 5L, dark = FALSE, caption = NULL, caption_width = 110L, scene_background = "dark") {
  light_scene <- identical(scene_background, "light")
  assets <- .pasa_cuvette_photo_assets(scene_background)
  n <- length(items)
  if (!n) return(NULL)
  ncol <- min(n, max(1, as.integer(ncol)))
  nrow <- ceiling(n / ncol)
  single <- n == 1L
  scene_width <- if (single) 1774 else 400 + ncol * 430
  row_height <- 927
  pieces <- list()
  add_piece <- function(asset, xmin, xmax, ymin, ymax) {
    pieces[[length(pieces) + 1L]] <<- data.frame(asset, xmin, xmax, ymin, ymax)
  }
  for (r in seq_len(nrow)) {
    y <- -(r - 1) * row_height
    add_piece(if (single) "full" else "lamp", 0, if (single) 1774 else 400, y, y + 887)
    if (!single) {
      add_piece("empty", 399, scene_width, y, y + 887)
      for (c in seq_len(min(ncol, n - (r - 1L) * ncol))) {
        dx <- 400 + (c - 1) * 430 - 869
        add_piece("glass", dx + 1001, dx + 1185, y + 887 - 690, y + 887 - 271)
      }
    }
  }
  scenes <- do.call(rbind, pieces)
  p <- ggplot2::ggplot() + ggplot2::layer(geom = .GeomPasaCuvetteRaster,
    stat = "identity", position = "identity", data = scenes,
    mapping = ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
    inherit.aes = FALSE, params = list(assets = assets, scene_names = scenes$asset))
  d <- data.frame(id = seq_len(n),
    dx = if (single) 0 else 400 + ((seq_len(n) - 1) %% ncol) * 430 - 869,
    dy = -((seq_len(n) - 1) %/% ncol) * row_height,
    hex = vapply(items, function(it) it$hex, character(1)),
    sample = vapply(items, function(it) {
      label <- as.character(it$sample)
      if (nchar(label) > 22L) label <- paste0(substr(label, 1, 21), "\u2026")
      tag <- if (isTRUE(it$near_blank)) "(floor)" else if (isTRUE(it$car_fallback)) "(blue OD)" else if (isTRUE(it$qy_fallback)) "(global OD)" else ""
      paste0(label, if (nzchar(tag)) paste0("\n", tag) else "")
    }, character(1)))
  polygon <- function(x, y, alpha) {
    k <- length(x)
    data.frame(id = rep(d$id, each = k), x = rep(d$dx, each = k) + rep(x, n),
      y = rep(d$dy, each = k) + rep(887 - y, n), hex = rep(d$hex, each = k), alpha = alpha)
  }
  # The generated photo contains only colorless liquid. These overlays derive
  # their color from the sample hex, inside the windows, leaving real glass
  # walls, the meniscus, and its photograph's highlights visible.
  front <- polygon(c(1044, 1054, 1109, 1118, 1118, 1112, 1054, 1044),
                   c(399, 402, 402, 399, 578, 582, 582, 576), .57)
  side <- polygon(c(1128, 1143, 1143, 1128), c(400, 396, 577, 582), .48)
  p <- p +
    ggplot2::geom_polygon(data = front, ggplot2::aes(x, y, group = id, fill = hex), alpha = .57, color = NA) +
    ggplot2::geom_polygon(data = side, ggplot2::aes(x, y, group = id, fill = hex), alpha = .48, color = NA) +
    ggplot2::geom_text(data = d, ggplot2::aes(x = dx + 1090, y = dy + 172, label = sample), size = 3.2, color = if (light_scene) "#26343d" else "#eff6fb") +
    ggplot2::scale_fill_identity() +
    ggplot2::coord_fixed(xlim = c(0, scene_width), ylim = c(-(nrow - 1) * row_height, 887), expand = FALSE) +
    ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0),
      plot.background = ggplot2::element_rect(fill = if (light_scene) "#f2f1ef" else "#071721", color = NA),
      plot.caption = ggplot2::element_text(size = 8, hjust = 0, color = if (light_scene) "#34434d" else "#dce8ed", margin = ggplot2::margin(t = 10, l = 6, r = 6)))
  if (!is.null(caption) && nzchar(caption)) p <- p + ggplot2::labs(caption = paste(strwrap(caption, width = caption_width), collapse = "\n"))
  p
}


draw_cuvette <- function(fill = "#4a7d12", fill_frac = .62, bg_tex = TRUE, caption = NULL, caption_width = 110L, scene_background = "dark", sample = "Sample") {
  .pasa_cuvette_scene(list(list(hex = fill, sample = sample)), ncol = 1L,
    caption = caption, caption_width = caption_width, scene_background = scene_background)
}

draw_cuvette_grid <- function(items, ncol, dark = FALSE, scene_background = "dark") {
  .pasa_cuvette_scene(items, ncol = ncol, dark = dark, scene_background = scene_background)
}
