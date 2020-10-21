library(lmerTest)

ftypes_list <- c("pre", "echo-2", "optcom", "meica-cons", "meica-orth", "meica-aggr")
ftypes_list <- c("pre", "echo-2", "optcom", "meica-cons", "meica-orth", "meica-aggr")

# Read data and make sure all the categorical data is a factor
# Also check that FD and DVARS are centered
data <- read.csv('sub_long_table.csv', header=T)
data$sub <- as.factor(data$sub)
data$ses <- as.factor(data$ses)
data$ftype <- as.factor(data$ftype)
data$fd <- scale(data$fd, scale=FALSE) # Centering
data$dvars <- scale(data$dvars, scale=FALSE) # Centering

# Run model
model <- lmer(dvars ~ fd * ftype + (1|ses) + (1|sub), data)
summary(model)
anova_table <- anova(model)

# Save model
saveRDS(model, file = "lme_model.rds")
saveRDS(anova_table, file = "lme_anova_table.rds")

# Prepare computations for post-hoc comparisons
combinations <- combn(ftypes_list, 2)
n_comb <- ncol(combinations)

model_subset <- vector("list", length = n_comb)
anova_table_subset <- vector("list", length = n_comb)

# Compute and output to file
sink(file = "LME_models.txt", append = TRUE, type = c("output", "message"),
     split = FALSE)
writeLines("Full model\n")
writeLines("Summary\n")
summary(model)
writeLines("\nANOVA table\n")
anova_table
writeLines("\n------------------\n\n\n\n")

for(i in 1:n_comb) {
writeLines(sprintf("Pairwise comparison: %s vs %s\n", combinations[1, i], combinations[2, i]))
subset_data <- subset(data, ftype == combinations[1, i] | ftype == combinations[2, i])
model_subset[[i]] <- lmer(dvars ~ fd * ftype + (1|ses) + (1|sub), subset_data)
anova_table_subset[[i]] <- anova(model_subset[[i]])
writeLines("Summary\n")
print(model_subset[[i]])
writeLines("\nANOVA table\n")
print(anova_table_subset[[i]])
writeLines("\n------------------\n\n\n\n")
}
sink()

saveRDS(combinations, file = "lme_combinations.rds")
saveRDS(model_subset, file = "lme_model_subset.rds")
saveRDS(anova_table_subset, file = "lme_anova_table_subset.rds")
