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
  declare -a analysis_types=("age" "revisions")
  declare -a all_analysis_types=("abs-churn" "age" "author-churn" "authors" "communication" "coupling" "entity-churn" "entity-effort" "entity-ownership" "fragmentation" "identity" "main-dev" "main-dev-by-revs" "messages" "refactoring-main-dev" "revisions" "soc" "summary")
  for i in "${analysis_types[@]}"
  do
    echo "Performing '$i' analysis"
    java -jar $maat_location -l ./$output/git_log.txt -c git2 -a $i > ./$output/analysis_$i.csv
  done

  cd $output

  # transform data
  python3 $scripts_location/merge/merge_comp_freqs.py analysis_revisions.csv complexity.csv                                         > /dev/null 2>&1 # don't print anything
  python3 $scripts_location/transform/csv_as_enclosure_json.py          --structure complexity.csv --weights analysis_revisions.csv > hotspots.json
  python3 $scripts_location/transform/code_age_csv_as_enclosure_json.py --structure complexity.csv --weights       analysis_age.csv > age.json

  # prepare visualisation website
  cp -r $scripts_location/transform/d3 d3
  cp $scripts_location/transform/crime-scene-hotspots.html hotspots.html
  cp $scripts_location/transform/crime-scene-age.html      age.html
  
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



