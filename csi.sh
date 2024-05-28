#!/bin/bash

# To setup: create the alias bellow
# alias csi='bash LOCATION_OF_THIS_REPO/csi.sh'
# After the alias has been set you can call this script from inside any git repo and it will:
# 1. Generate d3 charts with all the metrics it can
# 2. Start a webserver for you to check the charts 

if ! git rev-parse &>/dev/null; then
  echo "The directory is not a Git repository. Stopping the script."
  exit 1
fi

maat_location=$(dirname "$0")/code-maat-1.0.4-standalone.jar
scripts_location=$(dirname "$0")

output=crime-scene-analysis
if [ -d "$output" ]; then
    rm -Rf "$output"
    mkdir -p $output/data
fi

printf "Analysis started: "
date

echo "Gathering data..."                                                                                                                                          # List of:
cloc --unix --vcs git --by-file --csv --quiet --timeout 1000                                                         --report-file=./$output/data/complexity.csv  # - files
git log --all --numstat   --date=short --pretty=format:'--%h--%ad--%aN' --no-merges --no-renames --ignore-space-change --reverse > ./$output/data/git_log.txt     # - commits
git log --all --shortstat --date=short --pretty=format:'--%h--%ad--%aN' --no-merges --no-renames --ignore-space-change --reverse > ./$output/data/git_log2.txt    # - commits, loc per commit
git shortlog -sn --no-merges | cut -f2                                                                                           > ./$output/data/git_authors.txt # - authors (sorted by # of commits)

# analyze data
# key value pair: (analysis, d3 visualization)
declare -A analysis_types
analysis_types["age"]="enclosure"
analysis_types["revisions"]="enclosure"
analysis_types["communication"]="edge_bundling"
analysis_types["main-dev"]="enclosure"
# TODO: add support for all the available analysis options
# declare -a all_analysis_types=("abs-churn" "age" "author-churn" "authors" "communication" "coupling" "entity-churn" "entity-effort" "entity-ownership" "fragmentation" "identity" "main-dev" "main-dev-by-revs" "messages" "refactoring-main-dev" "revisions" "soc" "summary")
for key in ${!analysis_types[@]}; do
  # echo ${key} ${analysis_types[${key}]}
  echo "Performing '${key}' analysis"
  java -jar $maat_location -l ./$output/data/git_log.txt -c git2 -a ${key} > ./$output/data/analysis_${key}.csv
done


cd $output/data/
# transform data

colors=("red" "blue" "green" "yellow" "orange" "purple" "cyan" "magenta" "lime" "brown") ; i=0
echo "author,color" >> "analysis_authors.csv"
while read -r name; do
    color="${colors[i]}" ; echo "$name,$color" >> "analysis_authors.csv" ; ((i++))
done < "git_authors.txt"
python3 $scripts_location/transform/csv_main_dev_as_knowledge_json.py --structure complexity.csv --owners analysis_main-dev.csv --authors analysis_authors.csv > main-dev.json

python3 $scripts_location/merge/merge_comp_freqs.py analysis_revisions.csv complexity.csv                                             > analysis_revisions2.csv    # > /dev/null 2>&1 # don't print anything
python3 $scripts_location/transform/csv_as_enclosure_json.py              --structure complexity.csv --weights analysis_revisions.csv > revisions.json
python3 $scripts_location/transform/code_age_csv_as_enclosure_json.py     --structure complexity.csv --weights       analysis_age.csv > age.json
python3 $scripts_location/transform/communication_csv_as_edge_bundling.py --communication analysis_communication.csv                  > communication.json

dotnet fsi $scripts_location/transform/csv_loc_change_per_date.fsx git_log2.txt                                                       > loc_change_over_time.csv


cd ..
# prepare visualisation website

cp -r $scripts_location/transform/d3 d3
for key in ${!analysis_types[@]}; do
  cp $scripts_location/transform/${analysis_types[${key}]}.html analysis_${key}.html
  sed -i "s/INPUT/\.\/data\/${key}.json/g" analysis_${key}.html
done

printf "Analysis finished: "
date

# run webserver
echo ""
echo "You can view the visualisations at: http://localhost:8080"
echo ""
python3 -m http.server 8080


