SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
-- SET CLIENT SIDE BY GOING TO HOME, RIGHT CLICK CONNECTION, EDIT CONNECTION, ADVANCED, OTHERS:
-- KEY IN: OPT_LOCAL_INFILE=1

DROP DATABASE covid;
CREATE DATABASE covid;
USE covid;

CREATE TABLE covid_vaccinations (
    iso_code VARCHAR(255),
    continent VARCHAR(255),
    location VARCHAR(255),
    date DATE,
    total_tests INT,
    new_tests INT,
    total_tests_per_thousand DOUBLE,
    new_tests_per_thousand DOUBLE,
    new_tests_smoothed INT,
    new_tests_smoothed_per_thousand DOUBLE,
    positive_rate DOUBLE,
    tests_per_case DOUBLE,
    tests_units VARCHAR(255),
    total_vaccinations INT,
    people_vaccinated INT,
    people_fully_vaccinated INT,
    total_boosters INT,
    new_vaccinations INT,
    new_vaccinations_smoothed INT,
    total_vaccinations_per_hundred DOUBLE,
    people_vaccinated_per_hundred DOUBLE,
    people_fully_vaccinated_per_hundred DOUBLE,
    total_boosters_per_hundred DOUBLE,
    new_vaccinations_smoothed_per_million INT,
    new_people_vaccinated_smoothed INT,
    new_people_vaccinated_smoothed_per_hundred DOUBLE,
    stringency_index DOUBLE,
    population_density DOUBLE,
    median_age DOUBLE,
    aged_65_older DOUBLE,
    aged_70_older DOUBLE,
    gdp_per_capita DOUBLE,
    extreme_poverty DOUBLE,
    cardiovasc_death_rate DOUBLE,
    diabetes_prevalence DOUBLE,
    female_smokers DOUBLE,
    male_smokers DOUBLE,
    handwashing_facilities DOUBLE,
    hospital_beds_per_thousand DOUBLE,
    life_expectancy DOUBLE,
    human_development_index DOUBLE,
    excess_mortality_cumulative_absolute DOUBLE,
    excess_mortality_cumulative DOUBLE,
    excess_mortality DOUBLE,
    excess_mortality_cumulative_per_million DOUBLE
);

LOAD DATA LOCAL INFILE '/Users/enoch/Portfolio/SQL Projects/covid_19/datasets/covidvac.csv'
INTO TABLE covid_vaccinations
FIELDS TERMINATED BY ','
ENCLOSED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

CREATE TABLE covid_deaths (
    iso_code VARCHAR(255),
    continent VARCHAR(255),
    location VARCHAR(255),
    date DATE,
    population INT,
    total_cases INT,
    new_cases INT,
    new_cases_smoothed INT,
    total_deaths INT,
    new_deaths INT,
    new_deaths_smoothed DOUBLE,
    total_cases_per_million DOUBLE,
    new_cases_per_million DOUBLE,
    new_cases_smoothed_per_million DOUBLE,
    total_deaths_per_million DOUBLE,
    new_deaths_per_million DOUBLE,
    new_deaths_smoothed_per_million DOUBLE,
    reproduction_rate DOUBLE,
    icu_patients INT,
    icu_patients_per_million DOUBLE,
    hosp_patients INT,
    hosp_patients_per_million DOUBLE,
    weekly_icu_admissions INT,
    weekly_icu_admissions_per_million DOUBLE,
    weekly_hosp_admissions INT,
    weekly_hosp_admissions_per_million DOUBLE
);
    
LOAD DATA LOCAL INFILE '/Users/enoch/Portfolio/SQL Projects/covid_19/datasets/coviddeaths.csv'
INTO TABLE covid_deaths
FIELDS TERMINATED BY ','
ENCLOSED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Checking the tables
SELECT * FROM covid_deaths LIMIT 10;
SELECT * FROM covid_vaccinations LIMIT 10;

-- Exploratory Data Analysis --
-- Checking number of rows (336043)
SELECT COUNT(*) as rows_num FROM covid_deaths;
SELECT COUNT(*) as rows_num FROM covid_vaccinations;

-- Checking number of columns for covid_deaths (26) and covid_vaccinations (45)
SELECT COUNT(*) AS cols_num
FROM information_schema.columns
WHERE table_name = 'covid_deaths' AND table_schema = 'covid2';

SELECT COUNT(*) AS cols_num
FROM information_schema.columns
WHERE table_name = 'covid_vaccinations' AND table_schema = 'covid2';

-- Checking distinct value of some columns
SELECT DISTINCT continent FROM covid_deaths; -- We have 6 continents but a blank column (''). We need to find out more
SELECT DISTINCT location FROM covid_deaths WHERE continent = ''; -- Continents are left blank when location is a continent/World/European Union or income category (High income, Upper middle income, Lower middle income, Low income)
SELECT DISTINCT location FROM covid_deaths WHERE continent != '';
SELECT COUNT(DISTINCT location) FROM covid_deaths WHERE continent != ''; -- 243 unique countries

SELECT DISTINCT tests_units FROM covid_vaccinations; -- We have 4 values (tests performed, units unclear, samples tested, people tested) and a blank column ('')
SELECT COUNT(*) from covid_vaccinations WHERE tests_units = ''; -- 229255 missing values or blank columns, may choose to ignore this column in light of little information

-- Count and percentage from total of each of the distinct values we got
SELECT continent, COUNT(*), COUNT(*)/(SELECT COUNT(*) FROM covid_deaths) * 100 AS pct
FROM covid_deaths
GROUP BY continent WITH ROLLUP;

SELECT location, COUNT(*), COUNT(*)/(SELECT COUNT(*) FROM covid_deaths) * 100 AS pct
FROM covid_deaths
WHERE continent != ''
GROUP BY location;

SELECT tests_units, COUNT(*), COUNT(*)/(SELECT COUNT(*) FROM covid_vaccinations) * 100 AS pct
FROM covid_vaccinations
GROUP BY tests_units;

-- Earliest and latest date in the datasets (2020-01-01 till 2023-08-25)
SELECT MIN(date) as earliest_date, MAX(date) as latest_date
FROM covid_deaths;

SELECT MIN(date) as earliest_date, MAX(date) as latest_date
FROM covid_vaccinations; 

-- Queries --

-- Globally
-- What is the total number of infected cases, deaths, vaccinations, and probability of death if infected?
SELECT
	SUM(new_vaccinations) as total_vaccinations,
    SUM(new_cases) as total_cases,
    SUM(new_deaths) as total_deaths,
    SUM(new_deaths)/SUM(new_cases) * 100 as death_probability
FROM covid_deaths dea
JOIN covid_vaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent != '';

-- Which year has the most cases / deaths / vaccinations?
SELECT
	YEAR(dea.date) as year,
    SUM(new_vaccinations) as total_vaccinations,
    SUM(new_cases) as total_cases,
    SUM(new_deaths) as total_deaths
FROM covid_deaths dea
JOIN covid_vaccinations vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent != ''
GROUP BY YEAR(date)
ORDER BY total_cases DESC;

-- Which month has the most deaths? Does covid display seasonality? Possible!
SELECT
	MONTHNAME(date) AS month,
	SUM(new_cases) as total_cases,
    SUM(new_deaths) as total_deaths
FROM covid_deaths
WHERE continent != '' AND YEAR(date) BETWEEN 2020 AND 2022
GROUP BY MONTHNAME(date)
ORDER BY total_cases DESC;

-- Continental level
-- Which continents have the highest/lowest absolute and per capita vaccination, cases, deaths (Using CTE)
WITH continent_cte (continent, total_population, total_cases, total_deaths, total_vaccinations)
AS
(
SELECT
    c1.continent,
    c1.total_population,
    SUM(c2.new_cases) as total_cases,
    SUM(c2.new_deaths) as total_deaths,
    SUM(c3.new_vaccinations) as total_vaccinations
FROM (
    SELECT continent, SUM(max_population) AS total_population
    FROM (
        SELECT continent, location, MAX(population) AS max_population
        FROM covid_deaths
        WHERE continent != ''
        GROUP BY continent, location
    ) AS subquery
    GROUP BY continent
) AS c1
JOIN covid_deaths AS c2
	ON c1.continent = c2.continent
JOIN covid_vaccinations AS c3
	ON c2.location = c3.location AND c2.date = c3.date
WHERE c2.continent != '' AND c3.continent != ''
GROUP BY c1.continent
ORDER BY total_deaths DESC
)
SELECT
	continent,
    total_cases,
    total_cases/total_population as case_per_cap,
    total_deaths,
    total_deaths/total_population as death_per_cap,
    total_vaccinations,
    total_vaccinations/total_population as vac_per_cap
FROM continent_cte
ORDER BY death_per_cap DESC;

-- Which income categories have the highest/lowest vaccination, cases, deaths per capita (Using Temp Tables)
DROP TEMPORARY TABLE IF EXISTS income_temp_table;

CREATE TEMPORARY TABLE income_temp_table (
	location VARCHAR(255),
    population BIGINT,
    total_cases BIGINT,
    total_deaths BIGINT,
    total_vaccinations BIGINT
);

INSERT INTO income_temp_table
SELECT
	dea.location,
    population,
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_vaccinations) AS total_vaccinations
FROM covid_deaths AS dea
JOIN covid_vaccinations AS vac
	ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.location LIKE '%income%'
GROUP BY location, population;

SELECT
	location,
    total_cases,
    total_cases/population AS case_per_cap,
    total_deaths,
    total_deaths/population as death_per_cap,
    total_vaccinations,
    total_vaccinations/population as vac_per_cap
FROM income_temp_table;

-- Grouping by countries
-- Which countries have the highest infection rates based on population?
SELECT
	location,
    population,
    MAX(total_cases) AS total_cases,
    (MAX(total_cases)/population)*100 AS pct_pop_infected 
FROM covid_deaths
WHERE continent != ''
GROUP BY location, population
ORDER BY pct_pop_infected DESC;

-- Which countries have the highest death percentage if infected by covid?
SELECT
	location,
    SUM(new_cases) as total_cases,
    SUM(new_deaths) as total_deaths,
    IFNULL(SUM(new_deaths)/SUM(new_cases) * 100, 0) as DeathProbability
FROM covid_deaths
WHERE continent != ''
GROUP BY location, population
ORDER BY DeathProbability DESC;

-- Which countries have the highest percentage death rates based on population?
SELECT
	location,
    population,
    MAX(total_deaths) as HighestDeathCount,
    MAX(total_deaths)/population*100 as pct_pop_dead
FROM covid_deaths
WHERE continent != ''
GROUP BY location, population
ORDER by pct_pop_dead DESC;

-- Which countries have the highest weekly ICU/Hospital admissions per capita?
SELECT
	location,
    population,
    AVG(weekly_icu_admissions) AS mean_weekly_icu_admission,
    AVG(weekly_hosp_admissions) AS mean_weekly_hosp_admission,
    AVG(weekly_icu_admissions)/population as mean_icu_adm_per_cap,
    AVG(weekly_hosp_admissions)/population as mean_hosp_adm_per_cap
FROM covid_deaths
WHERE continent != ''
GROUP BY location, population
ORDER BY mean_icu_adm_per_cap DESC;

-- When did each country start testing for covid?
SELECT
	location,
    MIN(date) AS earliest_date,
    MIN(total_tests) AS num_tests_on_first_day,
    COUNT(*)
FROM covid_vaccinations
WHERE continent != '' AND total_tests > 0
GROUP BY location
ORDER BY earliest_date; 

-- Creating view to store data for later visualizations
CREATE VIEW PopVacCaseDeathsView AS
SELECT
	vac.continent,
    vac.location,
    vac.date,
    dea.population,
    vac.new_vaccinations,
    vac.total_vaccinations,
    vac.people_vaccinated,
    vac.people_fully_vaccinated,
    vac.total_boosters,
    dea.new_cases,
    dea.new_deaths,
    dea.total_cases,
    dea.total_deaths
FROM covid_vaccinations vac
JOIN covid_deaths dea
	ON vac.location = dea.location AND  vac.date= dea.date
WHERE vac.continent != '';
    
SELECT * FROM PopVacCaseDeathsView;

-- How many people are vaccinated per capita for each country?
SELECT 
	location,
    population,
    MAX(people_vaccinated) AS people_vaccinated,
    MAX(people_vaccinated)/population*100 AS pct_population_vaccinated
FROM PopVacCaseDeathsView
GROUP BY location, population
ORDER BY pct_population_vaccinated DESC;

-- How many people are fully vaccinated per capita for each country?
SELECT
	location,
    population,
    MAX(people_fully_vaccinated) AS people_fully_vaccinated,
    MAX(people_fully_vaccinated)/population*100 AS pct_population_fully_vaccinated
FROM PopVacCaseDeathsView
GROUP BY location, population
ORDER BY pct_population_fully_vaccinated DESC;

-- Time Series
-- Probability of death over time
SELECT
	date,
    SUM(new_cases) as total_cases,
    SUM(new_deaths) as total_deaths,
    IFNULL(SUM(new_deaths)/SUM(new_cases)*100, 0) as DeathProbability
FROM covid_deaths
WHERE continent != ''
GROUP BY date
ORDER BY date;

-- What is the percentage of population infected by covid, over time for each country
SELECT
	location,
    population,
    date,
    total_cases,
    total_cases/population*100 as pct_pop_infected
From covid_deaths
WHERE continent != ''
ORDER BY location, date;

-- Absolute and percentage rolling people vaccinated for each country
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
SELECT
	dea.continent,
	dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(new_vaccinations) OVER(PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
FROM covid_deaths dea
JOIN covid_vaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent != ''
)
SELECT *, (RollingPeopleVaccinated/Population)*100 AS PercentPeopleVaccinated
FROM PopvsVac;

-- Rolling death percentage
SELECT
	location,
    date,
    population,
    total_cases,
    total_deaths,
    IFNULL((total_deaths/total_cases)*100, 0) as DeathPercentage
FROM covid_deaths
where continent != '';