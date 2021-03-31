source Proto.tcl
package require Itcl
catch {namespace import itcl::*}

class Ob1 {
    public variable x 1
    method do_nothing {} {set x}
}

set p1 [$::Proto::Object new -x 1]
$p1 proc do_nothing {} {$self -x}

puts "::Proto::newObject Object -> [time { ::Proto::newObject Object } 1000]"

puts "Ob1 \#auto -> [time { Ob1 \#auto } 1000]"

puts "::Proto::$p1 do_nothing -> [time { $p1 do_nothing } 10000]"

set ob1 [Ob1 \#auto]
puts "$ob1 do_nothing } -> [time { $ob1 do_nothing } 10000]"

class Ob2 {
    inherit Ob1
    method do_nothing {} {Ob1::do_nothing}
}

set ob2 [Ob2 \#auto]
puts "$ob2 do_nothing } -> [time { $ob2 do_nothing } 10000]"

set p2 [$p1 new]
puts "::Proto::$p2 do_nothing -> [time { $p2 do_nothing } 10000]"

puts "Ob2 \#auto -> [time { Ob2 \#auto } 1000]"
