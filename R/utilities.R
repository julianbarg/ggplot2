#' @export
#' @examples
#' ggplot(mpg, aes(displ, hwy)) +
#'   geom_point(alpha = 0.5, colour = "blue")
#'
#' ggplot(mpg, aes(displ, hwy)) +
#'   geom_point(colour = alpha("blue", 0.5))
scales::alpha

"%||%" <- function(a, b) {
  if (!is.null(a)) a else b
}

"%|W|%" <- function(a, b) {
  if (!is.waive(a)) a else b
}

# Check required aesthetics are present
# This is used by geoms and stats to give a more helpful error message
# when required aesthetics are missing.
#
# @param character vector of required aesthetics
# @param character vector of present aesthetics
# @param name of object for error message
# @keyword internal
check_required_aesthetics <- function(required, present, name, call = caller_env()) {
  if (is.null(required)) return()

  required <- strsplit(required, "|", fixed = TRUE)
  if (any(lengths(required) > 1)) {
    required <- lapply(required, rep_len, 2)
    required <- list(
      vapply(required, `[`, character(1), 1),
      vapply(required, `[`, character(1), 2)
    )
  } else {
    required <- list(unlist(required))
  }
  missing_aes <- lapply(required, setdiff, present)
  if (any(lengths(missing_aes) == 0)) return()
  message <- "{.fn {name}} requires the following missing aesthetics: {.field {missing_aes[[1]]}}"
  if (length(missing_aes) > 1) {
    message <- paste0(message, " {.strong or} {.field {missing_aes[[2]]}}")
  }
  cli::cli_abort(paste0(message, "."), call = call)
}

# Concatenate a named list for output
# Print a `list(a=1, b=2)` as `(a=1, b=2)`
#
# @param list to concatenate
# @keyword internal
#X clist(list(a=1, b=2))
#X clist(par()[1:5])
clist <- function(l) {
  paste(paste(names(l), l, sep = " = ", collapse = ", "), sep = "")
}

# Return unique columns
# This is used for figuring out which columns are constant within a group
#
# @keyword internal
uniquecols <- function(df) {
  df <- df[1, sapply(df, is_unique), drop = FALSE]
  rownames(df) <- seq_len(nrow(df))
  df
}

#' Convenience function to remove missing values from a data.frame
#'
#' Remove all non-complete rows, with a warning if `na.rm = FALSE`.
#' ggplot is somewhat more accommodating of missing values than R generally.
#' For those stats which require complete data, missing values will be
#' automatically removed with a warning. If `na.rm = TRUE` is supplied
#' to the statistic, the warning will be suppressed.
#'
#' @param df data.frame
#' @param na.rm If true, will suppress warning message.
#' @param vars Character vector of variables to check for missings in
#' @param name Optional function name to improve error message.
#' @param finite If `TRUE`, will also remove non-finite values.
#' @keywords internal
#' @export
remove_missing <- function(df, na.rm = FALSE, vars = names(df), name = "",
                           finite = FALSE) {
  check_bool(na.rm)
  missing <- detect_missing(df, vars, finite)

  if (any(missing)) {
    df <- df[!missing, , drop = FALSE]
    if (!na.rm) {
      if (name != "") name <- paste(" ({.fn ", name, "})", sep = "")
      msg <- paste0(
        "Removed {sum(missing)} row{?s} containing ",
        if (finite) "non-finite" else "missing values or values",
        " outside the scale range", name, "."
      )
      cli::cli_warn(msg)
    }
  }

  df
}
detect_missing <- function(df, vars, finite = FALSE) {
  vars <- intersect(vars, names(df))
  !cases(df[, vars, drop = FALSE], if (finite) is_finite else is_complete)
}

# Returns a logical vector of same length as nrow(x). If all data on a row
# is finite (not NA, NaN, Inf, or -Inf) return TRUE; otherwise FALSE.
cases <- function(x, fun) {
  ok <- vapply(x, fun, logical(nrow(x)))

  # Need a special case test when x has exactly one row, because rowSums
  # doesn't respect dimensions for 1x1 matrices. vapply returns a vector (not
  # a matrix when the input has one row.
  if (is.vector(ok)) {
    all(ok)
  } else {
    # Find all the rows where all are TRUE
    rowSums(as.matrix(ok)) == ncol(x)
  }
}

# Wrapper around is.finite to handle list and character cols
is_finite <- function(x) {
  if (typeof(x) == "list") {
    !vapply(x, is.null, logical(1))
  } else if (typeof(x) == "character") {
    !is.na(x)
  } else {
    is.finite(x)
  }
}

is_complete <- function(x) {
  if (typeof(x) == "list") {
    !vapply(x, is.null, logical(1))
  } else {
    !is.na(x)
  }
}


#' Used in examples to illustrate when errors should occur.
#'
#' @param expr code to evaluate.
#' @export
#' @keywords internal
#' @examples
#' should_stop(stop("Hi!"))
#' should_stop(should_stop("Hi!"))
should_stop <- function(expr) {
  res <- try(print(force(expr)), TRUE)
  if (!inherits(res, "try-error")) {
    cli::cli_abort("No error!")
  }
  invisible()
}


#' A waiver object.
#'
#' A waiver is a "flag" object, similar to `NULL`, that indicates the
#' calling function should just use the default value.  It is used in certain
#' functions to distinguish between displaying nothing (`NULL`) and
#' displaying a default value calculated elsewhere (`waiver()`)
#'
#' @export
#' @keywords internal
waiver <- function() structure(list(), class = "waiver")

is.waive <- function(x) inherits(x, "waiver")


rescale01 <- function(x) {
  rng <- range(x, na.rm = TRUE)
  (x - rng[1]) / (rng[2] - rng[1])
}

pal_binned <- function(palette) {
  function(x) {
    palette(length(x))
  }
}

#' Give a deprecation error, warning, or message, depending on version number.
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' @param version The last version of ggplot2 where this function was good
#'   (in other words, the last version where it was not deprecated).
#' @param msg The message to print.
#' @keywords internal
#' @export
gg_dep <- function(version, msg) {
  deprecate_warn0("3.3.0", "gg_dep()")
  .Deprecated()
  v <- as.package_version(version)
  cv <- utils::packageVersion("ggplot2")
  text <- "{msg} (Defunct; last used in version {version})."

  # If current major number is greater than last-good major number, or if
  #  current minor number is more than 1 greater than last-good minor number,
  #  give error.
  if (cv[[1,1]] > v[[1,1]]  ||  cv[[1,2]] > v[[1,2]] + 1) {
    cli::cli_abort(text)

  # If minor number differs by one, give warning
  } else if (cv[[1,2]] > v[[1,2]]) {
    cli::cli_warn(text)

  # If only subminor number is greater, give message
  } else if (cv[[1,3]] > v[[1,3]]) {
    cli::cli_inform(text)
  }

  invisible()
}

has_name <- function(x) {
  nms <- names(x)
  if (is.null(nms)) {
    return(rep(FALSE, length(x)))
  }

  !is.na(nms) & nms != ""
}

# Use chartr() for safety since toupper() fails to convert i to I in Turkish locale
lower_ascii <- "abcdefghijklmnopqrstuvwxyz"
upper_ascii <- "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
to_lower_ascii <- function(x) chartr(upper_ascii, lower_ascii, x)
to_upper_ascii <- function(x) chartr(lower_ascii, upper_ascii, x)

tolower <- function(x) {
  cli::cli_abort("Please use {.fn to_lower_ascii}, which works fine in all locales.")
}

toupper <- function(x) {
  cli::cli_abort("Please use {.fn to_upper_ascii}, which works fine in all locales.")
}

# Convert a snake_case string to camelCase
camelize <- function(x, first = FALSE) {
  x <- gsub("_(.)", "\\U\\1", x, perl = TRUE)
  if (first) x <- firstUpper(x)
  x
}

snakeize <- function(x) {
  x <- gsub("([A-Za-z])([A-Z])([a-z])", "\\1_\\2\\3", x)
  x <- gsub(".", "_", x, fixed = TRUE)
  x <- gsub("([a-z])([A-Z])", "\\1_\\2", x)
  to_lower_ascii(x)
}

firstUpper <- function(s) {
  paste0(to_upper_ascii(substring(s, 1, 1)), substring(s, 2))
}

snake_class <- function(x) {
  snakeize(class(x)[1])
}

empty <- function(df) {
  is.null(df) || nrow(df) == 0 || ncol(df) == 0 || is.waive(df)
}

is.discrete <- function(x) {
  is.factor(x) || is.character(x) || is.logical(x)
}

# This function checks that all columns of a dataframe `x` are data and returns
# the names of any columns that are not.
# We define "data" as atomic types or lists, not functions or otherwise.
# The `inherits(x, "Vector")` check is for checking S4 classes from Bioconductor
# and whether they can be expected to follow behavior typical of vectors. See
# also #3835
check_nondata_cols <- function(x) {
  idx <- (vapply(x, function(x) {
    is.null(x) || rlang::is_vector(x) || inherits(x, "Vector")
  }, logical(1)))
  names(x)[which(!idx)]
}

compact <- function(x) {
  null <- vapply(x, is.null, logical(1))
  x[!null]
}

is.formula <- function(x) inherits(x, "formula")

deparse2 <- function(x) {
  y <- deparse(x, backtick = TRUE)
  if (length(y) == 1) {
    y
  } else {
    paste0(y[[1]], "...")
  }
}

dispatch_args <- function(f, ...) {
  args <- list(...)
  formals <- formals(f)
  formals[names(args)] <- args
  formals(f) <- formals
  f
}

is_missing_arg <- function(x) identical(x, quote(expr = ))
# Get all arguments in a function as a list. Will fail if an ellipsis argument
# named .ignore
# @param ... passed on in case enclosing function uses ellipsis in argument list
find_args <- function(...) {
  env <- parent.frame()
  args <- names(formals(sys.function(sys.parent(1))))

  vals <- mget(args, envir = env)
  vals <- vals[!vapply(vals, is_missing_arg, logical(1))]

  modify_list(vals, list2(..., `...` = NULL))
}

# Used in annotations to ensure printed even when no
# global data
dummy_data <- function() data_frame0(x = NA, .size = 1)

with_seed_null <- function(seed, code) {
  if (is.null(seed)) {
    code
  } else {
    withr::with_seed(seed, code)
  }
}

seq_asc <- function(to, from) {
  if (to > from) {
    integer()
  } else {
    to:from
  }
}

# Needed to trigger package loading
#' @importFrom tibble tibble
NULL

# Wrapping vctrs data_frame constructor with no name repair
data_frame0 <- function(...) data_frame(..., .name_repair = "minimal")

# Wrapping unique0() to accept NULL
unique0 <- function(x, ...) if (is.null(x)) x else vec_unique(x, ...)

# Code readability checking for uniqueness
is_unique <- function(x) vec_unique_count(x) == 1L

is_scalar_numeric <- function(x) is_bare_numeric(x, n = 1L)

# Check inputs with tibble but allow column vectors (see #2609 and #2374)
as_gg_data_frame <- function(x) {
  x <- lapply(x, validate_column_vec)
  data_frame0(!!!x)
}
validate_column_vec <- function(x) {
  if (is_column_vec(x)) {
    dim(x) <- NULL
  }
  x
}
is_column_vec <- function(x) {
  dims <- dim(x)
  length(dims) == 2L && dims[[2]] == 1L
}

# Parse takes a vector of n lines and returns m expressions.
# See https://github.com/tidyverse/ggplot2/issues/2864 for discussion.
#
# parse(text = c("alpha", "", "gamma"))
# #> expression(alpha, gamma)
#
# parse_safe(text = c("alpha", "", "gamma"))
# #> expression(alpha, NA, gamma)
#
parse_safe <- function(text) {
  check_character(text)
  out <- vector("expression", length(text))
  for (i in seq_along(text)) {
    expr <- parse(text = text[[i]])
    out[[i]] <- if (length(expr) == 0) NA else expr[[1]]
  }
  out
}

switch_orientation <- function(aesthetics) {
  # We should have these as globals somewhere
  x <- ggplot_global$x_aes
  y <- ggplot_global$y_aes
  x_aes <- match(aesthetics, x)
  x_aes_pos <- which(!is.na(x_aes))
  y_aes <- match(aesthetics, y)
  y_aes_pos <- which(!is.na(y_aes))
  if (length(x_aes_pos) > 0) {
    aesthetics[x_aes_pos] <- y[x_aes[x_aes_pos]]
  }
  if (length(y_aes_pos) > 0) {
    aesthetics[y_aes_pos] <- x[y_aes[y_aes_pos]]
  }
  aesthetics
}

#' Utilities for working with bidirectional layers
#'
#' These functions are what underpins the ability of certain geoms to work
#' automatically in both directions. See the *Extending ggplot2* vignette for
#' how they are used when implementing `Geom`, `Stat`, and `Position` classes.
#'
#' `has_flipped_aes()` is used to sniff out the orientation of the layer from
#' the data. It has a range of arguments that can be used to finetune the
#' sniffing based on what the data should look like. `flip_data()` will switch
#' the column names of the data so that it looks like x-oriented data.
#' `flipped_names()` provides a named list of aesthetic names that corresponds
#' to the orientation of the layer.
#'
#' @section Controlling the sniffing:
#' How the layer data should be interpreted depends on its specific features.
#' `has_flipped_aes()` contains a range of flags for defining what certain
#' features in the data correspond to:
#'
#' - `main_is_orthogonal`: This argument controls how the existence of only a `x`
#'   or `y` aesthetic is understood. If `TRUE` then the existing aesthetic
#'   would be then secondary axis. This behaviour is present in [stat_ydensity()]
#'   and [stat_boxplot()]. If `FALSE` then the existing aesthetic is the main
#'   axis as seen in e.g. [stat_bin()], [geom_count()], and [stat_density()].
#' - `range_is_orthogonal`: This argument controls whether the existence of
#'   range-like aesthetics (e.g. `xmin` and `xmax`) represents the main or
#'   secondary axis. If `TRUE` then the range is given for the secondary axis as
#'   seen in e.g. [geom_ribbon()] and [geom_linerange()].
#' - `group_has_equal`: This argument controls whether to test for equality of
#'   all `x` and `y` values inside each group and set the main axis to the one
#'   where all is equal. This test is only performed if `TRUE`, and only after
#'   less computationally heavy tests has come up empty handed. Examples are
#'   [stat_boxplot()] and [stat_ydensity]
#' - `ambiguous`: This argument tells the function that the layer, while
#'   bidirectional, doesn't treat each axis differently. It will circumvent any
#'   data based guessing and only take hint from the `orientation` element in
#'   `params`. If this is not present it will fall back to `FALSE`. Examples are
#'   [geom_line()] and [geom_area()]
#' - `main_is_continuous`: This argument controls how the test for discreteness
#'   in the scales should be interpreted. If `TRUE` then the main axis will be
#'   the one which is not discrete-like. Conversely, if `FALSE` the main axis
#'   will be the discrete-like one. Examples of `TRUE` is [stat_density()] and
#'   [stat_bin()], while examples of `FALSE` is [stat_ydensity()] and
#'   [stat_boxplot()]
#' - `main_is_optional`: This argument controls the rare case of layers were the
#'   main direction is an optional aesthetic. This is only seen in
#'   [stat_boxplot()] where `x` is set to `0` if not given. If `TRUE` there will
#'   be a check for whether all `x` or all `y` are equal to `0`
#'
#' @param data The layer data
#' @param params The parameters of the `Stat`/`Geom`. Only the `orientation`
#'   parameter will be used.
#' @param main_is_orthogonal If only `x` or `y` are present do they correspond
#'   to the main orientation or the reverse. E.g. If `TRUE` and `y` is present
#'   it is not flipped. If `NA` this check will be ignored.
#' @param range_is_orthogonal If `xmin`/`xmax` or `ymin`/`ymax` is present do
#'   they correspond to the main orientation or reverse. If `NA` this check will
#'   be ignored.
#' @param group_has_equal Is it expected that grouped data has either a single
#'   `x` or `y` value that will correspond to the orientation.
#' @param ambiguous Is the layer ambiguous in its mapping by nature. If so, it
#'   will only be flipped if `params$orientation == "y"`
#' @param main_is_continuous If there is a discrete and continuous axis, does
#'   the continuous one correspond to the main orientation?
#' @param main_is_optional Is the main axis aesthetic optional and, if not
#'   given, set to `0`
#' @param flip Logical. Is the layer flipped.
#'
#' @return `has_flipped_aes()` returns `TRUE` if it detects a layer in the other
#' orientation and `FALSE` otherwise. `flip_data()` will return the input
#' unchanged if `flip = FALSE` and the data with flipped aesthetic names if
#' `flip = TRUE`. `flipped_names()` returns a named list of strings. If
#' `flip = FALSE` the name of the element will correspond to the element, e.g.
#' `flipped_names(FALSE)$x == "x"` and if `flip = TRUE` it will correspond to
#' the flipped name, e.g. `flipped_names(FALSE)$x == "y"`
#'
#' @export
#' @keywords internal
#' @name bidirection
#'
has_flipped_aes <- function(data, params = list(), main_is_orthogonal = NA,
                            range_is_orthogonal = NA, group_has_equal = FALSE,
                            ambiguous = FALSE, main_is_continuous = FALSE,
                            main_is_optional = FALSE) {
  # Is orientation already encoded in data?
  if (!is.null(data$flipped_aes)) {
    not_na <- which(!is.na(data$flipped_aes))
    if (length(not_na) != 0) {
      return(data$flipped_aes[[not_na[1L]]])
    }
  }

  # Is orientation requested in the params
  if (!is.null(params$orientation) && !is.na(params$orientation)) {
    return(params$orientation == "y")
  }

  x <- data$x %||% params$x
  y <- data$y %||% params$y
  xmin <- data$xmin %||% params$xmin
  ymin <- data$ymin %||% params$ymin
  xmax <- data$xmax %||% params$xmax
  ymax <- data$ymax %||% params$ymax

  # Does a single x or y aesthetic correspond to a specific orientation
  if (!is.na(main_is_orthogonal) && xor(is.null(x), is.null(y))) {
    return(is.null(y) == main_is_orthogonal)
  }

  has_x <- !is.null(x)
  has_y <- !is.null(y)

  # Does a provided range indicate an orientation
  if (!is.na(range_is_orthogonal)) {
    if (!is.null(ymin) || !is.null(ymax)) {
      return(!range_is_orthogonal)
    }
    if (!is.null(xmin) || !is.null(xmax)) {
      return(range_is_orthogonal)
    }
  }

  # If ambiguous orientation = NA will give FALSE
  if (ambiguous && (is.null(params$orientation) || is.na(params$orientation))) {
    return(FALSE)
  }

  # Is there a single actual discrete position
  y_is_discrete <- is_mapped_discrete(y)
  x_is_discrete <- is_mapped_discrete(x)
  if (xor(y_is_discrete, x_is_discrete)) {
    return(y_is_discrete != main_is_continuous)
  }

  # Does each group have a single x or y value
  if (group_has_equal) {
    if (has_x) {
      if (length(x) == 1) return(FALSE)
      x_groups <- vapply(split(data$x, data$group), vec_unique_count, integer(1))
      if (all(x_groups == 1)) {
        return(FALSE)
      }
    }
    if (has_y) {
      if (length(y) == 1) return(TRUE)
      y_groups <- vapply(split(data$y, data$group), vec_unique_count, integer(1))
      if (all(y_groups == 1)) {
        return(TRUE)
      }
    }
  }

  # default to no
  FALSE
}
#' @rdname bidirection
#' @export
flip_data <- function(data, flip = NULL) {
  flip <- flip %||% any(data$flipped_aes) %||% FALSE
  if (isTRUE(flip)) {
    names(data) <- switch_orientation(names(data))
  }
  data
}
#' @rdname bidirection
#' @export
flipped_names <- function(flip = FALSE) {
  x_aes <- ggplot_global$x_aes
  y_aes <- ggplot_global$y_aes
  if (flip) {
    ret <- as.list(c(y_aes, x_aes))
  } else {
    ret <- as.list(c(x_aes, y_aes))
  }
  names(ret) <- c(x_aes, y_aes)
  ret
}

split_with_index <- function(x, f, n = max(f)) {
  if (n == 1) return(list(x))
  f <- as.integer(f)
  attributes(f) <- list(levels = as.character(seq_len(n)), class = "factor")
  unname(split(x, f))
}

is_bang <- function(x) {
  is_call(x, "!", n = 1)
}

# Puts all columns with 'AsIs' type in a '.ignore' column.



#' Ignoring and exposing data
#'
#' The `.ignore_data()` function is used to hide `<AsIs>` columns during
#' scale interactions in `ggplot_build()`. The `.expose_data()` function is
#' used to restore hidden columns.
#'
#' @param data A list of `<data.frame>`s.
#'
#' @return A modified list of `<data.frame>s`
#' @export
#' @keywords internal
#' @name ignoring_data
#'
#' @examples
#' data <- list(
#'   data.frame(x = 1:3, y = I(1:3)),
#'   data.frame(w = I(1:3), z = 1:3)
#' )
#'
#' ignored <- .ignore_data(data)
#' str(ignored)
#'
#' .expose_data(ignored)
.ignore_data <- function(data) {
  if (!is_bare_list(data)) {
    data <- list(data)
  }
  lapply(data, function(df) {
    is_asis <- vapply(df, inherits, logical(1), what = "AsIs")
    if (!any(is_asis)) {
      return(df)
    }
    df <- unclass(df)
    # We trust that 'df' is a valid data.frame with equal length columns etc,
    # so we can use the more performant `new_data_frame()`
    new_data_frame(c(
      df[!is_asis],
      list(.ignored = new_data_frame(df[is_asis]))
    ))
  })
}

# Restores all columns packed into the '.ignored' column.
#' @rdname ignoring_data
#' @export
.expose_data <- function(data) {
  if (!is_bare_list(data)) {
    data <- list(data)
  }
  lapply(data, function(df) {
    is_ignored <- which(names(df) == ".ignored")
    if (length(is_ignored) == 0) {
      return(df)
    }
    df <- unclass(df)
    new_data_frame(c(df[-is_ignored], df[[is_ignored[1]]]))
  })
}

is_triple_bang <- function(x) {
  if (!is_bang(x)) {
    return(FALSE)
  }

  x <- x[[2]]
  if (!is_bang(x)) {
    return(FALSE)
  }

  x <- x[[2]]
  if (!is_bang(x)) {
    return(FALSE)
  }

  TRUE
}

# Restart handler for using vec_rbind with mix of types
# Ordered is coerced to factor
# If a character vector is present the other is converted to character
with_ordered_restart <- function(expr, .call) {
  withCallingHandlers(
    expr,
    vctrs_error_incompatible_type = function(cnd) {
      x <- cnd[["x"]]
      y <- cnd[["y"]]

      class_x <- class(x)[1]
      class_y <- class(y)[1]

      restart <- FALSE

      if (is.ordered(x) || is.ordered(y)) {
        restart <- TRUE
        if (is.ordered(x)) {
          x <- factor(as.character(x), levels = levels(x))
        }
        if (is.ordered(y)) {
          y <- factor(as.character(y), levels = levels(y))
        }
      } else if (is.character(x) || is.character(y)) {
        restart <- TRUE
        if (is.character(x)) {
          y <- as.character(y)
        } else {
          x <- as.character(x)
        }
      } else if (is.factor(x) || is.factor(y)) {
        restart <- TRUE
        lev <- c()
        if (is.factor(x)) {
          lev <- c(lev, levels(x))
        }
        if (is.factor(y)) {
          lev <- c(lev, levels(y))
        }
        x <- factor(as.character(x), levels = unique(lev))
        y <- factor(as.character(y), levels = unique(lev))
      }

      # Don't recurse and let ptype2 error keep its course
      if (!restart) {
        return(zap())
      }

      msg <- paste0("Combining variables of class <", class_x, "> and <", class_y, ">")
      desc <- paste0(
        "Please ensure your variables are compatible before plotting (location: ",
        format_error_call(.call),
        ")"
      )

      deprecate_soft0(
        "3.4.0",
        I(msg),
        details = desc
      )

      x_arg <- cnd[["x_arg"]]
      y_arg <- cnd[["y_arg"]]
      call <- cnd[["call"]]

      # Recurse with factor methods and restart with the result
      if (inherits(cnd, "vctrs_error_ptype2")) {
        out <- vec_ptype2(x, y, x_arg = x_arg, y_arg = y_arg, call = call)
        restart <- "vctrs_restart_ptype2"
      } else if (inherits(cnd, "vctrs_error_cast")) {
        out <- vec_cast(x, y, x_arg = x_arg, to_arg = y_arg, call = call)
        restart <- "vctrs_restart_cast"
      } else {
        return(zap())
      }

      # Old-R compat for `tryInvokeRestart()`
      try_restart <- function(restart, ...) {
        if (!is_null(findRestart(restart))) {
          invokeRestart(restart, ...)
        }
      }
      try_restart(restart, out)
    }
  )
}

vec_rbind0 <- function(..., .error_call = current_env(), .call = caller_env()) {
  with_ordered_restart(
    vec_rbind(..., .error_call = .error_call),
    .call
  )
}

# This function is used to vectorise the following pattern:
#
# obj$name1 <- obj$name1 %||% value
# obj$name2 <- obj$name2 %||% value
#
# and express this pattern as:
#
# replace_null(obj, name1 = value, name2 = value)
replace_null <- function(obj, ..., env = caller_env()) {
  # Collect dots without evaluating
  dots <- enexprs(...)
  # Select arguments that are null in `obj`
  nms  <- names(dots)
  nms  <- nms[vapply(obj[nms], is.null, logical(1))]
  # Replace those with the evaluated dots
  obj[nms] <- inject(list(!!!dots[nms]), env = env)
  obj
}

attach_plot_env <- function(env) {
  old_env <- getOption("ggplot2_plot_env")
  options(ggplot2_plot_env = env)
  withr::defer_parent(options(ggplot2_plot_env = old_env))
}

as_cli <- function(..., env = caller_env()) {
  cli::cli_fmt(cli::cli_text(..., .envir = env))
}

deprecate_soft0 <- function(..., user_env = NULL) {
  user_env <- user_env %||% getOption("ggplot2_plot_env") %||% caller_env(2)
  lifecycle::deprecate_soft(..., user_env = user_env)
}

deprecate_warn0 <- function(..., user_env = NULL) {
  user_env <- user_env %||% getOption("ggplot2_plot_env") %||% caller_env(2)
  lifecycle::deprecate_warn(..., user_env = user_env)
}
