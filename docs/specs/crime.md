# Specification: Crime System

## Purpose
Define the comprehensive crime subsystem for City-Sim, including crime generation, law enforcement, criminal justice, corrections, rehabilitation programs, crime prevention initiatives, and their effects on public safety, economic activity, population happiness, and community wellbeing.

## Overview

The Crime System simulates criminal activity and the city's response through law enforcement, judicial processes, and correctional facilities. Crime rates affect citizen safety, property values, business investment, tourism, and quality of life. This subsystem models various crime types, police investigation and apprehension, court prosecution, incarceration, rehabilitation, and crime prevention programs. The system integrates closely with Emergency Services for police response, Education for prevention, Population for demographics, and Healthcare for substance abuse treatment.

## Core Concepts

### Crime Types
- **Violent Crime**: Homicide, assault, robbery, sexual assault, domestic violence
- **Property Crime**: Burglary, larceny/theft, motor vehicle theft, arson, vandalism
- **White Collar Crime**: Fraud, embezzlement, identity theft, cybercrime, insider trading
- **Drug Crimes**: Drug trafficking, drug possession, manufacturing, distribution
- **Public Order Crimes**: Disorderly conduct, public intoxication, prostitution, gambling
- **Traffic Crimes**: DUI/DWI, reckless driving, hit-and-run, vehicular homicide
- **Organized Crime**: Gang activity, racketeering, money laundering, human trafficking
- **Cybercrime**: Hacking, data breaches, online fraud, ransomware attacks

### Law Enforcement Infrastructure
- **Police Stations**: Patrol dispatch, investigation units, holding cells
- **Police Precincts**: Geographic divisions for patrol coverage
- **Detective Bureaus**: Specialized investigation units (homicide, narcotics, fraud, cybercrime)
- **Crime Labs**: Forensic analysis, DNA testing, ballistics, digital forensics
- **Police Patrol Units**: Marked vehicles, officers on beat, bicycle/motorcycle patrols
- **Specialized Units**: SWAT, K-9, gang task force, vice squad, undercover operations
- **Crime Analysis Centers**: Data analysis, crime mapping, predictive policing
- **Police Training Academies**: Officer recruitment, training, and certification

### Crime Prevention
- **Community Policing**: Neighborhood engagement, trust-building, problem-solving
- **Youth Programs**: After-school programs, mentorship, juvenile diversion
- **Surveillance Systems**: CCTV cameras, license plate readers, monitoring centers
- **Environmental Design**: Crime Prevention Through Environmental Design (CPTED)
- **Neighborhood Watch**: Citizen crime prevention groups
- **Business Security**: Commercial area patrols, business improvement districts
- **Lighting Improvements**: Street lighting reducing opportunity for crime
- **Hot Spot Policing**: Concentrated patrols in high-crime areas

### Justice System
- **Courts**: Criminal courts processing cases from arrest to verdict
- **Prosecutors**: District attorneys prosecuting criminal cases
- **Public Defenders**: Legal representation for defendants
- **Judges**: Presiding over trials and sentencing
- **Jury System**: Citizens serving on juries for trials
- **Plea Bargaining**: Negotiated case resolutions
- **Sentencing**: Determining penalties for convicted offenders
- **Appeals Process**: Review of convictions and sentences

### Corrections and Rehabilitation
- **Jails**: Short-term detention for pre-trial and misdemeanor sentences
- **Prisons**: Long-term incarceration for felony sentences
- **Probation**: Supervised release in community
- **Parole**: Early release with continued supervision
- **Rehabilitation Programs**: Education, job training, substance abuse treatment
- **Reentry Services**: Transitional support for released inmates
- **Alternative Sentencing**: Community service, house arrest, drug courts
- **Juvenile Detention**: Youth offender facilities and programs

### Crime Metrics
- **Crime Rate**: Crimes per 100,000 population
- **Violent Crime Rate**: Violent crimes per 100,000 population
- **Property Crime Rate**: Property crimes per 100,000 population
- **Clearance Rate**: Percentage of crimes solved by arrest
- **Arrest Rate**: Arrests per 100 crimes reported
- **Conviction Rate**: Convictions per arrest
- **Recidivism Rate**: Percentage of released offenders re-offending
- **Incarceration Rate**: Inmates per 100,000 population
- **Crime Severity Index**: Weighted measure of crime seriousness
- **Victimization Rate**: Percentage of population victimized

## Architecture

### Component Structure

```
CrimeSubsystem
├── CrimeGenerator
│   ├── ViolentCrimeGenerator
│   ├── PropertyCrimeGenerator
│   ├── WhiteCollarCrimeGenerator
│   ├── DrugCrimeGenerator
│   └── OrganizedCrimeSimulator
├── LawEnforcementSystem
│   ├── PoliceStationManager
│   ├── PatrolManager
│   ├── DetectiveUnitManager
│   ├── CrimeLabManager
│   └── SpecializedUnitManager
├── InvestigationSystem
│   ├── CrimeSceneProcessor
│   ├── EvidenceCollector
│   ├── ForensicAnalyzer
│   ├── SuspectIdentifier
│   └── CaseBuilder
├── JusticeSystem
│   ├── CourtManager
│   ├── ProsecutorOffice
│   ├── PublicDefenderOffice
│   ├── TrialProcessor
│   └── SentencingCalculator
├── CorrectionsSystem
│   ├── JailManager
│   ├── PrisonManager
│   ├── ProbationManager
│   ├── ParoleBoard
│   └── InmateTracker
├── RehabilitationSystem
│   ├── EducationProgramManager
│   ├── VocationalTrainingManager
│   ├── SubstanceAbuseTreatment
│   ├── MentalHealthServices
│   └── ReentryServicesCoordinator
├── CrimePreventionSystem
│   ├── CommunityPolicingProgram
│   ├── YouthPreventionPrograms
│   ├── SurveillanceSystemManager
│   ├── NeighborhoodWatchCoordinator
│   └── EnvironmentalDesignPlanner
├── CrimeAnalytics
│   ├── CrimeStatisticsTracker
│   ├── CrimeMappingSystem
│   ├── PredictivePolicing
│   ├── RecidivismPredictor
│   └── ClearanceRateCalculator
└── VictimServices
    ├── VictimSupportCenter
    ├── WitnessProtectionProgram
    └── VictimCompensationFund
```

## Interfaces

### CrimeSubsystem

```python
class CrimeSubsystem(ISubsystem):
    """
    Primary crime subsystem managing all criminal activity and law enforcement.
    """
    
    def __init__(self, settings: CrimeSettings, random_service: RandomService):
        """
        Initialize crime subsystem.
        
        Arguments:
            settings: Configuration for crime system parameters
            random_service: Seeded random number generator for deterministic behavior
        """
        
    def update(self, city: City, context: TickContext) -> CrimeDelta:
        """
        Update crime system for current tick.
        
        Execution order:
        1. Generate new criminal incidents based on city conditions
        2. Process ongoing police investigations
        3. Handle arrests and suspect processing
        4. Process court cases and trials
        5. Update inmate population and releases
        6. Execute rehabilitation programs
        7. Process crime prevention activities
        8. Calculate crime metrics and trends
        9. Apply crime effects to city (safety, economy, happiness)
        10. Process criminal justice budget expenditures
        
        Arguments:
            city: Current city state
            context: Tick context with timing and random services
            
        Returns:
            CrimeDelta containing all crime activities, law enforcement actions, and justice outcomes
        """
        
    def get_crime_rate(self) -> float:
        """Get current crime rate per 100,000 population."""
        
    def get_violent_crime_rate(self) -> float:
        """Get violent crime rate per 100,000 population."""
        
    def get_property_crime_rate(self) -> float:
        """Get property crime rate per 100,000 population."""
        
    def get_clearance_rate(self) -> float:
        """Get percentage of crimes cleared by arrest."""
        
    def get_incarceration_rate(self) -> float:
        """Get inmates per 100,000 population."""
        
    def get_recidivism_rate(self) -> float:
        """Get percentage of released offenders re-offending within 3 years."""
        
    def get_public_safety_index(self) -> float:
        """Get overall public safety score (0-100)."""
```

### CrimeGenerator

```python
class CrimeGenerator:
    """
    Generates criminal incidents based on city conditions and risk factors.
    """
    
    def __init__(self, settings: CrimeGenerationSettings, random_service: RandomService):
        """
        Initialize crime generator.
        
        Arguments:
            settings: Crime generation parameters
            random_service: Seeded RNG for crime generation
        """
        
    def generate_crimes(self, city: City, context: TickContext) -> list[CrimeIncident]:
        """
        Generate new criminal incidents for current tick.
        
        Crime generation factors:
        - Population size and density
        - Unemployment rate and poverty level
        - Education levels (inverse correlation)
        - Drug and alcohol availability
        - Police presence and response times
        - Lighting and environmental design
        - Weather conditions (temperature, precipitation)
        - Time of day/year (seasonal patterns)
        - Gang activity and organized crime presence
        - Economic inequality and social cohesion
        
        Arguments:
            city: Current city state
            context: Tick context
            
        Returns:
            List of generated crime incidents with type, location, and severity
        """
        
    def calculate_crime_risk(self, location: Location, crime_type: CrimeType,
                            city_conditions: CityConditions) -> float:
        """
        Calculate risk probability for specific crime type at location.
        
        Location factors:
        - Neighborhood socioeconomic status
        - Police presence and patrol frequency
        - Lighting and visibility
        - Land use (residential, commercial, industrial)
        - Population density and foot traffic
        - Proximity to high-crime areas
        - Presence of crime attractors (bars, ATMs, etc.)
        
        Returns:
            Crime risk probability (0-1)
        """
        
    def apply_seasonal_patterns(self, base_rate: float, crime_type: CrimeType,
                               season: Season, temperature: float) -> float:
        """
        Adjust crime rate based on seasonal patterns and weather.
        
        Patterns:
        - Violent crime increases in summer heat
        - Property crime increases during holidays
        - Domestic violence peaks during winter holidays
        - Drug crimes relatively stable year-round
        
        Returns:
            Adjusted crime rate
        """
```

### LawEnforcementSystem

```python
class LawEnforcementSystem:
    """
    Manages police operations and law enforcement activities.
    """
    
    def __init__(self, settings: LawEnforcementSettings):
        """
        Initialize law enforcement system.
        
        Arguments:
            settings: Law enforcement configuration
        """
        
    def update_law_enforcement(self, city: City, crimes: list[CrimeIncident],
                              budget: float) -> LawEnforcementDelta:
        """
        Update all law enforcement activities.
        
        Activities:
        - Dispatch patrol units to reported crimes
        - Conduct proactive patrols in high-risk areas
        - Execute criminal investigations
        - Process crime scenes and collect evidence
        - Identify and apprehend suspects
        - Process arrests and book suspects
        - Maintain equipment and facilities
        
        Arguments:
            city: Current city state
            crimes: Crimes requiring law enforcement response
            budget: Available law enforcement budget
            
        Returns:
            LawEnforcementDelta with responses, arrests, investigations, and costs
        """
        
    def calculate_police_effectiveness(self, staffing: PoliceStaffing,
                                      equipment: PoliceEquipment,
                                      training: TrainingLevel) -> float:
        """
        Calculate overall police effectiveness rating.
        
        Factors:
        - Officers per capita ratio
        - Equipment quality and availability
        - Training level and specializations
        - Technology adoption (crime analytics, body cameras, etc.)
        - Community trust and cooperation
        
        Returns:
            Effectiveness rating (0-100)
        """
        
    def dispatch_to_crime(self, crime: CrimeIncident, 
                         available_units: list[PoliceUnit],
                         traffic_conditions: TrafficConditions) -> PoliceResponse:
        """
        Dispatch police units to crime scene.
        
        Dispatch logic:
        1. Prioritize by crime severity and danger
        2. Select nearest available unit(s)
        3. Calculate response time based on distance and traffic
        4. Assign backup units for high-severity crimes
        5. Coordinate with specialized units if needed
        
        Arguments:
            crime: Crime incident requiring response
            available_units: Police units available for dispatch
            traffic_conditions: Current traffic for routing
            
        Returns:
            PoliceResponse with dispatched units and estimated arrival
        """
```

### InvestigationSystem

```python
class InvestigationSystem:
    """
    Manages criminal investigations and evidence processing.
    """
    
    def __init__(self, settings: InvestigationSettings):
        """
        Initialize investigation system.
        
        Arguments:
            settings: Investigation system configuration
        """
        
    def investigate_crime(self, crime: CrimeIncident, detectives: list[Detective],
                         crime_lab: CrimeLab, context: TickContext) -> Investigation:
        """
        Conduct criminal investigation to identify and arrest suspect.
        
        Investigation process:
        1. Crime scene processing and evidence collection
        2. Witness interviews and statements
        3. Forensic analysis (DNA, fingerprints, ballistics, digital)
        4. Suspect identification through evidence and leads
        5. Surveillance and undercover operations
        6. Suspect apprehension and arrest
        7. Case building for prosecution
        
        Investigation success factors:
        - Detective experience and skills
        - Evidence quality and quantity
        - Crime lab capabilities and backlog
        - Witness cooperation
        - Time elapsed since crime
        - Community information and tips
        
        Arguments:
            crime: Crime to investigate
            detectives: Available detective resources
            crime_lab: Forensic capabilities
            context: Tick context
            
        Returns:
            Investigation with status, evidence, suspects, and outcome
        """
        
    def calculate_clearance_probability(self, crime_type: CrimeType,
                                       evidence_quality: float,
                                       detective_skill: float,
                                       time_elapsed: int) -> float:
        """
        Calculate probability of solving crime (clearance).
        
        Base clearance rates (FBI national averages):
        - Homicide: 61.6%
        - Aggravated assault: 52.3%
        - Robbery: 29.7%
        - Burglary: 13.9%
        - Motor vehicle theft: 13.8%
        - Larceny-theft: 18.3%
        
        Modified by:
        - Evidence quality (+/- 20%)
        - Detective skill level (+/- 15%)
        - Time elapsed (decreases with time)
        - Witness cooperation (+/- 10%)
        
        Returns:
            Clearance probability (0-1)
        """
        
    def process_forensic_evidence(self, evidence: Evidence, lab: CrimeLab) -> ForensicResults:
        """
        Process physical evidence through crime lab.
        
        Forensic capabilities:
        - DNA analysis (3-7 days processing)
        - Fingerprint analysis (1-3 days)
        - Ballistics matching (2-5 days)
        - Trace evidence analysis (5-10 days)
        - Digital forensics (7-30 days)
        - Toxicology (5-14 days)
        
        Arguments:
            evidence: Evidence to analyze
            lab: Crime lab with capabilities and backlog
            
        Returns:
            ForensicResults with analysis findings
        """
```

### JusticeSystem

```python
class JusticeSystem:
    """
    Manages courts, prosecution, defense, and judicial processes.
    """
    
    def __init__(self, settings: JusticeSettings):
        """
        Initialize justice system.
        
        Arguments:
            settings: Justice system configuration
        """
        
    def process_criminal_cases(self, arrests: list[Arrest], 
                              courts: list[Court],
                              context: TickContext) -> JusticeDelta:
        """
        Process criminal cases through judicial system.
        
        Case processing stages:
        1. Arraignment and bail hearing
        2. Preliminary hearing or grand jury
        3. Plea bargaining negotiations
        4. Pre-trial motions and discovery
        5. Trial (if no plea agreement)
        6. Verdict and sentencing
        7. Appeals (if filed)
        
        Arguments:
            arrests: Arrested suspects awaiting prosecution
            courts: Available court resources
            context: Tick context
            
        Returns:
            JusticeDelta with case outcomes, convictions, and sentences
        """
        
    def conduct_trial(self, case: CriminalCase, evidence: list[Evidence],
                     jury: Jury) -> TrialOutcome:
        """
        Simulate criminal trial proceedings.
        
        Trial factors affecting verdict:
        - Strength of evidence
        - Prosecutor effectiveness
        - Defense attorney effectiveness
        - Witness credibility
        - Defendant characteristics
        - Jury composition and bias
        
        Conviction probability varies by:
        - Evidence quality: Strong evidence = 85% conviction
        - Medium evidence = 55% conviction
        - Weak evidence = 25% conviction
        
        Arguments:
            case: Criminal case being tried
            evidence: Evidence presented at trial
            jury: Jury deciding the case
            
        Returns:
            TrialOutcome with verdict and reasoning
        """
        
    def determine_sentence(self, conviction: Conviction, 
                          sentencing_guidelines: SentencingGuidelines,
                          defendant_history: CriminalHistory) -> Sentence:
        """
        Determine sentence for convicted offender.
        
        Sentencing factors:
        - Crime severity and type
        - Sentencing guidelines and mandatory minimums
        - Defendant criminal history
        - Aggravating circumstances
        - Mitigating circumstances
        - Victim impact statements
        - Plea agreement terms
        
        Sentence types:
        - Incarceration (jail or prison)
        - Probation
        - Fines and restitution
        - Community service
        - Treatment programs
        - Combination of above
        
        Arguments:
            conviction: Conviction details
            sentencing_guidelines: Applicable sentencing rules
            defendant_history: Prior criminal record
            
        Returns:
            Sentence with type, duration, and conditions
        """
```

### CorrectionsSystem

```python
class CorrectionsSystem:
    """
    Manages jails, prisons, probation, parole, and inmate populations.
    """
    
    def __init__(self, settings: CorrectionsSettings):
        """
        Initialize corrections system.
        
        Arguments:
            settings: Corrections system configuration
        """
        
    def update_corrections(self, city: City, new_sentences: list[Sentence],
                          budget: float) -> CorrectionsDelta:
        """
        Update correctional facilities and supervised populations.
        
        Operations:
        - Process new inmate admissions
        - Manage inmate populations and security
        - Execute rehabilitation programs
        - Process inmate releases and discharges
        - Supervise probationers and parolees
        - Handle parole hearings and decisions
        - Track violations and revocations
        - Monitor facility capacity and overcrowding
        
        Arguments:
            city: Current city state
            new_sentences: Newly sentenced offenders
            budget: Corrections budget
            
        Returns:
            CorrectionsDelta with population changes, costs, and program outcomes
        """
        
    def calculate_recidivism_risk(self, inmate: Inmate, 
                                 programs_completed: list[Program],
                                 release_plan: ReleasePlan) -> float:
        """
        Calculate recidivism risk for inmate being released.
        
        Risk factors (increasing recidivism):
        - Young age at release
        - Prior criminal history
        - Gang affiliation
        - Substance abuse history
        - Lack of education/job skills
        - Inadequate housing plan
        - Weak family/social support
        
        Protective factors (reducing recidivism):
        - Completed education programs
        - Vocational training
        - Substance abuse treatment
        - Employment lined up
        - Stable housing arranged
        - Family support
        
        National baseline: ~44% recidivism within 1 year
        
        Returns:
            Recidivism risk probability (0-1)
        """
        
    def manage_prison_capacity(self, inmate_population: int, capacity: int,
                              admission_rate: float) -> CapacityManagement:
        """
        Manage prison capacity and overcrowding.
        
        Overcrowding effects (>100% capacity):
        - Increased violence and security incidents
        - Reduced program availability
        - Higher operating costs per inmate
        - Constitutional issues if extreme
        
        Capacity management strategies:
        - Parole board accelerated reviews
        - Good time credit programs
        - Alternative sentencing expansion
        - Prison construction (long-term, expensive)
        - Sentencing reform advocacy
        
        Arguments:
            inmate_population: Current inmate count
            capacity: Rated facility capacity
            admission_rate: Rate of new admissions
            
        Returns:
            CapacityManagement with strategies and projections
        """
```

### RehabilitationSystem

```python
class RehabilitationSystem:
    """
    Manages rehabilitation programs for offenders.
    """
    
    def __init__(self, settings: RehabilitationSettings):
        """
        Initialize rehabilitation system.
        
        Arguments:
            settings: Rehabilitation program configuration
        """
        
    def provide_rehabilitation(self, participants: list[Offender],
                              programs: list[Program],
                              funding: float) -> RehabilitationDelta:
        """
        Provide rehabilitation services to offenders.
        
        Program types:
        - Education (GED, literacy, college)
        - Vocational training (trade skills)
        - Substance abuse treatment (counseling, medication)
        - Mental health services (therapy, medication)
        - Cognitive behavioral therapy
        - Anger management
        - Parenting classes
        - Life skills training
        - Job readiness and placement
        - Housing assistance
        
        Arguments:
            participants: Offenders enrolled in programs
            programs: Available rehabilitation programs
            funding: Program funding
            
        Returns:
            RehabilitationDelta with completion rates and recidivism reduction
        """
        
    def calculate_program_effectiveness(self, program: Program,
                                       completion_rate: float,
                                       recidivism_reduction: float) -> float:
        """
        Calculate cost-effectiveness of rehabilitation program.
        
        Effectiveness metrics:
        - Recidivism reduction percentage
        - Employment rate post-release
        - Program completion rate
        - Cost per participant
        - Cost savings from avoided recidivism
        
        Evidence-based programs:
        - Cognitive behavioral therapy: 25% recidivism reduction
        - Vocational training: 13% reduction
        - Drug treatment in prison: 13% reduction
        - Education programs: 13% reduction
        
        Returns:
            Effectiveness score (0-100)
        """
```

### CrimePreventionSystem

```python
class CrimePreventionSystem:
    """
    Manages crime prevention programs and initiatives.
    """
    
    def __init__(self, settings: CrimePreventionSettings):
        """
        Initialize crime prevention system.
        
        Arguments:
            settings: Crime prevention configuration
        """
        
    def implement_prevention_programs(self, city: City, 
                                     at_risk_population: Population,
                                     budget: float) -> PreventionDelta:
        """
        Implement crime prevention initiatives.
        
        Prevention programs:
        - After-school youth programs
        - Mentorship and tutoring
        - Job training for at-risk youth
        - Community policing initiatives
        - Neighborhood watch programs
        - Business improvement districts
        - Environmental design improvements
        - Surveillance system deployment
        - Lighting upgrades
        - Gang intervention programs
        - Conflict resolution training
        
        Arguments:
            city: Current city state
            at_risk_population: Population at risk for criminal involvement
            budget: Prevention program funding
            
        Returns:
            PreventionDelta with participation and crime reduction impacts
        """
        
    def calculate_prevention_effectiveness(self, program: PreventionProgram,
                                          target_population: int,
                                          participation_rate: float) -> float:
        """
        Calculate crime reduction from prevention program.
        
        Evidence-based effectiveness:
        - After-school programs: 20% reduction in juvenile crime
        - Mentorship programs: 46% reduction in first-time drug use
        - Job training: 25% reduction in recidivism
        - Hot spot policing: 16% crime reduction in targeted areas
        - Improved lighting: 7% reduction in nighttime crime
        - CCTV surveillance: 16% reduction in property crime
        
        Returns:
            Crime reduction percentage for target population
        """
        
    def identify_crime_hot_spots(self, crime_history: list[CrimeIncident],
                                geographic_data: GeographicData) -> list[HotSpot]:
        """
        Identify geographic areas with concentrated crime for intervention.
        
        Hot spot analysis:
        - Kernel density estimation of crime locations
        - Statistical significance testing
        - Temporal pattern analysis (time of day, day of week)
        - Crime type concentration
        - Repeat victimization locations
        
        Arguments:
            crime_history: Historical crime data
            geographic_data: City geography and land use
            
        Returns:
            List of crime hot spots prioritized for intervention
        """
```

## Data Structures

### CrimeIncident

```python
@dataclass
class CrimeIncident:
    """Represents a single criminal incident."""
    
    incident_id: str
    incident_type: CrimeType
    crime_category: CrimeCategory                # Violent, Property, Drug, etc.
    
    # Location and time
    location: Location
    district: str                                # Police district/precinct
    occurred_at: int                             # Tick when crime occurred
    reported_at: int                             # Tick when crime reported
    
    # Severity
    severity: CrimeSeverity                      # Misdemeanor, Felony, Capital
    severity_score: float                        # 0-100
    involves_weapon: bool
    involves_violence: bool
    
    # Parties involved
    victim_id: Optional[str]                     # Citizen ID if applicable
    suspect_id: Optional[str]                    # If known at time of crime
    witnesses: list[str]                         # Witness citizen IDs
    
    # Damage and loss
    property_damage_value: float
    property_stolen_value: float
    injuries: int                                # Number of people injured
    fatalities: int                              # Number of people killed
    
    # Investigation
    evidence_quality: float                      # 0-100
    has_physical_evidence: bool
    has_witnesses: bool
    has_surveillance_footage: bool
    
    # Status
    status: IncidentStatus                       # Reported, Investigating, Cleared, Unfounded
    assigned_detective: Optional[str]
    case_number: Optional[str]
    
    # Outcome
    arrest_made: bool
    arrest_date: Optional[int]
    cleared_by_arrest: bool
    cleared_exceptionally: bool                  # Death of offender, prosecution declined, etc.
```

### CrimeType

```python
class CrimeType(Enum):
    """Specific types of criminal offenses."""
    
    # Violent crimes
    HOMICIDE = "homicide"
    AGGRAVATED_ASSAULT = "aggravated_assault"
    SIMPLE_ASSAULT = "simple_assault"
    ROBBERY = "robbery"
    SEXUAL_ASSAULT = "sexual_assault"
    DOMESTIC_VIOLENCE = "domestic_violence"
    KIDNAPPING = "kidnapping"
    
    # Property crimes
    BURGLARY = "burglary"
    LARCENY_THEFT = "larceny_theft"
    MOTOR_VEHICLE_THEFT = "motor_vehicle_theft"
    ARSON = "arson"
    VANDALISM = "vandalism"
    TRESPASSING = "trespassing"
    SHOPLIFTING = "shoplifting"
    
    # Drug crimes
    DRUG_POSSESSION = "drug_possession"
    DRUG_TRAFFICKING = "drug_trafficking"
    DRUG_MANUFACTURING = "drug_manufacturing"
    
    # White collar crimes
    FRAUD = "fraud"
    EMBEZZLEMENT = "embezzlement"
    IDENTITY_THEFT = "identity_theft"
    FORGERY = "forgery"
    MONEY_LAUNDERING = "money_laundering"
    
    # Public order crimes
    DISORDERLY_CONDUCT = "disorderly_conduct"
    PUBLIC_INTOXICATION = "public_intoxication"
    PROSTITUTION = "prostitution"
    ILLEGAL_GAMBLING = "illegal_gambling"
    WEAPONS_VIOLATION = "weapons_violation"
    
    # Traffic crimes
    DUI_DWI = "dui_dwi"
    RECKLESS_DRIVING = "reckless_driving"
    HIT_AND_RUN = "hit_and_run"
    VEHICULAR_HOMICIDE = "vehicular_homicide"
    
    # Organized crime
    GANG_VIOLENCE = "gang_violence"
    RACKETEERING = "racketeering"
    HUMAN_TRAFFICKING = "human_trafficking"
    
    # Cybercrime
    HACKING = "hacking"
    CYBERSTALKING = "cyberstalking"
    RANSOMWARE = "ransomware"
    ONLINE_FRAUD = "online_fraud"
```

### PoliceStation

```python
@dataclass
class PoliceStation:
    """Police facility providing law enforcement services."""
    
    station_id: str
    name: str
    location: Location
    precinct_number: int
    
    # Coverage
    service_area_square_miles: float
    population_served: int
    
    # Staffing
    sworn_officers: int                          # Uniformed police officers
    detectives: int                              # Criminal investigators
    civilian_staff: int                          # Administrative support
    patrol_officers_on_duty: int                 # Currently on patrol
    
    # Specializations
    has_detective_unit: bool
    has_gang_unit: bool
    has_narcotics_unit: bool
    has_cybercrime_unit: bool
    has_k9_unit: bool
    has_swat_team: bool
    
    # Resources
    patrol_vehicles: int
    motorcycles: int
    bicycles: int
    police_dogs: int
    body_cameras: int
    in_car_cameras: int
    
    # Facilities
    holding_cells: int
    interview_rooms: int
    has_evidence_storage: bool
    has_crime_lab: bool
    has_training_facility: bool
    has_shooting_range: bool
    
    # Performance
    average_response_time_minutes: float
    crimes_reported_monthly: int
    arrests_monthly: int
    clearance_rate: float                        # Percentage of crimes cleared
    
    # Budget
    annual_operating_budget: float
    budget_per_capita: float
    
    def get_officers_per_capita(self) -> float:
        """Calculate officers per 1,000 residents."""
        
    def get_patrol_coverage(self) -> float:
        """Calculate patrol coverage percentage of service area."""
```

### Investigation

```python
@dataclass
class Investigation:
    """Criminal investigation case."""
    
    investigation_id: str
    crime_incident: CrimeIncident
    case_number: str
    
    # Assignment
    lead_detective: Detective
    assisting_detectives: list[Detective]
    assigned_date: int
    
    # Status
    status: InvestigationStatus                  # Active, Cold, Cleared, Closed
    priority: InvestigationPriority              # High, Medium, Low
    
    # Evidence
    evidence_collected: list[Evidence]
    forensic_results: list[ForensicResults]
    witness_statements: list[WitnessStatement]
    
    # Leads and suspects
    leads_pursued: int
    suspects_identified: list[Suspect]
    primary_suspect: Optional[Suspect]
    
    # Progress
    hours_invested: float
    percentage_complete: float                   # Estimated completion
    
    # Outcome
    cleared: bool
    arrest_made: bool
    arrest_date: Optional[int]
    submitted_to_prosecutor: bool
    prosecution_declined: bool
    reason_declined: Optional[str]
```

### Offender

```python
@dataclass
class Offender:
    """Individual who has committed crime."""
    
    offender_id: str
    citizen_id: str                              # Link to population
    
    # Demographics
    age: int
    sex: str
    race_ethnicity: str
    education_level: EducationLevel
    
    # Criminal history
    prior_arrests: int
    prior_convictions: int
    prior_incarcerations: int
    juvenile_record: bool
    gang_affiliation: Optional[str]
    
    # Current status
    status: OffenderStatus                       # At large, Arrested, In custody, Incarcerated, Supervised
    current_charges: list[CrimeType]
    current_convictions: list[Conviction]
    
    # Risk factors
    substance_abuse: bool
    mental_illness: bool
    unemployment: bool
    homelessness: bool
    prior_violence: bool
    
    # Sentence
    current_sentence: Optional[Sentence]
    incarceration_start_date: Optional[int]
    expected_release_date: Optional[int]
    
    # Rehabilitation
    programs_enrolled: list[Program]
    programs_completed: list[Program]
    
    # Supervision
    on_probation: bool
    on_parole: bool
    supervision_officer: Optional[str]
    
    # Recidivism
    recidivism_risk_score: float                 # 0-100
    has_recidivated: bool
    time_to_recidivism_days: Optional[int]
```

### Prison

```python
@dataclass
class Prison:
    """Correctional facility for incarcerated offenders."""
    
    facility_id: str
    name: str
    location: Location
    facility_type: PrisonType                    # Jail, Minimum, Medium, Maximum, Supermax
    
    # Capacity
    rated_capacity: int                          # Design capacity
    operational_capacity: int                    # Safe operating capacity
    current_population: int
    
    # Population breakdown
    pretrial_detainees: int                      # Awaiting trial
    sentenced_inmates: int
    male_inmates: int
    female_inmates: int
    juvenile_inmates: int
    
    # Security
    security_level: SecurityLevel                # Minimum, Medium, Maximum
    correctional_officers: int
    inmate_to_officer_ratio: float
    security_incidents_monthly: int
    
    # Programs
    has_education_programs: bool
    has_vocational_training: bool
    has_substance_abuse_treatment: bool
    has_mental_health_services: bool
    has_work_release_program: bool
    
    # Facilities
    has_infirmary: bool
    has_library: bool
    has_recreation_yard: bool
    has_visitation_center: bool
    has_chapel: bool
    
    # Operations
    annual_operating_budget: float
    cost_per_inmate_daily: float
    staff_count: int
    
    # Performance
    recidivism_rate: float                       # For releases from this facility
    program_participation_rate: float
    violence_rate: float                         # Incidents per 1000 inmates
    
    def get_overcrowding_percentage(self) -> float:
        """Calculate percentage over/under capacity."""
        
    def get_capacity_utilization(self) -> float:
        """Calculate percentage of capacity in use."""
```

### CrimeDelta

```python
@dataclass
class CrimeDelta:
    """Summary of crime system changes during a tick."""
    
    # Crime incidents
    new_crimes_total: int
    new_crimes_by_type: dict[CrimeType, int]
    violent_crimes: int
    property_crimes: int
    drug_crimes: int
    white_collar_crimes: int
    
    # Victimization
    victims_total: int
    injuries: int
    fatalities: int
    property_damage_total: float
    property_stolen_total: float
    
    # Law enforcement
    police_responses: int
    average_police_response_time_minutes: float
    arrests_made: int
    arrests_by_crime_type: dict[CrimeType, int]
    
    # Investigations
    investigations_opened: int
    investigations_closed: int
    crimes_cleared_by_arrest: int
    clearance_rate: float
    
    # Justice
    cases_filed: int
    trials_completed: int
    convictions: int
    acquittals: int
    plea_bargains: int
    
    # Corrections
    new_incarcerations: int
    inmate_population_change: int
    current_inmate_population: int
    prison_capacity_utilization: float
    inmates_released: int
    
    # Rehabilitation
    program_enrollments: int
    program_completions: int
    inmates_educated: int
    inmates_trained_vocational: int
    
    # Prevention
    prevention_program_participants: int
    youth_program_participants: int
    surveillance_systems_deployed: int
    
    # Recidivism
    released_offenders_recidivating: int
    recidivism_rate: float
    
    # Metrics
    crime_rate_per_100k: float
    violent_crime_rate_per_100k: float
    property_crime_rate_per_100k: float
    incarceration_rate_per_100k: float
    public_safety_index: float                   # Overall safety score 0-100
    
    # Economic impact
    crime_economic_cost: float                   # Property loss, medical, productivity
    law_enforcement_spending: float
    judicial_system_spending: float
    corrections_spending: float
    prevention_program_spending: float
    
    # Social effects
    population_fear_level: float                 # Public fear of crime 0-100
    police_trust_level: float                    # Community trust in police 0-100
    happiness_impact_from_crime: float           # Negative impact on happiness
    tourism_impact: float                        # Crime impact on tourism revenue
```

## Configuration

### CrimeSettings

```python
@dataclass
class CrimeSettings:
    """Configuration for crime subsystem."""
    
    # Crime generation
    base_crime_rate_per_100k: float              # Baseline crime rate
    violent_crime_percentage: float              # Percentage of crimes that are violent
    property_crime_percentage: float
    drug_crime_percentage: float
    crime_rate_multiplier_unemployment: float    # Crime increase per % unemployment
    crime_rate_multiplier_poverty: float         # Crime increase per % poverty
    crime_rate_reduction_education: float        # Crime decrease per education level
    seasonal_variation_enabled: bool
    
    # Law enforcement
    target_officers_per_1000: float              # Target police staffing ratio
    police_response_time_target_minutes: float   # Target response time
    patrol_coverage_target: float                # Target patrol coverage percentage
    detective_to_officer_ratio: float            # Detectives as percentage of officers
    average_officer_salary: float
    
    # Investigation
    base_clearance_rate_violent: float           # Base clearance for violent crimes
    base_clearance_rate_property: float          # Base clearance for property crimes
    crime_lab_processing_time_days: int          # Average forensic processing time
    investigation_hours_per_case: float
    cold_case_threshold_days: int                # Days before case goes cold
    
    # Justice system
    prosecution_rate: float                      # Percentage of arrests prosecuted
    conviction_rate: float                       # Percentage of prosecutions convicted
    plea_bargain_rate: float                     # Percentage resolved by plea
    average_trial_duration_days: int
    average_case_backlog_months: float
    
    # Sentencing
    average_sentence_violent_months: int
    average_sentence_property_months: int
    average_sentence_drug_months: int
    mandatory_minimum_enabled: bool
    three_strikes_law_enabled: bool
    alternative_sentencing_enabled: bool
    
    # Corrections
    prison_capacity_per_100k: int                # Prison beds per 100k population
    jail_capacity_per_100k: int                  # Jail beds per 100k population
    cost_per_inmate_daily: float
    good_time_credit_enabled: bool               # Early release for good behavior
    overcrowding_threshold: float                # Percentage triggering concerns
    
    # Rehabilitation
    education_program_availability: float        # 0-1 scale of program access
    vocational_training_availability: float
    substance_abuse_treatment_availability: float
    mental_health_services_availability: float
    program_completion_bonus_days: int           # Sentence reduction for completion
    
    # Recidivism
    baseline_recidivism_rate: float              # Base rate of re-offense
    recidivism_reduction_education: float        # Reduction from education programs
    recidivism_reduction_job_training: float
    recidivism_reduction_treatment: float
    recidivism_measurement_period_months: int    # Time window for measuring (typically 36)
    
    # Crime prevention
    prevention_budget_percentage: float          # Percentage of law enforcement budget
    youth_program_effectiveness: float           # Crime reduction percentage
    community_policing_enabled: bool
    hot_spot_policing_enabled: bool
    surveillance_system_enabled: bool
    
    # Effects
    crime_impact_on_happiness: float             # Happiness reduction per crime
    crime_impact_on_property_values: float       # Property value reduction
    crime_impact_on_business: float              # Business investment reduction
    crime_impact_on_tourism: float               # Tourism reduction
```

## Behavioral Specifications

### Crime Generation Model

1. **Base Crime Rate**: 
   - Start with city-specific baseline (e.g., 3,500 per 100,000 population)
   - Varies by city size, region, and initial conditions

2. **Risk Factor Adjustments**:
   ```
   adjusted_rate = base_rate × (1 + unemployment_factor + poverty_factor + 
                                  inequality_factor - education_factor - 
                                  police_presence_factor)
   ```

3. **Crime Type Distribution**:
   - Property crimes: ~70% of total crimes (burglary, theft, vehicle theft)
   - Violent crimes: ~10% of total crimes (homicide, assault, robbery)
   - Drug crimes: ~15% of total crimes
   - Other: ~5% (white collar, public order, etc.)

4. **Temporal Patterns**:
   - Violent crime peaks in summer (temperature correlation)
   - Property crime increases during holidays
   - Time of day patterns: Crime peaks 6pm-midnight

5. **Geographic Concentration**:
   - 50% of crimes occur in 5% of locations (hot spots)
   - High-crime areas cluster near poverty, unemployment, low education

### Clearance Rate Model

1. **Base Clearance Rates** (FBI national averages):
   - Homicide: 61.6%
   - Aggravated assault: 52.3%
   - Rape: 32.9%
   - Robbery: 29.7%
   - Burglary: 13.9%
   - Larceny-theft: 18.3%
   - Motor vehicle theft: 13.8%

2. **Modifying Factors**:
   - Evidence quality: +/- 20%
   - Detective skill and experience: +/- 15%
   - Crime lab capability: +/- 10%
   - Response time: -5% per hour delay
   - Witness cooperation: +/- 10%
   - Surveillance footage: +15%

3. **Time Decay**: Clearance probability decreases over time
   - First 48 hours: Maximum probability
   - After 30 days: -25% probability
   - After 90 days: -50% probability (cold case)

### Sentencing Model

1. **Factors**:
   - Crime severity (misdemeanor vs felony)
   - Prior criminal history
   - Sentencing guidelines/mandatory minimums
   - Aggravating factors (weapon use, victim vulnerability)
   - Mitigating factors (cooperation, remorse)

2. **Typical Sentences**:
   - Misdemeanors: 0-12 months jail, probation, fines
   - Low-level felonies: 1-5 years prison
   - Mid-level felonies: 5-20 years prison
   - Serious violent felonies: 20 years to life
   - Capital crimes: Life without parole or death penalty (if applicable)

### Recidivism Model

1. **Baseline Recidivism Rates**:
   - 1-year: 44% (national average)
   - 3-year: 68%
   - 5-year: 77%

2. **Risk Factors** (increase recidivism):
   - Age at release: Younger = higher risk
   - Prior criminal history: More priors = higher risk
   - Gang affiliation: +20%
   - Substance abuse: +15%
   - No high school diploma: +12%
   - Unemployment: +10%
   - Homelessness: +15%

3. **Protective Factors** (decrease recidivism):
   - Completed education program: -13%
   - Completed vocational training: -13%
   - Substance abuse treatment: -13%
   - Stable housing: -10%
   - Employment: -15%
   - Family support: -8%

## Integration with Other Subsystems

### Emergency Services
- **Police Coordination**: Crime subsystem generates incidents; Emergency Services responds
- **Shared Resources**: Police stations and patrol units coordinated
- **Data Sharing**: Crime statistics inform emergency service deployment
- **Joint Operations**: SWAT, hazmat, and disaster response coordination

### Population Subsystem
- **Victimization**: Crime directly affects citizens, causing injury, death, or property loss
- **Fear of Crime**: High crime reduces happiness and quality of life
- **Criminal Population**: Track offenders within total population
- **Migration**: High crime rates drive out-migration, deter in-migration
- **Demographics**: Age, education, employment affect crime propensity

### Education Subsystem
- **Crime Prevention**: Higher education levels reduce crime rates
- **Youth Programs**: After-school programs reduce juvenile delinquency
- **Dropout Link**: High school dropouts at elevated crime risk
- **Prison Education**: GED and college programs reduce recidivism
- **Early Childhood**: Quality early education reduces future criminal behavior

### Healthcare Subsystem
- **Substance Abuse**: Drug addiction drives property and drug crimes
- **Mental Health**: Untreated mental illness correlates with crime
- **Treatment Programs**: Addiction treatment reduces crime
- **Injury Care**: Violent crime victims require medical treatment
- **Prisoner Health**: Inmate healthcare needs

### Finance Subsystem
- **Criminal Justice Budget**: Major expenditure (police, courts, prisons)
  - Law enforcement: 40-50% of criminal justice budget
  - Corrections: 30-40%
  - Judicial: 10-20%
- **Economic Costs**: Property loss, medical costs, productivity loss
- **Property Values**: Crime reduces real estate values
- **Business Impact**: Crime deters investment and reduces revenue
- **Tax Revenue**: Incarceration removes workers from tax base

### Employment Subsystem
- **Unemployment-Crime Link**: Unemployment increases property crime
- **Job Training**: Reduces recidivism for released offenders
- **Criminal Record**: Limits employment opportunities
- **Lost Productivity**: Incarceration removes workers from economy
- **Reentry Employment**: Job placement critical for reducing recidivism

### Transportation Subsystem
- **Traffic Crimes**: DUI, reckless driving, hit-and-run
- **Response Times**: Traffic conditions affect police response
- **Crime Locations**: Transit stations can be crime hot spots
- **Vehicle Theft**: Auto theft impacts transportation

### Environment Subsystem
- **Lighting**: Better street lighting reduces nighttime crime
- **Design**: CPTED principles (sight lines, territoriality) reduce crime
- **Abandoned Buildings**: Blight attracts criminal activity
- **Parks and Recreation**: Well-maintained spaces reduce crime

## Metrics and Logging

### Per-Tick Metrics

```python
{
    "tick_index": int,
    "timestamp": str,
    
    # Crime volume
    "crimes_total": int,
    "violent_crimes": int,
    "property_crimes": int,
    "drug_crimes": int,
    "white_collar_crimes": int,
    
    # Crime rates
    "crime_rate_per_100k": float,
    "violent_crime_rate_per_100k": float,
    "property_crime_rate_per_100k": float,
    "homicide_rate_per_100k": float,
    
    # Law enforcement
    "sworn_officers": int,
    "officers_per_1000_population": float,
    "police_responses": int,
    "average_response_time_minutes": float,
    "patrol_coverage_percentage": float,
    
    # Investigation
    "arrests_total": int,
    "crimes_cleared": int,
    "clearance_rate": float,
    "active_investigations": int,
    "cold_cases": int,
    
    # Justice
    "cases_prosecuted": int,
    "convictions": int,
    "conviction_rate": float,
    "average_case_duration_days": float,
    "court_case_backlog": int,
    
    # Corrections
    "inmate_population_total": int,
    "incarceration_rate_per_100k": float,
    "jail_population": int,
    "prison_population": int,
    "prison_capacity_utilization_percentage": float,
    "inmates_in_programs": int,
    
    # Releases and recidivism
    "inmates_released": int,
    "recidivists": int,
    "recidivism_rate_3year": float,
    
    # Prevention
    "prevention_program_participants": int,
    "youth_programs_participants": int,
    "surveillance_cameras_active": int,
    
    # Economic impact
    "property_loss_total": float,
    "crime_economic_cost_total": float,
    "law_enforcement_spending": float,
    "corrections_spending": float,
    
    # Public safety
    "public_safety_index": float,
    "population_fear_of_crime": float,
    "police_community_trust": float,
    
    # Victimization
    "victims_total": int,
    "injuries_from_crime": int,
    "deaths_from_crime": int
}
```

## Testing Strategy

### Unit Tests
1. Crime generation produces rates within expected ranges
2. Clearance probability calculations respect evidence and detective quality
3. Sentence determinations follow sentencing guidelines
4. Recidivism risk calculations incorporate all factors correctly
5. Prison capacity utilization calculated accurately
6. Crime rate calculations per 100,000 population are correct

### Integration Tests
1. Generated crimes trigger police responses from Emergency Services
2. Arrested offenders properly flow through justice system to corrections
3. Education level increases reduce crime generation rates
4. Substance abuse treatment reduces drug crime recidivism
5. Crime spending properly deducted from Finance budget
6. High crime reduces Population happiness and increases out-migration
7. Unemployment increases property crime rates
8. Prison education programs reduce recidivism in released offenders

### Determinism Tests
1. Same seed produces identical crime incidents
2. Investigation outcomes reproducible with same conditions
3. Sentencing decisions deterministic given same factors
4. Recidivism events reproducible across runs

### Performance Tests
1. Crime generation scales efficiently with population size
2. Investigation processing performant for many concurrent cases
3. Prison population updates efficient for large inmate populations
4. Crime analytics calculations efficient for historical data

## Future Enhancements

1. **Individual Offender Tracking**: Track full criminal histories and rehabilitation progress
2. **Gang Systems**: Gangs with territories, rivalries, and organized crime operations
3. **Corruption**: Police misconduct, judicial corruption, political interference
4. **Private Prisons**: Private corrections facilities with profit incentives
5. **Restorative Justice**: Victim-offender mediation and community-based justice
6. **Drug Legalization**: Policy levers to legalize certain drugs, affecting crime
7. **Police Reform**: Body cameras, use-of-force policies, civilian oversight
8. **Predictive Policing**: AI-driven crime prediction and resource allocation
9. **Organized Crime Networks**: Complex criminal organizations with hierarchies
10. **Cybercrime Task Forces**: Specialized units for digital crime investigation
11. **Forensic Technology**: DNA databases, facial recognition, gunshot detection
12. **Mental Health Diversion**: Pre-arrest diversion to treatment instead of jail
13. **Bail Reform**: Risk-based release vs. cash bail systems
14. **Sentencing Reform**: Policy changes to sentencing guidelines and mandatory minimums
15. **Victim Services**: Comprehensive victim support, compensation, and advocacy

## Implementation Notes

### Python 3.13+ Features
- Use free-threaded mode for parallel crime generation across districts
- Employ structural pattern matching for crime type routing
- Leverage improved error messages for debugging complex crime scenarios
- Use dataclasses for all crime, offender, and facility representations

### Determinism Requirements
- All crime generation must use seeded RandomService
- Investigation outcomes determined by evidence + RNG seed
- Sentencing decisions must be reproducible
- Recidivism events seeded for consistency

### Performance Considerations
- Cache crime hot spot analysis (expensive computation)
- Use spatial indexing for geographic crime queries
- Batch process investigations and court cases
- Pre-calculate crime risk factors per district

### State Management
- Track all active investigations with unique IDs
- Maintain offender registry across arrests/releases
- Keep historical crime data for trend analysis
- Log all criminal justice system transitions

## References

### Real-World Crime Statistics
- **FBI Uniform Crime Report (UCR)**: National crime statistics and trends
- **Bureau of Justice Statistics**: Criminal justice system data
- **National Crime Victimization Survey (NCVS)**: Victimization rates
- **NIBRS (National Incident-Based Reporting System)**: Detailed incident data

### Criminology Research
- **Routine Activity Theory**: Crime occurs when motivated offender meets suitable target without guardian
- **Broken Windows Theory**: Visible disorder encourages further crime
- **Social Disorganization Theory**: Community structure affects crime rates
- **Strain Theory**: Economic pressure increases property crime

### Policing Methods
- **CompStat**: Data-driven police management
- **Hot Spot Policing**: Concentrated patrols in high-crime areas
- **Problem-Oriented Policing**: Addressing underlying crime causes
- **Community Policing**: Partnership between police and community

### Evidence-Based Practices
- **What Works in Reducing Recidivism**: Meta-analyses of program effectiveness
- **Cost-Benefit Analysis of Crime Prevention**: Economic evaluation of programs
- **Sentencing Guidelines Research**: Effectiveness of sentencing policies
- **Rehabilitation Program Evaluations**: Evidence base for correctional programs

## Related Specifications

- [Emergency Services](emergency_services.md) - Police response and law enforcement coordination
- [Population](population.md) - Demographics, victimization, and crime propensity factors
- [Education](education.md) - Education's role in crime prevention and rehabilitation
- [Healthcare](healthcare.md) - Substance abuse treatment and mental health services
- [Finance](finance.md) - Criminal justice budgeting and economic impacts
