source Proto.tcl

::Proto::Object new: Tangible

Tangible -parent {}
Tangible -children {}
Tangible -visible false
Tangible -tag {}
Tangible -id {}
Tangible -configure {}
Tangible -bounded true
Tangible -lock false
Tangible -stepTime -1
Tangible -stepId  -1
Tangible -boundUpperLeftX 0
Tangible -boundUpperLeftY 0
Tangible -boundLowerRightX 50
Tangible -boundLowerRightY 50
Tangible -coords {0 0 50 50}
Tangible -defaultPopup true
Tangible -popupList {}
Tangible -popupMenu {}

Tangible -observers {}

Tangible proc init {args} {
    $self -tag $self
    $self -id $self

    $self -popupList {}
    $self -popupMenu {}
    eval $self _init $args
}

Tangible proc _init {args} {
}

Tangible proc addObserver {observer} {
    if {[lsearch [$self -observers] $observer] == -1} {
	lappend [$self @observers] $observer
    }
}

Tangible proc removeObserver {observer} {
    set index [lsearch [$self -observers] $observer]
    $self -observers [lreplace [$self -observers] $index $index]
}
    
Tangible proc notify {fromObj event} {
}

Tangible proc broadcast {event args} {
    foreach observer [$self -observers] {
	$observer notify $self $event $args
    }

}


Tangible proc boundBox {args} {
    if {$args != {}} {
	if {[llength $args] < 4} {
	    return -code error "boundBox needs 4 parameters!"
	}
	$self -boundUpperLeftX [lindex $args 0]
	$self -boundUpperLeftY [lindex $args 1]
	$self -boundLowerRightX [lindex $args 2]
	$self -boundLowerRightY [lindex $args 3]
    }
    return [list [$self -boundUpperLeftX] [$self -boundUpperLeftY] \
		[$self -boundLowerRightX] [$self -boundLowerRightY]]
}

Tangible proc cleanup {} {
    if {[$self -stepId] != -1} {
	after cancel [$self -stepId]
    }
    # Notify observers that I am going away!
    #
    $self broadcast "cleanup"
    [$self -canvas] delete withtag $self
}

Tangible proc step {} {
}

Tangible proc stepTime {{value ""}} {
    if {$value != ""} {
	$self -stepTime $value
    }
    return [$self -stepTime]
}

Tangible proc restartStepper {} {
    $self step
    set steptime [$self -stepTime]
    if {$steptime > 0} {
	$self -stepId [after $steptime "$self restartStepper"]
    }
}

Tangible proc drawBody {} {
    set canvas [$self -canvas]
    $self create rectangle [$self -coords] -fill lightblue
}

Tangible proc clone {} {
    set obj [$self new]
    $obj -visible false
   [$self -parent] add $obj [expr [$self -boundUpperLeftX]+5]\
	[expr [$self -boundUpperLeftY]+5]
    $self broadcast "clone" $obj
    return $obj
}

Tangible proc lower {} {
    [$self -canvas] lower $self
}

Tangible proc raise {} {
    [$self -canvas] raise $self
}


Tangible proc drawOn {aCanvas} {
    $self -canvas $aCanvas
    $self createMenu

    $self drawBody

    if {[$self -defaultPopup]} {
	$self addSeparatorToMenu
	$self addToMenu "Who Am I?" "tk_messageBox -message \"I am  $self !\""
	$self addToMenu "Unglue Me" "$self unglue"
	$self addToMenu "Clone Me" "$self clone"
	$self addSeparatorToMenu
	$self addToMenu "Send to back" "$self lower"
	$self addToMenu "Bring to front" "$self raise"
	$self addSeparatorToMenu
	$self addToMenu "Delete" "::Proto::delete $self"
    }
    $self -visible true
    eval $self configure [$self -configure]
    $self bindMouseEvents $self
    $self restartStepper

    return $self
}

Tangible proc handlesMouseDown {} {
    return true
}

Tangible proc handlesMouseOver {} {
    return true
}

Tangible proc handlesMouseDrag {} {
    return true
}

Tangible proc bindMouseEvents {toWhat} {
    set canvas [$self -canvas]
    if {[$self handlesMouseDown]} {
	eval $canvas bind $toWhat <ButtonPress> \
	    {"+ $self mouseDown %W %b %X %Y;break"}
	eval $canvas bind $toWhat <ButtonRelease> \
	    {"+ $self mouseUp %W %b %X %Y"}
    }
    if {[$self handlesMouseOver]} {
	eval $canvas bind $toWhat <Enter> \
	    {"+ $self mouseEnter %W %X %Y;break"}
	eval $canvas bind $toWhat <Leave> \
	    {"+ $self mouseLeave %W %X %Y;break"}
    }
    if {[$self handlesMouseDrag]} {
	eval $canvas bind $toWhat <ButtonPress> \
	    {"+ $self mouseDown %W %b %X %Y;break"}
	eval $canvas bind $toWhat <B1-Motion> \
	    {"+ $self mouseDrag %W %X %Y;break"}
    }
}

Tangible proc mouseDown {aWindow aButton x y} {
    set canvas [$self -canvas]
    if {$aButton == 1} {
	$self broadcast "mouseDown"
	$self -evnt(x) [$canvas canvasx $x]
	$self -evnt(y) [$canvas canvasy $y]
    } elseif {$aButton == 3} {
	tk_popup [$self -popupMenu] $x $y
    }
}

Tangible proc mouseUp {aWindow aButton x y} {
    $self broadcast "mouseUp"
    set canvas [$self -canvas]
    set coords [$canvas coords $self]
    $self moveTo [lindex $coords 0] [lindex $coords 1]

    if {![$self inBoundsOf [$self parent]]} {
 	$self unglue
    }
    set pId [eval $canvas find overlapping [$self boundBox]]
    set tags [$canvas gettags [lindex $pId 0]]
    set target [lindex $tags 0]
    if {$target != "" && $target != $self && [$self inBoundsOf $target]} {
	$self dropOn $target
    }
}
Tangible proc dropOn {obj} {
    if {[$obj acceptDrop $self]} {
	set old_parent [$self -parent]
	[$self -parent] remove $self
	set newx [expr [$self -boundUpperLeftX]-[$obj -boundUpperLeftX]]
	set newy [expr [$self -boundUpperLeftY]-[$obj -boundUpperLeftY]]
	$obj add $self $newx $newy
    }
}

Tangible proc acceptDrop {obj} {
    return false
}

Tangible proc mouseEnter {aWindow x y} {
	$self broadcast "mouseEnter"
}
Tangible proc mouseLeave {aWindow x y} {
	$self broadcast "mouseLeave"
}

Tangible proc mouseDrag {aWindow x y} {
    if {[$self -lock]} {
	return false
    }
    set canvas [$self -canvas]
    set ax [$canvas canvasx $x]
    set ay [$canvas canvasx $y]
    set new_x [expr {$ax-[$self -evnt(x)]}]
    set new_y [expr {$ay-[$self -evnt(y)]}]
    $self move $new_x $new_y
    $self -evnt(x) $ax
    $self -evnt(y) $ay
    $canvas raise $self
    return true
}

Tangible proc createMenu {} {
    $self -popupMenu .popup[$self -name]
    uplevel \#0 "menu [$self -popupMenu] -tearoff 0"
    foreach item [$self info] {
	if {[string match M_*_Checkbutton_P $item]} {
	    set label [string map {_ " "} [string range $item 2 end-14]]
	    $self addToMenu $label "$self [string range $item 0 end-2]" \
		checkbutton
	} elseif {[string match M_*_P $item]} {
	    set label [string map {_ " "} [string range $item 2 end-2]]
	    $self addToMenu $label "$self [string range $item 0 end-2]"
	}
    }
}

Tangible proc addSeparatorToMenu {} {
    [$self -popupMenu] add separator
}

Tangible proc addToMenu {label aMethod {type "command"}} {
    [$self -popupMenu] add $type -label $label -command "$aMethod"
}

Tangible proc parent {{obj ""}} {
    if {$obj != ""} {
	[$self -parent $obj]
    }
    return [$self -parent]
}

Tangible proc width {{value ""}} {
    if {$value != ""} {
	$self -boundLowerRightX [expr [$self -boundUpperLeftX] + $value]
    }
    return [expr abs([$self -boundLowerRightX] - [$self -boundUpperLeftX])]
}

Tangible proc height {{value ""}} {
    if {$value != ""} {
	$self -boundLowerRightY [expr [$self -boundUpperLeftY] + $value]
    }
    return [expr abs([$self -boundLowerRightX] - [$self -boundUpperLeftX])]
}

Tangible proc moveTo {x y} {
    set canvas [$self -canvas]
    set tag $self

    set curwidth [$self width]
    set curheight [$self height]

    set x2 [expr $x+$curwidth] 
    set y2 [expr $y+$curheight]
    $self boundBox $x $y $x2 $y2
    set coords [$canvas coords $tag]
    if {[llength $coords] == 2} {
	$canvas coords $tag $x $y
    } else {
	$canvas coords $tag $x $y $x2 $y2
    }
}

Tangible proc add {obj x y args} {
    $obj parent $self
    if {![$obj -visible]} {
	$obj drawOn [$self -canvas]
    }
    $obj moveTo [expr [$self -boundUpperLeftX] + $x] \
	[expr [$self -boundUpperLeftY] + $y]
    lappend [$self @children] $obj
    $obj join $self
    $self do_options {\
		    -bounded - {$obj -bounded true} \
		    -lock - {$obj -lock true} \
		    -unbounded - {$obj -bounded false}} $args
}

Tangible proc remove {obj} {
    set index [lsearch [$self -children] $obj]
    if {$index != -1} {
	$self -children [lreplace [$self -children] $index $index]
    }
    [$self -canvas] dtag [$obj -tag] $self
}

Tangible proc inBoundsOf {obj} {
    foreach {px1 py1 px2 py2} [$obj boundBox] {
	foreach {x1 y1 x2 y2} [$self boundBox] {
	    if {$x1 < $px1 ||
		$x2 > $px2 ||
		$y1 < $py1 ||
		$y2 > $py2} {
		return false
	    }
	}
    }
    return true
}

Tangible proc unglue {} {
    set old_parent [$self -parent]
    $old_parent remove $self
    set new_parent [$old_parent parent]
    $new_parent add $self [$self -boundUpperLeftX] [$self -boundUpperLeftY]
}

Tangible proc join {obj} {
    $self joinAccept $obj
    return true
}

Tangible proc joinAccept {obj} {
    [$self -canvas] addtag [$obj -tag] withtag $self
    return true
}

Tangible proc breakJoin {obj} {
    $obj breakJoinAccept $self
}

Tangible proc breakJoinAccept {obj} {
    [$self -canvas] dtag $self [$obj -tag]
}


Tangible proc create {obj args} {
    $self -id [eval [$self -canvas] create $obj $args -tags $self]
    return [$self -id]
}

Tangible proc move {xdelta ydelta} {
    [$self -canvas] move $self $xdelta $ydelta
}

Tangible proc configure {args} {
    $self -configure $args
    if {[$self -visible]} {
	eval [$self -canvas] itemconfigure [$self -id] $args
    }
}

# Parse options and execute associated commands. Opts are specified
# as a list of {option +|- command} If '+' then an additional argument
# is expected and is passed as %arg to the command.
#
# This proc returns a list of umatched options.
# 
Tangible proc do_options {opts arglist} {
    set cnt [llength $arglist]
    set nomatch ""
    for {set argidx 0} {$argidx < $cnt} {incr argidx} {
	set item [lindex $arglist $argidx]
	set optidx [lsearch $opts $item]
	if {$optidx == -1} {
	    lappend nomatch $item
	    continue
	}
	incr optidx
	set needmore [lindex $opts $optidx]
	incr optidx
	set cmd [lindex $opts $optidx]
	if {$needmore == "+"} {
	    incr argidx
	    set param [lindex $arglist $argidx]
	    regsub -all "%arg" $cmd $param cmd
	}
#	uplevel 1 eval $cmd
	eval $cmd
    }
    return $nomatch
}

###########################################################
# Tangibles

Tangible new: Canvas

Canvas proc _init {args} {
    $self -parent $self
    return [$self do_options {\
				  -width + {$self width %arg} \
				  -height + {$self height %arg}} $args]
}

Canvas proc drawOn {aCanvas} {
    regsub -all "::" ${aCanvas}.$self "" canvas
    set canvas [string tolower $canvas]
    ::canvas $canvas -width [$self width] -height [$self height] \
	-borderwidth 0 -highlightthickness 0
    $self -canvas $aCanvas
    $self create window 0 0 -window $canvas -anchor nw
    $self moveTo 0 0
    $self -canvas $canvas
    $self -visible true
    return $self
}

Tangible new: Text
Text -text ""
Text -editable false

Text proc _init {args} {
    set arglen [llength $args]
    if {$arglen == 0} {
	return
    }
    if {$arglen != 1} {
	return -code error "Usage: Text new: name|{} value"
    }
    $self -text [lindex $args 0]
}

Text proc drawBody {} {
    if {[$self -editable]} {
	$self addToMenu "Edit" "$self _edit"
    }
    set canvas [$self -canvas]
    $self create text [$self -boundUpperLeftX] [$self -boundUpperLeftY] \
	-text [$self -text] -anchor nw
    eval $self boundBox [$canvas bbox $self]
}


Text proc _edit {} {
    [$self -canvas] delete [$self -id]
    set et [entry .[$self -id] -bd 0 -relief flat]
    $et insert end "[$self -text]"
    $self create window [$self -boundUpperLeftX] [$self -boundUpperLeftY] \
	-window $et -anchor nw
    $self -editw $et
    bind $et <KeyPress-Return> "$self _restore"
}

Text proc _restore {} {
    [$self -canvas] delete [$self -id]
    $self -text [[$self -editw] get]
    destroy [$self -editw]
    $self drawBody
}


Tangible new: BoxShape
BoxShape proc _init {args} {
    return [$self do_options {\
				  -width + {$self width %arg} \
				  -height + {$self height %arg}} $args]
}

BoxShape proc drawBody {} {
    $self -color green
    $self create [$self -fig] [$self boundBox]
}

BoxShape proc acceptDrop {obj} {
    return true
}

BoxShape new: Rectangle
Rectangle -fig rectangle

Rectangle proc roundRect { w x0 y0 x3 y3 radius} {
    
    set r [winfo pixels $w $radius]
    set d [expr { 2 * $r }]
    
    # Make sure that the radius of the curve is less than 3/8
    # size of the box!
    
    set maxr 0.75
    
    if { $d > $maxr * ( $x3 - $x0 ) } {
	set d [expr { $maxr * ( $x3 - $x0 ) }]
    }
    if { $d > $maxr * ( $y3 - $y0 ) } {
	set d [expr { $maxr * ( $y3 - $y0 ) }]
    }
    
    set x1 [expr { $x0 + $d }]
    set x2 [expr { $x3 - $d }]
    set y1 [expr { $y0 + $d }]
    set y2 [expr { $y3 - $d }]
    
    set cmd [list polygon]
    lappend cmd $x0 $y0
    lappend cmd $x1 $y0
    lappend cmd $x2 $y0
    lappend cmd $x3 $y0
    lappend cmd $x3 $y1
    lappend cmd $x3 $y2
    lappend cmd $x3 $y3
    lappend cmd $x2 $y3
    lappend cmd $x1 $y3
    lappend cmd $x0 $y3
    lappend cmd $x0 $y2
    lappend cmd $x0 $y1
    lappend cmd -smooth 1
    return $cmd
}


BoxShape new: Oval
Oval -fig oval

Text new: DigitalClock
DigitalClock -editable false
DigitalClock -12hr "%I:%M:%S%p"
DigitalClock -24hr "%H:%M:%S"

DigitalClock proc _init {args} { 
    $self -format [$self -12hr]
}

DigitalClock proc M_24HR_Checkbutton {} {
    if {[$self -format] == [$self -12hr]} {
	$self -format [$self -24hr]
    } else {
	$self -format [$self -12hr]
    }

}

DigitalClock proc step {} {
    $self stepTime 1000
    $self configure -text [clock format [clock sec] -format [$self -format]]
}


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

###########################################################################
# Test

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

canvas .c -width 640 -height 480
pack .c

$oval1 configure -fill blue
$rect1 configure -fill red

eval set canvas1 [Canvas new {} -width 640 -height 480]
$canvas1 drawOn .c
$canvas1 add $rect1 100 100
$canvas1 add $oval1 200 200
$canvas1 add $clock1 300 300
$rect1 add $text1 0 0

set cloner1 [Cloner new]
$canvas1 add $cloner1 10 10
$canvas1 add $observer1 500 435
$cloner1 collect $canvas1
$canvas1 add [Text new: {} "<-- Right click on the *Cloner*..."] 25 10

foreach child [$canvas1 -children] {
    $child addObserver $observer1
}
