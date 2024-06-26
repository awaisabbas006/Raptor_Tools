#!/usr/bin/env tclsh

# RIC modeling system initial Tcl implementation
# Copyright (C) 2023 Rapid Silicon

puts "Raptor IP Configuration (RIC) Modeling tool"
puts "Help: ric <model_file> : Compile the model, checks the model, generate Raptor DB and SV constraints"

if {[llength $argv] == 0} {
    exit 0
}

set model  [lindex $argv 0]

puts "RIC: Processing model: $model..."

# -- pdict
#
# Pretty print a dict similar to parray.
#
# USAGE:
#
#   pdict d [i [p [s]]]
#
# WHERE:
#  d - dict value or reference to be printed
#  i - indent level
#  p - prefix string for one level of indent
#  s - separator string between key and value
#
# EXAMPLE:
# % set d [dict create a {1 i 2 j 3 k} b {x y z} c {i m j {q w e r} k o}]
# a {1 i 2 j 3 k} b {x y z} c {i m j {q w e r} k o}
# % pdict $d
# a ->
#   1 -> 'i'
#   2 -> 'j'
#   3 -> 'k'
# b -> 'x y z'
# c ->
#   i -> 'm'
#   j ->
#     q -> 'w'
#     e -> 'r'
#   k -> 'o'
# % pdict d
# dict d
# a ->
# ...
proc pdict { d {i 0} {p "  "} {s " -> "} } {
    set fRepExist [expr {0 < [llength\
        [info commands tcl::unsupported::representation]]}]
        if { (![string is list $d] || [llength $d] == 1)
            && [uplevel 1 [list info exists $d]] } {
            set dictName $d
            unset d
            upvar 1 $dictName d
            puts "dict $dictName"
        }
        if { ! [string is list $d] || [llength $d] % 2 != 0 } {
            return -code error  "error: pdict - argument is not a dict"
        }
        set prefix [string repeat $p $i]
        set max 0
        foreach key [dict keys $d] {
            if { [string length $key] > $max } {
                set max [string length $key]
            }
        }
        dict for {key val} ${d} {
            puts -nonewline "${prefix}[format "%-${max}s" $key]$s"
            if {    $fRepExist && [string match "value is a dict*"\
                [tcl::unsupported::representation $val]]
                || ! $fRepExist && [string is list $val]
                && [llength $val] % 2 == 0 } {
                puts ""
                pdict $val [expr {$i+1}] $p $s
            } else {
                puts "'${val}'"
            }
        }
        return
    }

    set ::enum_scope [ dict create ]

    set ::param_scope [ dict create ]

    set ::block_scope [ dict create ]

    set ::instance_list [ list ]

    set ::instance_scope [ dict create ]

    set ::attribute_scope [ dict create ]

    set ::chaine_scope [ dict create ]

    set ::RTL_To_User_Name_Map [ dict create ]

    set ::User_To_RTL_Name_Map [ dict create ]


    # Lookup this scope then ::enum_scope
    set ::param_type_scope [ dict create integer 32 double 64 string 32 ]

    set ::optionpat {
        ^[\-]([a-z_]+)?$
    }

    set ::version_pat {
        ^\d+(\.\d+){2}$
    }

    set ::simple_id_pat {
        ^[a-zA-Z_]([a-zA-Z0-9\[\]_-]+)?$
    }

    set ::hier_id_pat {
        ^[a-zA-Z_]([a-zA-Z0-9\[\]_-]+)?(\.[a-zA-Z_]([a-zA-Z0-9\[\]_-]+)?)?$
    }

    set ::par_name_ports [ dict create  \
        -name { 1 simple_id hier_id } \
        -ports { -1 list } \
        -force { 0 Nill } \
    ]

set ::pat_block_ports [ dict create  \
    -block { 1 simple_id } \
    -ports { -1 list } \
]

set ::par_name_value_List [ dict create  \
    -name { 1 simple_id hier_id } \
    -values { -1 list } \
    -force { 0 Nill } \
]

set ::attribute_pat [ dict create  \
    -block  {  1 simple_id hier_id } \
    -name   {  1 simple_id } \
    -type   {  1 simple_id } \
    -addr   {  1 integer } \
    -width  {  1 integer } \
    -enum { -1 list } \
    -enumname   {  1 simple_id  hier_id } \
    -force  {  0 Nill } \
]

set ::ric_schema_version 0.0
set ::device_name None
set ::device_version 0.0

proc dm_type value {
    if { [regexp -expanded $::simple_id_pat $value ] } {
        return simple_id
    } elseif { [regexp -expanded $::hier_id_pat $value ] } {
        return hier_id
    } elseif { [regexp -expanded $::version_pat $value ] } {
        return version
    }  elseif { [regexp -expanded $::optionpat $value ] } {
        return option
    }   elseif {[string is integer -strict $value]} {
        return  integer
    } elseif {[string is double -strict $value]} {
        return  double
    } elseif {[string is boolean -strict $value]} {
        return  boolean
    } elseif {[string is xdigit -strict $value]} {
        return  xdigit
    } elseif {[string is alpha -strict $value]} {
        return  alpha
    } elseif {[string is list -strict $value]} {
        return  list
    } else {
        return __unknown_type__
    }
}

proc verify_make_params { params actuals } {
    set idx 0
    set dictRes [dict create valid 1 ]
    while { $idx < [llength $actuals ] } {
        set op [ lindex $actuals $idx ]
        set tp [ dm_type $op ]
        if { $tp != "option" } {
            puts "Too much values for last option at this value \"$op\""
            puts "Got $tp while expecting option"
            dict set dictRes valid 0
            return $dictRes
        }
        if { ! [dict exists $params $op] } {
            puts "Unknown option : $op"
            dict set dictRes valid 0
            return $dictRes
        }
        set valDesc [ dict get $params $op ]
        if { "list" != [ dm_type $valDesc ] } {
            puts "Not well formed option dictionary"
            dict set dictRes valid 0
            return $dictRes
        }
        set numValues [ lindex $valDesc 0 ]
        incr idx
        if { ! $numValues } {
            dict set dictRes $op 1
            continue
        }
        set values {  }
        if { $numValues > 0 } {
            while { $idx < [llength $actuals ] && $numValues } {
                set typeCheck 0
                set i 1
                while { $i < [llength $valDesc ] } {
                    set elem [ lindex $actuals $idx ]
                    set elType [ dm_type $elem ]
                    set expectedType [ lindex $valDesc $i ]
                    set typeCheck [ expr { $typeCheck || [ expr { $elType ==  $expectedType } ] }  ]
                    if { $typeCheck } {
                        lappend values $elem
                        break
                    }
                    incr i
                }
                if { ! $typeCheck } {
                    puts "The option $op takes values of type $expectedType , $elem is of type $elType"
                    dict set dictRes valid 0
                    return $dictRes
                }
                incr idx
                incr numValues -1
            }
            if { $numValues } {
                puts "The option $op takes $numValues values"
                dict set dictRes valid 0
                return $dictRes
            }
            if { [dict exists $dictRes $op] } {
                puts "The option $op is specified twice"
                dict set dictRes valid 0
                return $dictRes
            }
            dict set dictRes $op $values
        }
        if { $numValues == -1 } {
            set cnt 0
            set elem [ lindex $actuals $idx ]
            set elType [ dm_type [ lindex $actuals $idx ] ]
            set expectedType [ lindex $valDesc 1 ]

            set values { }
            while { $idx < [llength $actuals ] && "option" != $elType  } {
                if { $expectedType != $elType } {
                    puts "The option $op takes values of type [ lindex $valDesc 1 ]"
                    dict set dictRes valid 0
                    return $dictRes
                }
                incr idx
                incr cnt
                lappend values $elem
                set elem [ lindex $actuals $idx ]
                set elType [ dm_type [ lindex $actuals $idx ] ]
            }
            if { ! $cnt } {
                puts "The option $op needs at least one argument"
                dict set dictRes valid 0
                return $dictRes
            }
            if { [dict exists $dictRes $op] } {
                puts "The option $op is specified twice"
                dict set dictRes valid 0
                return $dictRes
            }
            dict set dictRes $op $values
        }

    }
    return $dictRes
}

proc add_instance { actual } {
    set block_name [ dict get $actual "-block"]
    set inst_name [ dict get $actual "-name"]
    if { ! [ dict exists $actual "-parent"] } {
        dict set actual "-parent" "__ROOT__"
    }
    set parent_block  [ dict get $actual "-parent"]
    if { ! [ dict exists $::block_scope $block_name ] } {
        puts "Could not find $block_name"
        return -1;
    }
    set global_name "$block_name.$inst_name"
    set id [ llength ::instance_list ]
    dict set actual -id $id
    lappend ::instance_list $actual
    dict set ::instance_scope $global_name $actual
    return $id
}

#===================================================================
#                           RIC Commands
#===================================================================

proc ric_schema_version { args } {
    set tp [ dm_type $args ]
    set dictRes [dict create valid 1 ]
    if { $tp == "list"  || $tp == "double" || $tp == "version" } {
        set ::ric_schema_version $args
        return $dictRes
    }
    puts "Invalid ric_schema_version : $args"
    dict set dictRes valid 0
    return $dictRes
}

proc device_name  { args } {
    set tp [ dm_type $args ]
    set dictRes [dict create valid 1 ]
    if { $tp == "simple_id" } {
        set ::device_name $args
        return $dictRes
    }
    puts "Invalid device_name : $args"
    dict set dictRes valid 0
    return $dictRes
}

proc device_version  { args } {
    set tp [ dm_type $args ]
    set dictRes [dict create valid 1 ]
    if { $tp == "list"  || $tp == "double" || $tp == "version" } {
        set ::device_version $args
        return $dictRes
    }
    puts "Invalid device_version : $args"
    dict set dictRes valid 0
    return $dictRes
}

proc define_enum_type { args } {
    # -name <enumerate>
    # -values { {<name>, value }, …, {<name>, value }, {"default", value } }
    # -force Nill   // Overrides older definition
    # example : puts [ define_enum_type -name myAttrType -values { { one 0x7 } { two 0x2 } { three 0x3} { default 0x9 } } -force ]

    set paramDict $::par_name_value_List
    set actual [ verify_make_params $paramDict $args ]
    set valuesDict [dict create ]
    set max -1
    set min 1000000
    dict set actual valid 0
    foreach elem [ lindex [ dict get $actual "-values" ] 0 ] {
        set tp  [ dm_type $elem ]
        if { $tp != "list" } {
            puts "An enum element should be a name vlue pair"
            return $actual
        }
        set l [ llength $elem]
        if { 2 > $l || 3 < $l } {
            if {$l } {
                puts "An enum element should be a name vlue pair at enum \"[lindex $elem 0]\""
            } else {
                puts "An enum element should be a name vlue pair , empty enum spec$elem in [ dict get $actual "-name" ]"
            }
            return $actual
        }
        set name [lindex $elem 0]
        set value [lindex $elem 1]
        set ntp [ dm_type $name ]
        set vtp [ dm_type $value ]
        if { "simple_id" != $ntp || "integer" != $vtp || $value < 0 } {
            puts "Mal formed attribute element { $elem }"
            return $elem
        }
        if {  [dict exists $valuesDict $name ] } {
            puts "$epeated attribute element { $elem }, ignoring"
            continue
        }
        dict set valuesDict $name $value
        # allows for default value to be un-named to allow forcing an distinct setting when needed
        if { $value < $min } {
            set min $value
        }
        if { $value > $max } {
            set max $value
        }
    }
    set width 1
    set m 1
    while { ($m << $width) <= $max } {
        incr width
    }
    dict set actual "-width" $width
    dict set actual "-values" $valuesDict

    if { ! [dict exists $::enum_scope [ dict get $actual "-name" ] ] || [dict exists $actual "-force" ]} {
        dict set actual valid 1
        dict set ::enum_scope [ dict get $actual "-name" ] $actual
        return 1
    }
    return 0
}

proc define_block  { args } {
    # -name <type>                      string // The name of the currently defined block
    # -ports  <list_of_port_objects>..  [ {DIR port , port} ] // Set of ports
    # Example : define_block -ports { in a b c } { out aa bb cc } { in ss } -name kkk

    set paramDict $::par_name_ports
    set actual  [ verify_make_params $paramDict $args ]
    # Fast access to keys, values not used for now, may get width or usage type (clk)
    set inputs  [ dict create ]
    set outputs [ dict create ]
    dict set actual valid 0
    if { [ dict exists $actual "-ports"] } {
        foreach port_set [ dict get $actual "-ports" ]  {
            if { "in" == [ lindex $port_set 0 ] } {
                set idx 1
                while {$idx < [llength $port_set ] } {
                    set in [ lindex $port_set $idx ]
                    if { "simple_id" != [ dm_type $in ]} {
                        puts "Not a suitable port name $in"
                        return 0
                    }
                    if { [dict exists $outputs $in ] || [dict exists $inputs $in ]} {
                        puts "Duplicated port name $out"
                        return 0
                    }
                    dict set inputs $in 1
                    incr idx
                }
            } elseif {"out" == [ lindex $port_set 0 ]  } {
                set idx 1
                while {$idx < [llength $port_set ] } {
                    set out [ lindex $port_set $idx ]
                    if { "simple_id" != [ dm_type $out ]} {
                        puts "Not a suitable port name $out"
                        return 0
                    }
                    if { [dict exists $outputs $out ] || [dict exists $inputs $out ]} {
                        puts "Duplicated port name $out"
                        return 0
                    }
                    dict set outputs $out 1
                    incr idx
                }
            } else {
                error "Not a Valid specification of ports $port_set, should start with in or out"
                return 0
            }
        }
        dict set actual "-inputs" $inputs
        dict set actual "-outputs" $outputs
    }
    if { ![dict exists $::block_scope [ dict get $actual "-name" ]  ]  || [dict exists $actual "-force" ]} {
        dict set actual valid 1
        dict set ::block_scope [ dict get $actual "-name" ] $actual
        return 1
    }
    return 0
}

# We may encapsilate all Global definitions in a __ROOT__ or __DEVICE_NAME__ module to be able to cleanly handle several Desighs
define_block -name __ROOT__

proc define_param { args } {
    # A parameter is a generalized attribute, it does not, necessarily, have to get an address neither a predefined size
    # -block <block_type_name> O   string // the name of a defined block to insert the attribute in if None then Global.
    # -name <attr_name>        N   string // The name of the currently defined attribute
    # -addr <offset_address>   O   string // Relative address of the attribute in the block config space.
    # -width <nb_bits>         O   int    // Number of bits intended to represent this parameter (to match with type)
    # -type <type_name>        N   string // Number of bits enough to code all possible values of this attribute
    # -force                   O   Nill    // Rewrite existing attribute if any
    # define_param -block GEARBOX -name P1 -addr 0x0 -width 0x4 -type integer
    set paramDict $::attribute_pat
    set actual  [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-name"] || ! [ dict exists $actual "-type"]  } {
        dict set actual valid 0
        puts "The options -name and -type"
        puts "are necessary in the command define_attr : $actual"
        dict set actual valid 0
        return 0
    }
    set name [ dict get $actual "-name" ]
    set type [ dict get $actual "-type" ]
    if { ! [ dict exists $::param_type_scope $type ] && ! [ dict exists $::enum_scope $type ]} {
        puts "Could not find type $type for parameter $name"
        dict set actual valid 0
        return 0
    }
    if { ( [ dict exists $::param_scope $name ] ||
        [ dict exists $::attribute_scope $name ] ) &&
        ! [ dict exists  $actual "-force" ]
        } { puts "Already defined parameter $name, no -force specified"
        dict set actual valid 0
        return 0
    }
    if { [ dict exists  $actual "-width" ] && [ dict get  $actual "-width" ] < 1 } {
    puts "The width of a parameter can not be less than 1"
    dict set actual valid 0
    return 0
}
if { [ dict exists  $actual "-addr" ] && [ dict get  $actual "-addr" ] < 0 } {
    puts "The address of a parameter can not be less than 0"
    dict set actual valid 0
    return 0
}
if { [ dict exists  $actual "-block" ] } {
    set block_name  [ dict get  $actual "-block" ]
    if { ! [dict exists  $::block_scope $block_name]} {
        puts "I could not find the block $block_name for the definition of the parameter $name"
        dict set actual valid 0
        return 0
    } else {
        if { [ dict exists ::block_scope $block_name "-params"  ] } {
            dict set ::block_scope $block_name -params [ dict create ]
        }
        dict set ::block_scope $block_name -params $name $actual
    }
} else {
    dict set ::param_scope $name $actual
}

return [ dict get $actual valid ]
}

proc define_attr { args } {
    # Create an attribute named -name associated with -block (if specified ) and being global (about the device if no -block)
    # the values come from the enum type -enumname if the enumtype -enumname does not exist and -enum is specified we generate
    # the enumtype and call it <-block>.<-enumname> or global__.<-enumname>
    # -block <block_type_name>    string // the name of a defined block to insert the attribute in if None then Global.
    # -name <attr_name>           string // The name of the currently defined attribute
    # -addr <offset_address>      string // Relative address of the attribute in the block config space.
    # -width <nb_bits>            int // Number of bits enough to code all possible values of this attribute
    # -enum { {<name>, value }, …, {<name>, value }, {"default", value } } list // Inline Attribute enumerated values
    # -enumname <enumerate_name>  string // Offline Attribute enumerated values
    # -force                      Nill    // Rewrite existing attribute if any
    # set options {-block -name -addr -width -enum -force }
    # define_attr -block "GEARBOX" -enumname sdsd -name "MODE0" -addr "0x017" -width 8 -enum {Mode_BP_SDR_A_TX 0x012} {Mode_BP_DDR_A_TX 0x013 default} {Mode_RATE_3_A_TX  0x014}

    set paramDict $::attribute_pat
    set actual  [ verify_make_params $paramDict $args ]
    dict set actual valid 0
    if { ! [ dict exists $actual "-name"] || ! [ dict exists $actual "-addr"] || \
        ! [ dict exists $actual "-width"] || ! [ dict exists $actual "-enumname"] } {
        puts "The options -name, -addr, -width and -enumname"
        puts "are necessary in the command define_attr : $actual"
        return 0
    }
    set registeringName ""
    if { [ dict exists $actual "-enumname"] } {
        set baseName global__
        set enName [ dict get $actual "-enumname" ]
        if { [ dict exists $actual "-block"] } {
            set baseName [ dict get $actual "-block" ]
        }
        set registeringName [ string cat $baseName "." $enName ]
        if { ! [ dict exists $::enum_scope $enName ] } {
            if { [ dict exists $actual "-enum"] } {
                set res [ define_enum_type -name $registeringName -values [ dict get $actual "-enum" ] ]
                set defWidth [ dict get [ dict get $::enum_scope $registeringName ] "-width" ]
                set actualWidth [ dict get $actual "-width"]
                if { $defWidth > $actualWidth } {
                    puts "The specified width of $actualWidth is not enough to represent all the values of the attribute [ dict get $actual "-name"]"
                    puts "At least $defWidth bits are needed"
                    dict set actual valid 0
                    return 0
                }
            } else {
                puts "Could not find the definition of $enName and no inline definition is provided to define it"
                dict set actual valid 0
                return 0
            }
            dict set actual -type $registeringName
        } else {
            dict set actual -type $enName
        }
    } else {
        puts "Should not reach here DBG"
    }
    # ::attribute_scope
    if { [ dict exists $actual "-block"] } {
        set bName [ dict get $actual "-block"]
        set attributeName [ dict get $actual "-name"]
        if { ! [ dict exists $::block_scope $bName] } {
            puts "Could not find the block $bName"
            dict set actual valid 0
            return 0
        } else {
            if { [ dict exists [ dict get $::block_scope $bName] "-attributes" ] } {
                dict set ::block_scope $bName -attributes $attributeName $actual
            } else {
                dict set ::block_scope $bName -attributes [ dict create $attributeName $actual]
            }
        }
    } else {
        dict set ::attribute_scope [ dict get $actual "-name"] $actual
    }
    dict set actual valid 1
    return 1
}

proc define_ports { args } {
    # -block <block_type_name>    string // the name of a defined block to insert the port in
    # -ports <port_list>          list // a list of port definitions atarting by in/out each time
    set paramDict $::pat_block_ports
    set actual  [ verify_make_params $paramDict $args ]
    set inputs  [ dict create ]
    set outputs [ dict create ]
    dict set actual valid 0
    if { [ dict exists $actual "-block"] && [ dict exists $actual "-ports"] } {
        set block_name  [ dict get  $actual "-block" ]
        if { ! [dict exists  $::block_scope $block_name]} {
            puts "I could not find the block $block_name for the definition of ports $actual"
            dict set actual valid 0
            return 0
        }
        foreach port_set [ dict get $actual "-ports" ]  {
            if { "in" == [ lindex $port_set 0 ] } {
                set idx 1
                while {$idx < [llength $port_set ] } {
                    set in [ lindex $port_set $idx ]
                    if { "simple_id" != [ dm_type $in ]} {
                        puts "Not a suitable port name $in"
                        return 0
                    }
                    if { [dict exists $outputs $in ] || [dict exists $inputs $in ]} {
                        puts "Duplicated port name $out"
                        return 0
                    }
                    dict set inputs $in 1
                    incr idx
                }
            } elseif {"out" == [ lindex $port_set 0 ]  } {
                set idx 1
                while {$idx < [llength $port_set ] } {
                    set out [ lindex $port_set $idx ]
                    if { "simple_id" != [ dm_type $out ]} {
                        puts "Not a suitable port name $out"
                        return 0
                    }
                    if { [dict exists $outputs $out ] || [dict exists $inputs $out ]} {
                        puts "Duplicated port name $out"
                        return 0
                    }
                    dict set outputs $out 1
                    incr idx
                }
            } else {
                error "Not a Valid specification of ports $port_set, should start with in or out"
                return 0
            }
        }
        if { [llength [dict keys $inputs] ]} {
            if { ! [ dict exists $::block_scope $block_name -inputs ] } {
                dict set ::block_scope $block_name -inputs [ dict create ]
            }
            foreach port_name [dict keys $inputs] {
                dict set ::block_scope $block_name -inputs $port_name 1
            }
        }
        if { [llength [dict keys $outputs] ]} {
            if { ! [ dict exists $::block_scope $block_name -outputs ] } {
                dict set ::block_scope $block_name -outputs [ dict create ]
            }
            foreach port_name [dict keys $outputs] {
                dict set ::block_scope $block_name -outputs $port_name 1
            }
        }
    } else {
        puts "A port definition must have a -block and a -ports parameter."
        return 0
    }
}

proc define_constraint { args } {
    # -block <block_type_name>          // Inner block constraint in the form of SV implication
    # -contraint <sv-like-implication>  // Inner block constraint in the form of SV implication
    # set options {-block }
    set pat_constraint [ dict create  -block { 1 simple_id } -constraint { -1 list } ]
    set paramDict $pat_constraint
    set actual [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-block"] || ! [ dict exists $actual "-constraint"]  } {
        dict set actual valid 0
        puts "The options -block and -constraint"
        puts "are necessary in the command define_constraint : $actual"
        dict set actual valid 0
        return 0
    }
    set block_name [ dict get $actual "-block" ]
    set const [ dict get $actual "-constraint" ]
    if { ! [dict exists  $::block_scope $block_name]} {
        puts "I could not find the block $block_name for the definition of the constraint $actual"
        dict set actual valid 0
        return 0
    }
    set key "Constraint0"
    if { ! [dict exists  $::block_scope $block_name -constraint ] } {
        dict set ::block_scope $block_name -constraint [dict create ]
    } else {
        set idx 1
        while { [ dict exists $::block_scope $block_name -constraint $key ] } {
            set key "Constraint$idx"
            incr idx
        }
    }
    dict set ::block_scope $block_name -constraint $key $const
    return 1
}

proc define_net { args } {
    # -name <net_name>                string // The name of the currently defined net.
    # -block <block_type_name>        string //
    # -source <net_name/port_name>    string // The name of the driver of the currently defined net.
    # examples :
    # define_net  -block __ROOT__ -name clk -source src -isclock 1
    # define_net  -block GEARBOX -name clk -source __ROOT__.clk -isclock 1
    # define_net  -block __ROOT__ -name data\[0\] -source GEARBOX.port1

    set pat_net_def [ dict create  -block { 1 simple_id } -name { 1 simple_id } -source { 1 simple_id hier_id } -isclock { 1 integer } ]
    set paramDict $pat_net_def
    set actual [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-block"] || ! [ dict exists $actual "-name"]  } {
        dict set actual valid 0
        puts "The options -block and -name"
        puts "are necessary in the command define_net : $actual"
        dict set actual valid 0
        return 0
    }
    set block_name [ dict get $actual "-block" ]
    set net_name [ dict get $actual "-name" ]
    if { ! [dict exists  $::block_scope $block_name]} {
        puts "I could not find the block $block_name for the definition of the net $actual"
        dict set actual valid 0
        return 0
    }
    if { [dict exists $actual -source ] } {
        set src_name [ dict get $actual "-source"]
        set src_name_type [ dm_type $src_name ]
        if { "simple_id" == $src_name_type && $block_name != "__ROOT__" &&
            (   ! [ dict exists  $::block_scope $block_name -nets   $src_name ] &&
            ! [ dict exists  $::block_scope $block_name -inputs $src_name ] )} {
            puts "Could not find the driver $src_name of the net $actual"
            dict set actual valid 0
            return 0

            } else { # A hierarchical name a.b.c

            }
        }
        if { ! [dict exists  $::block_scope $block_name -nets ] } {
        dict set ::block_scope $block_name -nets [dict create ]
    }
    dict set ::block_scope $block_name -nets $net_name $actual
}

proc drive_net { args } {
    # -block <block_type_name>        string  // Inner block constraint in the form of SV implication
    # -name <net_name>                string  // The name of the currently driven net.
    # -source <net_name/port_name>    string  // The name of the driver of the currently driven net.
    # example : define_net  -block __ROOT__ -name clk -source aaa -isclock 1
    #           drive_net   -block __ROOT__ -name clk -source aaaTsu -isclock 1
    set pat_net_def [ dict create  -block { 1 simple_id } -name { 1 simple_id } -source { 1 simple_id hier_id } -isclock { 1 integer } ]
    set paramDict $pat_net_def
    set actual [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-block"] || ! [ dict exists $actual "-name"] || ! [ dict exists $actual "-source"]  } {
        dict set actual valid 0
        puts "The options -block, -source and -name"
        puts "are necessary in the command define_net : $actual"
        dict set actual valid 0
        return 0
    }
    set block_name  [ dict get $actual "-block" ]
    set net_name    [ dict get $actual "-name"  ]
    set src_name    [ dict get $actual "-source"]
    # Looking for a local (relatively to the defined net) source
    if { ! [dict exists  $::block_scope $block_name -nets $net_name ] ||
        (   ! [ dict exists  $::block_scope $block_name -nets   $src_name ] &&
        ! [ dict exists  $::block_scope $block_name -inputs $src_name ]  && $block_name != "__ROOT__" ) } {
        puts "Could not find the block $block_name or the driver $src_name of the net $actual"
        dict set actual valid 0
        return 0
    }
    # setting the source
    dict set  ::block_scope $block_name -nets $net_name -source $src_name

}

proc create_instance { args } {
    # -block <block_type_name>        string      // the name of a defined block we are instanciating
    # -name <instance_name>           string      // the currently defined instance name
    # -id <instance_id>               int         // A per design unique instance id (Should be automatic)
    # -logic_location                 {int, int}  // Logic Location (VPR)
    # -logic_address <logical_address> int        // Logic address in chain
    # -io_bank <io_bank_name> (optional)  string  // IO bank name
    # -parent <block_type>    (optional)  string  // Parent block (Creates hierarchy – like Verilog folded model)
    # set options {-block -name -logic_location -logic_address -io_bank -parent }
    set pat_inst_def [ dict create  -block { 1 simple_id } \
        -name { 1 simple_id } \
        -logic_location { 1 list } \
        -id { 1 integer } \
        -logic_address { 1 integer }  \
        -io_bank { 1 simple_id } \
        -parent { 1 simple_id }  ]
    set paramDict $pat_inst_def
    set actual [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-block"] || ! [ dict exists $actual "-name"]  }  {
        puts "You have to define the options -block and -name for the command create_instance"
        dict set actual valid 0
        return 0
    }
    return [ add_instance $actual ]
}

proc define_chain { args } {
    # -type <type>                    string      // The name of the currently created chain
    set pat_chain_def [ dict create -type { 1 simple_id } ]
    set paramDict $pat_chain_def
    set actual [ verify_make_params $paramDict $args ]
    if { ! [ dict exists $actual "-type" ] } {
        error "Missisn chain type"
        return 0;
    }
    set type [ dict get $actual "-type" ]
    dict set ::chaine_scope $type  { }
    return 1
}

proc add_block_to_chain_type { args } {
    # -type <chain_type_name>         string      // The name of the currently created chain
    # -block <block_type_name>        string      // The name of the currently created chain
    set pat_add_b_chain_def [ dict create -type { 1 simple_id } -block { 1 simple_id } ]
    set actual [ verify_make_params $pat_add_b_chain_def $args ]
    if { ! [ dict exists $actual "-type" ] || ! [ dict exists $actual "-block" ] } {
        error "Missisn chain type or block type"
        return 0;
    }
    set type [dict get $actual "-type" ]
    set block [dict get $actual "-block" ]
    set lst [ dict get $::chaine_scope $type ]
    lappend lst $block
    dict set ::chaine_scope $type $lst
    return 1
}

proc create_chain_instance { args } {
    # -type <chain_type_name>                     string // The name of the instanciated chain
    # -name <chain_instance_name>                 string // The name of the currently defined chain instance
    # -start_address <START_LOGICAL_ADDRESS>      int    // Logic address
    # -end_address <END_LOGICAL_ADDRESS>          int    // Logic address
    #  
    set pat_chain_inst [ dict create \
        -type { 1 simple_id } \
        -name { 1 simple_id } \
        -start_address { 1 integer } \
        -end_address { 1 integer } ]
    set actual [ verify_make_params $pat_chain_inst $args ]

    if { ! [ dict exists $actual "-type" ] || ! [ dict exists $actual "-name" ]  || \
     ! [ dict exists $actual "-type" ] || ! [ dict exists $actual "-name" ]   } {
        error "Missisn chain option -type, -name, -start_address or -end_address"
        return 0;
    }
    set type [ dict get $actual "-type" ]
    set name [ dict get $actual "-name" ]
    dict set actual -instances {}
    dict set ::instance_chaine_scope $name  $actual
    return 1
}

proc link_chain { args } {
    # -inst <block_instance_name>          string      // The name of the currently created chain
    # -chain <chain_instance_name>          string      // The name of the currently created chain
    set link_chain_pat [ dict create -inst { 1 simple_id } -chain { 1 simple_id } ]
    set actual [ verify_make_params $link_chain_pat $args ]
    if { ! [ dict exists $actual "-inst" ] || ! [ dict exists $actual "-chain" ] } {
        error "Missisn chain or inst in link_chain"
        return 0;
    }
    set inst [ dict get $actual "-inst" ]
    set chain [ dict get $actual "-chain" ]
    set lst  [ dict get $::instance_chaine_scope $chain "-instances" ]
    lappend lst $inst
    dict set ::instance_chaine_scope $chain "-instances" $lst
    return 1
}

proc append_instance_to_chain  { args } {
    # -inst <block_instance_name>          string      // The name of the currently created chain
    # -chain <chain_instance_name>          string      // The name of the currently created chain
    set link_chain_pat [ dict create -inst { 1 simple_id } -chain { 1 simple_id } ]
    set actual [ verify_make_params $link_chain_pat $args ]
    if { ! [ dict exists $actual "-inst" ] || ! [ dict exists $actual "-chain" ] } {
        error "Missisn chain or inst in link_chain"
        return 0;
    }
    set inst [ dict get $actual "-inst" ]
    set chain [ dict get $actual "-chain" ]
    set lst  [ dict get $::instance_chaine_scope $chain "-instances" ]
    lappend lst $inst
    dict set ::instance_chaine_scope $chain "-instances" $lst
    return 1
}

proc map_rtl_user_names  { args } {
    # -rtl_name  <rtl_sig_name>          string      // The name of the signal in the RTL level
    # -user_name <rtl_sig_name>          string      // The name of the signal as seen/set by Raptor user
    # Example : 

    set rtl_user_name_pat [ dict create -rtl_name { 1 simple_id } -user_name { 1 simple_id } ]
    set actual [ verify_make_params $rtl_user_name_pat $args ]
    if { ! [ dict exists $actual "-rtl_name" ] || ! [ dict exists $actual "-user_name" ] } {
        error "Missisn rtl name or user name for rtl/user name association"
        return 0;
    }
    set rtl_name [ dict get $actual "-rtl_name" ]
    set user_name [ dict get $actual "-user_name" ]
   # Any call will override previous associations
    dict set ::RTL_To_User_Name_Map $rtl_name $user_name
    dict set ::User_To_RTL_Name_Map $user_name $rtl_name
    return 1
}

proc get_user_name  { args } {
    # -rtl_name  <rtl_sig_name>          string      // The name of the signal in the RTL level
    set get_user_name_pat [ dict create -rtl_name { 1 simple_id } ]
    set actual [ verify_make_params $get_user_name_pat $args ]
    if { ! [ dict exists $actual "-rtl_name" ] } {
        error "Missisn rtl name to retreive associated user name"
        return 0;
    }
    set rtl_name [ dict get $actual "-rtl_name" ]
    set user_name [ dict get $::RTL_To_User_Name_Map $rtl_name ]
    return $user_name
}

proc get_rtl_name  { args } {
    # -user_name  <rtl_sig_name>          string      // The name of the signal in the RTL level
    set get_rtl_name_pat [ dict create -user_name { 1 simple_id } ]
    set actual [ verify_make_params $get_rtl_name_pat $args ]
    if { ! [ dict exists $actual "-user_name" ] } {
        error "Missisn user name to retreive associated rtl name"
        return 0;
    }
    set user_name [ dict get $actual "-user_name" ]
    set rtl_name [ dict get $::User_To_RTL_Name_Map $user_name ]
    return $rtl_name
}

proc drive_port { args } {
    # -name <port_name>               string  // The name of the currently driven net.
    # -source <net_name/port_name>    string  // The name of the driver of the currently driven net.
    # // port_name should be in the format instance_name.port_name

    set options {-name -source }
}

proc get_block_names { args } {
    # -reg <regular_expression>       string  // The regular expression that the names match, all if empty
    set options {-reg }
}

proc get_ports { args } {
    # -reg <regular_expression>       string  // The regular expression that the names match, all if empty
    set options {-reg }
}

proc get_instance_names { args } {
    # -reg <regular_expression>       string  // The regular expression that the names match, all if empty
    set options {-reg }
}

proc get_instance_id { args } {
    # -instance <instance_name>       string  //
    set options {-instance }
}

proc get_instance_block_name { args } {
    # -instance <instance_name>       string  //
    set options {-instance }
}

proc get_instance_by_id { args } {
    # -id <instance_id>               int     //
    set options {-id }
}

proc get_instance_id_set { args } {
    # -block <block_name>             string  //
    set options {-block }
}

proc get_instance_name_set { args } {
    # -block <block_name>             string  //
    set options {-block }
}

proc get_attributes { args } {
    # -block <block_name>             string  //
    set options {-block }
}

proc get_constraints { args } {
    # -block <block_name>             string  //
    set options {}
}

proc get_attributes { args } {
    # -instance <instance_name>               string  // The name of
    set options {-instance }
}

proc get_constraints { args } {
    # -instance <instance_name>               string  // The name of
    set options {-instance }
}

proc get_port_connections { args } {
    # -instance <instance_name>               string  // The name of
    set options {-instance }
}

proc get_chain_names { args } {
    # -device <device_name>               string  // The name of
    set options {-device }
}

proc get_parent { args } {
    # -instance <instance_name>               string  // The name of
    set options {-instance }
}

proc get_port_connection_source { args } {
    # -port_conn <port_conn_name>             string  // The name of the port instance_name::port_name
    set options {-port_conn }
}

proc get_port_connection_sink_set { args } {
    # -port_conn <port_conn_name>             string  // The name of the port instance_name::port_name
    set options {-port_conn }
}

proc get_net_source { args } {
    # -net <net_name>                         string  // The name of the net
    set options {-net }
}

proc get_net_sink_set { args } {
    # -net <net_name>                         string  // The name of the net
    set options {-net }
}

proc get_logic_location { args } {
    # -instance <instance_name>  |            string  // The name of the instance from which we are reading.
    # -id <id>                                int     //

    set options {-instance -id }
}

proc set_logic_location  { args } {
    # -instance <instance_name>   |           string  // The name of the instance from which we are reading.
    # -id <id>                                 int     //
    # -location <liocation>                   {int, int} //
    set options {-instance -id -location }
}

proc get_logic_address { args } {
    # -instance <instance_name>               string  // The name of the instance from which we are reading.
    set options {-instance }
}

proc get_io_bank { args } {
    # -instance <instance_name>   |           string  // The name of the instance from which we are reading.
    # -id <id>
    set options {-instance -id }
}

proc set_io_bank  { args } {
    # -instance <instance_name>   |           string  // The name of the instance from which we are reading.
    # -id <id>
    # -io_bank {$IO_BANK}

    set options {-instance -id -io_bank }
}

proc get_phy_address  { args } {
    # -instance <instance_name>  |            string  // The name of the instance from which we are reading.
    # -id <id>                                int     //
    set options {-instance -id }
}

proc set_phy_address  { args } {
    # -instance <instance_name>   |           string  // The name of the instance from which we are reading.
    # -id <id>                                int     //
    # -address <ph_address>            int     //
    set options {-instance -id -address }
}

source $model

puts "RIC: Done."

