#!/bin/bash

# To setup: create the alias bellow
# alias csi='bash LOCATION_OF_THIS_REPO/csi.sh'
# After the alias has been set you can call this script from inside any git repo and it will:
# 1. Generate d3 charts with all the metrics it can
# 2. Start a webserver for you to check the charts 

if git rev-parse &>/dev/null; then

  printf "Analysis started: "
  date

  maat_location=$(dirname "$0")/code-maat-1.0.4-standalone.jar
  scripts_location=$(dirname "$0")
  output=crime-scene-analysis

  mkdir $output

  echo "Gathering data..."                                                                                   # List of:
  cloc --unix --vcs git --by-file --csv --quiet --timeout 1000 --report-file=./$output/complexity.csv        # - files
  git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames > ./$output/git_log.txt # - commits

  # analyze data
  # key value pair: (analysis, d3 visualization)
  declare -A analysis_types
  analysis_types["age"]="enclosure"
  analysis_types["revisions"]="enclosure"
  analysis_types["communication"]="edge_bundling"
  # TODO: add support for all the available analysis options
  # declare -a all_analysis_types=("abs-churn" "age" "author-churn" "authors" "communication" "coupling" "entity-churn" "entity-effort" "entity-ownership" "fragmentation" "identity" "main-dev" "main-dev-by-revs" "messages" "refactoring-main-dev" "revisions" "soc" "summary")

  for key in ${!analysis_types[@]}; do
    # echo ${key} ${analysis_types[${key}]}
    echo "Performing '${key}' analysis"
    java -jar $maat_location -l ./$output/git_log.txt -c git2 -a ${key} > ./$output/analysis_${key}.csv
  done

  cd $output

  # transform data
  python3 $scripts_location/merge/merge_comp_freqs.py analysis_revisions.csv complexity.csv                                             > /dev/null 2>&1 # don't print anything
  python3 $scripts_location/transform/code_age_csv_as_enclosure_json.py     --structure complexity.csv --weights       analysis_age.csv > age.json
  python3 $scripts_location/transform/csv_as_enclosure_json.py              --structure complexity.csv --weights analysis_revisions.csv > revisions.json
  python3 $scripts_location/transform/communication_csv_as_edge_bundling.py --communication analysis_communication.csv                  > communication.json

  # prepare visualisation website
  cp -r $scripts_location/transform/d3 d3
  for key in ${!analysis_types[@]}; do
    cp $scripts_location/transform/${analysis_types[${key}]}.html analysis_${key}.html
    sed -i "s/INPUT/${key}.json/g" analysis_${key}.html
  done

  printf "Analysis finished: "
  date

  # run webserver
  echo ""
  echo "You can view the visualisations at: http://localhost:8080"
  echo ""
  python3 -m http.server 8080

else
    echo "The directory is not a Git repository. Stopping the script."
    exit 1
fi



