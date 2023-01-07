
"""
Player struct.
"""
mutable struct Player
    rating::Float64
    games::Int
    history::Vector{Tuple{Float64, Int}}
end

"""
    E(R::Vector{Float64})

Expecting win chance of R[1] against R[2] based on ratings.
"""
function E(R::Vector{Float64})
    (1 + 10 ^ ((R[2] - R[1]) / 400)) ^ -1
end

"""
    E(R1::Float64, R2::Float64)

Expecting win chance of R1 against R2 based on ratings.
"""
function E(R1::Float64, R2::Float64)
    E([R1, R2])
end

"""
    Kc(N::Int, R::Number, hi::Number=1200)

Maximum rating change for rating R with N games played assuming high elo at hi (default 1200).
"""
function Kc(N::Int, R::Float64, hi::Float64=1200.0)
    if N < 30 && R < hi
        return 40
    elseif R <= hi
        return 20
    else
        return 15
    end
end

"""
    score(s1::Number, s2::Number, ref=nothing)

A rating change boost based on difference between scores s1 and s2.

If the reference score ref is set to nothing, this will be relative to total score.

With ref set to a Number, this is based on how close to ref the difference is.
"""
function score(s1::Number, s2::Number, ref=nothing)
    if ref === nothing
        boost = abs(s1 - s2) / ((s1 + s2) / 2)
        if boost == Inf
            boost = 0
        end
    elseif ref == 0 
        boost = 0
    else
        boost = max(abs(s1 - s2) - 1, 0) / ref
    end
    boost
end

"""
    newR(R, S, E, N, s1, s2, ref=nothing)

Calculate new rating based on current rating R, outcome S, expected outcome E, N games played, scorelines s1 and s2, and reference stomp value ref.
"""
function newR(R, S, E, N, s1, s2, ref=nothing)
    if N > 10
        return R + Kc(N, R) * (S - E) * (1 + score(s1, s2, ref)) + S
    else
        if S == 1 
            return R + 50
        elseif S == 0 
            return R - 10
        elseif S == 0.5 
            return R + 20
        else
            throw(error("bad outcome"))
        end
    end
end

"""
    w_mean(ratings, ratings_o)

Calculate a weighted arithmetic mean of ratings with weights based on their difference from ratings_o.
"""
function w_mean(ratings, ratings_o)
    mean_o = sum(ratings_o) / length(ratings_o)
    diffs = [abs(r - mean_o) for r in ratings]
    weights = zeros(length(diffs))
    sum_diffs = sum(diffs)
    if sum_diffs > 0
        for i in 1:length(weights)
            weights[i] = diffs[i] / sum_diffs
        end
    end

    w_sum = sum(weights)
    if w_sum == 0
        weights = ones(length(ratings))
    end
    sum([ratings[i] * weights[i] for i in 1:length(ratings)]) / sum(weights)
end

"""
    w_mean(ratings)

Calculate a weighted arithmetic mean of ratings of first team with weights based on their difference from second team's ratings.
"""
function w_mean(ratings::Vector{Vector{Float64}})
    w_mean(ratings[1], ratings[2])
end

function team_ratings!(all_players, teams, outcome, s1, s2, ref=nothing, totalgames=1, iterations=1)
    l = length(teams)
    if length(teams[1]) != length(teams[2])
        throw(error("team lengths differ"))
    end

    # make sure the player is actually known otherwise create them
    for i in 1:l
        for p in teams[i]
            if !haskey(all_players, p)
                all_players[p] = Player(800.0, 0, [(800.0, totalgames)])
            end
        end
    end

    if outcome == 1 
        S = (1, 0)
    elseif outcome == 2
        S = (0, 1)
    elseif outcome == 0 
        S = (0.5, 0.5)
    else
        throw(error("bad outcome; must be ∈ {0, 1, 2}"))
    end

    # get all players' rating from all_players
    playerratings = [[all_players[p].rating for p in teams[i]] for i in 1:2]
    # calculate E for first team using w_mean on playerratings and its reverse
    Es = [E(w_mean(playerratings), w_mean(reverse(playerratings)))]
    # second team is just 1 - first
    push!(Es, 1 - Es[1])

    for j in 1:l
        for i in 1:2
            if newR(all_players[teams[i][j]].rating, S[i], Es[i], all_players[teams[i][j]].games, s1, s2, ref) < 0 
                println(teams, S, Es, s1, s2)
                p = all_players[teams[i][j]]
                println(p.rating + Kc(p.games, p.rating) * (S[i] - Es[i]) * (1 + score(s1, s2, ref)) + S[i])
                throw(error("bad data"))
            end
            all_players[teams[i][j]].rating = newR(all_players[teams[i][j]].rating, S[i], Es[i], all_players[teams[i][j]].games, s1, s2, ref)
            all_players[teams[i][j]].games += 1
            push!(all_players[teams[i][j]].history, (all_players[teams[i][j]].rating, totalgames))
        end
    end

    all_players
end

function get_elos(teams, outcomes, mode, iterations=1)
    if mode == "Artifact assault"
        ref = 4
    elseif mode == "Domination"
        ref = 0
    else
        ref = nothing
    end
    all_players = Dict{String, Player}()
    totalgames = 1
    for i in 1:length(teams[1])
        n_players = length(teams[1][i])
        temp_teams = [Vector{String}(undef, n_players), Vector{String}(undef, n_players)]
        ss = Vector{Float64}(undef, 2)
        for j in 1:2
            temp = JSON.parse(replace(teams[j][i], "'" => "\""))
            if mode == "Artifact assault"
                temp = aaroles(temp)
                names = [p["player"] * " " * p["role"] for p in temp]
            else
                names = [p["player"] for p in temp]
            end
            temp_teams[j] = names
            if mode == "Artifact assault"
                ss[j] = sum([p["scored"] for p in temp])
            else
                ss[j] = sum([p["score"] for p in temp])
            end
        end
        team_ratings!(all_players, temp_teams, outcomes[i], ss[1], ss[2], ref, totalgames)
        totalgames += 1
    end

    all_players
end
 
