## Rating history plots

A simple rating history plotting script.

This assumes history as CSV files exported from the Assassins' Network database:
* [Escort](https://assassins.network/static/matches_escort.csv)
* [Manhunt](https://assassins.network/static/matches_manhunt.csv)
* [Domination](https://assassins.network/static/matches_domination.csv)
* [Artifact Assault](https://assassins.network/static/matches_artifact_assault.csv)

TrueSkillThroughTime and the Assassins' Network Elo flavor are supported as rating algorithms. The idea here was to compare the two.

### Requirements

```
CSV, TrueSkillThroughTime, DataFrames, JSON, Plots, Dates, ArgParse, OrderedCollections
```

For HTML exports, PlotlyJS is used.

### Run

```
julia ratingplot.jl --help
```

