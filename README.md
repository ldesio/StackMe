# StackMe
Tools for stacked data analysis - a Stata package

StackMe is the evolution of the PTVTools Stata package, originally published on SSC in 2011.

This GitHub repository contains different package versions, starting from older SSC releases of the PTVTools package (now renamed to StackMe), and is the main repository for development and distribution, although future releases of StackMe might also be published on the SSC archive.

To easily install StackMe from this GitHub repository, please install the nice `github` Stata package:

`net install github, from("https://haghish.github.io/github/")`

Once this is done, you can install in Stata the latest version of StackMe:

`github install ldesio/stackme`

To install previous versions, e.g. one of the two versions published on SSC in 2011 and 2015, simply:

1. Uninstall previous versions of StackMe:

`ado uninstall stackme`

2. Install the preferred version (e.g. the 2015 version):

`github install ldesio/stackme, version("0.9.201509014")`
