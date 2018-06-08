#
# This code uses jquery-ui to replace the built in tooltip popup with a nicer
# one. The popup can be styled but by default is slightly larger and pops up
# faster. The tooltip function only needs to be called once as it searches
# the DOM attaching the new UI to any tag with a defined tooltip.
#

$(document).ready -> $(document).tooltip()