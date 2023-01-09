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
    "--iterations", "-i"
    help = "number of iterations for convergence"
    arg_type = Int64
    required = false
    default = 0
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

"""
    gethistory(teams, outcome, dates, p_draw, converge, gamma, startingdate, trackingstart)

Get the TrueSkillThroughTime History. If converge=true, the convergence method is ran.
"""
function gethistory(teams::Vector{Vector{String}}, outcome::Vector{Int64}, mode, dates=false, p_draw::Symbol=:auto, converge::Bool=true, gamma::Float64=0.036, iterations::Int64=30, startingdate::String="2020-03-01", trackingstart::String="2022-03-03")
    # pre-allocate
    n_games = length(teams[1])
    games::Vector{Vector{Vector{String}}} = Vector{Vector{Vector{String}}}(undef, n_games)

    if dates === true
        times::Vector{Int64} = Vector{Int64}(undef, n_games)
    end

    # parse teams and dates and prepare results
    results::Vector{Vector{Float64}} = Vector{Vector{Float64}}(undef, n_games)

    for i in 1:n_games
        n_players = length(teams[1][i])
        if dates !== false
            # these dates are a bit weird
            # all modes other than domi will have some dates missing
            if dates[i] === missing
                times[i] = Dates.value(Date(trackingstart) - Date(startingdate))
            else
                times[i] = Dates.value(Date(dates[i]) - Date(startingdate))
            end
        end

        # parse the teams in the game
        temp_teams = [Vector{String}(undef, n_players), Vector{String}(undef, n_players)]
        for j in 1:2
            temp_teams[j] = parse_team(teams[j][i], mode)
        end
        games[i] = temp_teams

        # format outcomes for TTT
        if outcome[i] == 1
            results[i] = [1., 0.]
        elseif r == 2
            results[i] = [0., 1.]
        else
            results = [0.5, 0.5]
        end
    end

    # calculate draw likelihood
    if p_draw === :auto
        draws = count(r->r==[0.5, 0.5], results)
        p_draw = draws / n_games
    end

    # create history if we have dates
    if dates === false
        h = ttt.History(games, results, p_draw=p_draw, gamma=gamma)
    else
        h = ttt.History(games, results, times, p_draw=p_draw, gamma=gamma)
    end

    if converge
        ttt.convergence(h, verbose=false, iterations=iterations)
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
    for name in keys(h)
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
        if pargs["iterations"] == 0
            pargs["iterations"] = 30
        end
        if pargs["no-dates"]
            h = gethistory(t, outcome, mode, false, :auto, !pargs["no-converge"], pargs["gamma"], pargs["iterations"])
        else
            h = gethistory(t, outcome, mode, dates, :auto, !pargs["no-converge"], pargs["gamma"], pargs["iterations"])
        end
        plothist(h, mode, pargs["threshold"], pargs["ribbon-scale"], (pargs["width"], pargs["height"]), pargs["ylim"], pargs["xlim"], pargs["format"])
    elseif pargs["algo"] == "Elo"
        pargs["iterations"] = max(pargs["iterations"], 1)
        players = Dict{String, Player}()
        for i in 1:pargs["iterations"]
            for p in keys(players)
                players[p].history = [(players[p].rating, 1)]
            end
            players = get_elos(t, outcome, mode, players)
        end
        plothist(players, mode, (pargs["width"], pargs["height"]), pargs["ylim"], pargs["xlim"], pargs["format"])
    end
end

main()
