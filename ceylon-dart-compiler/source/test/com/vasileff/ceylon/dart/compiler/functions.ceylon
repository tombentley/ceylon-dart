import ceylon.test {
    test
}

shared
object functions {

    shared test
    void voidFunction()
        =>  compileAndCompare2("functions/voidFunction");

    shared test
    void anonymousFunction()
        =>  compileAndCompare2("functions/anonymousFunction");

    shared test
    void functionReturnBoxing()
        =>  compileAndCompare2("functions/functionReturnBoxing");

    shared test
    void nestedFunction()
        =>  compileAndCompare2("functions/nestedFunction");

    shared test
    void functionReference()
        =>  compileAndCompare2("functions/functionReference");

    shared test
    void functionDefaultedParameters()
        =>  compileAndCompare2("functions/functionDefaultedParameters");

    shared test
    void functionDefaultedParameters2()
        =>  compileAndCompare2("functions/functionDefaultedParameters2");

    shared test
    void functionDefaultedBoolean()
        =>  compileAndCompare2("functions/functionDefaultedBoolean");

    shared test
    void functionDefaultedFloat()
        =>  compileAndCompare2("functions/functionDefaultedFloat");

    "Return and parameter types of callable parameters should not be erased to native.
     Otherwise, boxing/unboxing wrapper functions would be necessary when generating
     Callables to hold them."
    shared test
    void dontEraseForCallableParameters()
        =>  compileAndCompare2("functions/dontEraseForCallableParameters");
}