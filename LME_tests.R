library(lme4)

ftypes_list <- c("pre", "echo-2", "optcom", "meica-mvar", "meica-cons", "meica-orth", "meica-aggr")

data <- read.csv('sub_long_table.csv')
model <- lmer(dvars ~ fd + ftype + ((1+fd+ftype)|ses) + ((1+fd+ftype)|sub), data)
anova_table <- anova(model)

saveRDS(model, file = "lme_model.rds")
saveRDS(anova_table, file = "lme_anova_table.rds")

combinations <- combn(ftypes_list, 2)
n_comb <- ncol(combinations)

model_subset <- vector("list", length = n_comb)
anova_table_subset <- vector("list", length = n_comb)

for(i in 1:n_comb) {
print(combinations[1, i])
print(combinations[2, i])
subset_data <- subset(data, ftype == combinations[1, i] | ftype == combinations[2, i])
model_subset[[i]] <- lmer(dvars ~ fd + ftype + ((1+fd+ftype)|ses) + ((1+fd+ftype)|sub), subset_data)
anova_table_subset[[i]] <- anova(model_subset[[i]])
print("------------------")
}

saveRDS(combinations, file = "lme_combinations.rds")
saveRDS(model_subset, file = "lme_model_subset.rds")
saveRDS(anova_table_subset, file = "lme_anova_table_subset.rds")


for(i in 1:n_comb) {
print(combinations[1, i])
print(combinations[2, i])
anova_table_subset[[i]] <- anova(model_subset[[i]])
print(model_subset[[i]])
print(anova_table_subset[[i]])
print("------------------")
}
