# mkslide
Generate a slideshow video from images

It makes a video playing a number of images with crossfade with no audio. The script provides a bunch of configurable parameters.

Look at `mk-slide.sh` for details.

## Requirements
- ffmpeg
- bash
- dc
- bc
- ImageMagick (optional)
- sed

Images must be in the target resolution. Look at `mk-slide.sh` for an example on image resize.

## Pros
- generates a high quality and compatible slideshow thanks to ffmpeg
- offloading of ffmpeg required resources by employing pre-resized pictures (e.g. with ImageMagick)

## Cons
- resource intensive. May quickly fill RAM and swap when processing a long list of FullHD pictures. In my use case it consumes roughly 18GB for 134 pictures.
