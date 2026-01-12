# TODO: 
# - Stop playback when answer is given
# - timeout for replay
module VogelZang
using CSV, DataFrames, StatsBase, REPL
using REPL.TerminalMenus
export quiz

global audiodir = joinpath(@__DIR__, "../data/audio")
global dbfile = joinpath(@__DIR__, "../data/database.csv")
global db = CSV.read(dbfile, DataFrame)
global width = 62

function get_audio_duration(fname)
    io = PipeBuffer()
    run(`ffprobe -i $fname -show_entries format=duration -v quiet -of csv="p=0"`, devnull, io, stderr)
    len = parse(Float64, read(io, String))
end

# get the audio fragment durations and write to the database file
function update_db!()
    db.duration = map(x->get_audio_duration(joinpath(audiodir, x)), db.file)
    CSV.write(dbfile, db)
end

function remove_col!(col)
    _db = db[:,Not(col)]
    CSV.write(dbfile, _db)
end

function randplayback(species, duration)
    spdf = filter(x->x.taxon == species, db)
    i = sample(1:nrow(spdf), Weights(spdf.duration))
    start = rand() * (spdf[i,:duration] - duration)
    fname = joinpath(audiodir, spdf[i,:file])
    return fname, start, duration, spdf[i,:]
end

function playback(file, start, duration; wait=true) 
    run(`ffplay -ss $start -t $duration -v 0 -autoexit -nodisp $file`, wait=wait)
end

function playback(file, start=0; wait=true) 
    run(`ffplay -ss $start -v 0 -autoexit -nodisp $file`, wait=wait)
end

_lowercase(x) = ismissing(x) ? "" : lowercase(x)

function iscorrect(row, answer)
    (answer == _lowercase(row.name) || 
        answer == _lowercase(row.taxon) || 
        answer == _lowercase(row.naam))
end

function question(vogel, duration)
    print("Welke vogel horen we?\n")
    fname, start, duration, row = randplayback(vogel, duration)
    answer = "o"
    process = nothing
    while answer == "o" || answer == "a"
        !isnothing(process) && kill(process)
        if answer == "a"  # new fragment for same species
            fname, start, duration, row = randplayback(vogel, duration)
        end
        try 
            process = playback(fname, start, duration, wait=false)
            print("Antwoord ([o]pnieuw, [a]nder fragment):\n  ")
            answer = lowercase(readline())
        catch InterruptException
            print("\nAntwoord ([o]pnieuw, [a]nder fragment):\n  ")
            answer = lowercase(readline())
        end
    end
    kill(process)
    correct = iscorrect(row, answer)
    if correct
        printstyled("Correct!\n", bold=true, color=:green) 
    else
        printstyled("Fout", bold=true, color=:red) 
        print(", we hoorden\n") 
    end
    print("  | $(row.naam) ($(row.name))\n")
    print("  |    $(row.taxon)\n")
    print("  |    $(row.family) ($(row.familie))\n")
    while true
        try
            print("Opnieuw horen [o]? Ander fragment [a]? Volledig fragment [v]?\n")
            print("(gelijk welke toets om verder te gaan) ")
            antw = strip(readline()) 
            antw != "o" && antw != "a" && antw != "v" && break
            antw == "o" && playback(fname, start, duration)
            antw == "a" && playback(randplayback(vogel, duration)[1:3]...)
            antw == "v" && playback(fname)
        catch InterruptException
            break
        end
    end
    return correct
end

function quiz()
    opts = filter(x->x != "duration" && x != "file", names(db))
    menu = RadioMenu(opts)
    k = request("Selecteer op basis van: ", menu)
    choice = opts[k]
    options = map(String, sort(filter(!ismissing, unique(db[:,choice]))))
    df = if options == ["F", "T"]
        db[db[:,choice] .== "T",:]
    else
        menu = MultiSelectMenu(options, pagesize=40)
        choices = sort(collect(request("Kies uit onderstaande ($choice):", menu)))
        filter(x->!ismissing(x[choice]) && x[choice] ∈ options[choices], db)
    end
    if nrow(df) == 0 
        @error "Geen soorten geselecteerd!"
        return
    end
    species = unique(df[:,:taxon])
    println("-"^width)
    print("Duur audiofragment (s)? ")
    duration = tryparse(Float64, strip(readline()))
    if isnothing(duration)
        println("  ongeldige duur, dan maar vijf seconden...")
        duration = 5.
    else
        println("  $duration seconden.")
    end
    correct = 0
    nq = 0
    try
        while true
            nq += 1
            sp = rand(species)
            println("\n"*"="^width)
            println("⋅ Vraag $nq ⋅")
            println("-"^width)
            correct += question(sp, duration)    
        end
    catch InterruptException
        println("\n"*"-"^width)
        println("\nQuiz stopgezet...")
    end
    println("\n"*"-"^width)
    println("Score: $correct/$(nq-1)")
    print("Deze selectie van soorten opslaan? [j/n] ")
    try
        answer = strip(readline())
        answer != "j" && return
        name = ""
        while true
            print("Onder welke naam? ")
            name = strip(readline())
            if name ∈ names(db)
                @warn "`$name` al in database!"
            elseif name == ""
                @warn "Ongeldige naam!"
            else
                break
            end
        end
        col = map(x->x.taxon ∈ species ? "T" : "F", eachrow(db))
        db[:,name] = col
        CSV.write(dbfile, db)
        return 
    catch InterruptException
    end
end

end # module VogelZang
