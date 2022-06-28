use ourproject; 	#data schema name
# 1. Overview of all greenhouse gases per year 
use ourproject;
SELECT year_emission, category, round(sum(emission),2) AS Total_emission
FROM v1_emissions
GROUP BY year_emission, category
ORDER BY year_emission DESC
;

# 2. Emission per cap of each chemical worlwide
use ourproject;
WITH emi_pop AS(
SELECT 
v1_emissions.country_code, 
year_emission, 
emission, 
category,
    v1_population.population
FROM v1_emissions
LEFT JOIN  v1_population ON  v1_population.country_code = v1_emissions.country_code 
AND  v1_population.year_population = v1_emissions.year_emission)
SELECT year, category, round(avg(emission_per_cap),2) AS Avg_emission_per_cap
FROM (
SELECT *, year_emission AS year,
        round(emission/population*1000,2) as emission_per_cap
FROM emi_pop
ORDER BY year DESC, emission DESC) AS subquery
GROUP BY category, year 
;



# 3. Ranking of countries have the highest greenhouse gases emission (CO2, CH4) in the world in 2018
# 3a: CO2 ranking
WITH emi_cou AS(
SELECT 
	v1_emissions.country_code, 
	year_emission AS year, 
	emission, 
	category,
	v1_countries.country_name
FROM v1_emissions
LEFT JOIN v1_countries ON v1_countries.country_code = v1_emissions.country_code)
SELECT *,
	   RANK() OVER(ORDER BY emission DESC) AS CO2_rank
FROM emi_cou
WHERE category = 'co2'  AND emission > 0 AND year = 2018
ORDER BY year DESC, emission DESC
LIMIT 10
;

# 3b: CH4 ranking
WITH emi_cou AS(
SELECT 
	v1_emissions.country_code, 
	year_emission AS year, 
	emission, 
	category,
	v1_countries.country_name
FROM v1_emissions
LEFT JOIN v1_countries ON v1_countries.country_code = v1_emissions.country_code)
SELECT *,
	   RANK() OVER(ORDER BY emission DESC) AS CH4_rank
FROM emi_cou
WHERE category = 'ch4'  AND emission > 0 AND year = 2018
ORDER BY year DESC, emission DESC
LIMIT 10
;

################ optimized version #################

with ranking as(
select *, rank() OVER(ORDER BY emission DESC) as co2_order
from v1_emissions
where category = 'co2' and year_emission = 2018
order by emission desc
limit 10)
Select 	ranking.country_code, 
	ranking.year_emission, 
	ranking.emission, 
	ranking.category, 
	v1_countries.country_name, 
	ranking.co2_order
from ranking
left join v1_countries on v1_countries.country_code = ranking.country_code
;



# 4. Countries have more CO2 emission than yearly average
use ourproject;
SELECT year_emission, 
	   COUNT(CASE WHEN emission > year_avg_world THEN country_code END) AS number_of_high_CO2_countries
FROM ( 
SELECT *,
		AVG(emission) OVER(PARTITION BY year_emission) AS year_avg_world
FROM v1_emissions 
WHERE category = 'co2'
) AS subquery
GROUP BY year_emission
;


# 5. Total GDP and CO2 emissions yearly worldwide
use ourproject;
WITH emi_gdp AS(
SELECT 
v1_emissions.country_code, 
year_emission, 
emission, 
category,
    	v1_gdp.gdp
FROM v1_emissions
LEFT JOIN v1_gdp ON v1_gdp.country_code = v1_emissions.country_code 
AND v1_gdp.year_gdp = v1_emissions.year_emission)
SELECT year_emission AS year,
       round(sum(gdp/1000000000),2) AS Total_GDP_bn,
   round(sum(emission),2) AS Total_CO2_emisison
FROM emi_gdp
WHERE category ='co2'
GROUP BY year
ORDER BY year DESC
;

################ optimized version #################

select year_emission, sum(emission) as emission_total, sum(gdp_bn) as gdp_total
from v1_emissions
left join v1_gdp on v1_gdp.country_code = v1_emissions.country_code and v1_gdp.year_gdp = v1_emissions.year_emission
where category = 'co2'
group by year_emission;

# 6. Devide countries into 2 groups and observe the relation between GDP per cap vs CO2 per cap by year
WITH emi_cou AS(
SELECT 
	v1_emissions.country_code, 
	year_emission AS year, 
	emission, 
	category,
	v1_countries.country_name
FROM v1_emissions
LEFT JOIN v1_countries ON v1_emissions.country_code = v1_countries.country_code
),
	emi_gdp AS(
SELECT 
	emi_cou.country_code, 
	emi_cou.country_name,
    emi_cou.year,
    emi_cou.category,
    emi_cou.emission,
    v1_gdp.gdp
FROM emi_cou
LEFT JOIN v1_gdp ON v1_gdp.country_code = emi_cou.country_code 
AND v1_gdp.year_gdp = emi_cou.year),
	emi_gdp_pop AS(
SELECT 
	emi_gdp.country_code, 
	emi_gdp.country_name,
    emi_gdp.year,
    emi_gdp.category,
    emi_gdp.emission,
    emi_gdp.gdp,
    v1_population.population
FROM emi_gdp
LEFT JOIN v1_population ON v1_population.country_code = emi_gdp.country_code 
AND v1_population.year_population = emi_gdp.year)
SELECT *,
       CASE WHEN GDP_per_cap > 24500 THEN 'Developed'
             WHEN GDP_per_cap < 24500 THEN 'Emerging'
             END AS country_group
FROM (
SELECT year,
	   country_code,
	   country_name,
       population,
       gdp,
       round(emission,2) AS CO2_emission,
       round(gdp/population,2) AS GDP_per_cap, 
	   round(emission/population*1000,2) AS CO2_per_cap
FROM emi_gdp_pop
WHERE category ='co2' AND emission > 0 AND year = 2018
ORDER BY year DESC
) AS subquery
;

################ optimized version #################

use ourproject; 
select  year_emission, emission_per_capita,gdp_per_capita,
       CASE WHEN gdp_per_capita > 24500 THEN 'Developed'
             WHEN gdp_per_capita < 24500 THEN 'Emerging'
             END AS country_group
from ( 
select v1_emissions.country_code, year_emission , emission / population as emission_per_capita, gdp / population as gdp_per_capita
from v1_emissions
left join v1_gdp on v1_emissions.country_code = v1_gdp.country_code and v1_emissions.year_emission = v1_gdp.year_gdp
left join v1_population on v1_emissions.country_code = v1_population.country_code and v1_emissions.year_emission = v1_population.year_population
where category = 'co2' and emission > 0) sub
where emission_per_capita is not null
group by country_group, year_emission
order by country_group, year_emission;


# 7. The relation between Population and CO2 emission
WITH emi_cou AS(
SELECT 
	v1_emissions.country_code, 
	year_emission AS year, 
	emission, 
	category,
	v1_countries.country_name
FROM v1_emissions
LEFT JOIN v1_countries ON v1_emissions.country_code = v1_countries.country_code
),
	emi_pop AS(
SELECT 
	emi_cou.country_code, 
	emi_cou.country_name,
    	emi_cou.category,
    	emi_cou.year,
   	emi_cou.emission,
    	v1_population.population
FROM emi_cou
LEFT JOIN  v1_population ON  v1_population.country_code = emi_cou.country_code 
AND  v1_population.year_population = emi_cou.year)
SELECT *
FROM emi_pop
WHERE emission > 0 AND category = 'co2' AND year = 2018
;

################ optimized version #################

use ourproject;
select country_name, emission, population
from(
select v1_emissions.country_code, emission, population
From v1_emissions
left join v1_population on (v1_emissions.country_code = v1_population.country_code) and (v1_emissions.year_emission = v1_population.year_population)
where category='co2' and year_emission=2018 and emission > 0) sub
left join v1_countries on sub.country_code=v1_countries.country_code;


# 8. The relation between CO2 and LE in 2018
WITH emi_cou AS(
SELECT 
	v1_emissions.country_code, 
	year_emission AS year, 
	emission, 
	category,
	v1_countries.country_name
FROM v1_emissions
LEFT JOIN v1_countries ON v1_emissions.country_code = v1_countries.country_code
),
	emi_pop AS(
SELECT 
	emi_cou.country_code, 
	emi_cou.country_name,
    emi_cou.year,
    emi_cou.category,
    emi_cou.emission,
    v1_population.population
FROM emi_cou
LEFT JOIN  v1_population ON  v1_population.country_code = emi_cou.country_code 
AND  v1_population.year_population = emi_cou.year),
	emi_pop_le AS(
SELECT 
	emi_pop.country_code, 
	emi_pop.country_name,
    emi_pop.year,
    emi_pop.category,
    emi_pop.emission,
    emi_pop.population,
    v1_lifeexpectancy.lifeexpectancy
FROM emi_pop
LEFT JOIN v1_lifeexpectancy ON v1_lifeexpectancy.country_code = emi_pop.country_code 
AND v1_lifeexpectancy.year_lifeexpectancy = emi_pop.year)
SELECT *, round(emission/population*1000,4) AS CO2_per_cap, 
          round(lifeexpectancy) AS Age
FROM emi_pop_le
WHERE category = 'co2' AND emission > 0 AND year = 2018
ORDER BY year DESC
;

################ optimized version #################

use ourproject; 
select country_name, round(lifeexpectancy) as LE, round(emission/population*1000,2) as emission_per_capita
from v1_emissions
left join v1_population on (v1_emissions.year_emission=v1_population.year_population) and (v1_emissions.country_code= v1_population.country_code)
left join v1_lifeexpectancy on (v1_emissions.year_emission=v1_lifeexpectancy.year_lifeexpectancy) and (v1_emissions.country_code= v1_lifeexpectancy.country_code)
left join v1_countries on v1_emissions.country_code= v1_countries.country_code
where year_emission=2018 and category='co2' and emission > 0
# order by emission_per_capita DESC;
