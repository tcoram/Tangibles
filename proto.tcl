#  ::Proto - A Prototype based object system for Tcl.
#
#    Author: Todd A. Coram (todd@maplefish.com) | http://www.maplefish.com
#
#    Copyright (c) 2001,2024 Todd A. Coram
#    All Rights Reserved.
#    See license.txt for details.

namespace eval ::Proto {
    variable version 0.9
}
package provide proto $::Proto::version

# A simple, self bootstrapping, highly malleable prototype-based object system.
#
# All objects are created by cloning prototype objects (or any other object
# for that matter). You get a copy of all the variables AND a reference to
# it's procedures.
#
# This system supports:
#   - instance variables (public only)
#   - inheritance (via prototyping/cloning)
#   - instance method renaming, overiding, addition
#   - persistence
#   - and all the dynamicism offered by Tcl
#
# History (a 2024 update):  Why not Javascript? Why not Snit (Tcl)? Why not...?
#    Proto was developed back in 2001; we were all inventing our own object
#    oriented extensions back then and Snit wasn't arround. To be honest,
#    I developed Proto with my "Tangibles" GUI system in mind and it has served
#    there well as an experimental UI system.
#    
#    So here we are in 2024, I am just providing a few "tweaks" and documentation
#    updates to Proto, with the intent of not breaking Tangibles and perhaps
#    using it as a UI for a couple of projects that need a unique means of
#    visualization and interacting with data.
#
#    So, for what it is worth (and perhaps not much at all), here Proto still lives,
#    warts and all, slow but highly malleaable...  Enjoy! 
# 

namespace eval ::Proto {
    # Every object has a unique id (uid).
    #
    variable uid
    set uid 0

    # The primordial way to create an object. If a 'name' is supplied, use it
    # as the name of the object (otherwise create a unique name: Object$uid).
    #
    proc newObject {{name ""}} {
	variable uid
	incr uid;			# make a unique id
	if {$name != ""} {
	    if {[string first "::" $name] == -1} {
		# If no namespace is indicated, assume global!
		#
		set obj ::$name
	    } else {
		set obj $name
	    }
	} else {
	    set obj ::Proto::Object$uid
	}
	# Every object has one proc associated with it: It's own private
	# dispatcher.
	#
	set dispatcher \
	       "proc $obj {{cmd id} args} {eval ::Proto::dispatch $obj \$cmd \$args}"
	eval $dispatcher;		# create dispatcher.
	return ${obj};			# Return the object name (id).
    }

    # Validate something to see if it is a Proto object.
    #
    proc isObj {something} {
	if {![info exists $something]} {
	    return false
	}
	if {[catch {$something -name }] == 0} {
	    return true
	}
	return false
    }

    # Delete an object.
    #
    proc delete {obj} {
	$obj cleanup
	unset ${obj};			# delete array.
	rename ${obj} {};		# delete private dispatcher.
    }

    # The primary dispatcher for object procs. This is optimized for speed.
    #
    # The basic commmands (cmd) supported:
    #
    # id                                        - Returns 'self'.
    # @varname                                  - Fetches variable's fully qualified  name.
    # set varname ?value? | -varname ?value?	   - Fetches or sets scalar values.
    # unset varname                             - Unset/free a scalar value.
    # proc arglist body                         - Define instance procedure.
    # info                                      - Retrieves var and proc names.
    # ?procname? ?args?                         - Execute a defined procedure.
    #
    proc dispatch {obj {cmd ""} {args ""}} {
	if {$cmd == ""} {
	    return $obj
	}
	switch -glob -- $cmd {
	    "id" {
		return $obj
	    }
	    "@*" {
		set var [string range $cmd 1 end]
		if {$var == "" || [array get $obj $var] == {}} {
		    return -code error "No such variable member as $var:"
		}
		return ${obj}($var)
	    }

	    "set" -
	    "-*" { 
		if {[llength $args] > 2} {
		    return -code error "Wrong number of args!"
		}
		if {$cmd == "set"} {
		    set var [lindex $args 0]
		    set value [lrange $args 1 end]
		} else {
		    set var [string range $cmd 1 end]
		    set value $args
		}
		if {$value == "" && [array get $obj $var] == {}} {
		    return -code error "No such variable member as $var:"
		}
		return [eval set ${obj}($var) $value]
	    }
	    "unset" {
		set var [lindex $args 0]
		unset ${obj}($var)
	    }
	    "proc" {
		set name [lindex $args 0]
		set arglist [lindex $args 1]
		set body [lindex $args 2]
		if {[llength $args] < 3} {
		    return -code error "Missing body in member proc definition:"
		}
		set procdef "proc ${obj}${name}_P \{self $arglist\} \{$body\}"
		set ${obj}(${name}_P) ${obj}${name}_P
		return [eval $procdef]
	    }
	    "info" {
		set subcmd [lindex $args 0]
		return [array names ${obj}]
	    }
	    default {
		# Dispatch a proc.
		#
		if {[array get $obj ${cmd}_P] == {}} {
		    return -code error "Unknown member proc ${cmd}:"
		}
		return [eval [set ${obj}(${cmd}_P)] $obj $args]
	    }
	}
    }
}

# The Root Cloneable Object.
#
::Proto::newObject ::Proto::Object

# Proc to make a clone of the current object.
#
::Proto::Object proc _clone {obj} {
    set x [newObject $obj]
    foreach slotname  [$self info]  {
	$x set $slotname [$self set $slotname]
    }
    return $x
}

# Proc to 'mixin' another object with this one.
# Don't mixin an attribute if we already have one.
#
::Proto::Object proc mixin {obj} {
    foreach slotname  [$obj info]  {
	# Only copy if we don't have attribute.
	#
	if {[lsearch [$self info] $slotname] == -1} {
	    $self set $slotname [$obj set $slotname]
	}
    }
    return $self
}

# All objects in this system are cloned from "Object" using "new".
#
::Proto::Object proc new {{name ""} args} {
    set x [$self _clone $name] 
    $x -prototype $self
    $x -name $x
    eval $x init $args
    return $x
}

# Default initialization proc
#
::Proto::Object proc init {args} {
    foreach {opt value} $args {
	eval $self $opt $value
    }
}

# Do anything you need to clean up here (when destroyed).
#
::Proto::Object proc cleanup {} {
}

# Adopt (inherit) a proc from an object (most likely one outside of the
# inheritance tree). This is like a single proc mixin (except the adopted
# proc always replaces any existing proc).
#
::Proto::Object proc adopt {from name} {
    set procname "${name}_P"
    $self set $procname [$from set $procname]
}

# Make an alias of a proc.
#
::Proto::Object proc alias {from to} {
    set fromp ${from}_P
    set top ${to}_P
    set value [$self set $fromp]
    $self set $top $value
}


# Rename a proc.
#
::Proto::Object proc rename {from to} {
    set fromp ${from}_P
    set top ${to}_P
    set value [$self set $fromp]
    $self set $top $value
    $self unset $fromp
}

# Persistence: Representing the object as a decodable string. But, be careful:
# The original object symbol names are stored, so you can potentially have
# an object name clash when reloading...
#
::Proto::Object proc dump {} {
    set result ""
    lappend result "[$self -prototype] new: [$self -name]"
    foreach attr [$self info] {
	set val [$self set $attr]
	
	if {$attr == "name" || $val == $self || $attr == "prototype"} {
	    continue
	}
	
	# Check to see if attr holds another object, otherwise append.
	#
	if {[::Proto::isObj $val]} {
	    lappend result "[$val dump]"
	} 
	lappend result "$self set $attr $val"
    }
    return $result
}


# Convenience: Alias "new" to "new:"
#
::Proto::Object alias new new:

# Convenience:  Set a bunch of variables together. You can do this with new...
#  Is this redundant?
#  
::Proto::Object proc attrs {pairs} {
    for {set i 0} {$i < [llength $pairs]} {incr i} {
        $self set [lindex $pairs $i] [lindex $pairs [incr i]]
    }
}

