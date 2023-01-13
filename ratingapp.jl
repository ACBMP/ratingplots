include("shared.jl")
include("elo.jl")
include("ttt.jl")

using ArgParse

function parse()
s = ArgParseSettings(description="Plot player ratings using CSV file.")

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
