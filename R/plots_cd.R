.plot_critdiff_1 = function(obj, meas, p.value, minimize, test, baseline, ratio, friedman_global) { # nolint
  cd = obj$.__enclos_env__$private$.crit_differences(meas, minimize, p.value, baseline, test, friedman_global)

  # Plot descriptive lines and learner names
  cd$data$yend = -cd$data$yend
  p = ggplot(cd$data)

  # visible binding hack
  x = NULL

  # Add bar (descriptive)
  p = p + annotate("segment",
                   x = mean(cd$data$mean_rank) - 0.5 * cd$cd,
                   xend = mean(cd$data$mean_rank) + 0.5 * cd$cd,
                   y = 1.5,
                   yend = 1.5,
                   size = 1)

  # Add crit difference test (descriptive)
  p = p + annotate("text",
                   label = paste("Critical Difference =", round(cd$cd, 2), sep = " "),
                   y = 2, x = mean(cd$data$mean_rank))

  # manually build axis
  p = p + geom_segment(aes(x = 0, xend = max(rank) + 1, y = 0, yend = 0)) +
    geom_text(data = data.frame(x = seq.int(0, max(cd$data$rank) + 1)),
              aes(x = x, label = x, y = 0.7)) +
    geom_segment(data = data.frame(x = seq.int(0, max(cd$data$rank) + 1)),
                 aes(x = x, xend = x, y = 0, yend = 0.3))

  # Horizontal descriptive bar
  p = p + geom_segment(aes_string("mean_rank", 0, xend = "mean_rank", yend = "yend"))
  # Vertical descriptive bar
  p = p + geom_segment(aes_string("mean_rank", "yend", xend = "xend", yend = "yend"))
  # Plot Learner name
  p = p + geom_text(aes_string("xend", "yend", label = obj$col_roles$learner_id,
                               hjust = "right"), vjust = -0.5)

  p = p + xlab("Average Rank")
  # Change appearance
  p = p + theme(axis.text = element_blank(),
                axis.ticks = element_blank(),
                axis.title = element_blank(),
                legend.position = "none",
                panel.background = element_blank(),
                panel.border = element_blank(),
                axis.line = element_blank(),
                panel.grid.major = element_blank(),
                plot.background = element_blank())

  # Plot the critical difference bars
  if (cd$test == "bd") {
    cdx = as.numeric(unlist(subset(cd$data, baseline == 1, "mean_rank")))
    # Add horizontal bar around baseline
    p = p + annotate("segment", x = cdx + cd$cd,
                     xend = cdx, y = -1, yend = -1,
                     color = "black", size = 1.3)
    # Add interval limiting bar's
    p = p + annotate("segment", x = cdx + cd$cd, xend = cdx + cd$cd, y = -0.7,
                     yend = -1.3, color = "black", size = 1.3)
  } else {
    nemenyi_data = cd$nemenyi_data # nolint
    if (!(nrow(nemenyi_data) == 0L)) {
      # Add connecting bars
      nemenyi_data$y = -nemenyi_data$y
      p = p + geom_segment(aes_string("xstart", "y", xend = "xend", yend = "y"),
                           data = nemenyi_data, size = 1.3)
    } else {
      message("No connecting bars to plot!")
    }
  }

  p = p + coord_fixed(ratio = ratio, ylim = c(min(cd$data$yend), 2))

  return(p)
}

.plot_critdiff_2 = function(obj, meas, p.value, minimize, test, baseline, friedman_global) { # nolint
  cd = obj$.__enclos_env__$private$.crit_differences(meas, minimize, p.value, baseline, test, friedman_global)

  # Plot descriptive lines and learner names
  p = ggplot(cd$data)
  # Point at mean rank
  p = p + geom_point(aes_string("mean_rank", 0, colour = obj$col_roles$learner_id), size = 3)
  # Horizontal descriptive bar
  p = p + geom_segment(aes_string("mean_rank", 0, xend = "mean_rank", yend = "yend",
                                  color = obj$col_roles$learner_id), size = 1)
  # Vertical descriptive bar
  p = p + geom_segment(aes_string("mean_rank", "yend", xend = "xend",
                                  yend = "yend", color = obj$col_roles$learner_id), size = 1)
  # Plot Learner name
  p = p + geom_text(aes_string("xend", "yend", label = obj$col_roles$learner_id,
                               color = obj$col_roles$learner_id,
                               hjust = "right"), vjust = -1)

  p = p + xlab("Average Rank")
  # Change appearance
  p = p + scale_x_continuous(breaks = c(0:max(cd$data$xend)))
  p = p + theme(axis.text.y = element_blank(),
                axis.ticks.y = element_blank(),
                axis.title.y = element_blank(),
                legend.position = "none",
                panel.background = element_blank(),
                panel.border = element_blank(),
                axis.line = element_line(size = 1),
                axis.line.y = element_blank(),
                panel.grid.major = element_blank(),
                plot.background = element_blank())

  # Add crit difference test (descriptive)
  p = p + annotate("text",
                   label = paste("Critical Difference =", round(cd$cd, 2), sep = " "),
                   y = max(cd$data$yend) + 0.8, x = mean(cd$data$mean_rank))
  # Add bar (descriptive)
  p = p + annotate("segment",
                   x = mean(cd$data$mean_rank) - 0.5 * cd$cd,
                   xend = mean(cd$data$mean_rank) + 0.5 * cd$cd,
                   y = max(cd$data$yend) + 0.7,
                   yend = max(cd$data$yend) + 0.7,
                   size = 1.3, alpha = 0.9)

  # Plot the critical difference bars
  if (test == "bd") {
    cdx = as.numeric(unlist(subset(cd$data, baseline == 1, "mean_rank"))) # nolint
    # Add horizontal bar around baseline
    p = p + annotate("segment", x = cdx + cd$cd,
                     xend = cdx, y = 0.5, yend = 0.5,
                     alpha = 0.9, color = "dimgrey", size = 1.3)
    # Add interval limiting bar's
    p = p + annotate("segment", x = cdx + cd$cd, xend = cdx + cd$cd, y = 0.3,
                     yend = 0.8, color = "dimgrey", size = 1.3, alpha = 0.9)
    # Add point at learner
    p = p + annotate("point", x = cdx, y = 0.5, alpha = 0.6, color = "black")
  } else {
    nemenyi_data = cd$nemenyi_data # nolint
    if (!(nrow(nemenyi_data) == 0L)) {
      # Add connecting bars
      p = p + geom_segment(aes_string("xstart", "y", xend = "xend", yend = "y"),
                           data = nemenyi_data, size = 1.3, color = "dimgrey", alpha = 0.9,
                           )
    } else {
      message("No connecting bars to plot!")
    }
  }

  return(p)
}
