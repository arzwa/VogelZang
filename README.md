
In een terminal, doe
```
julia --project=/path/to/VogelZang/
```
Dan in de julia REPL, doe
```
julia> using VogelZang

julia> quiz()
```
en ge zoudt vertrokken moeten zijn.

De relevante audio files worden verwacht in de directory `data/audio/` in
de repo. Indien ze elders op uw hard drive staan, dan kunt ge dat aangeven
door middel van onderstaande wijziging:
```
VogelZang.audiodir = "/het/relevante/pad"
```

