# Runs a general linear model with logit link on the test dta
library(data.table)
library(lme4)
library(emmeans) # package emmeans needs to be attached for follow-up tests. 
setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # change this to the folder where this script is lying; works only in RStudio

# 0. Prepares data
source("3_predicts_models.R", chdir = TRUE)
source("fig_setup.R")

dt <- dt[block == "test" & stim_type == "new", ]
dt[, time_pressure_cond := factor(time_pressure_cond, levels = c(TRUE, FALSE), labels = c(TRUE, FALSE))]
dt[, subj_id := as.factor(subj_id)]
dt[, stim := factor(stim, labels = c("100", "003", "221", "231", "321", "331"))]
dt[, test_stim_type := ifelse(stim == "100", "100", 
                              ifelse(stim == "003", "003", "221-331"))]
dt[, test_stim_type := factor(test_stim_type, labels = c("100", "003", "221-331"))]

contrasts(dt$test_stim_type) <- "contr.sum"
contrasts(dt$time_pressure_cond) <- "contr.sum"

# 1. Computes generalized linear models
# 1.1. With interaction time_pressure_cond*stim
# full_model <- glm(response ~ time_pressure_cond * stim, data = dt, family = binomial) 
full_model <- glmer(response ~ time_pressure_cond * test_stim_type + (1|subj_id), data = dt, family = binomial) 
summary(full_model)
# TO DO: 1. ||, 2. random intercept (1|subj_id), 3. no random effects; 4. no fixed effects but (0 + stim|subj_id); 5. group stimuli (221, 231, 321, 331 together)

dt[, test_stim_type := relevel(test_stim_type, ref = "003")]
contrasts(dt$test_stim_type) <- "contr.sum"
full_model2 <- glmer(response ~ time_pressure_cond * test_stim_type + (1|subj_id), data = dt, family = binomial) 
summary(full_model2)
# 1.2. Without interaction time_pressure_cond*stim
# restricted_model <- glmer(response ~ time_pressure_cond + stim + (0 + stim|subj_id), data = dt, family = binomial)
restricted_model <- glmer(response ~ time_pressure_cond + test_stim_type + (1|subj_id), data = dt, family = binomial) 
summary(restricted_model)

# 1.3. Tests the necessity of the interaction time_pressure_cond*stim
# 1.3.1. AIC: How much more likely is full_model relative to restricted_model?
aics <- as.data.table(AIC(full_model, restricted_model), keep.rownames = TRUE)
aics[, delta_AIC := AIC - min(AIC)] 
aics[, weights := exp(-0.5*delta_AIC)/sum(exp(-0.5*delta_AIC))]
aics[, weights[1]/weights[2]]

# 1.3.2. ANOVA
anova(restricted_model, full_model)

# 2. Pairwise comparisons
emm1 <- emmeans(full_model, ~ test_stim_type |  time_pressure_cond)
pairs(emm1, adjust = "holm") # all pairwise comparisons 

# 2.1. Contrast coefficients
H1 <- list(H1ac = c(2, rep(-1, 2)), # H1a & H1c
           H1b = c(-1, 2, rep(-1, 1)) # H1b
           ) 
H2 <- list(H2a = c(2, rep(-1, 2))) # H2a

contrast(emm1, list(H1, H2), adjust = "holm", type = "response") # check if holm method is specified globally or separately for both time_pressure_cond

# contrast(emm1[1:6], H2, adjust = "holm")
# contrast(emm1[7:12], H1, adjust = "holm")




# fixed_eff <- fixef(full_model)
# betas <- as.data.table(fixed_eff[grepl("^stim|Intercept", names(fixed_eff))], keep.rownames = TRUE)
# betas[, stim := levels(dt$stim)] # gsub("stim", "", V1)
# betas[, beta := exp(V2)/(1+exp(V2))]
# 
# dt_long <- melt(dt, measure.vars = patterns("pred"), id.vars = c("stim", "subj_id")) # used for plot below
# dt_long <- dt_long[, .(value = unique(value)), by = list(stim, variable, subj_id)]
# dt_long[, variable := toupper(gsub("pred_", "", variable))]
# 
# # learn_stim <- apply(expand.grid(0:1, 0:1, 1:2), 1, paste, collapse = "")
# # dt_long[, stim_type := factor(!stim %in% learn_stim, labels = c("old", "new"))]
# # betas[, stim_type := factor(!stim %in% learn_stim, labels = c("old", "new"))]
# 
# dt_long[, stim := factor(stim, levels = stim_order)]
# betas[, stim := factor(stim, levels = stim_order)]
# 
# j <- position_dodge(0.6)
# ggplot(data = betas, aes(x = stim, y = beta)) +
#   geom_bar(fill = "lightgrey", color = "lightgrey", stat = "identity", size = 1) +
#   geom_point(data = dt_long, aes(y = value, color = variable), position = j) +
#   geom_line(data = dt_long, aes(y = value, color = variable, group = variable), position = j) +
#   ylim(0, 1) +
#   # facet_grid(subj_id~stim_type, scales = "free_x", space = "free") +
#   guides(fill = "none") +
#   scale_color_manual(values = cols) +
#   theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)) +
#   theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
#   xl + yl
# 
# ggsave("../../output/images/glm_testphase.jpg")
