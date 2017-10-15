#' Calculate the mean and its variation using survey methods
#'
#' Calculate means and proportions from complex survey data. A wrapper
#' around \code{\link[survey]{svymean}}, or if \code{proportion = TRUE},
#' \code{\link[survey]{svyciprop}}. \code{survey_mean} should always be
#' called from \code{\link{summarise}}.
#'
#' @param x A variable or expression, or empty
#' @param na.rm A logical value to indicate whether missing values should be dropped
#' @param vartype Report variability as one or more of: standard error ("se", default),
#'                confidence interval ("ci"), variance ("var") or coefficient of variation
#'                ("cv").
#' @param level (For vartype = "ci" only) A single number or vector of numbers indicating
#'              the confidence level
#' @param proportion Use methods to calculate the proportion that may have more accurate
#'                   confidence intervals near 0 and 1. Based on
#'                   \code{\link[survey]{svyciprop}}.
#' @param prop_method Type of proportion method to use if proportion is \code{TRUE}. See
#'                    \code{\link[survey]{svyciprop}} for details.
#' @param deff A logical value to indicate whether the design effect should be returned.
#' @param df (For vartype = "ci" only) A numeric value indicating the degrees of freedom
#'           for t-distribution. The default (NULL) uses \code{\link[survey]{degf}},
#'           but Inf is the usual survey package's default (except in
#'           \code{\link[survey]{svyciprop}}.
#' @param .svy A \code{tbl_svy} object. When called from inside a summarize function
#'   the default automatically sets the survey to the current survey.
#' @param ... Ignored
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(api99 = survey_mean(api99),
#'             api_diff = survey_mean(api00 - api99, vartype = c("ci", "cv")))
#'
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(api00 = survey_mean(api00))
#'
#' # Leave x empty to calculate the proportion in each group
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(pct = survey_mean())
#'
#' # Setting proportion = TRUE uses a different method for calculating confidence intervals
#' dstrata %>%
#'   summarise(high_api = survey_mean(api00 > 875, proportion = TRUE, vartype = "ci"))
#'
#' # level takes a vector for multiple levels of confidence intervals
#' dstrata %>%
#'   summarise(api99 = survey_mean(api99, vartype = "ci", level = c(0.95, 0.65)))
#'
#' # Note that the default degrees of freedom in srvyr is different from
#' # survey, so your confidence intervals might not be exact matches. To
#' # Replicate survey's behavior, use df = Inf
#' dstrata %>%
#'   summarise(srvyr_default = survey_mean(api99, vartype = "ci"),
#'             survey_defualt = survey_mean(api99, vartype = "ci", df = Inf))
#'
#' comparison <- survey::svymean(~api99, dstrata)
#' confint(comparison) # survey's default
#' confint(comparison, df = survey::degf(dstrata)) # srvyr's default
#'
#' @export
survey_mean <- function(
  x, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  proportion = FALSE, prop_method = c("logit", "likelihood", "asin", "beta", "mean"),
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  UseMethod("survey_mean", .svy)
}

#' @export
survey_mean.tbl_svy <- function(
  x, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  proportion = FALSE, prop_method = c("logit", "likelihood", "asin", "beta", "mean"),
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)
  if (missing(prop_method)) prop_method <- "logit"
  prop_method <- match.arg(prop_method, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  if (!proportion) {
    survey_stat_ungrouped(.svy, survey::svymean, x, na.rm, vartype, level, deff, df)
  } else {
    # survey::ciprop only accepts formulas so can't use main function
    survey_stat_proportion(.svy, x, na.rm, vartype, level, prop_method, df)
  }
}

#' @export
survey_mean.grouped_svy <- function(
  x, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  proportion = FALSE, prop_method = c("logit", "likelihood", "asin", "beta", "mean"),
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)
  if (missing(prop_method)) prop_method <- "logit"
  prop_method <- match.arg(prop_method, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  if (missing(x)) {
    if (proportion) stop("proportion does not work with factors.")
    survey_stat_factor(.svy, survey::svymean, na.rm, vartype, level, deff, df)
  } else if (proportion) {
    survey_stat_grouped(.svy, survey::svyciprop, x, na.rm, vartype, level,
                        deff = FALSE, df, prop_method)
  } else survey_stat_grouped(.svy, survey::svymean, x, na.rm, vartype, level, deff, df)
}


#' Calculate the total and its variation using survey methods
#'
#' Calculate totals from complex survey data. A wrapper
#' around \code{\link[survey]{svytotal}}. \code{survey_total} should always be
#' called from \code{\link{summarise}}.
#'
#' @param x A variable or expression, or empty
#' @param na.rm A logical value to indicate whether missing values should be dropped
#' @param vartype Report variability as one or more of: standard error ("se", default),
#'                confidence interval ("ci"), variance ("var") or coefficient of variation
#'                ("cv").
#' @param level A single number or vector of numbers indicating the confidence level
#' @param deff A logical value to indicate whether the design effect should be returned.
#' @param df (For vartype = "ci" only) A numeric value indicating the degrees of freedom
#'           for t-distribution. The default (NULL) uses \code{\link[survey]{degf}},
#'           but Inf is the usual survey package's default.
#' @param .svy A \code{tbl_svy} object. When called from inside a summarize function
#'   the default automatically sets the survey to the current survey.
#' @param ... Ignored
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(enroll = survey_total(enroll),
#'             tot_meals = survey_total(enroll * meals / 100, vartype = c("ci", "cv")))
#'
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(api00 = survey_total(enroll))
#'
#' # Leave x empty to calculate the total in each group
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(pct = survey_total())
#'
#' # level takes a vector for multiple levels of confidence intervals
#' dstrata %>%
#'   summarise(enroll = survey_total(enroll, vartype = "ci", level = c(0.95, 0.65)))
#'
#' # Note that the default degrees of freedom in srvyr is different from
#' # survey, so your confidence intervals might not exactly match. To
#' # replicate survey's behavior, use df = Inf
#' dstrata %>%
#'   summarise(srvyr_default = survey_total(api99, vartype = "ci"),
#'             survey_defualt = survey_total(api99, vartype = "ci", df = Inf))
#'
#' comparison <- survey::svytotal(~api99, dstrata)
#' confint(comparison) # survey's default
#' confint(comparison, df = survey::degf(dstrata)) # srvyr's default
#'
#' @export
survey_total <- function(
  x = NULL, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  UseMethod("survey_total", .svy)
}

#' @export
survey_total.tbl_svy <- function(
  x, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  survey_stat_ungrouped(.svy, survey::svytotal, x, na.rm, vartype, level, deff, df)
}

#' @export
survey_total.grouped_svy <- function(
  x, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"), level = 0.95,
  deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  if (!missing(x)) survey_stat_grouped(.svy, survey::svytotal, x, na.rm,
                                       vartype, level, deff, df)
  else survey_stat_factor(.svy, survey::svytotal, na.rm, vartype, level, deff, df)
}


#' Calculate the ratio and its variation using survey methods
#'
#' Calculate ratios from complex survey data. A wrapper
#' around \code{\link[survey]{svyratio}}. \code{survey_ratio}
#' should always be called from \code{\link{summarise}}.
#'
#' @param numerator The numerator of the ratio
#' @param denominator The denominator of the ratio
#' @param na.rm A logical value to indicate whether missing values should be dropped
#' @param vartype Report variability as one or more of: standard error ("se", default),
#'                confidence interval ("ci"), variance ("var") or coefficient of variation
#'                ("cv").
#' @param level A single number or vector of numbers indicating the confidence level
#' @param deff A logical value to indicate whether the design effect should be returned.
#' @param df (For vartype = "ci" only) A numeric value indicating the degrees of freedom
#'           for t-distribution. The default (NULL) uses \code{\link[survey]{degf}},
#'           but Inf is the usual survey package's default (except in
#'           \code{\link[survey]{svyciprop}}.
#' @param .svy A \code{tbl_svy} object. When called from inside a summarize function
#'   the default automatically sets the survey to the current survey.
#' @param ... Ignored
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(enroll = survey_ratio(api00, api99, vartype = c("ci", "cv")))
#'
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(api00 = survey_ratio(api00, api99))
#'
#' # level takes a vector for multiple levels of confidence intervals
#' dstrata %>%
#'   summarise(enroll = survey_ratio(api99, api00, vartype = "ci", level = c(0.95, 0.65)))
#'
#' # Note that the default degrees of freedom in srvyr is different from
#' # survey, so your confidence intervals might not exactly match. To
#' # replicate survey's behavior, use df = Inf
#' dstrata %>%
#'   summarise(srvyr_default = survey_total(api99, vartype = "ci"),
#'             survey_defualt = survey_total(api99, vartype = "ci", df = Inf))
#'
#' comparison <- survey::svytotal(~api99, dstrata)
#' confint(comparison) # survey's default
#' confint(comparison, df = survey::degf(dstrata)) # srvyr's default
#'
#' @export
survey_ratio <- function(
  numerator, denominator, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"),
  level = 0.95, deff = FALSE, df = NULL, .svy  = current_svy(), ...
) {
  UseMethod("survey_ratio", .svy)
}

#' @export
survey_ratio.tbl_svy <- function(
  numerator, denominator, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"),
  level = 0.95, deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  vartype <- c("coef", vartype)
  if (deff) vartype <- c(vartype, "deff")

  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- data.frame(SRVYR_VAR_NUM = numerator,
                                               SRVYR_VAR_DEN = denominator)
  } else {
    .svy$variables <- data.frame(SRVYR_VAR_NUM = numerator,
                                 SRVYR_VAR_DEN = denominator)
  }

  stat <- survey::svyratio(~SRVYR_VAR_NUM, ~SRVYR_VAR_DEN,
                           .svy, na.rm = na.rm, deff = deff, df = df)

  out <- get_var_est(stat, vartype, level = level, df = df)
  dplyr::bind_cols(out)
}

#' @export
survey_ratio.grouped_svy <- function(
  numerator, denominator, na.rm = FALSE, vartype = c("se", "ci", "var", "cv"),
  level = 0.95, deff = FALSE, df = NULL, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "se"
  vartype <- match.arg(vartype, several.ok = TRUE)

  if (is.null(df)) df <- survey::degf(.svy)

  grp_names <- group_vars(.svy)

  grps <- select(.svy$variables, !!!rlang::syms(grp_names))

  new_vars <- data.frame(dplyr::bind_cols(grps,
                                          data.frame(SRVYR_VAR_NUM = numerator,
                                                     SRVYR_VAR_DEN = denominator)))
  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- new_vars
  } else {
    .svy$variables <- new_vars
  }

  stat <- survey::svyby(~SRVYR_VAR_NUM, survey::make.formula(grp_names),
                        .svy, survey::svyratio,
                        denominator = ~SRVYR_VAR_DEN,
                        na.rm = na.rm, ci = TRUE, deff = deff)

  vartype <- c("grps", "coef", vartype)
  if (deff) vartype <- c(vartype, "deff")

  out <- get_var_est(stat, vartype, grps = grp_names,
                     level = level, df = df)

  dplyr::bind_cols(out)
}

#' Calculate the quantile and its variation using survey methods
#'
#' Calculate quantiles from complex survey data. A wrapper
#' around \code{\link[survey]{svyquantile}}. \code{survey_quantile} and
#' \code{survey_median} should always be called from \code{\link{summarise}}.
#'
#' @param x A variable or expression
#' @param na.rm A logical value to indicate whether missing values should be dropped
#' @param quantiles A vector of quantiles to calculate
#' @param vartype Report variability as one or more of: standard error ("se", default),
#'                confidence interval ("ci") (variance and coefficient of variation not
#'                available).
#' @param level A single number indicating the confidence level (only one level allowed)
#' @param q_method See "method" in \code{\link[stats]{approxfun}}
#' @param f See \code{\link[stats]{approxfun}}
#' @param interval_type See \code{\link[survey]{svyquantile}}
#' @param ties See \code{\link[survey]{svyquantile}}
#' @param df A number indicating the degrees of freedom for t-distribution. The
#'           default, Inf uses the normal distribution (matches the survey package).
#'           Also, has no effect for \code{type = "betaWald"}.
#' @param .svy A \code{tbl_svy} object. When called from inside a summarize function
#'   the default automatically sets the survey to the current survey.
#' @param ... Ignored
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(api99 = survey_quantile(api99, c(0.25, 0.5, 0.75)),
#'             api00 = survey_median(api00, vartype = c("ci")))
#'
#' dstrata %>%
#'   group_by(awards) %>%
#'   summarise(api00 = survey_median(api00))
#'
#' @export
survey_quantile <- function(
  x, quantiles, na.rm = FALSE, vartype = c("none", "se", "ci"),
  level = 0.95, q_method = "linear", f = 1,
  interval_type = c("Wald", "score", "betaWald", "probability", "quantile"),
  ties = c("discrete", "rounded"), df = Inf, .svy = current_svy(), ...
) {
  UseMethod("survey_quantile", .svy)
}

#' @export
survey_quantile.tbl_svy <- function(
  x, quantiles, na.rm = FALSE, vartype = c("none", "se", "ci"),
  level = 0.95, q_method = "linear", f = 1,
  interval_type = c("Wald", "score", "betaWald", "probability", "quantile"),
  ties = c("discrete", "rounded"), df = Inf, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "none"
  vartype <- match.arg(vartype, several.ok = TRUE)
  vartype <- setdiff(vartype, "none")
  vartype <- c("coef", vartype)

  if (missing(interval_type) & !inherits(.svy, "svyrep.design")) interval_type <- "Wald"
  if (missing(interval_type) & inherits(.svy, "svyrep.design")) interval_type <- "probability"
  interval_type <- match.arg(interval_type, several.ok = TRUE)
  if (missing(ties)) ties <- "discrete"
  ties <- match.arg(ties, several.ok = TRUE)

  if (length(level) > 1) {
    warning("Only the first confidence level will be used")
    level <- level[1]
  }

  # Because of machine precision issues, 1 - 0.95 != 0.05...
  # Here's a hacky way to force it, though it technically limits
  # us to 7 digits of precision in alpha (seems like enough,
  # we could go higher, but I worry about 32bit vs 64bit systems)
  alpha = round(1 - level, 7)

  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- data.frame(SRVYR_VAR = x)
  } else {
    .svy$variables <- data.frame(SRVYR_VAR = x)
  }

  stat <- survey::svyquantile(~SRVYR_VAR, .svy,
                              quantiles = quantiles, na.rm = na.rm,
                              ci = TRUE, alpha = alpha, method = q_method, f = f,
                              interval.type = interval_type, ties = ties, df = df)

  q_text <- paste0("_q", gsub("\\.", "", formatC(quantiles * 100, width = 2,
                                                 flag = "0")))

  out <- get_var_est(stat, vartype, var_names = q_text, level = level,
                     quantile = TRUE)
  dplyr::bind_cols(out)
}

#' @export
survey_quantile.grouped_svy <- function(
  x, quantiles, na.rm = FALSE, vartype = c("none", "se", "ci"),
  level = 0.95, q_method = "linear", f = 1,
  interval_type = c("Wald", "score", "betaWald", "probability", "quantile"),
  ties = c("discrete", "rounded"), df = Inf, .svy = current_svy(), ...
) {
  if (vartype == "none") {
    vartype <- "se"
    remove_se <- TRUE
  } else {
    vartype <- setdiff(vartype, "none")
    remove_se <- FALSE
  }

  if (missing(interval_type) & !inherits(.svy, "svyrep.design")) interval_type <- "Wald"
  if (missing(interval_type) & inherits(.svy, "svyrep.design")) interval_type <- "probability"
  interval_type <- match.arg(interval_type, several.ok = TRUE)
  if (missing(ties)) ties <- "discrete"
  ties <- match.arg(ties, several.ok = TRUE)

  if (length(level) > 1) {
    warning("Only the first confidence level will be used")
    level <- level[1]
  }

  grp_names <- group_vars(.svy)
  grps <- select(.svy$variables, !!!rlang::syms(grp_names))


  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- data.frame(dplyr::bind_cols(grps, data.frame(SRVYR_VAR = x)))
  } else {
    .svy$variables <- data.frame(dplyr::bind_cols(grps, data.frame(SRVYR_VAR = x)))
  }

  # Because of machine precision issues, 1 - 0.95 != 0.05...
  # Here's a hacky way to force it, though it technically limits
  # us to 7 digits of precision in alpha (seems like enough,
  # we could go higher, but I worry about 32bit vs 64bit systems)
  alpha = round(1 - level, 7)

  stat <- survey::svyby(formula = ~SRVYR_VAR, survey::make.formula(grp_names),
                        .svy, survey::svyquantile,
                        quantiles = quantiles, na.rm = na.rm,
                        ci = TRUE, alpha = alpha, method = q_method,
                        f = f, interval.type = interval_type, ties = ties,
                        df = df, vartype = vartype)

  q_text <- paste0("_q", gsub("\\.", "", formatC(quantiles * 100, width = 2,
                                                 flag = "0")))
  vartype <- c("grps", "coef", vartype)
  vartype[vartype == "ci"] <- "ci-prop"

  out <- get_var_est(stat, vartype, var_names = q_text,
                     grps = grp_names, level = level,
                     quantile = TRUE)

  dplyr::bind_cols(out)
}


#' @export
#' @rdname survey_quantile
survey_median <- function(
  x, na.rm = FALSE, vartype = c("none", "se", "ci"),
  level = 0.95, q_method = "linear", f = 1,
  interval_type = c("Wald", "score", "betaWald", "probability", "quantile"),
  ties = c("discrete", "rounded"), df = Inf, .svy = current_svy(), ...
) {
  if (missing(vartype)) vartype <- "none"
  vartype <- match.arg(vartype, several.ok = TRUE)
  if (missing(interval_type) & !inherits(.svy, "svyrep.design")) interval_type <- "Wald"
  if (missing(interval_type) & inherits(.svy, "svyrep.design")) interval_type <- "probability"
  interval_type <- match.arg(interval_type, several.ok = TRUE)
  if (missing(ties)) ties <- "discrete"
  ties <- match.arg(ties, several.ok = TRUE)

  if (length(level) > 1) {
    warning("Only the first confidence level will be used")
    level <- level[1]
  }

  survey_quantile(
    x, quantiles = 0.5, na.rm = na.rm, vartype = vartype, level = level, q_method = q_method,
    f = f, interval_type = interval_type, ties = ties, df = df, .svy = .svy
  )
}

#' Calculate the an unweighted summary statistic from a survey
#'
#' Calculate unweighted summaries from a survey dataset, just as on
#' a normal data.frame with \code{\link[dplyr]{summarise}}.
#'
#' @param x A variable or expression
#' @param .svy A \code{tbl_svy} object. When called from inside a summarize function
#'   the default automatically sets the survey to the current survey.
#' @param ... Ignored
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(api99_unw = unweighted(mean(api99)),
#'             n = unweighted(n()))
#'
#' dstrata %>%
#'   group_by(stype) %>%
#'   summarise(api_diff_unw = unweighted(mean(api00 - api99)))
#'
#' @export
unweighted <- function(x, .svy = current_svy(), ...) {
  dots <- rlang::enquo(x)

  out <- summarize(.svy[["variables"]], !!!dots)
  names(out)[length(names(out))] <- ""
  out
}


survey_stat_ungrouped <- function(.svy, func, x, na.rm, vartype, level, deff, df) {
  if (class(x) == "factor") {
    stop(paste0("Factor not allowed in survey functions, should ",
                "be used as a grouping variable"))
  }
  if (class(x) == "logical") x <- as.integer(x)

  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- data.frame(SRVYR_VAR = x)
  } else {
  .svy$variables <- data.frame(SRVYR_VAR = x)
  }
  stat <- func(~SRVYR_VAR, .svy, na.rm = na.rm, deff = deff)

  vartype <- c("coef", vartype)
  if (deff) vartype <- c(vartype, "deff")
  out <- get_var_est(stat, vartype, level = level, df = df)

  dplyr::bind_cols(out)
}

survey_stat_grouped <- function(.svy, func, x, na.rm, vartype, level,
                                deff, df, prop_method = NULL) {
  UseMethod("survey_stat_grouped")
}

survey_stat_grouped.default <- function(.svy, func, x, na.rm, vartype, level,
                                        deff, df, prop_method = NULL) {
  grp_names <- group_vars(.svy)
  grps <- select(.svy$variables, !!!rlang::syms(grp_names))
  if (class(x) == "factor") {
    stop(paste0("Factor not allowed in survey functions, should ",
                "be used as a grouping variable"))
  }

  if (class(x) == "logical") x <- as.integer(x)

  vartype <- c("grps", "coef", vartype)
  if (deff) vartype = c(vartype, "deff")

  .svy$variables <- data.frame(dplyr::bind_cols(grps, data.frame(SRVYR_VAR = x)))

  if (is.null(prop_method)) {
    stat <- survey::svyby(~SRVYR_VAR, survey::make.formula(grp_names), .svy,
                          deff = deff, func, na.rm = na.rm)
  } else {
    vartype[vartype == "ci"] <- "ci-prop"
    stat <- survey::svyby(~SRVYR_VAR, survey::make.formula(grp_names),
                          .svy, func, na.rm = na.rm,
                          se = TRUE, vartype = c("se", "ci"),
                          method = prop_method)
  }

  out <- get_var_est(stat, vartype, grps = grp_names,
                     level = level, df = df)
  dplyr::bind_cols(out)
}

survey_stat_grouped.twophase2 <- function(.svy, func, x, na.rm, vartype, level,
                                          deff, df, prop_method = NULL) {
  grps <- survey::make.formula(groups(.svy))

  if (class(x) == "factor") {
    stop(paste0("Factor not allowed in survey functions, should ",
                "be used as a grouping variable"))
  }
  if (class(x) == "logical") x <- as.integer(x)
  # svyby breaks when you feed it raw vector to be measured... Add it to
  # the data.frame with mutate and then pass in the name
  .svy$variables[["___arg"]] <- x

  # Slight hack for twophase -- move the created variables to where survey
  # expects them
  if (inherits(.svy, "twophase2")) {
    .svy$phase1$sample$variables <- .svy$variables
  }
  vartype <- c("grps", "coef", vartype)
  if (deff) vartype = c(vartype, "deff")

  if (is.null(prop_method)) {
    stat <- survey::svyby(~`___arg`, grps, .svy, func, na.rm = na.rm, se = TRUE, deff = deff)
  } else {
    vartype[vartype == "ci"] <- "ci-prop"
    stat <- survey::svyby(~`___arg`, grps, .svy, func, na.rm = na.rm,
                          se = TRUE, vartype = c("ci", "se"),
                          method = prop_method)
  }

  out <- get_var_est(stat, vartype, grps = group_vars(.svy),
                     level = level, df = df)
  dplyr::bind_cols(out)
}

survey_stat_factor <- function(.svy, func, na.rm, vartype, level, deff, df) {
  grps_names <- group_vars(.svy)
  peel_name <- grps_names[length(grps_names)]
  grps_names <- setdiff(grps_names, peel_name)

  if (is.numeric(.svy$variables[[peel_name]])) {
    warning("Coercing ", peel_name, " to character in survey_mean().", call. = FALSE)
    .svy$variables[[peel_name]] <- as.character(.svy$variables[[peel_name]])
  }

  vartype <- c("coef", vartype)
  if (deff) vartype <- c(vartype, "deff")

  if (length(level) > 1) {
    warning("Only the first confidence level will be used")
    level <- level[1]
  }

  if (length(grps_names) > 0) {
    stat <- survey::svyby(survey::make.formula(peel_name),
                          survey::make.formula(grps_names),
                          .svy, func, na.rm = na.rm, se = TRUE, deff = deff)

    var_names <- attr(stat, "svyby")[["variables"]]
    var_names <- unlist(lapply(var_names,
                               function(x) substring(x, nchar(peel_name) + 1)))

    vartype <- c("grps", vartype)

    out <- get_var_est(stat, vartype, var_names = var_names, grps = grps_names,
                       level = level, df = df)
    # out <- dplyr::bind_cols(out)
    names(out) <- vartype
    peel_levels <- levels(.svy[["variables"]][[peel_name]])
    out <- factor_stat_reshape(out, peel_name, var_names, peel_levels)

    out
  } else {
    # Needed because grouped don't usually have "coef"
    vartype <- c("lvls", vartype)
    stat <- func(survey::make.formula(peel_name), .svy, na.rm = na.rm, deff = deff)

    out <- get_var_est(stat, vartype, peel = peel_name,
                       peel_levels = levels(.svy[["variables"]][[peel_name]]),
                       df = df)

    dplyr::bind_cols(out)
  }
}

survey_stat_proportion <- function(.svy, x, na.rm, vartype, level,
                                   prop_method, df) {
  .svy$variables["___arg"] <- x
  stat <- survey::svyciprop(~`___arg`, .svy, na.rm = na.rm, level = level,
                            method = prop_method)

  vartype <- c("coef", vartype)

  out <- get_var_est(stat, vartype, quantile = TRUE, df = df)
  dplyr::bind_cols(out)
}

get_var_est <- function(stat, vartype, var_names = "", grps = "",
                        peel = "", peel_levels = NULL, level = 0.95,
                        quantile = FALSE, df = Inf) {
  out_width <- length(var_names)
  out <- lapply(vartype, function(vvv) {
    if (vvv == "coef") {
      coef <- data.frame(matrix(coef(stat), ncol = out_width))
      names(coef) <- var_names
      coef
    } else if (vvv == "se") {
      se <- survey::SE(stat)
      # Needed for grouped quantile
      if (!inherits(se, "data.frame")) {
        se <- data.frame(matrix(se, ncol = out_width))
      }
      names(se) <- paste0(var_names, "_se")
      se
    } else if (vvv == "ci") {
      if (!quantile) {
        if (length(level)==1) {
          ci <- data.frame(matrix(stats::confint(stat, level = level, df = df),
                                  ncol = 2 * out_width))
          names(ci) <- c(paste0(var_names, "_low"), paste0(var_names, "_upp"))
        } else {
          lci <- lapply(level, function(x) {as.data.frame(stats::confint(stat,level = x, df = df))})
          ci <- dplyr::bind_cols(lci)
          names(ci) <- paste0(var_names,"_", c("low","upp"),rep(level,each=2)*100)
        }
      } else {
        ci <- data.frame(matrix(stats::confint(stat), ncol = 2 * out_width))
        names(ci) <- c(paste0(var_names, "_low"), paste0(var_names, "_upp"))
      }

      ci
    } else if (vvv == "ci-prop") {
      ci <- data.frame(stat[c("ci_l", "ci_u")])
      names(ci) <- c(paste0(var_names, "_low"), paste0(var_names, "_upp"))
      ci
    } else if (vvv == "var") {
      var <- data.frame(matrix(survey::SE(stat) ^ 2, ncol = out_width))
      names(var) <- paste0(var_names, "_var")
      var
    } else if (vvv == "cv") {
      cv <- data.frame((matrix(survey::cv(stat), ncol = out_width)))
      names(cv) <- paste0(var_names, "_cv")
      cv
    } else if (vvv == "deff") {
      deff <- data.frame(matrix(survey::deff(stat), ncol = out_width))
      names(deff) <- paste0(var_names, "_deff")
      deff
    } else if (vvv == "grps") {
      stat[grps]
    } else if (vvv == "lvls") {
      # Only for survey_stat_factor with only one groups
      # Add on level variable -- survey leaves it in an ugly state, with the
      # varname pasted in, so we have to remove it. Also, check if it was
      # originally a character and convert if it was.
      lvls <- data.frame(names(coef(stat)), stringsAsFactors = FALSE)
      lvls[[1]] <- gsub(paste0("^", peel), "", lvls[[1]])
      if (!is.null(peel_levels)) {
        lvls[[1]] <- factor(lvls[[1]], peel_levels)
      }
      names(lvls) <- peel
      lvls
    }
  })
}


factor_stat_reshape <- function(stat, peel, var_names, peel_levels) {
  out <- lapply(seq_along(stat), function(iii) {
    stat_name <- names(stat)[iii]
    stat_df <- stat[[iii]]
    if (stat_name == "grps") {
      stat_df <- dplyr::tbl_df(stat_df)
      stat_df[rep(seq_len(nrow(stat_df)), length(var_names)), ]
    } else if(stat_name == "ci") {
      out <- utils::stack(stat_df)
      out <- data.frame(
        `_low` = out[substr_right(out$ind, 4) == "_low", "values"],
        `_upp` = out[substr_right(out$ind, 4) == "_upp", "values"],
        check.names = FALSE, stringsAsFactors = FALSE
      )
    } else if(stat_name == "coef") {
      out <- utils::stack(stat_df)
      names(out) <- c("", peel)
      out[, c(2, 1)]
    } else {
      out <- utils::stack(stat_df)
      out <- select(out, -.data$ind)
      names(out) <- paste0("_", stat_name)
      out
    }
  })
  out <- dplyr::bind_cols(out)

  # peel's factor was created by stack, but is just alphabetic
  out[[peel]] <- as.character(out[[peel]])
  if (!is.null(peel_levels)) {
    out[[peel]] <- factor(out[[peel]], peel_levels)
  }

  out
}
