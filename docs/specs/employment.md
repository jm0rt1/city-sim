# Specification: Employment System

## Purpose
Define the comprehensive employment subsystem for City-Sim, including job markets, employers, labor force dynamics, workplace infrastructure, wage determination, hiring and layoffs, skills matching, job quality metrics, and their effects on economic productivity, population wellbeing, income inequality, and city prosperity.

## Overview

The Employment System simulates the labor market and workforce dynamics. Employment affects household income, economic growth, tax revenue, migration patterns, happiness, and social stability. This subsystem models job creation and destruction, labor supply and demand, skills matching, wage negotiations, unemployment dynamics, career progression, workplace conditions, and labor market policies. The system integrates closely with Education for skills development, Finance for economic cycles, Population for demographics, and Transportation for commuting patterns.

## Core Concepts

### Employment Types
- **Full-Time Employment**: Standard 40-hour work week with benefits
- **Part-Time Employment**: Less than 40 hours, often limited benefits
- **Contract/Temporary**: Fixed-term employment for specific projects
- **Self-Employment**: Business owners, freelancers, independent contractors
- **Gig Economy**: On-demand platform work (rideshare, delivery, freelance)
- **Remote Work**: Telework without physical office presence
- **Seasonal Employment**: Jobs tied to specific times of year (agriculture, tourism)
- **Apprenticeships**: Training positions combining work and learning

### Industry Sectors
- **Primary Sector**: Agriculture, mining, forestry, fishing, resource extraction
- **Manufacturing**: Factory production, assembly, heavy industry
- **Construction**: Building, infrastructure development, trades
- **Retail & Wholesale**: Stores, sales, distribution
- **Services**: Personal services, hospitality, food service, entertainment
- **Finance & Insurance**: Banking, investment, insurance, real estate
- **Information Technology**: Software, telecommunications, data services
- **Healthcare**: Medical professionals, hospitals, clinics, home care
- **Education**: Teachers, trainers, academic staff
- **Professional Services**: Legal, accounting, consulting, engineering
- **Government**: Public administration, civil service
- **Transportation & Logistics**: Shipping, warehousing, delivery

### Labor Market Dynamics
- **Labor Force Participation**: Percentage of working-age population employed or seeking work
- **Employment Rate**: Percentage of labor force currently employed
- **Unemployment Rate**: Percentage of labor force actively seeking work
- **Underemployment**: Workers in jobs below their skill level or part-time seeking full-time
- **Job Openings**: Available positions employers are seeking to fill
- **Job Vacancy Rate**: Openings as percentage of total jobs
- **Hiring Rate**: New hires per period as percentage of employment
- **Separation Rate**: Job separations (quits + layoffs) as percentage of employment
- **Job-to-Job Transitions**: Workers changing employers without unemployment

### Workplace Infrastructure
- **Office Buildings**: Commercial office space for white-collar work
- **Factories**: Manufacturing facilities with production equipment
- **Retail Stores**: Commercial spaces for customer-facing sales
- **Warehouses**: Distribution and storage facilities
- **Construction Sites**: Temporary job sites for building projects
- **Farms**: Agricultural production land and facilities
- **Home Offices**: Remote work infrastructure
- **Co-Working Spaces**: Shared flexible office environments
- **Industrial Parks**: Concentrated manufacturing and logistics zones

### Job Quality Metrics
- **Wages**: Hourly wage rate or annual salary by occupation
- **Benefits**: Health insurance, retirement plans, paid leave
- **Job Security**: Risk of layoff, contract permanence
- **Working Conditions**: Safety, physical demands, stress levels
- **Work-Life Balance**: Hours, schedule flexibility, commute time
- **Career Advancement**: Promotion opportunities, skill development
- **Job Satisfaction**: Worker contentment with position
- **Workplace Safety**: Injury rates, occupational hazards

### Skills and Qualifications
- **Education Level**: Required degree or diploma
- **Work Experience**: Years in occupation or industry
- **Technical Skills**: Job-specific competencies and knowledge
- **Soft Skills**: Communication, teamwork, problem-solving
- **Certifications**: Professional licenses and credentials
- **Skill Obsolescence**: Skills becoming outdated due to technology
- **Training Programs**: Employer-provided skill development
- **Skills Gap**: Mismatch between worker skills and job requirements

### Wage Determination
- **Market Wages**: Supply and demand equilibrium for each occupation
- **Minimum Wage**: Legally mandated wage floor
- **Living Wage**: Wage needed to afford basic necessities
- **Wage Premium**: Higher pay for skills, experience, or hazardous work
- **Wage Discrimination**: Pay disparities based on demographics
- **Collective Bargaining**: Union-negotiated wages
- **Productivity**: Worker output affecting compensation
- **Cost of Living**: Local price levels affecting wage requirements

## Architecture

### Component Structure

```
EmploymentSubsystem
├── LaborMarket
│   ├── JobMarketManager
│   ├── UnemploymentTracker
│   ├── LaborForceCalculator
│   └── VacancyManager
├── EmployerSystem
│   ├── EmployerRegistry
│   ├── JobCreationEngine
│   ├── LayoffProcessor
│   └── IndustrySimulator
├── WorkerPopulation
│   ├── WorkerRegistry
│   ├── SkillsDatabase
│   ├── JobHistoryTracker
│   └── CareerProgressionManager
├── JobMatchingSystem
│   ├── JobSearchEngine
│   ├── SkillsMatcher
│   ├── HiringProcessor
│   └── ApplicationManager
├── WageSystem
│   ├── WageCalculator
│   ├── CompensationManager
│   ├── BenefitsAdministrator
│   └── MinimumWageEnforcer
├── WorkplaceSystem
│   ├── WorkplaceInfrastructureManager
│   ├── OccupationalSafetyManager
│   ├── RemoteWorkCoordinator
│   └── CommuteOptimizer
├── LaborPolicy
│   ├── UnemploymentInsurance
│   ├── WorkerProtections
│   ├── LaborRegulations
│   └── JobTrainingPrograms
└── EconomicCycleManager
    ├── BusinessCycleTracker
    ├── SeasonalAdjuster
    └── StructuralChangeManager
```

## Interfaces

### EmploymentSubsystem

```python
class EmploymentSubsystem(ISubsystem):
    """
    Primary employment subsystem managing labor markets, jobs, and workers.
    """
    
    def __init__(self, settings: EmploymentSettings, random_service: RandomService):
        """
        Initialize employment subsystem.
        
        Arguments:
            settings: Configuration for employment system parameters
            random_service: Seeded random number generator for deterministic behavior
        """
        
    def update(self, city: City, context: TickContext) -> EmploymentDelta:
        """
        Update employment system for current tick.
        
        Execution order:
        1. Update labor force participation based on demographics
        2. Process employer job creation and destruction
        3. Execute job matching between unemployed workers and openings
        4. Process layoffs and quits
        5. Update wages based on market conditions
        6. Calculate unemployment benefits and costs
        7. Track career progression and skill development
        8. Update workplace infrastructure
        9. Calculate employment metrics and economic impacts
        
        Arguments:
            city: Current city state
            context: Tick context with timing and random services
            
        Returns:
            EmploymentDelta containing all employment changes and labor metrics
        """
        
    def get_employment_rate(self) -> float:
        """Get percentage of labor force currently employed."""
        
    def get_unemployment_rate(self) -> float:
        """Get percentage of labor force actively seeking work."""
        
    def get_median_wage(self) -> float:
        """Get median hourly wage across all employed workers."""
        
    def get_jobs_by_sector(self) -> dict[str, int]:
        """Get count of jobs in each industry sector."""
        
    def get_skills_gap_index(self) -> float:
        """Get measure of mismatch between worker skills and job requirements (0-1)."""
```

### LaborMarket

```python
class LaborMarket:
    """
    Manages overall labor market dynamics and equilibrium.
    """
    
    def __init__(self, settings: LaborMarketSettings):
        """
        Initialize labor market.
        
        Arguments:
            settings: Labor market configuration
        """
        
    def update_labor_force(self, population: Population, 
                          context: TickContext) -> LaborForceDelta:
        """
        Update labor force participation and composition.
        
        Processes:
        - Calculate working-age population (typically 16-65)
        - Determine labor force participation by demographics
        - Account for students, retirees, caregivers out of labor force
        - Track discouraged workers exiting labor force
        - Update labor force skills distribution
        
        Arguments:
            population: Current population demographics
            context: Tick context
            
        Returns:
            LaborForceDelta with labor force size, participation rate, demographics
        """
        
    def calculate_unemployment_rate(self, employed: int, 
                                    unemployed: int) -> float:
        """
        Calculate official unemployment rate.
        
        Formula: unemployed / (employed + unemployed) * 100
        
        Arguments:
            employed: Count of employed workers
            unemployed: Count actively seeking work
            
        Returns:
            Unemployment rate percentage
        """
        
    def match_jobs_to_workers(self, job_openings: list[JobOpening],
                             unemployed_workers: list[Worker],
                             context: TickContext) -> MatchingResults:
        """
        Match unemployed workers to job openings.
        
        Matching algorithm considers:
        - Skills match between worker and job requirements
        - Geographic distance (commute feasibility)
        - Wage acceptability
        - Schedule compatibility
        - Random search frictions
        
        Arguments:
            job_openings: Available job positions
            unemployed_workers: Workers seeking employment
            context: Tick context with RNG
            
        Returns:
            MatchingResults with successful matches, filled jobs, hired workers
        """
```

### EmployerSystem

```python
class EmployerSystem:
    """
    Manages employers and their hiring/firing decisions.
    """
    
    def __init__(self, settings: EmployerSettings, random_service: RandomService):
        """
        Initialize employer system.
        
        Arguments:
            settings: Employer configuration
            random_service: Seeded RNG for employer decisions
        """
        
    def update_employers(self, city: City, economic_conditions: EconomicConditions,
                        context: TickContext) -> EmployerDelta:
        """
        Update all employers and their employment decisions.
        
        Processes:
        - Create new businesses and close existing ones
        - Determine job creation based on demand and growth
        - Process layoffs based on economic conditions
        - Update job openings and recruitment
        - Adjust wages based on market conditions
        - Calculate employer costs (wages + benefits + overhead)
        
        Arguments:
            city: Current city state
            economic_conditions: Economic cycle phase and indicators
            context: Tick context
            
        Returns:
            EmployerDelta with job creation, destruction, and employer changes
        """
        
    def create_job_openings(self, employer: Employer, count: int,
                           job_type: JobType) -> list[JobOpening]:
        """
        Create new job openings for an employer.
        
        Job characteristics determined by:
        - Industry sector norms
        - Employer size and resources
        - Market wage rates
        - Required skill levels
        
        Arguments:
            employer: Employer creating jobs
            count: Number of openings to create
            job_type: Type of job being offered
            
        Returns:
            List of new job openings
        """
        
    def process_layoffs(self, employer: Employer, layoff_count: int,
                       workers: list[Worker]) -> list[Worker]:
        """
        Process layoffs from an employer.
        
        Layoff selection criteria:
        - Last in, first out (LIFO) seniority
        - Performance-based
        - Random (restructuring)
        - Position elimination
        
        Arguments:
            employer: Employer conducting layoffs
            layoff_count: Number of workers to lay off
            workers: Current employees
            
        Returns:
            List of laid-off workers
        """
```

### WorkerPopulation

```python
class WorkerPopulation:
    """
    Tracks individual workers, skills, and employment histories.
    """
    
    def __init__(self, population: Population):
        """
        Initialize worker population from city population.
        
        Arguments:
            population: Total city population to derive workers from
        """
        
    def update_worker_status(self, employment_changes: EmploymentChanges,
                            context: TickContext) -> WorkerDelta:
        """
        Update worker employment status and characteristics.
        
        Updates:
        - Employment status (employed, unemployed, out of labor force)
        - Job tenure and experience accumulation
        - Skill development through on-the-job training
        - Wage changes and promotions
        - Job satisfaction and engagement
        
        Arguments:
            employment_changes: Hires, layoffs, quits this tick
            context: Tick context
            
        Returns:
            WorkerDelta with updated worker states
        """
        
    def calculate_worker_skills(self, worker: Worker, education: Education,
                               experience: Experience) -> SkillsProfile:
        """
        Calculate worker's skills profile.
        
        Skills derived from:
        - Education level and field of study
        - Work experience in occupations/industries
        - Training programs completed
        - Certifications earned
        - Time decay of unused skills
        
        Arguments:
            worker: Worker to evaluate
            education: Educational background
            experience: Work experience history
            
        Returns:
            SkillsProfile with skill levels by category
        """
        
    def track_unemployment_duration(self, worker: Worker) -> int:
        """
        Track duration of current unemployment spell.
        
        Returns:
            Number of ticks worker has been unemployed
        """
```

### JobMatchingSystem

```python
class JobMatchingSystem:
    """
    Matches workers to jobs using skills and preferences.
    """
    
    def __init__(self, settings: MatchingSettings):
        """
        Initialize job matching system.
        
        Arguments:
            settings: Matching algorithm configuration
        """
        
    def match_worker_to_job(self, worker: Worker, job: JobOpening,
                           commute_distance: float) -> float:
        """
        Calculate match quality score for worker-job pair.
        
        Match factors:
        - Skills overlap (required vs possessed)
        - Education level fit
        - Experience relevance
        - Wage acceptability (reservation wage)
        - Commute distance feasibility
        - Schedule compatibility
        
        Arguments:
            worker: Worker seeking employment
            job: Job opening
            commute_distance: Distance from worker home to job location
            
        Returns:
            Match quality score (0-1)
        """
        
    def search_for_jobs(self, worker: Worker, available_jobs: list[JobOpening],
                       city: City) -> list[tuple[JobOpening, float]]:
        """
        Search for suitable jobs for a worker.
        
        Search process:
        - Filter jobs by basic qualifications
        - Score remaining jobs by match quality
        - Consider geographic accessibility
        - Account for search intensity and information frictions
        
        Arguments:
            worker: Worker conducting job search
            available_jobs: All job openings
            city: City state for geographic calculations
            
        Returns:
            List of (job, match_score) tuples, sorted by match quality
        """
        
    def make_hiring_decision(self, employer: Employer, applicants: list[Worker],
                            job: JobOpening, context: TickContext) -> Worker | None:
        """
        Employer selects best applicant for job opening.
        
        Selection criteria:
        - Skills match
        - Experience level
        - Education credentials
        - References and job history
        - Random elements (interview performance)
        
        Arguments:
            employer: Employer making decision
            applicants: Workers who applied
            job: Job opening being filled
            context: Tick context with RNG
            
        Returns:
            Selected worker or None if no suitable candidate
        """
```

### WageSystem

```python
class WageSystem:
    """
    Determines wages and compensation across the labor market.
    """
    
    def __init__(self, settings: WageSettings):
        """
        Initialize wage system.
        
        Arguments:
            settings: Wage calculation configuration
        """
        
    def calculate_market_wage(self, occupation: str, skill_level: float,
                             labor_demand: float, labor_supply: float) -> float:
        """
        Calculate market-clearing wage for an occupation.
        
        Wage determination factors:
        - Labor supply and demand balance
        - Skill level requirements
        - Industry sector norms
        - Cost of living in city
        - Productivity of workers
        - Minimum wage constraints
        
        Arguments:
            occupation: Occupation type
            skill_level: Required skill level (0-1)
            labor_demand: Demand for this occupation
            labor_supply: Supply of qualified workers
            
        Returns:
            Hourly wage rate
        """
        
    def adjust_wages(self, employer: Employer, market_conditions: MarketConditions,
                    inflation_rate: float) -> WageAdjustments:
        """
        Adjust employer wages based on market conditions.
        
        Adjustment factors:
        - Inflation (cost of living adjustments)
        - Labor market tightness (competition for workers)
        - Employer profitability
        - Minimum wage changes
        - Union contracts
        - Performance and seniority raises
        
        Arguments:
            employer: Employer adjusting wages
            market_conditions: Current labor market state
            inflation_rate: Price inflation rate
            
        Returns:
            WageAdjustments with new wage levels and costs
        """
        
    def calculate_total_compensation(self, base_wage: float,
                                    benefits: Benefits) -> float:
        """
        Calculate total compensation including benefits.
        
        Compensation components:
        - Base wage or salary
        - Health insurance value
        - Retirement contributions
        - Paid time off
        - Bonuses and profit-sharing
        - Stock options
        - Other perks
        
        Arguments:
            base_wage: Hourly wage or annual salary
            benefits: Benefits package details
            
        Returns:
            Total hourly compensation value
        """
```

### WorkplaceSystem

```python
class WorkplaceSystem:
    """
    Manages workplace infrastructure and conditions.
    """
    
    def __init__(self, settings: WorkplaceSettings):
        """
        Initialize workplace system.
        
        Arguments:
            settings: Workplace infrastructure configuration
        """
        
    def update_workplaces(self, city: City, employment: Employment,
                         budget: float) -> WorkplaceDelta:
        """
        Update workplace infrastructure.
        
        Updates:
        - Office space capacity and utilization
        - Factory capacity and modernization
        - Retail store construction
        - Remote work infrastructure
        - Workplace safety improvements
        - Accessibility accommodations
        
        Arguments:
            city: Current city state
            employment: Current employment levels by sector
            budget: Available budget for workplace investment
            
        Returns:
            WorkplaceDelta with capacity changes and investments
        """
        
    def calculate_commute_time(self, worker_location: Location,
                              workplace_location: Location,
                              transport_network: TransportNetwork) -> float:
        """
        Calculate commute time from home to work.
        
        Uses transportation network to find optimal route and time.
        
        Arguments:
            worker_location: Worker's residential location
            workplace_location: Job location
            transport_network: City transportation infrastructure
            
        Returns:
            Commute time in minutes
        """
        
    def assess_workplace_safety(self, workplace: Workplace,
                               industry: str) -> float:
        """
        Assess workplace safety level.
        
        Safety factors:
        - Industry hazard level (construction > office)
        - Safety equipment and training
        - Regulatory compliance
        - Accident history
        - Maintenance quality
        
        Arguments:
            workplace: Workplace to assess
            industry: Industry sector
            
        Returns:
            Safety score (0-1, higher is safer)
        """
```

### LaborPolicy

```python
class LaborPolicy:
    """
    Implements labor market policies and regulations.
    """
    
    def __init__(self, settings: LaborPolicySettings):
        """
        Initialize labor policy system.
        
        Arguments:
            settings: Labor policy configuration
        """
        
    def administer_unemployment_insurance(self, unemployed: list[Worker],
                                         budget: float) -> UIBenefits:
        """
        Provide unemployment insurance benefits.
        
        Eligibility:
        - Involuntary job loss (laid off, not quit)
        - Minimum work history
        - Actively seeking work
        - Maximum duration (e.g., 26 weeks)
        
        Benefit calculation:
        - Percentage of previous wage (e.g., 50%)
        - Maximum weekly benefit cap
        - Duration limits
        
        Arguments:
            unemployed: Unemployed workers
            budget: Available UI budget
            
        Returns:
            UIBenefits with payments and recipients
        """
        
    def enforce_minimum_wage(self, employers: list[Employer],
                           minimum_wage: float) -> ComplianceReport:
        """
        Enforce minimum wage requirements.
        
        Actions:
        - Identify employers paying below minimum
        - Issue warnings and fines
        - Require wage adjustments
        - Track compliance
        
        Arguments:
            employers: All employers in city
            minimum_wage: Current minimum wage rate
            
        Returns:
            ComplianceReport with violations and enforcement actions
        """
        
    def implement_training_programs(self, unemployed: list[Worker],
                                   skills_gap: SkillsGap,
                                   budget: float) -> TrainingResults:
        """
        Provide job training programs for unemployed workers.
        
        Training types:
        - Skills retraining for displaced workers
        - Vocational certification programs
        - Apprenticeships
        - Soft skills development
        
        Arguments:
            unemployed: Unemployed workers eligible for training
            skills_gap: Current mismatch between supply and demand
            budget: Training program budget
            
        Returns:
            TrainingResults with participants and skill improvements
        """
```

### EconomicCycleManager

```python
class EconomicCycleManager:
    """
    Tracks business cycles and their employment effects.
    """
    
    def __init__(self, settings: CycleSettings):
        """
        Initialize economic cycle manager.
        
        Arguments:
            settings: Business cycle configuration
        """
        
    def determine_cycle_phase(self, economic_indicators: EconomicIndicators,
                            context: TickContext) -> CyclePhase:
        """
        Determine current business cycle phase.
        
        Phases:
        - Expansion: Growing employment and output
        - Peak: Maximum employment and output
        - Contraction/Recession: Declining employment and output
        - Trough: Minimum employment and output
        
        Indicators:
        - GDP growth rate
        - Employment growth rate
        - Business confidence
        - Consumer spending
        
        Arguments:
            economic_indicators: Current economic metrics
            context: Tick context
            
        Returns:
            CyclePhase (expansion, peak, contraction, trough)
        """
        
    def apply_cycle_effects(self, phase: CyclePhase,
                           employment_system: EmploymentSubsystem) -> CycleEffects:
        """
        Apply business cycle effects to employment.
        
        Expansion effects:
        - Increased hiring
        - Reduced layoffs
        - Rising wages
        - Lower unemployment
        
        Contraction effects:
        - Hiring freezes
        - Increased layoffs
        - Wage stagnation
        - Rising unemployment
        
        Arguments:
            phase: Current cycle phase
            employment_system: Employment subsystem to affect
            
        Returns:
            CycleEffects with employment impacts
        """
```

## Data Models

### Worker

```python
@dataclass
class Worker:
    """Represents an individual worker in the labor force."""
    
    worker_id: int
    age: int
    education_level: EducationLevel
    skills: SkillsProfile
    occupation: str | None  # None if unemployed
    employer_id: int | None  # None if unemployed
    employment_status: EmploymentStatus
    wage: float  # Hourly wage when employed
    experience_years: float
    job_tenure_ticks: int  # Time in current job
    unemployment_duration_ticks: int  # Time unemployed
    job_satisfaction: float  # 0-1 scale
    home_location: Location
    workplace_location: Location | None
    reservation_wage: float  # Minimum acceptable wage
    
    def is_employed(self) -> bool:
        """Check if worker is currently employed."""
        return self.employment_status == EmploymentStatus.EMPLOYED
    
    def is_unemployed(self) -> bool:
        """Check if worker is unemployed and seeking work."""
        return self.employment_status == EmploymentStatus.UNEMPLOYED
    
    def is_in_labor_force(self) -> bool:
        """Check if worker is in the labor force."""
        return self.employment_status in (
            EmploymentStatus.EMPLOYED, 
            EmploymentStatus.UNEMPLOYED
        )
```

### Employer

```python
@dataclass
class Employer:
    """Represents a business employing workers."""
    
    employer_id: int
    business_name: str
    industry_sector: IndustrySector
    size_category: EmployerSize  # Small, medium, large
    location: Location
    employee_count: int
    job_openings: list[JobOpening]
    total_wage_bill: float
    profitability: float  # Affects hiring/layoff decisions
    growth_rate: float  # Annual growth rate
    
    def get_jobs_by_type(self) -> dict[JobType, int]:
        """Get count of jobs by type (full-time, part-time, etc.)."""
        
    def calculate_labor_costs(self) -> float:
        """Calculate total labor costs including wages and benefits."""
```

### JobOpening

```python
@dataclass
class JobOpening:
    """Represents an available job position."""
    
    job_id: int
    employer_id: int
    occupation: str
    industry_sector: IndustrySector
    job_type: JobType  # Full-time, part-time, contract, etc.
    required_education: EducationLevel
    required_skills: SkillsProfile
    required_experience_years: float
    offered_wage: float
    benefits: Benefits
    location: Location
    remote_eligible: bool
    posted_tick: int
    
    def matches_worker_qualifications(self, worker: Worker) -> bool:
        """Check if worker meets basic qualifications."""
```

### SkillsProfile

```python
@dataclass
class SkillsProfile:
    """Represents a worker's skills or job requirements."""
    
    technical_skills: dict[str, float]  # Skill name -> proficiency (0-1)
    cognitive_skills: float  # Problem-solving, critical thinking (0-1)
    interpersonal_skills: float  # Communication, teamwork (0-1)
    physical_skills: float  # Manual dexterity, strength (0-1)
    digital_literacy: float  # Computer and technology skills (0-1)
    
    def calculate_match_score(self, required: 'SkillsProfile') -> float:
        """
        Calculate how well this profile matches required skills.
        
        Returns:
            Match score (0-1), 1.0 = perfect match
        """
```

### Benefits

```python
@dataclass
class Benefits:
    """Represents employee benefits package."""
    
    health_insurance: bool
    dental_insurance: bool
    vision_insurance: bool
    retirement_contribution_rate: float  # As percentage of wage
    paid_time_off_days: int
    sick_leave_days: int
    parental_leave_days: int
    life_insurance: bool
    disability_insurance: bool
    
    def calculate_total_value(self, annual_wage: float) -> float:
        """Calculate total annual value of benefits package."""
```

### EmploymentDelta

```python
@dataclass
class EmploymentDelta:
    """Changes to employment state for one tick."""
    
    # Labor force changes
    labor_force_size: int
    labor_force_participation_rate: float
    new_entrants: int  # Workers entering labor force
    exits: int  # Workers leaving labor force
    
    # Employment changes
    hires: int
    layoffs: int
    quits: int
    retirements: int
    employed_count: int
    unemployed_count: int
    employment_rate: float
    unemployment_rate: float
    
    # Job changes
    jobs_created: int
    jobs_destroyed: int
    total_jobs: int
    job_openings: int
    vacancy_rate: float
    
    # Wages and compensation
    median_wage: float
    mean_wage: float
    total_wage_bill: float
    total_compensation: float
    
    # Skills and matching
    skills_gap_index: float
    average_job_search_duration_ticks: float
    job_finding_rate: float  # Percentage of unemployed finding jobs
    
    # Industry composition
    employment_by_sector: dict[str, int]
    wage_by_sector: dict[str, float]
    
    # Economic impacts
    labor_income_total: float
    unemployment_benefits_paid: float
    employment_tax_revenue: float
```

## State Management

### Persistent State
- **Worker Registry**: All workers with IDs, status, skills, history
- **Employer Registry**: All employers with IDs, industry, size, jobs
- **Job Openings**: Current vacancies and their characteristics
- **Employment Matches**: Current employer-employee relationships
- **Wage Rates**: Current wages by occupation and industry
- **Labor Market History**: Time series of employment metrics
- **Unemployment Spells**: Duration tracking for each unemployed worker
- **Workplace Infrastructure**: Capacity and utilization by type

### State Transitions
- **Hire**: Unemployed worker → Employed worker, Job opening → Filled job
- **Layoff**: Employed worker → Unemployed worker, Employer reduces headcount
- **Quit**: Employed worker → Unemployed worker (voluntary separation)
- **Labor Force Entry**: Out of labor force → Unemployed (job seeking begins)
- **Labor Force Exit**: Employed/Unemployed → Out of labor force (retirement, discouragement)
- **Job Creation**: Employer creates new job opening
- **Job Destruction**: Employer eliminates position
- **Business Formation**: New employer enters market
- **Business Closure**: Employer exits, all employees laid off

### Invariants
- Worker count by status = employed + unemployed + out_of_labor_force
- Labor force = employed + unemployed
- Unemployment rate = unemployed / labor_force
- Employment rate = employed / labor_force
- Total jobs ≥ employed count (jobs can be vacant)
- Wages ≥ minimum wage (if minimum wage enforced)
- Worker age matches demographics from Population subsystem

## Algorithms

### Job Matching Algorithm

```python
def match_jobs_to_workers(self, openings: list[JobOpening], 
                         unemployed: list[Worker],
                         context: TickContext) -> MatchingResults:
    """
    Match unemployed workers to job openings.
    
    Algorithm:
    1. For each unemployed worker:
        a. Search subset of job openings (limited information)
        b. Filter jobs by basic qualifications
        c. Score remaining jobs by match quality
        d. Apply for top N jobs (application limit)
    2. For each job opening with applicants:
        a. Score all applicants
        b. Select best applicant with randomness
        c. Make job offer
    3. Worker accepts/rejects offer based on reservation wage
    4. Update employment status for matches
    """
    
    matches = []
    rng = context.random_service
    
    # Phase 1: Workers search and apply
    applications = defaultdict(list)  # job_id -> list of applicants
    for worker in unemployed:
        # Worker searches limited set of jobs (search frictions)
        search_sample_size = rng.randint(5, 20)
        available_jobs = rng.sample(openings, min(search_sample_size, len(openings)))
        
        # Filter by basic qualifications
        qualified_jobs = [
            job for job in available_jobs
            if job.matches_worker_qualifications(worker)
        ]
        
        # Score jobs by match quality
        scored_jobs = [
            (job, self.calculate_match_score(worker, job))
            for job in qualified_jobs
        ]
        scored_jobs.sort(key=lambda x: x[1], reverse=True)
        
        # Apply to top jobs (application limit)
        application_limit = rng.randint(3, 8)
        for job, score in scored_jobs[:application_limit]:
            applications[job.job_id].append((worker, score))
    
    # Phase 2: Employers select from applicants
    for job in openings:
        applicants = applications.get(job.job_id, [])
        if not applicants:
            continue
        
        # Score applicants with randomness (interview luck)
        scored_applicants = [
            (worker, score * rng.uniform(0.8, 1.2))
            for worker, score in applicants
        ]
        scored_applicants.sort(key=lambda x: x[1], reverse=True)
        
        # Make offer to top candidate
        selected_worker, _ = scored_applicants[0]
        
        # Worker accepts if wage meets reservation wage
        if job.offered_wage >= selected_worker.reservation_wage:
            matches.append(JobMatch(worker=selected_worker, job=job))
    
    return MatchingResults(matches=matches)
```

### Wage Determination Algorithm

```python
def calculate_market_wage(self, occupation: str, skill_level: float,
                         labor_demand: float, labor_supply: float) -> float:
    """
    Calculate market-clearing wage using supply and demand.
    
    Algorithm:
    1. Get base wage for occupation from reference data
    2. Adjust for skill level premium
    3. Adjust for supply/demand ratio (tight market → higher wages)
    4. Adjust for cost of living in city
    5. Apply minimum wage floor
    6. Add random variance for firm-specific differences
    """
    
    # Base wage for occupation (national average)
    base_wage = self.occupation_base_wages.get(occupation, 15.0)
    
    # Skill premium (higher skills command higher wages)
    skill_multiplier = 1.0 + (skill_level * 0.5)  # 0-50% premium
    wage = base_wage * skill_multiplier
    
    # Supply and demand adjustment
    # tight market (demand > supply) → wage increase
    # slack market (supply > demand) → wage decrease
    if labor_supply > 0:
        demand_supply_ratio = labor_demand / labor_supply
        # Use elasticity of 0.3 (wage responds to demand/supply imbalance)
        supply_demand_multiplier = demand_supply_ratio ** 0.3
        wage *= supply_demand_multiplier
    
    # Cost of living adjustment
    wage *= self.city_cost_of_living_index
    
    # Minimum wage floor
    wage = max(wage, self.minimum_wage)
    
    # Firm-specific variance (some firms pay more/less)
    firm_variance = self.rng.uniform(0.95, 1.05)
    wage *= firm_variance
    
    return wage
```

### Layoff Decision Algorithm

```python
def determine_layoffs(self, employer: Employer, 
                     economic_conditions: EconomicConditions,
                     context: TickContext) -> int:
    """
    Determine how many workers an employer lays off.
    
    Algorithm:
    1. Assess employer financial health and market conditions
    2. Calculate desired workforce size based on demand
    3. If current > desired, compute layoff count
    4. Apply randomness and adjustment costs
    """
    
    rng = context.random_service
    
    # Factors driving layoffs
    profitability = employer.profitability  # -1 to 1 scale
    demand_change = economic_conditions.demand_growth_rate  # % change
    
    # Calculate desired workforce
    base_workforce = employer.employee_count
    
    # Adjust workforce based on demand
    if demand_change < 0:  # Demand declining
        workforce_adjustment = demand_change * 0.7  # Partial adjustment
    else:
        workforce_adjustment = 0  # Don't layoff when demand growing
    
    # Adjust for profitability
    if profitability < -0.2:  # Significant losses
        workforce_adjustment += -0.1  # Cut 10% more
    
    desired_workforce = base_workforce * (1 + workforce_adjustment)
    
    # Calculate layoff count
    if desired_workforce < base_workforce:
        layoff_count = int(base_workforce - desired_workforce)
        
        # Add randomness (some firms over-react)
        layoff_count = int(layoff_count * rng.uniform(0.8, 1.2))
        
        # Cap at maximum percentage per period (adjustment costs)
        max_layoffs_per_tick = int(base_workforce * 0.15)  # Max 15% per tick
        layoff_count = min(layoff_count, max_layoffs_per_tick)
    else:
        layoff_count = 0
    
    return layoff_count
```

### Skills Obsolescence Algorithm

```python
def update_skill_obsolescence(self, worker: Worker, 
                             tech_change_rate: float,
                             context: TickContext) -> SkillsProfile:
    """
    Update worker skills accounting for technological change and decay.
    
    Algorithm:
    1. Technical skills decay when not used
    2. Technology change makes some skills obsolete
    3. On-the-job experience builds skills
    4. Training programs update skills
    """
    
    skills = worker.skills
    
    # Skills decay without use
    if worker.is_unemployed():
        decay_rate = 0.01  # 1% per tick unemployed
        for skill_name in skills.technical_skills:
            current_level = skills.technical_skills[skill_name]
            skills.technical_skills[skill_name] = current_level * (1 - decay_rate)
    
    # Technology change obsoletes some skills
    # Higher tech_change_rate → faster obsolescence
    obsolescence_rate = tech_change_rate * 0.005  # Scale to tick
    for skill_name in skills.technical_skills:
        current_level = skills.technical_skills[skill_name]
        skills.technical_skills[skill_name] = current_level * (1 - obsolescence_rate)
    
    # On-the-job learning (if employed)
    if worker.is_employed():
        learning_rate = 0.005  # 0.5% per tick
        for skill_name in skills.technical_skills:
            current_level = skills.technical_skills[skill_name]
            # Skills improve toward max proficiency
            improvement = (1.0 - current_level) * learning_rate
            skills.technical_skills[skill_name] = current_level + improvement
    
    return skills
```

## Integration Points

### Education Subsystem
- **Graduates → Labor Force**: High school and university graduates enter labor force
- **Education Level → Skills**: Education level determines initial skill levels
- **Vocational Training → Skills**: Trade school provides specific job skills
- **University Research → Innovation**: Research affects productivity and job creation
- **Student Status**: Students typically not in labor force (except part-time work)

### Finance Subsystem
- **Employment → Tax Revenue**: Employed workers pay income taxes
- **Wages → Tax Base**: Wage levels determine income tax revenue
- **Unemployment Benefits → Spending**: Government spending on unemployed
- **Business Taxes**: Employers pay corporate taxes based on payroll
- **Economic Cycle**: Financial sector health affects hiring/layoffs

### Population Subsystem
- **Demographics → Labor Force**: Age distribution determines working-age population
- **Migration**: Job opportunities attract in-migration, unemployment drives out-migration
- **Birth/Death**: Population changes affect labor force size
- **Happiness**: Employment status and job quality affect population happiness
- **Income → Fertility**: Employment and wages affect family formation decisions

### Transportation Subsystem
- **Commuting**: Workers need transportation from home to workplace
- **Commute Time → Job Matching**: Long commutes reduce job acceptance
- **Traffic Congestion**: Employment density affects traffic patterns
- **Public Transit**: Transit access enables job access
- **Remote Work**: Reduces transportation demand

### Healthcare Subsystem
- **Healthcare Jobs**: Healthcare sector is major employer
- **Worker Health**: Health affects productivity and employment
- **Workplace Injuries**: Occupational health affects healthcare demand
- **Health Insurance**: Employer-provided benefits

### Crime Subsystem
- **Unemployment → Crime**: Higher unemployment increases crime rates
- **Job Programs**: Employment programs reduce recidivism
- **Criminal Records**: Criminal history affects employment prospects

### Housing Subsystem
- **Income → Housing**: Wages determine housing affordability
- **Job Location → Residential Choice**: Workers locate near jobs
- **Housing Costs → Reservation Wage**: Housing costs affect minimum acceptable wage

## Configuration and Settings

### EmploymentSettings

```python
@dataclass
class EmploymentSettings:
    """Configuration for employment subsystem."""
    
    # Labor force parameters
    labor_force_participation_rate: float = 0.63  # US: 63%
    retirement_age: int = 65
    minimum_working_age: int = 16
    student_employment_rate: float = 0.30  # Students working part-time
    
    # Job matching
    job_search_sample_size_range: tuple[int, int] = (5, 20)
    application_limit_range: tuple[int, int] = (3, 8)
    match_quality_threshold: float = 0.50  # Minimum match to apply
    
    # Wages
    minimum_wage: float = 7.25  # Federal minimum wage (USD/hour)
    wage_elasticity_of_demand: float = 0.30  # Wage response to supply/demand
    cost_of_living_index: float = 1.0  # Multiplier for local costs
    wage_growth_rate: float = 0.02  # Annual nominal wage growth
    
    # Unemployment
    baseline_unemployment_rate: float = 0.05  # Natural rate
    unemployment_benefit_rate: float = 0.50  # 50% of previous wage
    unemployment_benefit_duration_weeks: int = 26
    
    # Job dynamics
    monthly_job_creation_rate: float = 0.03  # 3% of jobs created per month
    monthly_job_destruction_rate: float = 0.025  # 2.5% destroyed per month
    baseline_quit_rate: float = 0.02  # 2% quit per month
    
    # Skills and experience
    experience_accumulation_rate: float = 1.0  # Years per year employed
    skill_decay_rate_unemployed: float = 0.01  # Decay per tick when unemployed
    skill_learning_rate_employed: float = 0.005  # Learning per tick when employed
    
    # Industry composition (initial distribution)
    industry_distribution: dict[str, float] = field(default_factory=lambda: {
        "manufacturing": 0.10,
        "construction": 0.06,
        "retail": 0.12,
        "services": 0.15,
        "finance": 0.08,
        "information_technology": 0.10,
        "healthcare": 0.14,
        "education": 0.10,
        "government": 0.08,
        "other": 0.07
    })
    
    # Business cycle
    enable_business_cycles: bool = True
    cycle_amplitude: float = 0.30  # Unemployment swing ±30%
    cycle_period_ticks: int = 1000  # Approximate cycle length
```

## Metrics and Reporting

### Employment Metrics Log Schema

```python
{
    # Standard fields
    "tick_index": int,
    "timestamp": str,
    "run_id": str,
    
    # Labor force
    "total_population": int,
    "working_age_population": int,
    "labor_force_size": int,
    "labor_force_participation_rate": float,
    "employed_count": int,
    "unemployed_count": int,
    "not_in_labor_force": int,
    
    # Employment rates
    "employment_rate": float,
    "unemployment_rate": float,
    "underemployment_rate": float,
    
    # Jobs
    "total_jobs": int,
    "job_openings": int,
    "vacancy_rate": float,
    "jobs_created_this_tick": int,
    "jobs_destroyed_this_tick": int,
    "net_job_creation": int,
    
    # Hires and separations
    "hires_this_tick": int,
    "layoffs_this_tick": int,
    "quits_this_tick": int,
    "hiring_rate": float,
    "separation_rate": float,
    
    # Wages and compensation
    "median_wage": float,
    "mean_wage": float,
    "wage_10th_percentile": float,
    "wage_90th_percentile": float,
    "total_wage_bill": float,
    "total_compensation": float,
    
    # Income distribution
    "gini_coefficient": float,
    "wage_share_top_10_percent": float,
    "wage_share_bottom_50_percent": float,
    
    # Industry breakdown
    "employment_manufacturing": int,
    "employment_services": int,
    "employment_retail": int,
    "employment_healthcare": int,
    "employment_technology": int,
    "employment_other": int,
    
    # Skills
    "skills_gap_index": float,
    "average_worker_education_years": float,
    "average_worker_experience_years": float,
    
    # Job quality
    "average_job_satisfaction": float,
    "percentage_jobs_with_benefits": float,
    "average_commute_time_minutes": float,
    "workplace_injury_rate": float,
    
    # Unemployment dynamics
    "average_unemployment_duration_weeks": float,
    "long_term_unemployment_rate": float,  # Unemployed >26 weeks
    "job_finding_rate": float,
    
    # Economic impacts
    "total_labor_income": float,
    "unemployment_benefits_paid": float,
    "income_tax_revenue": float,
    "payroll_tax_revenue": float,
    
    # Business cycle
    "economic_cycle_phase": str,  # expansion, peak, contraction, trough
    "months_since_last_recession": int
}
```

## Testing Considerations

### Unit Tests
1. Labor force participation calculations respect demographics
2. Job matching scores computed correctly for worker-job pairs
3. Wage determination reflects supply/demand balance
4. Unemployment rate calculations are accurate
5. Skills decay and accumulation formulas work correctly

### Integration Tests
1. Education graduates properly enter labor force
2. Employment income flows to Finance subsystem
3. Unemployment affects happiness in Population subsystem
4. Job locations affect commute patterns in Transportation
5. Layoffs during recession increase unemployment benefits spending

### Determinism Tests
1. Same seed produces identical hiring/layoff decisions
2. Job matching outcomes reproducible with same inputs
3. Wage adjustments deterministic given market conditions
4. Economic cycle timing is deterministic

### Performance Tests
1. Job matching scales efficiently with large numbers of workers and openings
2. Worker skill updates performant for large labor force
3. Employer updates efficient for many employers

### Economic Tests
1. Labor market reaches equilibrium (unemployment near natural rate)
2. Wages respond appropriately to supply/demand changes
3. Business cycles generate realistic employment fluctuations
4. Skills gap affects unemployment duration

## Implementation Notes

### Phase 1: Core Labor Market
- Implement Worker, Employer, JobOpening data models
- Build LaborMarket with basic matching algorithm
- Implement wage determination based on supply/demand
- Track employment/unemployment rates
- Integrate with Population for demographics

### Phase 2: Skills and Matching
- Implement SkillsProfile and matching algorithm
- Add skills decay and accumulation
- Improve job matching with skills consideration
- Add job search and application process
- Track skill gaps and mismatches

### Phase 3: Industry Sectors
- Implement IndustrySector differentiation
- Add sector-specific job characteristics
- Track employment by industry
- Implement sector-specific wage levels
- Add industry growth/decline dynamics

### Phase 4: Business Cycles
- Implement EconomicCycleManager
- Add business cycle effects on hiring/layoffs
- Implement recession and expansion dynamics
- Add leading economic indicators
- Integrate with Finance subsystem business cycle

### Phase 5: Labor Policies
- Implement unemployment insurance
- Add minimum wage enforcement
- Implement job training programs
- Add worker protections
- Track policy costs and impacts

### Python 3.13+ Considerations
- Use free-threaded mode for parallel job matching across workers
- Lock-free data structures for worker/employer registries
- Parallel processing of employer hiring decisions
- Concurrent skill updates for large worker populations
- Thread-safe random number generation per worker

## Future Enhancements

1. **Individual Workers**: Full agent-based modeling with individual histories
2. **Labor Unions**: Collective bargaining affecting wages and conditions
3. **Immigration**: International migration affecting labor supply
4. **Gig Economy Platform**: Explicit platform-mediated work
5. **Occupational Licensing**: Professional requirements affecting supply
6. **Discrimination**: Wage and hiring discrimination by demographics
7. **Monopsony Power**: Employer market power affecting wages
8. **Automation**: Technology replacing workers in occupations
9. **Telecommuting**: Remote work reducing geographic constraints
10. **Worker Cooperatives**: Alternative ownership structures

## References

- **Labor Economics**: Borjas "Labor Economics", Cahuc & Zylberberg "Labor Economics"
- **Job Search Theory**: Diamond-Mortensen-Pissarides search and matching models
- **Wage Determination**: Supply and demand equilibrium, search frictions
- **Business Cycles**: Real Business Cycle and New Keynesian models
- **BLS Statistics**: U.S. Bureau of Labor Statistics employment data
- **Labor Market Data**: JOLTS (Job Openings and Labor Turnover Survey)
- **Unemployment Insurance**: UI program design and impacts
- **Skills Gap**: Research on skills mismatch and training effectiveness

## Related Specs

- [Education](education.md): Education system producing skilled workers
- [Finance](finance.md): Economic cycles, tax revenue, government spending
- [Population](population.md): Demographics, migration, happiness
- [Transportation](traffic.md): Commuting patterns and job accessibility
- [Healthcare](healthcare.md): Healthcare sector employment and worker health
- [Crime](crime.md): Crime affecting employment and unemployment affecting crime
