#!/bin/bash

# To setup: create the alias bellow
# alias csi='bash LOCATION_OF_THIS_REPO/csi.sh'
# After the alias has been set you can call this script from inside any git repo and it will:
# 1. Generate d3 charts with all the metrics it can
# 2. Start a webserver for you to check the charts 

if git rev-parse &>/dev/null; then

  maat_location=$(dirname "$0")/code-maat-1.0.4-standalone.jar
  scripts_location=$(dirname "$0")
  output=crime-scene-analysis

  mkdir $output

  # create data                                                                                                         # List of:
  cloc --unix --vcs git --by-file --csv --quiet --timeout 10 --report-file=./$output/complexity.csv                     # - files
  git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames > ./$output/git_log.txt            # - commits
  java -jar $maat_location -l ./$output/git_log.txt -c git2 -a revisions  > ./$output/analysis_revisions.csv            # - files, number of revisions
  java -jar $maat_location -l ./$output/git_log.txt -c git2 -a age        > ./$output/analysis_age.csv                  # - files, age 

  cd $output

  # transform data
  python3 $scripts_location/merge/merge_comp_freqs.py analysis_revisions.csv complexity.csv
  python3 $scripts_location/transform/csv_as_enclosure_json.py          --structure complexity.csv --weights analysis_revisions.csv > hotspots.json
  python3 $scripts_location/transform/code_age_csv_as_enclosure_json.py --structure complexity.csv --weights       analysis_age.csv > age.json

  # prepare visualisation website
  cp -r $scripts_location/transform/d3 d3
  cp $scripts_location/transform/crime-scene-hotspots.html hotspots.html
  cp $scripts_location/transform/crime-scene-age.html      age.html
  

  # run webserver
  echo ""
  echo "You can view the visualisations at: http://localhost:8080"
  echo ""
  python3 -m http.server 8080

else
    echo "The directory is not a Git repository. Stopping the script."
    exit 1
fi



