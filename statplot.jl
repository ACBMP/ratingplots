include("shared.jl")

function get_difference(teams, mode)
    n_games = length(teams[1])
    key = "score"
    if mode == "Artifact assault"
        key *= "d"
    end
    if mode == "Manhunt"
        # there was one broken game
        n_games -= 1
    end
    score_diffs = Vector{Int64}(undef, n_games)
    for i in 1:n_games
        temp_scores = Vector{Int64}(undef, 2)
        for j in 1:2
            temp = JSON.parse(replace(teams[j][i], "'" => "\""))
            temp_scores[j] = sum([p[key] for p in temp])
        end
        score_diff = abs(temp_scores[1] - temp_scores[2])
        if score_diff < 50000
            score_diffs[i] = score_diff
        end
    end
    score_diffs
end

function plot_score_diffs(score_diffs, mode, distr=Exponential; size=(1500, 750))
    if distr !== nothing
        # histogram of score diffs
        hist = histogram(score_diffs, label="Score Diffs", normalize=:pdf, size=size, margin=(15, :mm))
        # fitted distribution
        plot!(fit(distr, score_diffs), label="Fit")
    else
        hist = histogram(score_diffs, label="Score Diffs", size=size, margin=(15, :mm))
    end
    vline!([mean(score_diffs)], label="Average", line=5, formatter=:plain)
    # ticks
    xlims!(0, maximum(score_diffs))
    # labels
    title!("$mode Score Difference")
    xlabel!("Score Difference")
    ylabel!("Occurences")
    savefig("$(mode)_score.html")
end

function get_stats(teams, mode)
    n_games = length(teams[1])
    players = Dict{String, Dict{String, Union{Int64, Vector{Int64}}}}()
    if mode == "Manhunt"
        # there was one broken game
        n_games -= 1
    end
    for i in 1:n_games
        for j in 1:2
            temp = JSON.parse(replace(teams[j][i], "'" => "\""))
            for p in temp
                try
                    for stat in ["score", "kills", "deaths"]
                        push!(players[p["player"]][stat], p[stat])
                    end
                    players[p["player"]]["games"] += 1
                catch
                    players[p["player"]] = Dict(
                            "score" => [p["score"]],
                            "kills" => [p["kills"]],
                            "deaths" => [p["deaths"]],
                            "games" => 1
                            )
                end
            end
        end
    end
    players
end

function plot_stats(stats, teams, mode)
    players = get_stats(teams, mode)
    
    names = keys(players) |> collect
    # find "interesting" players by checking number of games played
    interesting = String[]
    for n in names
        if players[n]["games"] > 10
            push!(interesting, n)
        end
    end

    # get plottable stats
    n_stats = length(stats)
    plotted_stats = Vector{Union{Vector{Float64}, Int64, Vector{Int64}}}(undef, n_stats)
    for i in 1:n_stats
        # games is the only one where the mean isn't what's interesting
        if stats[i] != "games"
            plotted_stats[i] = [mean(players[p][stats[i]]) for p in interesting]
        else
            plotted_stats[i] = [players[p][stats[i]] for p in interesting]
        end
    end
    # setting the size with 3D html plots seems buggy
    plot(legend=false, size=(1000, 750), margin=(15, :mm))
    
    n_players = length(interesting)
    colors = distinguishable_colors(n_players)
    if length(stats) == 2
        annots = text.(interesting, :bottom, colors)
        scatter!(plotted_stats[1], plotted_stats[2], series_annotations=annots, c=colors)
    elseif length(plotted_stats) == 3
        # this unfortunately seems to be necessary to get a proper label for each player
        for i in 1:n_players
            scatter3d!([plotted_stats[1][i]], [plotted_stats[2][i]], [plotted_stats[3][i]], label=interesting[i], c=colors[i])
        end
        zlabel!(titlecase(stats[3]))
    else
        throw(error("not enough stats"))
    end
    
    stats = titlecase.(stats)
    title!(titlecase(mode) * " " * join(reverse(stats), " / "))
    xlabel!(stats[1])
    ylabel!(stats[2])
    savefig("$(mode)_$(join(stats, '_')).html")
end

