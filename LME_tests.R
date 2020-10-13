library(lmerTest)

ftypes_list <- c("pre", "echo-2", "optcom", "meica-cons", "meica-orth", "meica-aggr")
ftypes_list <- c("pre", "echo-2", "optcom", "meica-cons", "meica-orth", "meica-aggr")

# Read data and make sure all the categorical data is a factor
data <- read.csv('sub_long_table.csv')
data$sub <- as.factor(data$sub)
data$ses <- as.factor(data$ses)
data$ftype <- as.factor(data$ftype)

# Run model
model <- lmer(dvars ~ fd * ftype + ((1+fd)|ses) + ((1+fd)|sub), data)
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
writeLines(model)
writeLines("\n\n")
writeLines("Summary\n")
summary(model)
writeLines("\n\n")
writeLines("ANOVA table\n")
anova_table
writeLines("\n\n")
writeLines("------------------\n\n\n\n")

for(i in 1:n_comb) {
print(combinations[1, i])
print(combinations[2, i])
print("\n")
subset_data <- subset(data, ftype == combinations[1, i] | ftype == combinations[2, i])
model_subset[[i]] <- lmer(dvars ~ fd * ftype + ((1+fd)|ses) + ((1+fd)|sub), subset_data)
anova_table_subset[[i]] <- anova(model_subset[[i]])
model_subset[[i]]
print("\n\n")
print("Summary\n")
summary(model_subset[[i]])
# print("\n\n")
print("ANOVA table\n")
anova_table_subset[[i]]
# writeLines("\n\n")
# writeLines("------------------\n\n\n\n")
}
sink()

saveRDS(combinations, file = "lme_combinations.rds")
saveRDS(model_subset, file = "lme_model_subset.rds")
saveRDS(anova_table_subset, file = "lme_anova_table_subset.rds")
