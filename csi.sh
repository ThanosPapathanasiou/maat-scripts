#!/bin/bash

# You can call this script from inside a git directory and it will generate a d3 chart

if git rev-parse &>/dev/null; then
  #alias csi='bash ~/projects/tools/csi.sh'
  maat_location=$(dirname "$0")/code-maat-1.0.4-standalone.jar
  scripts_location=$(dirname "$0")
  output=crime-scene-analysis

  mkdir $output

  # create data
  git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames > ./$output/git_log.txt
  java -jar $maat_location -l ./$output/git_log.txt -c git2 -a revisions > ./$output/revisions.csv
  cloc --unix --vcs git --by-file --csv --quiet --timeout 10 --report-file=./$output/complexity.csv

  cd $output

  # transform data
  python3 $scripts_location/merge/merge_comp_freqs.py revisions.csv complexity.csv
  python3 $scripts_location/transform/csv_as_enclosure_json.py --structure complexity.csv --weights revisions.csv > hotspots.json

  # prepare visualisation website
  cp $scripts_location/transform/crime-scene-hotspots.html index.html
  cp -r $scripts_location/transform/d3 d3

  # run webserver
  echo ""
  echo "You can view the visualisations at: http://localhost:8080"
  echo ""
  python3 -m http.server 8080

else
    echo "The directory is not a Git repository. Stopping the script."
    exit 1
fi



