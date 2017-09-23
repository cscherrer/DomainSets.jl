# interval.jl

##################
### An interval
##################

abstract type AbstractInterval{T} <: Domain{T}
end

ndims(::Type{D}) where {D <: AbstractInterval} = 1

"The left endpoint of the interval."
leftendpoint(d::AbstractInterval) = d.a

"The right endpoint of the interval."
rightendpoint(d::AbstractInterval) = d.b

isempty(d::AbstractInterval) = leftendpoint(d) > rightendpoint(d)

approx_indomain(x, d::AbstractInterval, tolerance) =
    (x <= rightendpoint(d)+tolerance) && (x >= leftendpoint(d)-tolerance)

function infimum(d::AbstractInterval{T}) where T
    a = leftendpoint(d)
    b = rightendpoint(d)
    a > b && throw(ArgumentError("Infimum not defined for empty intervals"))
    a
end

function supremum(d::AbstractInterval{T}) where T
    a = leftendpoint(d)
    b = rightendpoint(d)
    a > b && throw(ArgumentError("Supremum not defined for empty intervals"))
    b
end

function point_in_domain(d::AbstractInterval)
    isempty(d) && throw(BoundsError())
    one(eltype(d))/2 * (leftendpoint(d) + rightendpoint(d))
end


## Some special intervals
# - the unit interval [0,1]
# - the 'Chebyshev' interval [-1,1]

"""
The abstract type `FixedInterval` is the supertype of intervals with endpoints
determined by the type, rather than field values. Examples include `UnitInterval`
and `ChebyshevInterval`.
"""
abstract type FixedInterval{T} <: AbstractInterval{T}
end

# We assume by default that fixed intervals are closed. Override if they aren't.
isclosed(d::FixedInterval) = true
isopen(d::FixedInterval) = false

# We also assume that the domain is compact. Override if it is not.
iscompact(d::FixedInterval) = true

# We assume a closed domain for membership.
indomain(x, d::FixedInterval) = leftendpoint(d) <= x <= rightendpoint(d)

"""
Return an interval that is similar to the given interval, but with endpoints
`a` and `b` instead.
"""
# Assume a closed interval by default
similar_interval(d::FixedInterval{T}, a, b) where {T} = ClosedInterval{T}(a, b)


"The closed unit interval [0,1]."
struct UnitInterval{T} <: FixedInterval{T}
end

unitinterval(::Type{T} = Float64) where {T} = UnitInterval{T}()

leftendpoint(d::UnitInterval{T}) where {T} = zero(T)
rightendpoint(d::UnitInterval{T}) where {T} = one(T)

minimum(d::UnitInterval) = infimum(d)
maximum(d::UnitInterval) = supremum(d)


"The closed interval [-1,1]."
struct ChebyshevInterval{T} <: FixedInterval{T}
end

leftendpoint(d::ChebyshevInterval{T}) where {T} = -one(T)
rightendpoint(d::ChebyshevInterval{T}) where {T} = one(T)

minimum(d::ChebyshevInterval) = infimum(d)
maximum(d::ChebyshevInterval) = supremum(d)


real_line(::Type{T} = Float64) where {T <: AbstractFloat} = FullSpace{T}()


"The half-open positive halfline `[0,∞)`."
struct Halfline{T} <: FixedInterval{T}
end

halfline(::Type{T} = Float64) where {T <: AbstractFloat} = Halfline{T}()

leftendpoint(d::Halfline{T}) where {T} = zero(T)
rightendpoint(d::Halfline{T}) where {T} = T(Inf)


minimum(d::Halfline) = infimum(d)
maximum(d::Halfline) = throw(ArgumentError("$d is unbounded. Use supremum."))

# A half-open domain is neither open nor closed
isclosed(d::Halfline) = false
isopen(d::Halfline) = false

iscompact(d::Halfline) = false

indomain(x, d::Halfline) = x >= 0

function similar_interval(d::Halfline, a, b)
    @assert a == 0
    @assert isinf(b) && b > 0
    d
end

point_in_domain(d::Halfline) = zero(eltype(d))


"The open negative halfline `(-∞,0)`."
struct NegativeHalfline{T} <: FixedInterval{T}
end

negative_halfline(::Type{T} = Float64) where {T <: AbstractFloat} = NegativeHalfline{T}()

leftendpoint(d::NegativeHalfline{T}) where {T} = -T(Inf)
rightendpoint(d::NegativeHalfline{T}) where {T} = zero(T)


minimum(d::NegativeHalfline) = throw(ArgumentError("$d is unbounded. Use infimum."))
maximum(d::NegativeHalfline) = supremum(d)

isclosed(d::NegativeHalfline) = false
isopen(d::NegativeHalfline) = true

iscompact(d::NegativeHalfline) = false

indomain(x, d::NegativeHalfline) = x < 0

function similar_interval(d::NegativeHalfline, a, b)
    @assert isinf(a) && a < 0
    @assert b == 0
    d
end

point_in_domain(d::NegativeHalfline) = -one(eltype(d))



"""
A general interval with endpoints `a` and `b`. The interval can be open or
closed at each endpoint. This is determined by the `L` and `R` type parameters,
which may be `:open` or `:closed`.
"""
struct Interval{L,R,T} <: AbstractInterval{T}
    a     ::  T
    b     ::  T

    # The interval defaults to the unit interval.
    function Interval{L,R,T}(a = 0, b = 1) where {L,R,T}
        # We only allow finite values for a and b
        @assert isfinite(a)
        @assert isfinite(b)
        new{L,R,T}(a,b)
    end
end

"A closed interval `[a,b]`."
const ClosedInterval{T} = Interval{:closed,:closed,T}

"An open interval `(a,b)`."
const OpenInterval{T} = Interval{:open,:open,T}

"A half-open interval `(a,b]`."
const HalfOpenLeftInterval{T} = Interval{:open,:closed,T}

"A half-open interval `[a,b)`."
const HalfOpenRightInterval{T} = Interval{:closed,:open,T}

"""
Return an interval domain:
- with no arguments, return the unit interval `[0,1]`
- with an argument of type T, return the unit interval with that type
- with arguments `interval(a,b)`, return the closed interval `[a,b]`
"""
interval() = unitinterval()

interval(::Type{T}) where {T} = UnitInterval{T}()

# Create a floating point interval by default. The knowledgeable user can construct
# an interval of integers by calling ClosedInterval{T} directly.
interval(a::T, b::T) where {T <: Integer} = interval(float(a), float(b))

# By default we create a closed interval
interval(args...) = closed_interval(args...)

closed_interval(args...) = ClosedInterval(args...)
open_interval(args...) = OpenInterval(args...)

# By default we use a Float64 type
Interval{L,R}() where {L,R} = Interval{L,R,Float64}()

Interval{L,R}(a::T, b::S) where {L,R,T,S} = Interval{L,R}(promote(a,b)...)

Interval{L,R}(a::T, b::T) where {L,R,T} = Interval{L,R,T}(a, b)

Interval{L,R}(::Type{T}, a, b) where {L,R,T} = Interval{L,R}(convert(T, a), convert(T, b))

leftendpoint(d::Interval) = d.a
rightendpoint(d::Interval) = d.b

minimum(d::Interval{:closed}) = infimum(d)
minimum(d::Interval{:open}) = throw(ArgumentError("$d is open on the left. Use infimum."))
maximum(d::Interval{L,:closed}) where L = supremum(d)
maximum(d::Interval{L,:open}) where L = throw(ArgumentError("$d is open on the right. Use supremum."))


# The interval is closed if it is closed at both endpoints, and open if it
# is open at both endpoints. In all other cases, it is neither open nor closed.
isclosed(d::ClosedInterval) = true
isopen(d::OpenInterval) = true
isclosed(d::Interval) = false
isopen(d::Interval) = false
isempty(d::Union{OpenInterval,HalfOpenLeftInterval,HalfOpenRightInterval}) = leftendpoint(d) ≥ rightendpoint(d)


iscompact(d::Interval) = true

indomain(x, d::OpenInterval) = d.a < x < d.b
indomain(x, d::ClosedInterval) = d.a <= x <= d.b
indomain(x, d::HalfOpenLeftInterval) = d.a < x <= d.b
indomain(x, d::HalfOpenRightInterval) = d.a <= x < d.b


similar_interval(d::Interval{L,R,T}, a, b) where {L,R,T} =
    Interval{L,R,T}(a, b)


#################################
# Conversions between intervals
#################################


for STyp in (:Domain, :AbstractInterval, :FixedInterval)
    @eval begin
        convert(::Type{$STyp{T}}, d::Interval{L,R,T}) where {L,R,T} = d
        convert(::Type{$STyp{T}}, d::Interval{L,R}) where {L,R,T} =
            Interval{L,R,T}(T(leftendpoint(d)), T(rightendpoint(d)))
    end

    for Typ in (:ChebyshevInterval, :UnitInterval, :Halfline, :NegativeHalfline)
        @eval begin
            convert(::Type{$STyp{T}}, d::$Typ{T}) where {T} = d
            convert(::Type{$STyp{T}}, d::$Typ) where T = $Typ{T}
        end
    end
end


convert(::Type{Interval{L,R,T}}, d::AbstractInterval{S}) where {L,R,T,S} =
    Interval{L,R,T}(leftendpoint(d), rightendpoint(d))

function convert(::Type{UnitInterval{T}}, d::AbstractInterval{S}) where {T,S}
    @assert leftendpoint(d) == 0
    @assert rightendpoint(d) == 1
    UnitInterval{T}()
end

function convert(::Type{ChebyshevInterval{T}}, d::AbstractInterval{S}) where {T,S}
    @assert leftendpoint(d) == -1
    @assert rightendpoint(d) == 1
    ChebyshevInterval{T}()
end



########################
# Arithmetic operations
########################

# Some computations with intervals simplify without having to use a mapped domain.
# This is only the case for Interval{L,R,T}, and not for any of the FixedIntervals
# because the endpoints of the latter are, well, fixed.

-(d::ChebyshevInterval) = d
-(d::AbstractInterval) = similar_interval(d, -rightendpoint(d), -leftendpoint(d))

for op in (:+, :-)
    @eval $op(d::AbstractInterval, x::Real) = similar_interval(d, $op(leftendpoint(d),x), $op(rightendpoint(d),x))
end

+(x::Real, d::AbstractInterval) = similar_interval(d, x+leftendpoint(d), x+rightendpoint(d))
-(x::Real, d::AbstractInterval) = similar_interval(d, x-rightendpoint(d), x-leftendpoint(d))

for op in (:*, :/)
    @eval function $op(d::AbstractInterval, x::Real)
        if x ≥ 0 # -{x : 0 ≤ x ≤ 1} should be {x : -1 ≤ x ≤ 0}, not empty set {x : 0 ≤ x ≤ -1}
            similar_interval(d, $op(leftendpoint(d),x), $op(rightendpoint(d),x))
        else
            similar_interval(d, $op(rightendpoint(d),x), $op(leftendpoint(d),x))
        end
    end
end

for op in (:*, :\)
    @eval function $op(x::Real, d::AbstractInterval)
        if x ≥ 0 # -{x : 0 ≤ x ≤ 1} should be {x : -1 ≤ x ≤ 0}, not empty set {x : 0 ≤ x ≤ -1}
            similar_interval(d, $op(x,leftendpoint(d)), $op(x,rightendpoint(d)))
        else
            similar_interval(d, $op(x,rightendpoint(d)), $op(x,leftendpoint(d)))
        end
    end
end


show(io::IO, d::AbstractInterval) = print(io, "the interval [", leftendpoint(d), ", ", rightendpoint(d), "]")
show(io::IO, d::Interval{:closed,:closed}) = print(io, "the interval [", leftendpoint(d), ", ", rightendpoint(d), "]")
show(io::IO, d::Interval{:closed,:open}) = print(io, "the interval [", leftendpoint(d), ", ", rightendpoint(d), ")")
show(io::IO, d::Interval{:open,:closed}) = print(io, "the interval (", leftendpoint(d), ", ", rightendpoint(d), "]")
show(io::IO, d::Interval{:open,:open}) = print(io, "the interval (", leftendpoint(d), ", ", rightendpoint(d), ")")


function union(d1::Interval{L1,R1,T}, d2::Interval{L2,R2,T}) where {L1,R1,L2,R2,T}
    a1 = leftendpoint(d1)
    b1 = rightendpoint(d1)
    a2 = leftendpoint(d2)
    b2 = rightendpoint(d2)

    if (b1 < a2) || (b2 < a1) || (b1 == a2 && R1 == L2 == :open) ||
                    (b2 == a1 && R2 == L1 == :open)
        UnionDomain(d1, d2)
    else
        a = min(a1, a2)
        b = max(b1, b2)
        Interval{a == a1 ? L1 : L2, b == b1 ? R1 : R2}(a, b)
    end
end


function intersect(d1::Interval{L1,R1,T}, d2::Interval{L2,R2,T}) where {L1,R1,L2,R2,T}
    a1 = leftendpoint(d1)
    b1 = rightendpoint(d1)
    a2 = leftendpoint(d2)
    b2 = rightendpoint(d2)

    if (b1 < a2) || (a1 > b2)
        EmptySpace{T}()
    else
        # TODO: add some logic to determine open and closed nature of endpoints of new interval
        interval(max(a1, a2), min(b1, b2))
    end
end

function setdiff(d1::AbstractInterval{T}, d2::AbstractInterval{T}) where T
    a1 = leftendpoint(d1)
    b1 = rightendpoint(d1)
    a2 = leftendpoint(d2)
    b2 = rightendpoint(d2)

    a1 > b1 && return d1
    a2 > b2 && return d1
    b1 < a2 && return d1
    a1 < a2 < b1 ≤ b2 && return interval(a1, a2)
    a1 < a2 ≤ b2 < b1 && return interval(a1, a2) ∪ interval(b2, b1)
    a2 ≤ a1 < b2 < b1 && return interval(b2, b1)
    a2 ≤ a1 ≤ b1 ≤ b2 && return EmptySpace{T}()

    @assert b2 ≤ a1
    d1
end
