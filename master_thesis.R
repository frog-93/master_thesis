library(tidyverse)
library(rstatix)
library(car)
library(readxl)
library(emmeans)

data <- read_excel("data.xlsx")
data <- data %>%
  mutate(
    sdr = as.numeric(sdr),
    sir = as.numeric(sir),
    sar = as.numeric(sar),
    model = factor(model, levels = c("LSTM", "BiLSTM")),
    condition = factor(condition, levels = c("baker", "book", "hospital", "room", "valid"))
  )

# Visualize data
  descriptive_stats <- data %>%
    group_by(model, condition) %>%
    get_summary_stats(sdr, sir, sar, type = "mean_sd")
  descriptive_stats

  # Graphs
  df_long <- data %>%
    pivot_longer(cols = c(sdr, sir, sar), 
                 names_to = "variable", 
                 values_to = "valeur")
  ggplot(df_long, aes(x = model, y = valeur, fill = condition)) +
    geom_boxplot(position = position_dodge(width = 0.8)) +
    facet_wrap(~ variable, nrow = 1) +  
    theme_minimal() +
    labs(title = "Comparaison des performances des deux modèles dans les différentes conditions d'évaluation",
         y = "dB",
         x = "Modèle")

# Check MANOVA assumptions
  # Multivariate normality+ QQ-plot
  vars <- data[, c("sdr", "sir", "sar")]
  mardia_result <- psych::mardia(vars)
  print(mardia_result)

  # Homogeneity of variances : univariate
  leveneTest(sdr ~ interaction(model, condition), data = data)
  leveneTest(sir ~ interaction(model, condition), data = data)
  leveneTest(sar ~ interaction(model, condition), data = data)

  # Homogeneity of covariance matrices (Box's M Test)
  box_m_results <- box_m(data[, c("sdr", "sar", "sir")], data$condition)
  print(box_m_results)
  
# MANOVA
  dependent_vars <- cbind(data$sdr, data$sir, data$sar)
  manova_model <- manova(dependent_vars ~ model * condition, data = data)
  summary(manova_model, test = "Pillai")
  
# Post-hoc 
  # ANOVA on SDR
  anova_model <- aov(sdr ~ model * condition, data=data)
  summary(anova_model)
  # Comparison of models
  emmeans_obj <- emmeans(manova_model, ~ model)
  pairs(emmeans_obj)
  # Planned contrast
  contrast_weights <- list(
    valid_vs_rest = c(-0.25, -0.25, -0.25, -0.25, 1)
  )
  emmeans_obj_condition <- emmeans(manova_model, ~ condition)
  planned_contrast <- contrast(emmeans_obj_condition, method = contrast_weights)
  summary(planned_contrast)  
  # Exploratory analysis on conditions
  pairwise_condition <- pairs(emmeans_obj_condition, adjust = "tukey")
  summary(pairwise_condition)