
datapath = "/home/arzwa/dev/VogelZang/data/Dave Farrow - A Field Guide to the Bird Songs & Calls of Britain and Northern Europe (2008) [MP3 V0]"
srcfiles = readdir(datapath, join=true)

nlnames = Dict{String,String}()
for line in readlines("/home/arzwa/dev/VogelZang/data/nl.txt")
    xs = split(line, '\t')
    length(xs) == 1 && continue
    nlnames[strip(xs[2])] = strip(xs[1])
end

families = Dict{String,String}()
nlfams = Dict{String,String}()
let lines = readlines("/home/arzwa/dev/VogelZang/data/nl.txt")
    family = ""
    k = 1; while k < length(lines)
        xs = split(lines[k], '\t')
        if length(xs) == 1
            family, familie = split(xs[1], "(")
            family = strip(family)
            nlfams[family] = strip(strip(familie, ')'))
        else
            families[strip(xs[2])] = family
        end
        k += 1
    end
end

searchfor(dict, x) = haskey(dict, strip(x)) ? dict[strip(x)] : ""

function parse_farrow(fname)
    _, taxon, _name = split(basename(fname), " - ")
    taxon = strip(taxon)
    if length(split(taxon)) > 2
        taxon = join(split(taxon)[1:2], " ")
    end
    name = split(_name, ".")[1]
    naam = searchfor(nlnames, taxon)
    fam = searchfor(families, taxon)
    familie = searchfor(nlfams, fam)
    (taxon=taxon, naam=naam, name=name, familie=familie, family=fam, file=fname)
end

df = DataFrame(map(parse_farrow, srcfiles))
