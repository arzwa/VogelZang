# TODO: 
# - Stop playback when answer is given
# - timeout for replay
# - when multiple audiofiles for a species, sample with weight given by
#   duration
# - after fragment, ask for replay before giving answer
module VogelZang
using CSV, DataFrames, StatsBase, REPL
using REPL.TerminalMenus
export quiz

global audiodir = joinpath(@__DIR__, "../data/audio")
global dbfile = joinpath(@__DIR__, "../data/database.csv")
global db = CSV.read(dbfile, DataFrame)

function randplayback(vogel, duration)
    io = PipeBuffer()
    fname = joinpath(audiodir, vogel.file)
    run(`ffprobe -i $fname -show_entries format=duration -v quiet -of csv="p=0"`, devnull, io, stderr)
    len = parse(Float64, read(io, String))
    if duration > len
        @error "duration > len"
    end
    start = rand() * (len - duration)
    return fname, start, duration
end

playback(file, start, duration) = run(`ffplay -ss $start -t $duration -v 0 -autoexit -nodisp $file`)
playback(file, start=0) = run(`ffplay -ss $start -v 0 -autoexit -nodisp $file`)

_lowercase(x) = ismissing(x) ? "" : lowercase(x)

function question(vogel, duration)
    print("Welke vogel horen we? (^C om te antwoorden)")
    fname, start, duration = randplayback(vogel, duration)
    answer = "o"
    while answer == "o" || answer == "a"
        if answer == "a" 
            fname, start, duration = randplayback(vogel, duration)
        end
        try 
            playback(fname, start, duration)
            print("Antwoord (`o` voor opnieuw, `a` voor ander fragment):\n  ")
            answer = lowercase(readline())
        catch InterruptException
            print("\nAntwoord (`o` voor opnieuw, `a` voor ander fragment):\n  ")
            answer = lowercase(readline())
        end
    end
    correct = (answer == _lowercase(vogel.name) || 
            answer == _lowercase(vogel.taxon) || 
            answer == _lowercase(vogel.naam))
    if correct 
        printstyled("Correct!\n", bold=true, color=:green) 
    else
        printstyled("Fout", bold=true, color=:red) 
        print(", we hoorden\n") 
    end
    println("  | $(vogel.naam) ($(vogel.name))\n  |    $(vogel.taxon)\n  |    $(vogel.family) ($(vogel.familie))")
    while true
        print("Opnieuw horen [o]? Volledig fragment [v]?\n(gelijk welke toets om verder te gaan)")
        antw = strip(readline()) 
        antw != "o" && antw != "v" && break
        antw == "o" && playback(fname, start, duration)
        antw == "v" && playback(fname)
    end
    return correct
end

function quiz()
    menu = RadioMenu(names(db)[1:end-1])
    choice = request("Selecteer op basis van: ", menu)
    options = map(String, sort(filter(!ismissing, unique(db[:,choice]))))
    menu = MultiSelectMenu(options, pagesize=40)
    choices = sort(collect(request("Kies uit onderstaande ($choice):", menu)))
    df = filter(x->!ismissing(x[choice]) && x[choice] ∈ options[choices], db)
    nr = size(df, 1)
    println("-"^53)
    print("Hoeveel vragen? (<= $nr) ")
    ns = strip(readline())
    nq = !isempty(ns) && all(isnumeric, ns) ? parse(Int, ns) : nr
    print("Duur audiofragment (s)? ")
    duration = tryparse(Float64, strip(readline()))
    if isnothing(duration)
        println("  ongeldige duur, dan maar vijf seconden...")
        duration = 5.
    end
    idx = sample(1:nr, nq, replace=false)
    correct = 0
    try
        for q=1:nq
            println("-"^53)
            println("⋅ Vraag $q ⋅")
            correct += question(df[idx[q],:], duration)    
        end
    catch InterruptException
        println("\n"*"-"^53)
        println("\nQuiz stopgezet...")
    end
    println("\n"*"-"^53)
    println("Score: $correct/$nq")
end

end # module VogelZang
