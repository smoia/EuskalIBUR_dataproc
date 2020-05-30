library(lme4)

ftypes_list <- c("pre", "echo-2", "optcom", "meica-cons", "meica-orth", "meica-aggr", "all-orth")

# Read data and make model
data <- read.csv('sub_long_table.csv')
model <- lmer(dvars ~ fd * ftype + ((1+fd*ftype)|ses) + ((1+fd*ftype)|sub), data)
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
print("Full model")
print(" ")
print(model)
print(" ")
print(anova_table)
print(" ")
print("------------------")
print(" ")
print(" ")

for(i in 1:n_comb) {
print(combinations[1, i])
print(combinations[2, i])
print(" ")
subset_data <- subset(data, ftype == combinations[1, i] | ftype == combinations[2, i])
model_subset[[i]] <- lmer(dvars ~ fd * ftype + ((1+fd*ftype)|ses) + ((1+fd*ftype)|sub), subset_data)
anova_table_subset[[i]] <- anova(model_subset[[i]])
print(model_subset[[i]])
print(" ")
print(anova_table_subset[[i]])
print("------------------")
print(" ")
print(" ")
}
sink()

saveRDS(combinations, file = "lme_combinations.rds")
saveRDS(model_subset, file = "lme_model_subset.rds")
saveRDS(anova_table_subset, file = "lme_anova_table_subset.rds")
