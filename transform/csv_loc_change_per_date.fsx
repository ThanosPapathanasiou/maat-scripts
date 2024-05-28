open System
open System.IO

// analyze a chunk that contains information like this:
//--8e60f4f--2024-05-26--Thanos Papathanasiou
// 3 files changed, 17 insertions(+), 13 deletions(-)
let analyze_chunk (s:string) = 

  // return lines of code from a line like the following:
  // 1 file changed, 9 insertions(+), 4 deletions(-)
  // 1 file changed, 1 deletion(-)
  // 1 file changed, 1 insertion(-)
  let calculate_loc_change (line: string) : int = 
    
    let insertions = line.Split(",", StringSplitOptions.RemoveEmptyEntries)
    // example: 1 file changed, 9 insertions(+), 4 deletions(-)
    if insertions.Length = 3 then
      let loc_inserted = (int)(insertions.[1].Split(" ", StringSplitOptions.RemoveEmptyEntries).[0])
      let loc_deleted = (int)(insertions.[2].Split(" ", StringSplitOptions.RemoveEmptyEntries).[0])
      loc_inserted - loc_deleted 
    // example: 1 file changed, 1 deletion(-)
    //      or: 1 file changed, 1 insertion(-)
    elif insertions.Length = 2 then
      if insertions.[1].Contains("insertion") then 
        (int)(insertions.[1].Split(" ", StringSplitOptions.RemoveEmptyEntries).[0])
      else
        -(int)(insertions.[1].Split(" ", StringSplitOptions.RemoveEmptyEntries).[0])
    else 
      failwith "unknown format"

  let lines = s.Split([|Environment.NewLine|], StringSplitOptions.RemoveEmptyEntries)
  let date = lines.[0].Split("--", StringSplitOptions.RemoveEmptyEntries).[1]
  let loc = 
    if lines.Length = 2 then calculate_loc_change lines.[1]
    else 0 // edge case where a commit is only whitespace changes.

  (date, loc)

/// analyze the git log that is output by this command: 
/// git log --all --shortstat --date=short --pretty=format:'--%h--%ad--%aN' --no-merges --no-renames --ignore-space-change
/// and output lines changed per date.
let analyze_git_log (s: string) =
  let chunks = s.Split([| Environment.NewLine + Environment.NewLine |], StringSplitOptions.RemoveEmptyEntries)
  let output = 
    chunks 
      |> Array.map (fun l -> analyze_chunk l) 
      |> Array.groupBy (fun (date, _) -> date)
      |> Array.map (fun (date, values) -> 
        let sum = values |> Array.sumBy snd
        (date, sum))
      |> Array.map (fun (date, sum) -> sprintf "%s, %d" date sum)

  output |> Array.insertAt 0 "date, loc_change"

let inputFile = fsi.CommandLineArgs.[1]
let output = inputFile |> File.ReadAllText |> analyze_git_log 

output |> Array.map System.Console.WriteLine


