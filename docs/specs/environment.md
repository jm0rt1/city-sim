# Specification: Environment and Climate System

## Purpose
Define the comprehensive environmental and climate simulation subsystem for City-Sim, including weather patterns, seasonal changes, natural disasters, air quality, and environmental impacts on city operations and citizen wellbeing.

## Overview

The Environment and Climate System simulates natural phenomena and their effects on the city. This subsystem operates deterministically, using seeded random number generation to produce predictable weather patterns and events that affect infrastructure, population happiness, economic activity, and resource consumption.

## Core Concepts

### Weather System
- **Temperature**: Daily temperature variations affecting energy consumption, health, and citizen comfort
- **Precipitation**: Rain and snow affecting traffic, construction, water supply, and citizen mood
- **Wind**: Wind speed and direction affecting air quality, energy generation (wind turbines), and citizen comfort
- **Cloud Cover**: Affects solar energy generation and citizen mood
- **Humidity**: Affects citizen comfort and health outcomes
- **Atmospheric Pressure**: Influences weather predictions and patterns

### Seasonal Cycles
- **Spring**: Moderate temperatures, increased rainfall, population growth season
- **Summer**: High temperatures, peak tourism, increased electricity demand for cooling
- **Autumn**: Cooling temperatures, harvest period, moderate resource consumption
- **Winter**: Low temperatures, snow management needs, increased heating demand, reduced construction activity

### Natural Disasters
- **Earthquakes**: Structural damage to buildings and infrastructure, temporary service disruptions
- **Floods**: Water damage, traffic disruptions, health hazards, temporary displacement
- **Tornadoes**: Localized severe damage, emergency response activation
- **Hurricanes**: Widespread damage, extended service disruptions, evacuation needs
- **Wildfires**: Air quality degradation, property damage, evacuation requirements
- **Blizzards**: Transportation paralysis, power grid stress, heating demand spikes
- **Heatwaves**: Health emergencies, cooling demand spikes, infrastructure stress
- **Droughts**: Water supply shortages, agricultural impacts, fire risk elevation

### Air Quality
- **Pollutants**: Carbon monoxide, nitrogen dioxide, sulfur dioxide, particulate matter, ozone
- **Sources**: Vehicle emissions, industrial activity, power generation, construction
- **Health Effects**: Respiratory issues, reduced life expectancy, increased healthcare costs
- **Mitigation**: Emission standards, green spaces, public transit adoption, renewable energy

### Environmental Sustainability
- **Carbon Footprint**: Total city emissions from all sources
- **Green Space Coverage**: Parks, forests, green belts affecting air quality and happiness
- **Water Conservation**: Sustainable water usage and recycling programs
- **Waste Management**: Recycling rates, landfill usage, waste-to-energy programs
- **Renewable Energy Adoption**: Solar, wind, hydro, geothermal energy percentage

## Architecture

### Component Structure

```
EnvironmentSubsystem
├── WeatherSimulator
│   ├── TemperatureModel
│   ├── PrecipitationModel
│   ├── WindModel
│   └── AtmosphericModel
├── SeasonalCycleManager
│   ├── SeasonTransitions
│   └── SeasonalEffects
├── DisasterManager
│   ├── DisasterProbabilityCalculator
│   ├── DisasterSimulator
│   └── DisasterImpactAssessor
├── AirQualityMonitor
│   ├── PollutionCalculator
│   ├── EmissionTracker
│   └── HealthImpactModel
└── SustainabilityTracker
    ├── CarbonFootprintCalculator
    ├── GreenSpaceManager
    └── ResourceEfficiencyMonitor
```

## Interfaces

### EnvironmentSubsystem

```python
class EnvironmentSubsystem(ISubsystem):
    """
    Primary environment and climate simulation subsystem.
    """
    
    def __init__(self, settings: EnvironmentSettings, random_service: RandomService):
        """
        Initialize environment subsystem.
        
        Arguments:
            settings: Configuration for weather patterns, disaster probabilities, pollution factors
            random_service: Seeded random number generator for deterministic behavior
        """
        
    def update(self, city: City, context: TickContext) -> EnvironmentDelta:
        """
        Update environmental conditions for current tick.
        
        Execution order:
        1. Update seasonal position and transitions
        2. Generate weather conditions for current tick
        3. Evaluate disaster probabilities and trigger events
        4. Calculate air quality based on city activity
        5. Update sustainability metrics
        6. Apply environmental effects to city systems
        
        Arguments:
            city: Current city state (read for activity levels, write for environmental effects)
            context: Tick context with timing and random services
            
        Returns:
            EnvironmentDelta containing all environmental changes and metrics
        """
        
    def get_current_weather(self) -> WeatherState:
        """Get current weather conditions."""
        
    def get_current_season(self) -> Season:
        """Get current season."""
        
    def get_air_quality_index(self) -> float:
        """Get current air quality index (0-500 scale)."""
        
    def get_active_disasters(self) -> list[Disaster]:
        """Get list of currently active disasters."""
```

### WeatherSimulator

```python
class WeatherSimulator:
    """
    Simulates weather conditions using Markov chains and seasonal patterns.
    """
    
    def __init__(self, base_climate: ClimateProfile, random_service: RandomService):
        """
        Initialize weather simulator.
        
        Arguments:
            base_climate: Base climate profile defining normal conditions
            random_service: Seeded RNG for deterministic weather generation
        """
        
    def simulate_tick(self, season: Season, previous_weather: WeatherState) -> WeatherState:
        """
        Generate weather for current tick based on season and previous conditions.
        
        Uses Markov chain transitions for realistic weather persistence
        and seasonal probability distributions.
        
        Arguments:
            season: Current season affecting probability distributions
            previous_weather: Weather from previous tick (for persistence)
            
        Returns:
            WeatherState for current tick
        """
        
    def apply_climate_change(self, years_elapsed: float, warming_factor: float):
        """
        Gradually shift climate baseline to simulate climate change effects.
        
        Arguments:
            years_elapsed: Simulation time elapsed
            warming_factor: Rate of temperature increase per year
        """
```

### DisasterManager

```python
class DisasterManager:
    """
    Manages natural disaster occurrence and impact simulation.
    """
    
    def __init__(self, settings: DisasterSettings, random_service: RandomService):
        """
        Initialize disaster manager.
        
        Arguments:
            settings: Disaster probabilities, severity distributions, and impact parameters
            random_service: Seeded RNG for deterministic disaster occurrence
        """
        
    def evaluate_disasters(self, city: City, weather: WeatherState, 
                          season: Season) -> list[Disaster]:
        """
        Evaluate whether disasters occur this tick.
        
        Disaster probability increases with:
        - Extreme weather conditions
        - Poor infrastructure maintenance
        - Climate change progression
        - Seasonal factors
        
        Arguments:
            city: Current city state (affects disaster probability and severity)
            weather: Current weather (extreme weather increases some disaster risks)
            season: Current season (affects disaster types and probabilities)
            
        Returns:
            List of disasters that occurred this tick (may be empty)
        """
        
    def apply_disaster_effects(self, disaster: Disaster, city: City) -> DisasterImpact:
        """
        Apply immediate and ongoing effects of a disaster to city state.
        
        Effects may include:
        - Infrastructure damage (reduced capacity or complete destruction)
        - Population displacement or casualties
        - Economic losses (property damage, business disruption)
        - Service interruptions
        - Emergency response costs
        
        Arguments:
            disaster: Disaster to apply
            city: City state to modify
            
        Returns:
            DisasterImpact summary for logging and display
        """
        
    def update_ongoing_disasters(self, city: City) -> list[Disaster]:
        """
        Update state of ongoing disasters (recovery progress, continuing effects).
        
        Returns:
            List of disasters still requiring recovery efforts
        """
```

### AirQualityMonitor

```python
class AirQualityMonitor:
    """
    Tracks air quality based on emissions and environmental factors.
    """
    
    def __init__(self, settings: AirQualitySettings):
        """
        Initialize air quality monitor.
        
        Arguments:
            settings: Emission factors, health thresholds, and calculation parameters
        """
        
    def calculate_air_quality(self, city: City, weather: WeatherState) -> AirQualityState:
        """
        Calculate current air quality index and pollutant concentrations.
        
        Factors:
        - Vehicle emissions (based on traffic volume and fleet composition)
        - Industrial emissions (based on industrial zone activity)
        - Power plant emissions (based on energy generation mix)
        - Weather dispersion (wind speed affects pollutant concentration)
        - Green space filtering (parks and forests absorb pollutants)
        
        Arguments:
            city: Current city state (emission sources and mitigation)
            weather: Current weather (affects pollutant dispersion)
            
        Returns:
            AirQualityState with pollutant levels and overall index
        """
        
    def calculate_health_impacts(self, air_quality: AirQualityState, 
                                population: int) -> HealthImpact:
        """
        Calculate health effects of current air quality on population.
        
        Returns:
            HealthImpact with affected population counts and healthcare costs
        """
```

## Data Structures

### WeatherState

```python
@dataclass
class WeatherState:
    """Snapshot of weather conditions for one tick."""
    
    temperature_celsius: float              # Current temperature
    precipitation_mm_per_hour: float        # Rainfall or snowfall rate
    wind_speed_km_per_hour: float          # Wind speed
    wind_direction_degrees: float          # Wind direction (0-360)
    cloud_cover_percentage: float          # Cloud coverage (0-100)
    humidity_percentage: float             # Relative humidity (0-100)
    atmospheric_pressure_hpa: float        # Atmospheric pressure
    visibility_km: float                   # Visibility distance
    is_snowing: bool                       # Whether precipitation is snow
    
    def get_description(self) -> str:
        """Generate human-readable weather description."""
        
    def get_comfort_index(self) -> float:
        """Calculate citizen comfort level (0-100)."""
```

### Season

```python
class Season(Enum):
    """Seasonal periods affecting weather patterns and city operations."""
    
    SPRING = "spring"      # Moderate temperatures, increased rainfall
    SUMMER = "summer"      # High temperatures, peak tourism
    AUTUMN = "autumn"      # Cooling temperatures, moderate conditions
    WINTER = "winter"      # Low temperatures, snow, heating demand
```

### Disaster

```python
@dataclass
class Disaster:
    """Represents a natural disaster event."""
    
    disaster_type: DisasterType            # Type of disaster
    severity: float                        # Severity scale (0-100)
    start_tick: int                        # Tick when disaster began
    duration_ticks: int                    # Expected duration
    affected_area: GeographicArea         # Affected city area
    current_status: DisasterStatus        # Current disaster status
    
    # Impacts
    infrastructure_damage: float          # Percentage damage to infrastructure
    population_affected: int              # Number of citizens affected
    economic_loss: float                  # Direct economic losses
    casualties: int                       # Fatalities
    displaced_population: int             # Temporarily displaced citizens
```

### DisasterType

```python
class DisasterType(Enum):
    """Types of natural disasters that can occur."""
    
    EARTHQUAKE = "earthquake"
    FLOOD = "flood"
    TORNADO = "tornado"
    HURRICANE = "hurricane"
    WILDFIRE = "wildfire"
    BLIZZARD = "blizzard"
    HEATWAVE = "heatwave"
    DROUGHT = "drought"
```

### AirQualityState

```python
@dataclass
class AirQualityState:
    """Current air quality measurements and index."""
    
    # Pollutant concentrations (μg/m³)
    carbon_monoxide: float
    nitrogen_dioxide: float
    sulfur_dioxide: float
    particulate_matter_25: float          # PM2.5
    particulate_matter_10: float          # PM10
    ozone: float
    
    # Calculated indices
    overall_aqi: float                    # Air Quality Index (0-500)
    health_category: AirQualityCategory   # Good, Moderate, Unhealthy, etc.
    
    # Source contributions
    vehicle_contribution_percentage: float
    industrial_contribution_percentage: float
    power_generation_contribution_percentage: float
    other_sources_contribution_percentage: float
```

### EnvironmentDelta

```python
@dataclass
class EnvironmentDelta:
    """Summary of environmental changes during a tick."""
    
    # Weather changes
    previous_weather: WeatherState
    current_weather: WeatherState
    
    # Seasonal information
    current_season: Season
    days_until_next_season: int
    
    # Disasters
    new_disasters: list[Disaster]
    ongoing_disasters: list[Disaster]
    resolved_disasters: list[Disaster]
    
    # Air quality
    current_air_quality: AirQualityState
    air_quality_trend: float              # Change from previous tick
    
    # Environmental effects on city
    temperature_energy_demand_modifier: float    # Multiplier for energy demand
    weather_traffic_speed_modifier: float        # Multiplier for traffic speed
    weather_happiness_modifier: float            # Modifier to base happiness
    disaster_service_disruptions: dict[str, float]  # Service capacity reductions
    
    # Sustainability metrics
    carbon_emissions_tons: float
    green_space_percentage: float
    renewable_energy_percentage: float
    water_conservation_rate: float
    waste_recycling_rate: float
```

## Configuration

### EnvironmentSettings

```python
@dataclass
class EnvironmentSettings:
    """Configuration for environment subsystem."""
    
    # Climate profile
    base_climate: ClimateProfile
    climate_change_enabled: bool
    warming_rate_celsius_per_year: float
    
    # Weather simulation
    weather_variation_intensity: float        # How much weather varies (0-1)
    weather_persistence_factor: float         # How much previous weather affects next (0-1)
    
    # Disaster settings
    earthquake_annual_probability: float
    flood_annual_probability: float
    tornado_annual_probability: float
    hurricane_annual_probability: float
    wildfire_annual_probability: float
    blizzard_annual_probability: float
    heatwave_annual_probability: float
    drought_annual_probability: float
    
    disaster_severity_distribution: ProbabilityDistribution
    disaster_warning_system_quality: float    # 0-1, affects preparation time
    
    # Air quality
    baseline_air_quality: float              # Natural air quality without human activity
    vehicle_emission_factor: float           # Emissions per vehicle-km
    industrial_emission_factor: float        # Emissions per industrial unit activity
    power_plant_emission_factor: float       # Emissions per MW generated
    green_space_filtering_factor: float      # Pollution reduction per hectare of green space
    
    # Sustainability
    track_carbon_footprint: bool
    enable_sustainability_metrics: bool
```

### ClimateProfile

```python
@dataclass
class ClimateProfile:
    """Defines the base climate characteristics of the city location."""
    
    name: str                                # Profile name (e.g., "Temperate Continental")
    
    # Temperature ranges (Celsius)
    spring_avg_temp: float
    spring_temp_variance: float
    summer_avg_temp: float
    summer_temp_variance: float
    autumn_avg_temp: float
    autumn_temp_variance: float
    winter_avg_temp: float
    winter_temp_variance: float
    
    # Precipitation patterns
    annual_precipitation_mm: float
    precipitation_distribution: dict[Season, float]  # Percentage by season
    
    # Other climate characteristics
    humidity_baseline: float
    wind_speed_average: float
    sunny_days_percentage: float
    
    # Geographic factors
    elevation_meters: float
    coastal_proximity_km: float              # Distance to coast (affects weather)
    
    @staticmethod
    def get_preset(climate_type: str) -> 'ClimateProfile':
        """
        Get predefined climate profile.
        
        Available presets:
        - "temperate_continental": Four distinct seasons, moderate precipitation
        - "mediterranean": Hot dry summers, mild wet winters
        - "tropical": High temperatures and humidity year-round, heavy rainfall
        - "arid": Low precipitation, high temperature variation
        - "polar": Very cold, low precipitation, long winters
        - "subtropical": Hot humid summers, mild winters
        """
```

## Behavioral Specifications

### Weather Simulation Behavior

1. **Deterministic Generation**: Weather patterns must be reproducible given the same seed
2. **Seasonal Transitions**: Smooth transitions between seasons over multiple ticks
3. **Weather Persistence**: Current weather influences next tick's weather (Markov property)
4. **Extreme Events**: Rare extreme weather events (1% probability) for dramatic scenarios
5. **Diurnal Patterns**: Temperature varies by time of day (if tick represents hours)

### Disaster Occurrence

1. **Base Probability**: Each disaster type has configurable annual probability
2. **Weather Triggers**: Certain weather conditions increase disaster probability
   - Heavy rain increases flood probability
   - High temperatures increase wildfire probability
   - Low temperatures increase blizzard probability
   - High wind speeds increase tornado probability
3. **Infrastructure Quality**: Well-maintained infrastructure reduces disaster impact
4. **Multiple Disasters**: Rare possibility of concurrent disasters
5. **Recovery Period**: Disasters have multi-tick recovery phases

### Air Quality Calculation

1. **Emission Sources**:
   - Vehicles: `emissions = traffic_volume × vehicle_emission_factor × (1 - electric_vehicle_percentage)`
   - Industry: `emissions = industrial_output × industrial_emission_factor`
   - Power: `emissions = energy_generated × power_emission_factor × (1 - renewable_percentage)`
2. **Dispersion**: Wind speed increases dispersion, reducing concentration
3. **Accumulation**: Low wind allows pollutants to accumulate
4. **Green Space Filtering**: Parks and forests absorb pollutants

### Environmental Effects on City Systems

1. **Energy Demand**:
   - Cold weather: Heating demand increases
   - Hot weather: Cooling demand increases
   - `energy_demand_modifier = 1.0 + 0.02 × |temperature - comfort_temperature|`

2. **Traffic Speed**:
   - Rain: Reduces speed by 10-20%
   - Snow: Reduces speed by 30-50%
   - Visibility: Low visibility reduces speed

3. **Construction Activity**:
   - Extreme cold or heat: Reduced construction progress
   - Heavy precipitation: Construction delays

4. **Citizen Happiness**:
   - Comfortable weather: Happiness bonus
   - Extreme weather: Happiness penalty
   - Natural disasters: Significant happiness penalty
   - Good air quality: Happiness bonus
   - Poor air quality: Happiness penalty and health effects

## Integration with Other Subsystems

### Finance Subsystem
- **Disaster Response Costs**: Emergency services, repairs, temporary housing
- **Weather-Related Expenses**: Snow removal, flood control, heating/cooling subsidies
- **Insurance Payouts**: City-funded disaster relief
- **Environmental Regulations**: Costs of emission controls and green initiatives
- **Revenue Impacts**: Tourism affected by weather and disasters

### Population Subsystem
- **Health Effects**: Air quality and weather affect health outcomes and healthcare costs
- **Migration**: Extreme weather and disasters trigger out-migration
- **Seasonal Population**: Tourism and temporary workers vary by season
- **Happiness**: Weather, air quality, and disaster recovery affect citizen satisfaction

### Transport Subsystem
- **Traffic Speed**: Weather conditions modify vehicle speeds
- **Road Capacity**: Snow, flooding, or disaster damage reduces effective capacity
- **Public Transit**: Weather affects ridership and service reliability
- **Emergency Access**: Disasters require special routing for emergency vehicles

### Infrastructure
- **Damage**: Disasters damage buildings, roads, utilities
- **Weather Wear**: Extreme weather accelerates infrastructure aging
- **Energy Grid**: Temperature extremes stress power generation and distribution
- **Water System**: Drought affects water supply; flooding contaminates water

## Metrics and Logging

### Per-Tick Metrics

```python
{
    "tick_index": int,
    "timestamp": str,
    
    # Weather
    "temperature_celsius": float,
    "precipitation_mm_per_hour": float,
    "wind_speed_km_per_hour": float,
    "weather_description": str,
    "season": str,
    
    # Disasters
    "active_disasters": int,
    "new_disasters_this_tick": int,
    "disaster_damage_cost": float,
    "population_affected_by_disasters": int,
    
    # Air quality
    "air_quality_index": float,
    "air_quality_category": str,
    "carbon_monoxide_concentration": float,
    "particulate_matter_25_concentration": float,
    
    # Sustainability
    "carbon_emissions_tons": float,
    "green_space_percentage": float,
    "renewable_energy_percentage": float,
    
    # Effects
    "temperature_energy_demand_modifier": float,
    "weather_traffic_speed_modifier": float,
    "weather_happiness_modifier": float
}
```

## Testing Strategy

### Unit Tests
1. Weather generation produces valid values in expected ranges
2. Seasonal transitions occur at correct intervals
3. Disaster probabilities sum correctly and respect configuration
4. Air quality calculations produce consistent results
5. All environmental effects are within reasonable bounds

### Integration Tests
1. Weather affects energy demand in energy subsystem
2. Disasters trigger emergency response in city management
3. Air quality affects health outcomes in population subsystem
4. Seasonal changes affect tourism revenue

### Determinism Tests
1. Same seed produces identical weather sequence
2. Same conditions produce identical disaster outcomes
3. Environmental state is fully reproducible

### Performance Tests
1. Environment update completes within time budget
2. Disaster simulation scales with city size
3. Air quality calculation is efficient for large cities

## Future Enhancements

1. **Climate Zones**: Multiple climate zones within city for diverse weather
2. **Microclimate Effects**: Urban heat island, building wind tunnels
3. **Weather Predictions**: In-game weather forecast system affecting citizen behavior
4. **Seasonal Events**: Seasonal festivals and activities
5. **Advanced Disasters**: Complex disaster chains (earthquake triggers fires, floods)
6. **Environmental Policies**: Carbon taxes, emission trading, green building codes
7. **Ecosystem Simulation**: Wildlife, vegetation, water bodies
8. **Real-World Data**: Import historical weather data for specific locations

## References

- **Air Quality Index**: EPA AQI calculation standard
- **Weather Simulation**: Markov chain weather modeling
- **Climate Profiles**: Köppen climate classification
- **Disaster Statistics**: Historical disaster frequency data
- **Related Specs**: [City](city.md), [Finance](finance.md), [Population](population.md), [Transport](traffic.md)
