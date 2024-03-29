#' @title Plots for BenchmarkAggr
#'
#' @description
#' Generates plots for [BenchmarkAggr], all assume that there are multiple, independent, tasks.
#' Choices depending on the argument `type`:
#'
#' * `"mean"` (default): Assumes there are at least two independent tasks. Plots the sample mean
#' of the measure for all learners with error bars computed with the standard error of the mean.
#' * `"box"`: Boxplots for each learner calculated over all tasks for a given measure.
#' * `"fn"`: Plots post-hoc Friedman-Nemenyi by first calling [BenchmarkAggr]`$friedman_posthoc`
#' and plotting significant pairs in coloured squares and leaving non-significant pairs blank,
#' useful for simply visualising pair-wise comparisons.
#' * `"cd"`: Critical difference plots (Demsar, 2006). Learners are drawn on the x-axis according
#' to their average rank with the best performing on the left and decreasing performance going
#' right. Any learners not connected by a horizontal bar are significantly different in performance.
#' Critical differences are calculated as:
#' \deqn{CD = q_{\alpha} \sqrt{\left(\frac{k(k+1)}{6N}\right)}}{CD = q_alpha sqrt(k(k+1)/(6N))}
#' Where \eqn{q_\alpha} is based on the studentized range statistic.
#' See references for further details.
#' It's recommended to crop white space using external tools, or function `image_trim()` from package \CRANpkg{magick}.
#'
#' @param object ([BenchmarkAggr])\cr
#'   The benchmark aggregation object.
#' @param type `(character(1))` \cr Type of plot, see description.
#' @param meas `(character(1))` \cr Measure to plot, should be in `obj$measures`, can be `NULL` if
#' only one measure is in `obj`.
#' @param level `(numeric(1))` \cr Confidence level for error bars for `type = "mean"`
#' @param p.value `(numeric(1))` \cr What value should be considered significant for
#' `type = "cd"` and `type = "fn"`.
#' @param minimize `(logical(1))` \cr
#' For `type = "cd"`, indicates if the measure is optimally minimized. Default is `TRUE`.
#' @param test (`character(1))`) \cr
#' For `type = "cd"`, critical differences are either computed between all learners
#' (`test = "nemenyi"`), or to a baseline (`test = "bd"`). Bonferroni-Dunn usually yields higher
#' power than Nemenyi as it only compares algorithms to one baseline. Default is `"nemenyi"`.
#' @param baseline `(character(1))` \cr
#' For `type = "cd"` and `test = "bd"` a baseline learner to compare the other learners to,
#' should be in `$learners`, if `NULL` then differences are compared to the best performing
#' learner.
#' @param style `(integer(1))` \cr
#' For `type = "cd"` two ggplot styles are shipped with the package (`style = 1` or `style = 2`),
#' otherwise the data can be accessed via the returned ggplot.
#' @param ratio (`numeric(1)`) \cr
#' For `type = "cd"` and `style = 1`, passed to [ggplot2::coord_fixed()], useful for quickly
#' specifying the aspect ratio of the plot, best used with [ggsave()].
#' @param col (`character(1)`)\cr
#' For `type = "fn"`, specifies color to fill significant tiles, default is `"red"`.
#' @param friedman_global (`logical(1)`)\cr
#' Should a friedman global test be performed for`type = "cd"` and `type = "fn"`?
#' If `FALSE`, a warning is issued in case the corresponding friedman posthoc test fails instead of an error.
#' Default is `TRUE` (raises an error if global test fails).
#' @param ... `ANY` \cr Additional arguments, currently unused.
#'
#' @references
#' `r format_bib("demsar_2006")`
#'
#' @return
#' The generated plot.
#'
#' @examples
#' if (requireNamespaces(c("mlr3learners", "mlr3", "rpart", "xgboost"))) {
#' library(mlr3)
#' library(mlr3learners)
#' library(ggplot2)
#'
#' set.seed(1)
#' task = tsks(c("iris", "sonar", "wine", "zoo"))
#' learns = lrns(c("classif.featureless", "classif.rpart", "classif.xgboost"))
#' bm = benchmark(benchmark_grid(task, learns, rsmp("cv", folds = 3)))
#' obj = as_benchmark_aggr(bm)
#'
#' # mean and error bars
#' autoplot(obj, type = "mean", level = 0.95)
#'
#' if (requireNamespace("PMCMRplus", quietly = TRUE)) {
#'   # critical differences
#'   autoplot(obj, type = "cd",style = 1)
#'   autoplot(obj, type = "cd",style = 2)
#'
#'   # post-hoc friedman-nemenyi
#'   autoplot(obj, type = "fn")
#' }
#'
#' }
#'
#' @export
autoplot.BenchmarkAggr = function(object, type = c("mean", "box", "fn", "cd"), meas = NULL, # nolint
                                  level = 0.95, p.value = 0.05, minimize = TRUE, # nolint
                                  test = "nem", baseline = NULL, style = 1L,
                                  ratio = 1/7, col = "red", friedman_global = TRUE, ...) { # nolint

  # fix no visible binding
  lower = upper = Var1 = Var2 = value = NULL

  type = match.arg(type)

  meas = .check_meas(object, meas)

  if (type == "cd") {
    if (style == 1L) .plot_critdiff_1(object, meas, p.value, minimize, test, baseline, ratio, friedman_global)
    else .plot_critdiff_2(object, meas, p.value, minimize, test, baseline, friedman_global)
  } else if (type == "mean") {
    if (object$ntasks < 2) {
      stop("At least two tasks required.")
    }
    loss = stats::aggregate(as.formula(paste0(meas, " ~ ", object$col_roles$learner_id)),
                            object$data, mean)
    se = stats::aggregate(as.formula(paste0(meas, " ~ ", object$col_roles$learner_id)), object$data,
                          stats::sd)[, 2] / sqrt(object$ntasks)
    loss$lower = loss[, meas] - se * stats::qnorm(1 - (1 - level) / 2)
    loss$upper = loss[, meas] + se * stats::qnorm(1 - (1 - level) / 2)
    ggplot(data = loss, aes_string(x = object$col_roles$learner_id, y = meas)) +
      geom_errorbar(aes(ymin = lower, ymax = upper),
                    width = .5) +
      geom_point()
  } else if (type == "fn") {

    p = tryCatch(object$friedman_posthoc(meas, p.value, FALSE)$p.value,
      warning = function(w) {
        if (friedman_global) {
          stopf("Global Friedman test non-significant (p > %s), try type = 'mean' instead.", p.value)
        } # nolint
        else {
          warning(sprintf("Global Friedman test non-significant (p > %s), try type = 'mean' instead.", p.value))
          suppressWarnings(object$friedman_posthoc(meas, p.value, FALSE)$p.value)
        } # nolint))
      }
    )

    p = p[rev(seq_len(nrow(p))), ]
    p = t(p)
    p = cbind(expand.grid(rownames(p), colnames(p)), value = as.numeric(p))
    p$value = factor(ifelse(p$value < p.value, "0", "1"))

    ggplot(data = p, aes(x = Var1, y = Var2, fill = value)) +
      geom_tile(size = 0.5, color = !is.na(p$value)) +
      scale_fill_manual(name = "p-value",
                        values = c("0" = col, "1" = "white"),
                        breaks = c("0", "1"),
                        labels = c(paste0("<= ", p.value), paste0("> ", p.value))) +
      theme(axis.title = element_blank(),
            axis.text.y = element_text(angle = 45),
            axis.text.x = element_text(angle = 45, vjust = 0.8, hjust = 0.7),
            panel.grid = element_blank(),
            panel.background = element_rect(fill = "white"),
            legend.background = element_rect(color = "black"),
            legend.key = element_rect(color = "black"),
            legend.position = c(1, 0.9),
            legend.justification = "right")

  } else if (type == "box") {
    ggplot(data = object$data,
           aes_string(x = object$col_roles$learner_id, y = meas)) +
      geom_boxplot()
  }
}
