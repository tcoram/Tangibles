###########################################################################
# Test
source tangibles.tcl


set observer1 [Text new: {}  "Observer"]
$observer1 proc notify {obj event args} {
    if {$event == "clone"} {
	set obj [lindex $args 0]
	$obj addObserver $self
    }
    $self configure -text "$event: [$obj -name] ([$obj -prototype])"
}
$observer1 proc M_rescan {} {
    foreach child [[$self -parent] -children] {
	$child addObserver $self
    }
}

set rect1 [Rectangle new {} -width 100 -height 100]

$rect1 -stepTime 500

$rect1 proc M_No_Flashing_Checkbutton {} {
    if {[$self -stepTime] == -1 } {
	$self -stepTime 500
	$self restartStepper
    } else {
	$self -stepTime -1
    }
}

$rect1 proc step {} {
    set color [$self -color]
     $self configure -fill $color
    if {$color == "red"} {
	$self -color green
    } else {
	$self -color red
    }
}

set oval1 [Oval new {} -width 100 -height 100]

set text1 [Text new: {} "Hello World. Edit me."]
$text1 -editable true

set clock1 [DigitalClock new]

# wm attributes . -fullscreen 1
. configure -bg white

canvas .c -width 800 -height 600
pack .c

$oval1 configure -fill blue
$rect1 configure -fill red

set canvas1 [Canvas new {} -width 800 -height 600]

$canvas1 drawOn .c
$canvas1 add $rect1 100 100
$canvas1 add $oval1 200 200
$canvas1 add $clock1 300 300
# $canvas1 add [Pushbutton new] 150 150
$canvas1 add [Pushbutton new] 750 550
$rect1 add $text1 0 0

Oval new: Cloner -width 10 10
Cloner configure -fill orange -outline black -width 2
Cloner -defaultPopup false
Cloner -lock true
Cloner proc collect {obj} {
    set cloned {}
    foreach child [$obj -children] {
	set proto [$child -prototype]
	if {$proto == "::Cloner"}  continue
	if {[lsearch $cloned $proto] != -1} continue;# no duplicates
	$self addToMenu "New $proto" "\[$child clone] moveTo [$self -boundLowerRightX] [$self -boundLowerRightY]"
	lappend cloned $proto
    }
}
set cloner1 [Cloner new]
$canvas1 add $cloner1 10 10
$canvas1 add $observer1 500 435
$cloner1 collect $canvas1
$canvas1 add [Text new: {} "<-- Right click on the *Cloner*..."] 25 10

foreach child [$canvas1 -children] {
    $child addObserver $observer1
}


