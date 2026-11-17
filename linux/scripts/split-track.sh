#!/bin/bash
# this one rencodes and seperates the input audio file into 55 minute flac files mainly intended for uploading long drones to bandcamp or distribution 
if [[ -z $1 ]];
then 
    echo "No parameter passed." 
    exit
fi
    echo "Breaking $1 into 55 minute segments"
INPUTFILE=$1

# 3330 = 55min
ffmpeg -i "$INPUTFILE" -y \
    -reset_timestamps 1 \
    -f segment \
    -segment_time 3300 \
    -map 0:a:0 -vn -sn -dn  \
    -ar 44100 -ac 2 \
    -c:a flac \
    temp_%03d.flac

# Have to rencode it because ffmpeg hates the final file i guess?! 
for f in temp_*.flac; do
    [[ -f "$f" ]] || continue
    OUT="${f/temp_/${1}_}"

    if ffmpeg -i "$f" -y -c:a flac "$OUT"; then
        rm -v -f "$f"
        echo "Made $OUT and removed temp files"
    else
        echo "ERROR $f leaving temp files"
    fi
done

echo "DONE"