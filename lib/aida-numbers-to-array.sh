#!/usr/bin/env bash

#MIT License
#Copyright (c) 2026 allmun

min="$1"
max="$2"
shift 2
input="$@"

numbers=()
previous=0
have_previous=0

IFS=',' read -r -a parts <<< "$input"
unset IFS

for part in "${parts[@]}"; do
  if [[ $part =~ ^([0-9]+)(-([0-9]+))?$ ]]; then
    start=$((10#${BASH_REMATCH[1]}))
    end=$start

    if [[ -n ${BASH_REMATCH[3]} ]]; then
      end=$((10#${BASH_REMATCH[3]}))
      (( start < end )) || {
        echo "Invalid range (must increase): $part" >&2
        exit 1
      }
    fi

    if (( have_previous && start <= previous )); then
      echo "Numbers must be in strictly increasing order near: $part" >&2
      exit 1
    fi

    for ((n = start; n <= end; n++)); do
      if (( n < min )); then
        echo "Numbers exceeding min ($min): $part" >&2
        exit 1
      elif (( n > max )); then
        echo "Numbers exceeding max ($max): $part" >&2
        exit 1
      else
        numbers+=( "$n" )
      fi
    done

    previous=$end
    have_previous=1
  else
    echo "Invalid item: $part" >&2
    exit 1
  fi
done

#printf '\n'
printf '%s ' "${numbers[@]}"
#printf '\n'
