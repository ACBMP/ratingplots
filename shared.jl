using CSV, DataFrames, Plots, JSON, Statistics, Distributions, Colors, OrderedCollections
plotlyjs()
theme(:dark)

"""
    readmatches(fname; teams=true, outcomes=true, dates=true, mode=true)

Read a CSV file and output teams, outcomes, dates, and mode if desired.
"""
function readmatches(fname="matches.csv"; teams=true, outcomes=true, dates=true, mode=true)
    matches = CSV.read(fname, DataFrame, drop=["new"])
    retvals = []
    if teams
        push!(retvals, [matches[!, 3], matches[!, 4]])
    end
    if outcomes
        push!(retvals, matches[!, 2])
    end
    if dates
        push!(retvals, matches[!, 5])
    end
    if mode
        push!(retvals, matches[!, 1][1])
    end
    retvals
end

"""
    readmatches(modesym; teams=true, outcomes=true, dates=true, mode=true)

Read a CSV file identified via modesym and output teams, outcomes, dates, and mode if desired.
"""
function readmatches(modesym::Symbol=:aa; teams=true, outcomes=true, dates=true, mode=true)
    modes_dict = Dict(:aa => "artifact_assault",
        :e => "escort",
        :mh => "manhunt",
        :do => "domination")
    readmatches("matches_$(modes_dict[modesym]).csv"; teams, outcomes, dates, mode)
end

"""
    aaroles(team)

Calculate roles for a team in AA and add them to the team dict.
"""
function aaroles(team)
    kds = OrderedDict()
    for p in team
        kds[p["player"]] = p["kills"] / p["deaths"]
    end
    kds = collect(sort(kds, byvalue=true))
    role = "[R]"
    for i = 1:length(team)
        if i > 2
            role = "[D]"
        end
        found = false
        j = 1
        while !found
            if team[j]["player"] == kds[i][1]
                team[j]["role"] = role
                found = true
            end
            j += 1
        end
    end
    return team
end

"""
    parse_team(team, mode)

Parse a JSON formatted team.
"""
function parse_team(team::String, mode, return_scores::Bool=false)
    temp = JSON.parse(replace(team, "'" => "\""))
    if mode == "Artifact assault"
        temp = aaroles(temp)
        names = [p["player"] * " " * p["role"] for p in temp]
    else
        names = [p["player"] for p in temp]
    end
    if return_scores
        if mode == "Artifact assault"
            scores = sum([p["scored"] for p in temp])
        else
            scores = sum([p["score"] for p in temp])
        end
        return names, scores
    end
    names
end


