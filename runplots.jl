include("statplot.jl")
include("elo.jl")
include("ttt.jl")

function julia_main()
    for m in [:mh, :e, :do, :aa]
    # for m in [:mh, :e, :do, :aa]
        size = (1500, 750)
        teams, outcomes, mode = readmatches(m; dates=false)
        # score diffs
        score_diffs = get_difference(teams, mode)
        plot_score_diffs(score_diffs, mode, nothing; size=size)
        # TTT
        h = gethistory(teams, outcomes, mode, false, :auto, true, 0.036, 30)
        plothist(h, mode, 0.8, 0.2, size, 0, 0, "html")
        # Elo
        players = get_elos(teams, outcomes, mode)
        plothist(players, mode, size, 0, 0, "html")
        # stats
        if mode === :aa
            stats_list = [
                          ["kills", "conceded"],
                          ["deaths", "scored"],
                         ]
        else
            stats_list = [
                          ["deaths", "kills"],
                          ["deaths", "kills", "games"],
                          ["deaths", "kills", "score"]
                         ]
        end
        for s in stats_list
            plot_stats(s, teams, mode)
        end
    end
end

julia_main()
