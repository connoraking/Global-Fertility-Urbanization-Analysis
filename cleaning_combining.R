library(tidyverse)

fertility_data <- read.csv("fertility data.csv")
urban_data <- read.csv("urban data.csv")

urban_pop <- urban_data[-(1:291), ]

#pivoting while preventing creating multiple rows for the same year
urban_pop <- urban_pop %>%
  pivot_wider(id_cols = colnames(urban_pop)[2:3], names_from = X.1, values_from = X.4)


#renaming the columns 
urban_df <- urban_pop %>%
  rename(country = Population.and.rates.of.growth.in.urban.areas.and.capital.cities,
         year = X,
         urban_pop_percent = `Urban population (percent)`,
         urban_growth = `Urban population (percent growth rate per annum)`,
         rural_growth = `Rural population (percent growth rate per annum)`,
         cap_city_pop = `Capital city population (thousands)`,
         cap_percent_pop = `Capital city population (as a percentage of total population)`,
         cap_percent_urban = `Capital city population (as a percentage of total urban population)`)

### Fertility Data Cleaning

# Selecting the desired fertility stats:
fert1 <- fertility_data %>%
  filter(X.1 != "Population annual rate of increase (percent)", 
         X.1 != "Series", 
         X.1 != "Maternal mortality ratio (deaths per 100,000 population)")

#dropping the irrelevant columns
fert1 <- fert1[ , -1]
fert2 <- subset(fert1, select = -c(`X.3`, `X.4`))

#creating separate columns for the desired statistics 
fert3 <- fert2 %>%
  pivot_wider(names_from = X.1, values_from = X.2)

#renaming the columns 
fert4 <- fert3 %>%
  rename(country = Population.growth.and.indicators.of.fertility.and.mortality,
         year = X,
         fertility_rate = `Total fertility rate (children per women)`,
         infant_morality_per_thousand = `Infant mortality for both sexes (per 1,000 live births)`,
         life_exp = `Life expectancy at birth for both sexes (years)`)

# Creating the gender ratio stat and then removing life exp of males and females:
fert5 <- fert4 %>%
  mutate(
    male = as.numeric(`Life expectancy at birth for males (years)`),
    female = as.numeric(`Life expectancy at birth for females (years)`),
    
    gender_ratio_lifeexp = male / female)

fert6 <- fert5 %>%
  subset(select = -c(male,female, `Life expectancy at birth for males (years)`, `Life expectancy at birth for females (years)`))


# Removing the regions and subregions and only including countries. This will be easier as we can use ``countrycode`` on the final data set to analyze continents and subregions.

fert7 <- fert6[-(1:118), ]

#fixing some values
fert7$country[fert7$country == 'Türkiye'] <- 'Turkey'

# Changing the 2017 reference year to 2018:
fert_df <- fert7 %>%
  mutate(year = ifelse(year == 2017, 2018, year))

head(fert_df)

### Combining the data sets

df <- left_join(urban_df, fert_df, by = c("country", "year"))

# Implementing ``countrycode`` so we can consider continents and subregions into analysis:
library(countrycode)

df$continent <- countrycode(df$country, origin = "country.name", destination = "un.region.name")
df$region <- countrycode(df$country, origin = "country.name", destination = "un.regionsub.name")


df$capital_pop = as.numeric(df$cap_city_pop)
df$urban_pop_percent = as.numeric(df$urban_pop_percent)
df$urban_growth = as.numeric(df$urban_growth)
df$rural_growth = as.numeric(df$rural_growth)
df$cap_percent_pop = as.numeric(df$cap_percent_pop)
df$fertility_rate = as.numeric(df$fertility_rate)

# if capital_pop is NA, label as 0; else 1
df$capital_pop_sign = ifelse(is.na(df$capital_pop), "0", "1")

# if capital_pop is NA, give the value of 1
df$capital_pop1 = ifelse(is.na(df$capital_pop), 1, df$capital_pop)

# if rural_growth<0, label as 0; else 1
df$sign = ifelse(df$rural_growth < 0, "0", "1")

# mark the missing value of rural_growth as missing
df$sign = ifelse(is.na(df$sign), "missing", df$sign)

df$capital_pop = as.numeric(df$cap_city_pop)
df$urban_pop_percent = as.numeric(df$urban_pop_percent)
df$urban_growth = as.numeric(df$urban_growth)
df$rural_growth = as.numeric(df$rural_growth)
df$cap_percent_pop = as.numeric(df$cap_percent_pop)
df$fertility_rate = as.numeric(df$fertility_rate)

write.csv(df, "combined_data.csv")
