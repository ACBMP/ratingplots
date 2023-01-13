import TrueSkillThroughTime as ttt

"""
    gethistory(teams, outcome, dates, p_draw, converge, gamma, startingdate, trackingstart)

Get the TrueSkillThroughTime History. If converge=true, the convergence method is ran.
"""
function gethistory(teams, outcome, mode, dates=false, p_draw::Symbol=:auto, converge::Bool=true, gamma::Float64=0.036, iterations::Int64=30, startingdate::String="2020-03-01", trackingstart::String="2022-03-03")
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
        elseif outcome[i] == 2
            results[i] = [0., 1.]
        else
            results[i] = [0.5, 0.5]
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
function plothist(h::ttt.History, mode, stdevthreshold=0.8, ribscale=0.1, size=(2000, 1000), ylim=0, xlim=0, fmt="png")
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

