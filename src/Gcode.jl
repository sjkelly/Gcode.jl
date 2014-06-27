module Gcode

import Base.write

export G, write, move, meander

type G
    output::IO
    echo::Bool
    header::String
    footer::String
    position::Dict
    absolute::Bool
    feedrate::Real
    flavor::String
    view::Bool
end

function G(;output::String = "",
            echo::Bool = false,
            header::String = "",
            footer::String = "",
            position::Dict = Dict{String, Float64}(),
            absolute::Bool = true,
            feedrate::Real = 0,
            flavor::String = "Marlin",
            view::Bool = false)
    
    io = (output != "") ? open(output, "w") : STDOUT
    if header != ""
        write(io, readall(open(header, "r")))
    end
    
    
    return G(io,echo,header,footer,position,absolute,feedrate,flavor,view)
end

function format_args(;args...)
    str = ""
    for (key, val) in args
        str *= uppercase(string(" ", key, val))
    end
    return str
end

function write(g::G, x)
    str = string(x)
    write(g.output, str*"\n")
    if g.echo; println(str); end
end

function set_home!(g::G; args...):
    """ Set the current position to the given position without moving.

Example
-------
>>> # set the current position to X=0, Y=0
>>> g.set_home(0, 0)

"""
    write(g, "G92"*format_args(;args...))

    updateposition!(g, args)
end

function relative!(g::G):
    """ Enter relative movement mode, in general this method should not be
used, most methods handle it automatically.

"""
    write(g, "G91")
    g.absolute = false
end


function absolute!(g::G):
    """ Enter absolute movement mode, in general this method should not be
used, most methods handle it automatically.

"""
    write(g,"G90")
    g.absolute = true
end

function update_position!(g::G; args...)
    for (axis, delta) in args
        axis_str = string(axis)
        if haskey(g.position, axis_str)
            if !g.absolute
                g.position[axis_str] += delta
            else
                g.position[string(axis)] = delta
            end
        else
            merge!(g.position, [axis_str=>delta])
        end
    end
end

function feedrate!(g::G, rate)
    """ Set the feed rate (tool head speed) in mm/s

Parameters
----------
rate : float
The speed to move the tool head in mm/s.

"""
    write(g, rate)
end

function dwell(g::G, time)
    """ Pause code executions for the given amount of time.

Parameters
----------
time : float
Time in seconds to pause code execution.

"""
    write(g, "G4 P"*string(time))
end

function teardown(g::G)
    """ Close the outfile file after writing the footer if opened. This
method must be called once after all commands.

"""
    if g.footer != ""
        write(g.output, readall(open(g.footer, "r")))
    end
end

function home(self):
    """ Move the tool head to the home position (X=0, Y=0).
"""
    self.abs_move(x=0, y=0)
end

function move(g::G ; args...)
    """ Move the tool head to the given position. This method operates in
relative mode unless a manual call to `absolute` was given previously.
If an absolute movement is desired, the `abs_move` method is
recommended instead.

Examples
--------
>>> # move the tool head 10 mm in x and 10 mm in y
>>> g.move(x=10, y=10)
>>> # the x and y keywords may be omitted:
>>> g.move(10, 10)

>>> # move the A axis up 20 mm
>>> g.move(A=20)

"""
    update_position!(g;args...)

    args = format_args(;args...)
    write(g, "G1 " * args)
end


function abs_move(g::G ; args...)
    """ Same as `move` method, but positions are interpreted as absolute.
"""
    if !g.absolute
        absolute!(g)
        move(g;args...)
        relative!(g)
    else #already absolute
        move(g;args...)
    end
end

#function arc(self, direction='CW', radius='auto', helix_dim=None, helix_len=0,
#        **kwargs):
#    """ Arc to the given point with the given radius and in the given
#direction. If helix_dim and helix_len are specified then the tool head
#will also perform a linear movement through the given dimension while
#completing the arc.

#Parameters
#----------
#points : floats
#Must specify two points as kwargs, e.g. X=5, Y=5
#direction : str (either 'CW' or 'CCW') (default: 'CW')
#The direction to execute the arc in.
#radius : 'auto' or float (default: 'auto')
#The radius of the arc. A negative value will select the longer of
#the two possible arc segments. If auto is selected the radius will
#be set to half the linear distance to desired point.
#helix_dim : str or None (default: None)
#The linear dimension to complete the helix through
#helix_len : float
#The length to move in the linear helix dimension.

#Examples
#--------
#>>> # arc 10 mm up in y and 10 mm over in x with a radius of 20.
#>>> g.arc(x-10, y=10, radius=20)

#>>> # move 10 mm up on the A axis, arcing through y with a radius of 20
#>>> g.arc(A=10, y=0, radius=20)

#>>> # arc through x and y while moving linearly on axis A
#>>> g.arc(x=10, y=10, radius=50, helix_dim='A', helix_len=5)

#"""
#    msg = 'Must specify point with 2 dimensions as keywords, e.g. X=0, Y=10'
#    if len(kwargs) != 2:
#        raise RuntimeError(msg)
#    dimensions = [k.lower() for k in kwargs.keys()]
#    if 'x' in dimensions and 'y' in dimensions:
#        plane_selector = 'G17' # XY plane
#        axis = helix_dim
#    elif 'x' in dimensions:
#        plane_selector = 'G18' # XZ plane
#        dimensions.remove('x')
#        axis = dimensions[0].upper()
#    elif 'y' in dimensions:
#        plane_selector = 'G19' # YZ plane
#        dimensions.remove('y')
#        axis = dimensions[0].upper()
#    else:
#        raise RuntimeError(msg)

#    if direction == 'CW':
#        command = 'G2'
#    elif direction == 'CCW':
#        command = 'G3'

#    values = kwargs.values()
#    if self.movement_mode == 'relative':
#        dist = math.sqrt(values[0] ** 2 + values[1] ** 2)
#    else:
#        k = kwargs.keys()
#        cp = self.current_position
#        dist = math.sqrt(
#            (cp[k[0]] - values[0]) ** 2 + (cp[k[1]] - values[1]) ** 2
#        )
#    if radius == 'auto':
#        radius = dist / 2.0
#    elif radius < dist / 2.0:
#        msg = 'Radius {} to small for distance {}'.format(radius, dist)
#        raise RuntimeError(msg)

#    if axis is not None:
#        self.write('G16 X Y {}'.format(axis)) # coordinate axis assignment
#    self.write(plane_selector)
#    args = ' '.join([(k.upper() + str(v)) for k, v in kwargs.items()])
#    if helix_dim is None:
#        self.write('{} {} R{}'.format(command, args, radius))
#    else:
#        self.write('{} {} R{} G1 {}{}'.format(command, args, radius,
#                                              helix_dim.upper(), helix_len))
#        kwargs[helix_dim] = helix_len

#    self._update_current_position(**kwargs)
#end

#function abs_arc(self, direction='CW', radius='auto', **kwargs):
#    """ Same as `arc` method, but positions are interpreted as absolute.
#"""
#    self.absolute()
#    self.arc(direction=direction, radius=radius, **kwargs)
#    self.relative()
#end

function rect(g, x, y; direction::String="CW", start::String="LL"):
    """ Trace a rectangle with the given width and height.

Parameters
----------
x : float
The width of the rectangle in the x dimension.
y : float
The heigh of the rectangle in the y dimension.
direction : str (either 'CW' or 'CCW') (default: 'CW')
Which direction to complete the rectangle in.
start : str (either 'LL', 'UL', 'LR', 'UR') (default: 'LL')
The start of the rectangle - L/U = lower/upper, L/R = left/right
This assumes an origin in the lower left.

Examples
--------
>>> # trace a 10x10 clockwise square, starting in the lower left corner
>>> g.rect(10, 10)

>>> # 1x5 counterclockwise rect starting in the upper right corner
>>> g.rect(1, 5, direction='CCW', start='UR')

"""
    start = uppercase(start)
    direction = uppercase(direction)
    if direction == "CW"
        if start == "LL"
            move(g, y=y)
            move(g, x=x)
            move(g, y=-y)
            move(g, x=-x)
        elseif start == "UL"
            move(g, x=x)
            move(g, y=-y)
            move(g, x=-x)
            move(g, y=y)
        elseif start == "UR"
            move(g, y=-y)
            move(g, x=-x)
            move(g, y=y)
            move(g, x=x)
        elseif start == "LR"
            move(g, x=-x)
            move(g, y=y)
            move(g, x=x)
            move(g, y=-y)
        end
    elseif direction == "CCW"
        if start == "LL"
            move(g, x=x)
            move(g, y=y)
            move(g, x=-x)
            move(g, y=-y)
        elseif start == "UL"
            move(g, y=-y)
            move(g, x=x)
            move(g, y=y)
            move(g, x=-x)
        elseif start == "UR"
            move(g, x=-x)
            move(g, y=-y)
            move(g, x=x)
            move(g, y=y)
        elseif start == "LR"
            move(g, y=y)
            move(g, x=-x)
            move(g, y=-y)
            move(g, x=x)
        end
    end
end

function meander(g::G, x, y, spacing; start="LL", orientation="x", tail=false):
    """ Infill a rectangle with a square wave meandering pattern. If the
relevant dimension is not a multiple of the spacing, the spacing will
be tweaked to ensure the dimensions work out.

Parameters
----------
x : float
The width of the rectangle in the x dimension.
y : float
The heigh of the rectangle in the y dimension.
spacing : float
The space between parallel meander lines.
start : str (either 'LL', 'UL', 'LR', 'UR') (default: 'LL')
The start of the meander - L/U = lower/upper, L/R = left/right
This assumes an origin in the lower left.
orientation : str ('x' or 'y') (default: 'x')

Examples
--------
>>> # meander through a 10x10 sqaure with a spacing of 1mm starting in
>>> # the lower left.
>>> g.meander(10, 10, 1)

>>> # 3x5 meander with a spacing of 1 and with parallel lines through y
>>> g.meander(3, 5, spacing=1, orientation='y')

>>> # 10x5 meander with a spacing of 2 starting in the upper right.
>>> g.meander(10, 5, 2, start='UR')

"""
    start = uppercase(start)
    if start == "UL"
        x, y = x, -y
    elseif start == "UR"
        x, y = -x, -y
    elseif start == "LR"
        x, y = -x, y
    end

    # Major axis is the parallel lines, minor axis is the jog.
    orientation = lowercase(orientation)
    if orientation == "x"
        major, major_name = x, :x
        minor, minor_name = y, :y
    else
        major, major_name = y, :y
        minor, minor_name = x, :x
    end

    if minor > 0
        passes = ceil(minor / spacing)
    else
        passes = abs(floor(minor / spacing))
    end
    actual_spacing = minor / passes
    if abs(actual_spacing) != spacing
        msg = "meander spacing updated from $spacing to $actual_spacing"
        warn(msg)
        write(g, ";"*msg)
    end
    spacing = actual_spacing
    sign = 1
    relative!(g)
    for _ in 1:passes
        move(g;{major_name => (sign * major)}...)
        move(g;{minor_name => spacing}...)
        sign = -1 * sign
    end
    if tail == false
        move(g;{major_name => (sign * major)}...)
    end
end

end # module
