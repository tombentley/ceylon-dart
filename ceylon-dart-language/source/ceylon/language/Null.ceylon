"""The type of the [[null]] value. Any union type of form 
   `Null|T` is considered an _optional_ type, whose values
   include `null`. Any type of this form may be written as
   `T?` for convenience.
   
   The `if (exists ... )` construct, or, alternatively,
   `assert (exists ...)`, may be used to narrow an optional 
   type to a _definite_ type, that is, a subtype of 
   [[Object]]:
   
       String? firstArg = process.arguments.first;
       if (exists firstArg) {
           print("hello " + firstArg);
       }
   
   The `else` operator evaluates its second operand if and 
   only if its first operand is `null`:
   
       String name = process.arguments.first else "world";
   
   The `then` operator evaluates its second operand when
   its first operand evaluates to `true`, and to `null` 
   otherwise:
   
       Float? diff = x>=y then x-y;
   
   No equivalence relation is defined for `Null`. In 
   particular, neither `null==null` nor `null===null` are
   considered meaningful. Therefore, `Null` is neither
   [[Identifiable]], nor does it define 
   [[value equality|Object.equals]]."""
see (`value null`)
by ("Gavin") 
native shared abstract class Null() 
        of null
        extends Anything() {}

"The null value."
by ("Gavin")
native shared object null extends Null() {}