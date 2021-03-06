import ceylon.interop.dart {
    dartDouble,
    dartNumFromFloat,
    dartNumFromInteger
}
import dart.math {
    pow
}

"An IEEE 754 64-bit [floating point number][]. A `Float` is 
 capable of approximately representing numeric values 
 between:
 
 - 2<sup>-1022</sup>, approximately 
   1.79769\{#00D7}10<sup>308</sup>, and 
 - (2-2<sup>-52</sup>)\{#00D7}2<sup>1023</sup>, 
   approximately 5\{#00D7}10<sup>-324</sup>.
 
 Zero is represented by distinct instances `+0.0`, `-0.0`, 
 but these instances are equal. `-0.0` can be distinguished
 from `+0.0` using `f == 0.0 && f.strictlyNegative`.
 
 In addition, the following special values exist:
 
 - [[infinity]] and `-infinity`, and
 - [[undefined values|undefined]], denoted [NaN][] by the
   IEEE standard.
 
 As required by the IEEE standard no undefined value is 
 equal to any other value, nor even to itself. Thus, the 
 definition of [[equals]] for `Float` violates the general 
 contract defined by [[Object.equals]].
 
 A floating point value with a zero [[fractionalPart]] is
 considered equal to its [[integer]] part.
 
 Literal floating point values are written with a decimal
 point and, optionally, a magnitude or exponent:
 
     1.0
     1.0E6
     1.0M
     1.0E-6
     1.0u
 
 In the case of a fractional magnitude, the decimal point is
 optional. Underscores may be used to group digits into 
 groups of three.
 
 [floating point number]: http://www.validlab.com/goldberg/paper.pdf
 [NaN]: http://en.wikipedia.org/wiki/NaN"
see (`function parseFloat`)
tagged("Basic types", "Numbers")
shared native final class Float(Float float)
        extends Object()
        satisfies Number<Float> & 
                  Exponentiable<Float,Float> {
    
    "Determines whether this value is undefined. The IEEE
     standard denotes undefined values [NaN][] (an 
     abbreviation of Not a Number). Undefined values include:
     
     - _indeterminate forms_ including `0.0/0.0`, 
       `infinity/infinity`, `0.0*infinity`, and
       `infinity-infinity`, along with
     - _complex numbers_ like `sqrt(-1.0)` and `log(-1.0)`.
     
     An undefined value has the property that it is not 
     [[equal|Object.equals]] (`==`) to itself, and as a 
     consequence the undefined value cannot sensibly be used 
     in most collections.
     
     If `x` is an undefined `Float`, then:
     
     - `x==x` evaluates to `false`
     - `x!=x` evaluates to `true`, and
     - `x>x`, `x<x`, `x>=x`, `x<=x` all evaluate to `false`.
     
     [NaN]: http://en.wikipedia.org/wiki/NaN"
    see (`function compare`)
    aliased("notANumber")
    shared native Boolean undefined => this!=this;
    
    "Determines whether this value is infinite in magnitude. 
     Produces `true` for `infinity` and `-infinity`. 
     Produces `false` for a finite number, `+0.0`, `-0.0`, 
     or undefined."
    see (`value infinity`, `value finite`)
    shared native Boolean infinite
            => this==infinity || this==-infinity;
    
    "Determines whether this value is finite. Produces
     `false` for `infinity`, `-infinity`, and undefined."
    see (`value infinite`, `value infinity`)
    shared native Boolean finite
            => this!=infinity && this!=-infinity
                    && !this.undefined;
    
    "The sign of this value. Produces `1` for a positive 
     number or `infinity`. Produces `-1` for a negative
     number or `-infinity`. Produces `0.0` for `+0.0`, 
     `-0.0`, or undefined."
    shared actual native Integer sign
            =>   if (this < 0.0) then -1
            else if (this > 0.0) then 1
            else 0;
    
    "Determines if this value is a positive number or
     `infinity`. Produces `false` for a negative number, 
     `+0.0`, `-0.0`, or undefined."
    shared actual native Boolean positive => this > 0.0;
    
    "Determines if this value is a negative number or
     `-infinity`. Produces `false` for a positive number, 
     `+0.0`, `-0.0`, or undefined."
    shared actual native Boolean negative => this < 0.0;
    
    "Determines if this value is a positive number, `+0.0`, 
     or `infinity`. Produces `false` for a negative number, 
     `-0.0`, or undefined."
    shared native Boolean strictlyPositive 
            => this > 0.0 || 1.0/this > 0.0;
    
    "Determines if this value is a negative number, `-0.0`, 
     or `-infinity`. Produces `false` for a positive number, 
     `+0.0`, or undefined."
    shared native Boolean strictlyNegative 
            => this < 0.0 || 1.0/this < 0.0;
    
    "Determines if the given object is equal to this `Float`,
     that is, if:
     
     - the given object is also a `Float`,
     - neither this value nor the given value is 
       [[undefined]], and either
     - both values are [[infinite]] and have the same 
       [[sign]], or both represent the same finite floating 
       point value as defined by the IEEE specification.
     
     Or if:
     
     - the given object is an [[Integer]],
     - this value is neither [[undefined]], nor [[infinite]],
     - the [[fractionalPart]] of this value equals `0.0`, 
     - the [[integer]] part of this value equals the given 
       integer, and
     - the given integer is between -2<sup>53</sup> and 
       2<sup>53</sup> (exclusive)."
    shared actual native Boolean equals(Object that);
    
    "A platform-dependent hash code for this `Float`."
    shared actual native Integer hash;
    
    "Compare this value to the given value, where 
     [[infinity]] is considered greater than every defined, 
     finite value, and `-infinity` is considered smaller 
     than every defined, finite value, and [[undefined]] 
     values are considered incomparable.
     
     Note that if `x` is an undefined `Float` and `y` is any 
     `Float` that is not undefined, then:
     
     - `x<=>y` produces an exception when evaluated, but
     - `x>y`, `x<y`, `x>=y`, `x<=y`, and `x==y` all evaluate 
       to `false`."
    throws (`class Exception`, 
            "if either this value, the given value, or both 
             are [[undefined]]")
    shared actual native Comparison compare(Float other)
            =>   if (this < other) then smaller
            else if (this > other) then larger
            else equal;
    
    shared actual native Float negated;
    
    shared actual native Float plus(Float other);
    shared actual native Float minus(Float other);
    shared actual native Float times(Float other);
    shared actual native Float divided(Float other);
    
    "The result of raising this number to the given floating
     point power, where, following the definition of the
     IEEE `pow()` function, the following indeterminate 
     forms all evaluate to `1.0`:
     
     - `0.0^0.0`,
     - `infinity^0.0` and `(-infinity)^0.0`, 
     - `1.0^infinity` and `(-1.0)^infinity`.
     
     Furthermore:
     
      - `0.0^infinity` evaluates to `0.0`, and
      - `0.0^(-infinity)` evaluates to `infinity`.
     
     If this is a [[negative]] number, and the given 
     [[power|other]] has a nonzero [[fractionalPart]], the 
     result is [[undefined]].
     
     For any negative power `y<0.0`:
     
     - `0.0^y` evaluates to `infinity`,
     - `(-0.0)^y` evaluates to `-infinity`, and
     - for any nonzero floating point number `x`, `x^y` 
       evaluates to `1.0/x^(-y)`."
    shared actual native Float power(Float other);
    
    shared actual native Float wholePart;
    shared actual native Float fractionalPart;
    
    aliased("absolute")
    shared actual native Float magnitude 
            => this <= 0.0 then 0.0-this else this;
    
    "This value, represented as an [[Integer]], after 
     truncation of its fractional part, if such a 
     representation is possible."
    throws (`class OverflowException`,
        "if the the [[wholePart]] of this value is too large 
         or too small to be represented as an `Integer`")
    since("1.1.0")
    shared native Integer integer;
    
    shared actual native Float timesInteger(Integer integer)
            => times(integer.nearestFloat);
    
    shared actual native Float plusInteger(Integer integer)
            => plus(integer.nearestFloat);
    
    "The result of raising this number to the given integer
     power, where the following indeterminate forms evaluate 
     to `1.0`:
     
     - `0.0^0`,
     - `infinity^0` and `(-infinity)^0`.
     
     For any negative integer power `n<0`:
     
     - `0.0^n` evaluates to `infinity`,
     - `(-0.0)^n` evaluates to `-infinity`, and
     - for any nonzero floating point number `x`, `x^n` 
       evaluates to `1.0/x^(-n)`."
    shared actual native Float powerOfInteger(Integer integer);
    
    "A string representing this floating point number.
     
     - `\"NaN\"`, for any [[undefined value|undefined]]
     - `\"Infinity\"`, for [[infinity]], 
     - `\"-Infinity\"`, for [[-infinity]], or,
     - a Ceylon floating point literal that evaluates to 
       this floating point number, for example, `\"1.0\"`, 
       `\"-0.0\"`, or `\"1.5E10\"`."
    see (`function formatFloat`)
    shared actual native String string;
    
    "Determines if this value is strictly larger than the 
     given value, where [[infinity]] is considered greater 
     than every defined, finite value, and `-infinity` is 
     considered smaller than every defined, finite value. 
     Evaluates to `false` if this value, the given value, or 
     both are [[undefined]]."
    shared actual native Boolean largerThan(Float other);
    
    "Determines if this value is strictly smaller than the 
     given value, where [[infinity]] is considered greater 
     than every defined, finite value, and `-infinity` is 
     considered smaller than every defined, finite value. 
     Evaluates to `false` if this value, the given value, or 
     both are [[undefined]]." 
    shared actual native Boolean smallerThan(Float other); 
    
    "Determines if this value is larger than or equal to the 
     given value, where [[infinity]] is considered greater 
     than every defined, finite value, and `-infinity` is 
     considered smaller than every defined, finite value. 
     Evaluates to `false` if this value, the given value, or 
     both are [[undefined]]."
    shared actual native Boolean notSmallerThan(Float other);
    
    "Determines if this value is smaller than or equal to the 
     given value, where [[infinity]] is considered greater 
     than every defined, finite value, and `-infinity` is 
     considered smaller than every defined, finite value. 
     Evaluates to `false` if this value, the given value, or 
     both are [[undefined]]." 
    shared actual native Boolean notLargerThan(Float other); 
}

shared final native("dart")
class Float(Float float) extends Object()
        satisfies Number<Float> & Exponentiable<Float,Float> {

    shared native("dart") Boolean undefined => dartDouble(this).isNaN;
    shared native("dart") Boolean infinite => dartDouble(this).isInfinite;
    shared native("dart") Boolean finite  => dartDouble(this).isFinite;

    shared actual native("dart") Integer sign
        =>  if (this > 0.0) then 1
            else if (this < 0.0) then -1
            else 0;

    shared actual native("dart") Boolean positive => this > 0.0;
    shared actual native("dart") Boolean negative => this < 0.0;

    shared native("dart") Boolean strictlyPositive
        =>  this > 0.0 || 1.0/this > 0.0;

    shared native("dart") Boolean strictlyNegative
        =>  this < 0.0 || 1.0/this < 0.0;

    shared actual native("dart") Boolean equals(Object that)
        =>  if (is Float that) then
                this == that
            else if (is Integer that) then
                that < twoFiftyThree
                    && that > -twoFiftyThree
                    && that.nearestFloat == this
            else false;

    shared actual native("dart") Integer hash => dartDouble(float).hashCode;

    shared actual native("dart") Comparison compare(Float other)
        =>  if (this < other) then smaller
            else if (this > other) then larger
            else equal;

    shared actual native("dart") Float plus(Float other) => this + other;
    shared actual native("dart") Float minus(Float other) => this - other;
    shared actual native("dart") Float times(Float other) => this * other;
    shared actual native("dart") Float divided(Float other) => this / other;

    shared actual native("dart") Float power(Float other)
        =>  pow(dartNumFromFloat(this), dartNumFromFloat(other)).toDouble();

    shared actual native("dart") Float wholePart {
        value result = dartDouble(this).truncateToDouble();
        if (result == this && result.sign == sign) {
            // Return this to avoid creating a new box
            return this;
        }
        return result;
    }

    shared actual native("dart") Float fractionalPart
        =>  dartDouble(this).remainder(dartNumFromInteger(1));

    shared actual native("dart") Float magnitude => if (this <= 0.0) then -this else this;
    shared actual native("dart") Float negated => -this;
    shared native("dart") Integer integer => dartDouble(this).toInt();
    shared actual native("dart") Float timesInteger(Integer integer) => this * integer;
    shared actual native("dart") Float plusInteger(Integer integer) => this + integer;

    shared actual native("dart") Float powerOfInteger(Integer integer)
        =>  pow(dartNumFromFloat(this), dartNumFromInteger(integer)).toDouble();

    shared actual native("dart") String string => float.string;
    shared actual native("dart") Boolean largerThan(Float other) => this > other;
    shared actual native("dart") Boolean smallerThan(Float other) => this < other;
    shared actual native("dart") Boolean notSmallerThan(Float other) => this >= other;
    shared actual native("dart") Boolean notLargerThan(Float other) => this <= other;
}
