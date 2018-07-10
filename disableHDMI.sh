#!/bin/bash

# If I want to disable the HMDI port, enter 'true'.

if [[ "$1" = "true" ]]; then

	# This option turns off the HDMI port on the pi.

	/opt/vc/bin/tvservice -o

else

	/opt/vc/bin/tvservice -p

fi
