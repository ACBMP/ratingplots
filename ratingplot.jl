using CSV, TrueSkillThroughTime, DataFrames, JSON, Plots, Dates, ArgParse, OrderedCollections
global const ttt = TrueSkillThroughTime;
theme(:dark)

include("elo.jl")

function parse()
s = ArgParseSettings(description="Plot TrueSkillThroughTime using CSV file.")

@add_arg_table s begin
    "fname"
    help = "CSV file to parse"
    arg_type = String
    required = true
    "width"
    help = "output image width"
    arg_type = Int64
    required = false
    default = 2000
    "height"
    help = "output image height"
    arg_type = Int64
    required = false
    default = 1000
    "--no-dates", "-d"
    help = "skip using dates data"
    action = :store_true
    "--ribbon-scale", "-r"
    help = "ribbon scaling factor"
    arg_type = Float64
    required = false
    default = 0.1
    "--threshold", "-t"
    help = "skill certainty threshold under which players will be plotted"
    arg_type = Float64
    required = false
    default = 0.8
    "--no-converge"
    help = "convergence flag"
    action = :store_true
    "--gamma", "-g"
    help = "TrueSkillThroughTime gamma"
    arg_type = Float64
    required = false
    default = 0.036
    "--ylim", "-y"
    help = "plot y limit"
    arg_type = Float64
    required = false
    default = 0.
    "--xlim", "-x"
    help = "plot x limit"
    arg_type = Float64
    required = false
    default = 0.
    "--algo", "-a"
    help = "rating algorithm"
    arg_type = String
    required = false
    default = "TTT"
    "--format", "-f"
    help = "output plot format"
    arg_type = String
    required = false
    default = "png"
    end

    parse_args(s)
end

"""
    readmatches(fname)

Read a CSV file and output teams, outcomes, dates, and mode.
"""
function readmatches(fname="matches.csv")
    matches = CSV.read(fname, DataFrame, drop=["new"])
    t = [matches[!, 3], matches[!, 4]]
    outcome = matches[!, 2]
    dates = matches[!, 5]
    mode = matches[!, 1][1]
    return t, outcome, dates, mode
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

auto::Symbol = Symbol(-1);

"""
    gethistory(teams, outcome, dates, p_draw, converge, gamma, startingdate, trackingstart)

Get the TrueSkillThroughTime History. If converge=true, the convergence method is ran.
"""
function gethistory(teams, outcome, mode, dates=false, p_draw=:auto, converge=true, gamma=0.036, startingdate="2020-03-01", trackingstart="2022-03-03")
    games::Vector{Vector{Vector{String}}} = []
    times::Vector{Int64} = []
    # parse teams
    for i in 1:length(teams[1])
        temp_teams = [[], []]
        for j in 1:2
            temp = JSON.parse(replace(teams[j][i], "'" => "\""))
            if mode == "Artifact assault"
                temp = aaroles(temp)
                names = [p["player"] * " " * p["role"] for p in temp]
            else
                names = [p["player"] for p in temp]
            end
            temp_teams[j] = names
        end
        if typeof(dates) != Bool
            # these dates are a bit weird
            if dates[i] === missing
                push!(times, Dates.value(Date(trackingstart) - Date(startingdate)))
            else
                push!(times, Dates.value(Date(dates[i]) - Date(startingdate)))
            end
        end
        push!(games, temp_teams)
    end
    # prepare results
    results::Vector{Vector{Float64}} = []
    for r in outcome
        if r == 1
            push!(results, [1., 0.])
        elseif r == 2
            push!(results, [0., 1.])
        else
            push!(results, [0.5, 0.5])
        end
    end
    # calculate draw likelihood
    if p_draw === :auto
        draws = count(r->r==[0.5, 0.5], results)
        p_draw = draws / length(results)
    end
    if dates === false
        h = ttt.History(games, results, p_draw=p_draw, gamma=gamma)
    else
        h = ttt.History(games, results, dates, p_draw=p_draw, gamma=gamma)
    end
    if converge
        ttt.convergence(h, verbose=false)
    end
    return h
end

"""
    plothist(h, mode, stdevthreshold, ribscale, size, ylim, xlim, fmt)

Plot History h. Players with deviation above stdevthreshold will be ignored. Deviations are scaled by ribscale for plotting.
"""
function plothist(h::History, mode, stdevthreshold=0.8, ribscale=0.1, size=(2000, 1000), ylim=0, xlim=0, fmt="png")
    plt = plot(xlabel="Games", ylabel="Skill", title=mode, size=size, margin=(20, :mm), legend=false, right_margin=(30, :mm))
    
    curve = ttt.learning_curves(h)
    
    annots::Vector{Tuple{String, Int64, Float64}} = []
    for a in h.agents
        name = a[1]
        r = [round(x[2].mu, digits=2) for x in curve[name]]
        rib = [round(x[2].sigma, digits=2) for x in curve[name]]
        t = [x[1] for x in curve[name]]
        if rib[end] < stdevthreshold
            plot!(plt, t, r, label=name, ribbon=rib .* ribscale, linewidth=2, fillalpha=0.1)
            push!(annots, (name, t[end], r[end]))
        end
    end
    
    for i = 1:length(annots)
        annotate!(annots[i][2] + 2, annots[i][3], text(annots[i][1], plt[1][i][:linecolor], :left))
    end

    if xlim > 0
        xlims!(xlim, xlims(plt)[2])
    end
    if ylim > 0
        ylims!(-ylim, ylim)
    end
    
    savefig("$mode-ttt.$fmt")
end

"""
    plothist(h::Dict{String, Player}, mode, size, ylim, xlim, fmt)

Plot player history dictionary h.
"""
function plothist(h::Dict{String, Player}, mode, size=(2000, 1000), ylim=0, xlim=0, fmt="png")
    plt = plot(xlabel="Games", ylabel="Rating", title=mode, size=size, margin=(20, :mm), legend=false, right_margin=(30, :mm))
    
    annots::Vector{Tuple{String, Int64, Float64}} = []
    for a in keys(h)
        name = a
        r = [x[1] for x in h[name].history]
        t = [x[2] for x in h[name].history]
        plot!(plt, t, r, label=name, linewidth=2, fillalpha=0.1)
        push!(annots, (name, t[end], r[end]))
    end
    
    for i = 1:length(annots)
        annotate!(annots[i][2] + 2, annots[i][3], text(annots[i][1], plt[1][i][:linecolor], :left))
    end

    if xlim > 0
        xlims!(xlim, xlims(plt)[2])
    end
    if ylim > 0
        ylims!(-ylim, ylim)
    end
    
    savefig("$mode-elo.$fmt")
end

function main()
    pargs = parse()

    if pargs["format"] == "html"
        plotlyjs()
    end

    t, outcome, dates, mode = readmatches(pargs["fname"])

    if pargs["algo"] == "TTT"
        if pargs["no-dates"]
            h = gethistory(t, outcome, mode, false, :auto, !pargs["no-converge"], pargs["gamma"])
        else
            h = gethistory(t, outcome, mode, dates, :auto, !pargs["no-converge"], pargs["gamma"])
        end
        plothist(h, mode, pargs["threshold"], pargs["ribbon-scale"], (pargs["width"], pargs["height"]), pargs["ylim"], pargs["xlim"], pargs["format"])
    elseif pargs["algo"] == "Elo"
        players = get_elos(t, outcome, mode)
        plothist(players, mode, (pargs["width"], pargs["height"]), pargs["ylim"], pargs["xlim"], pargs["format"])
    end

end

main()
