#!/bin/bash

# INPUT_LIST is generated as null separated filenames.
# e.g. 
# 
# $ find /path/to/files/ -type f -name '*jpg' | sort | tr $'\n' "\0
# 
# Please note that the images must possess the final video resolution. ImageMagick's
# convert can do the job.
#
# e.g.:
#   This will put converted files in a preexisting "resize-1920x1080" directory
#
# $ for f in *jpg; do convert "$f" -resize 1920x1080 -background black -gravity center -extent 1920x1080 "resize-1920x1080/$(basename -- $f)"; done
#
INPUT_LIST="${INPUT_LIST:-'media-list.txt'}"
# -an flag to ffmpeg will not render audio
INPUT_AUDIO="./audio-ripetuto-presentazione.flac"
DEFAULT_IMG_DURATION=6
FADE_DURATION=1.5
LAST_PIC_DURATION=12
#VID_WIDTH=720
#VID_HEIGTH=480
# FullHD: 1920x1080
VID_WIDTH=1920
VID_HEIGTH=1080
FPS=25
OUTPUT_FILE="${OUTPUT_FILE:-presentazione-${FPS}fps.mp4}"
#OUTPUT_FILE="/home/daniele/Video/$OUTPUT_FILE"

LOG_FILE="mk-slide.log"


function log() {
  echo "$1" >> $LOG_FILE
}

# adds a suffix before $OUTPUT_FILE extension
function addSuffix() 
{
  if [ "$( echo $OUTPUT_FILE | sed '/\./p' --quiet )" == "" ]; then
    echo $OUTPUT_FILE$1
  else
    echo $( echo $OUTPUT_FILE | sed "s/.\([^.]*\$\)/$1.\1/p" --quiet )
  fi
}

function dcCalc()
{
  #echo $FUNCNAME $1
  dc --expression "$1" 
}

# Accept total number of pics as the only parameter
function printEstimatedSlideshowDurationFromNumOfPics() 
{
  NUM_OF_PICS=$1
  let NUM_OF_PICS--; # don't count the last pic as it has its own duration
  ESTIMATED_SLIDESHOW_DURATION_IN_SECS=$( dcCalc "$DEFAULT_IMG_DURATION $FADE_DURATION - $NUM_OF_PICS * $LAST_PIC_DURATION + p" )
  OTIME_HOURS=$( echo "$ESTIMATED_SLIDESHOW_DURATION_IN_SECS / 3600" | bc )
  OTIME_MIN=$( echo "$ESTIMATED_SLIDESHOW_DURATION_IN_SECS / 60" | bc )
  OTIME_SECS=$( echo "($ESTIMATED_SLIDESHOW_DURATION_IN_SECS / 1) % 60" | bc )
  MSECCALCULATION="(($ESTIMATED_SLIDESHOW_DURATION_IN_SECS-($ESTIMATED_SLIDESHOW_DURATION_IN_SECS/1))*1000)/1" 
  OTIME_MSECS=$( echo $MSECCALCULATION | bc ) 
  #echo $OTIME_HOURS $OTIME_MIN $OTIME_SECS $OTIME_MSECS  
  OTIME=$( printf "%02d:%02d:%02d.%s" $OTIME_HOURS $OTIME_MIN $OTIME_SECS $OTIME_MSECS )
  echo "Durata stimata del filmato risultante: $OTIME ($ESTIMATED_SLIDESHOW_DURATION_IN_SECS secondi)"
}


log ------------------------ 
log "$( date )"
log "Path of calculator (bc):"
log $( which bc )
log "Path of calculator (dc):"
log $( which dc )
log "Path of sed (sed):"
log  $( which sed )
log "Input file list: '$INPUTLINE'"
log "Processing :"


declare -a INPUTFILES
declare INPUTLINE
declare FILTER

while IFS= read -d '' -r FILE
do
  INPUTFILES+=("$FILE")
done < "$INPUT_LIST"

#declare -p INPUTFILES

LASTINPUTIDX=$((${#INPUTFILES[@]}-1))
for i in $( seq 0 $((LASTINPUTIDX-1)) ); do
  #echo ${INPUTFILES[$i]}
  INPUTLINE="$INPUTLINE\
  -loop 1 -t $DEFAULT_IMG_DURATION -framerate $FPS -i \"${INPUTFILES[$i]}\""
done
INPUTLINE="$INPUTLINE\
  -loop 1 -t $LAST_PIC_DURATION -framerate $FPS -i \"${INPUTFILES[$LASTINPUTIDX]}\""
INPUTLINE="$INPUTLINE\
  -i $INPUT_AUDIO"

FILTER="-filter_complex \""

PIC_DURATION=$DEFAULT_IMG_DURATION
OFFSET=$( dcCalc "2 k $PIC_DURATION $FADE_DURATION - p" )
FILTER="$FILTER\
  [0][1]xfade=transition=circleopen:duration=$FADE_DURATION:offset=$OFFSET[f0]; "
SOURCE_A="f0"
for i in $( seq 2 $((LASTINPUTIDX-1)) ); do
  SOURCE_B="$i"
  FADE_AB="f"$((i-1))
  OFFSET=$( dcCalc "2 k $PIC_DURATION $FADE_DURATION - $i * p" )
  FILTER="$FILTER\
  [$SOURCE_A][$SOURCE_B]xfade=transition=circleopen:duration=$FADE_DURATION:offset=$OFFSET[$FADE_AB];"
  SOURCE_A=$FADE_AB
done
SOURCE_A="f"$((LASTINPUTIDX-2))
SOURCE_B="$LASTINPUTIDX"


i=$LASTINPUTIDX
OFFSET=$( dcCalc "2 k $PIC_DURATION $FADE_DURATION - $i * p" )
FILTER="$FILTER\
  [$SOURCE_A][$SOURCE_B]xfade=transition=circleopen:duration=$FADE_DURATION:offset=$OFFSET\""

AUDIO_IDX=$((LASTINPUTIDX+1))
# FILTER="$FILTER\
#   [$AUDIO_IDX:a] [$AUDIO_IDX:a] [$AUDIO_IDX:a] concat=n=3:v=0:a=1 [audio]; \
#   [1:v] [2:v] [3:v] concat=n=3:v=1:a=0 [video]; \
#     [video] [audio] afade=t=out:st=8:d=3,aresample=44100 [out]" 

FIRST_OUTPUT_FILE=$( addSuffix "-aac" )
#SECOND_OUTPUT_FILE=$( addSuffix "-flac" )
FFMPEG_CMD="ffmpeg $INPUTLINE\
  $FILTER\
  -c:v libx264 -pix_fmt yuv420p -preset slow -crf 22 -an ${FIRST_OUTPUT_FILE} "
  #-c:v libx264 -pix_fmt yuv420p -preset slow -crf 22 -c:a aac -b:a 256k ${FIRST_OUTPUT_FILE} "
  #-c:v libx264 -pix_fmt yuv420p -preset slow -crf 22 -c:a copy $OUTPUT_FILE"

log "$( printEstimatedSlideshowDurationFromNumOfPics "$((LASTINPUTIDX+1))" )"

log "Executing:"
log "$FFMPEG_CMD"
eval "time nice -n 10 $FFMPEG_CMD"
ERR=$?
if [ $ERR -eq 0 ]; then 
  log "$FIRST_OUTPUT_FILE pronto."
  open "$FIRST_OUTPUT_FILE"; 
else 
  log "Qualcosa è andato storto (errore $ERR)."
fi

#template
#ffmpeg -loop 1 -t 3 -framerate 60 -i image1.jpg -loop 1 -t 3 -framerate 60 -i image2.jpg -loop 1 -t 3 -framerate 60 -i image3.jpg -filter_complex "[0]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1[s0]; [1]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1[s1]; [2]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1[s2]; [s0][s1]xfade=transition=circleopen:duration=1:offset=2[f0]; [f0][s2]xfade=transition=circleopen:duration=1:offset=4" -c:v libx264 -pix_fmt yuv420p output.mp4
