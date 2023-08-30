#!/bin/bash

echo "Press [CTRL+C] to stop.."
while true; do
        # gs -dPDFA=1 -dNOOUTERSAVE -sProcessColorModel=DeviceRGB -sDEVICE=pdfwrite -dPDFACompatibilityPolicy=1 -o output_file.pdf data.pdf &>/dev/null
        gzip --keep -f data.txt -c >/dev/null 
done
