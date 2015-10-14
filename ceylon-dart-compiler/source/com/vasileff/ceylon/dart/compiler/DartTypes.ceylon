import ceylon.ast.core {
    Node
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.model.loader {
    JvmBackendUtil
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationModel=Declaration,
    TypedDeclarationModel=TypedDeclaration,
    FunctionModel=Function,
    ClassModel=Class,
    InterfaceModel=Interface,
    ValueModel=Value,
    ElementModel=Element,
    UnitModel=Unit,
    ModuleModel=Module,
    ScopeModel=Scope,
    SetterModel=Setter,
    ParameterModel=Parameter,
    TypeModel=Type,
    PackageModel=Package,
    ClassOrInterfaceModel=ClassOrInterface,
    FunctionOrValueModel=FunctionOrValue,
    ControlBlockModel=ControlBlock,
    ConstructorModel=Constructor,
    SpecificationModel=Specification,
    NamedArgumentListModel=NamedArgumentList
}
import com.vasileff.ceylon.dart.ast {
    DartConstructorName,
    DartPrefixedIdentifier,
    DartTypeName,
    DartSimpleIdentifier,
    DartIdentifier,
    DartExpression,
    DartPropertyAccess,
    createDartPropertyAccess
}
import com.vasileff.ceylon.dart.model {
    DartTypeModel
}
import com.vasileff.jl4c.guava.collect {
    ImmutableMap
}

shared
class DartTypes(CeylonTypes ceylonTypes, CompilationContext ctx) {

    variable value counter = 0;

    value nameCache => ctx.nameCache;

    [String, Boolean]?(DeclarationModel) mappedFunctionOrValue = (() {
        return ImmutableMap {
            ceylonTypes.objectDeclaration.getMember("string", null, false)
                -> ["toString", true],
            ceylonTypes.objectDeclaration.getMember("hash", null, false)
                -> ["hashCode", false]
        }.get;
    })();

    value reservedWords = set {
        "assert", "break", "case", "catch", "class", "const", "continue",
        "default", "do", "else", "enum", "extends", "false", "final", "finally",
        "for", "if", "in", "is", "new", "null", "rethrow", "return", "super",
        "switch", "this", "throw", "true", "try", "var", "void", "while", "with"
    };

    // TODO improve this.
    function sanitizeIdentifier(String id)
        =>  if (reservedWords.contains(id))
            then "$" + id
            else id;

    String getUnprefixedName(DeclarationModel|ParameterModel declaration) {
        String classOrObjectShortName(ClassModel declaration)
            =>  if (declaration.anonymous) then
                    // *all* objects are anonymous classes, not just expressions that
                    // get the "anonymous#" names. Non-expression objects are named
                    // the same as their values.
                    declaration.name.replace("anonymous#", "$anonymous$") + "_"
                else
                    declaration.name;

        if (is SetterModel declaration) {
            return getUnprefixedName(declaration.getter);
        }

        "Unless a replacement declaration has been made, always use the
         originalDeclaration to determine the name."
        DeclarationModel | ParameterModel originalDeclaration;

        if (is TypedDeclarationModel declaration) {
            // search for replacement name
            variable value model = declaration;
            while (true) {
                if (exists name = nameCache[model]) {
                    return name;
                }
                if (exists parent = model.originalDeclaration) {
                    model = parent;
                    continue;
                }
                break;
            }
            originalDeclaration = model;
        }
        else {
            originalDeclaration = declaration;
        }

        function makePrivate(TypedDeclarationModel declaration, String baseName) {
            // For now, not prefixing toplevels. We *can't* make `$package$element`
            // identifiers private, since in dev our files aren't always in proper
            // Dart packages. And for convenience, leaving the non `$package$` qualified
            // bridges alone.
            if ((isClassOrInterfaceMember(declaration)) && !declaration.shared) {
                return "_$" + baseName;
            }
            return baseName;
        }

        switch (originalDeclaration)
        case (is ValueModel | FunctionModel) {
            return makePrivate {
                originalDeclaration;
                sanitizeIdentifier(originalDeclaration.name);
            };
        }
        case (is ClassModel) {
            return sanitizeIdentifier(classOrObjectShortName(originalDeclaration));
        }
        case (is ConstructorModel | InterfaceModel) {
            return sanitizeIdentifier(originalDeclaration.name);
        }
        case (is ParameterModel) {
            return getUnprefixedName(originalDeclaration.model);
        }
        else {
            throw Exception("declaration type not yet supported \
                             for ``className(originalDeclaration)``");
        }
    }

    "The prefix to use for identifiers to simulate Ceylon packages
     in Dart. This is the part of the Ceylon package name that is not
     part of the containing module's base package, with `.` replaced
     by `$`, and a trailing `$` if nonempty."
    shared
    String identifierPackagePrefix(DeclarationModel | ParameterModel declaration);

    identifierPackagePrefix
        =   memoize((DeclarationModel | ParameterModel declaration)
            =>  if (!is ParameterModel declaration, isToplevel(declaration))
                then (
                    CeylonIterable(getPackage(declaration).name)
                        .skip(getModule(declaration).name.size())
                        .map(Object.string)
                        .interpose("$")
                        .reduce(plus)
                        ?.plus("$") else "")
                else "");

    shared
    String getName(DeclarationModel|ParameterModel declaration) {
        // TODO it might make sense to make this private, and have callers
        //      use `dartIdentifierForX()` methods that can also handle
        //      function <-> value mappings.

        String classOrInterfacePrefix(DeclarationModel member)
            // for member classes/interfaces, prepend with outer type names
            =>  if (exists container = getContainingDeclaration(member.container))
                then classOrInterfacePrefix(container)
                        + getUnprefixedName(container) + "$"
                else "";

        switch (declaration)
        case (is SetterModel | ValueModel | FunctionModel
                | ConstructorModel | ParameterModel) {
            return identifierPackagePrefix(declaration)
                    + getUnprefixedName(declaration);
        }
        case (is ClassModel | InterfaceModel) {
            return identifierPackagePrefix(declaration)
                    + classOrInterfacePrefix(declaration)
                    + getUnprefixedName(declaration);
        }
        else {
            throw Exception("declaration type not yet supported \
                             for ``className(declaration)``");
        }
    }

    "The name of the static method used for the implementation of
     non-formal interface methods."
    shared
    String getStaticInterfaceMethodName(
            FunctionModel|ValueModel|SetterModel declaration,
            Boolean isSetter = declaration is SetterModel)
        =>  if (declaration is FunctionModel) then
                "$" + getName(declaration)
            else if (isSetter) then
                "$set$" + getName(declaration)
            else
                "$get$" + getName(declaration);

    shared
    DartSimpleIdentifier getStaticInterfaceMethodIdentifier(
            FunctionModel|ValueModel|SetterModel declaration,
            Boolean isSetter = declaration is SetterModel)
        =>  DartSimpleIdentifier(getStaticInterfaceMethodName(declaration, isSetter));

    shared
    String getOrCreateReplacementName(ValueModel declaration) {
        // Must be idempotent!!!
        if (exists replacement = nameCache.get(declaration)) {
            return replacement;
        }

        value replacement = declaration.name + "$" + (counter++).string;
        nameCache.put(declaration, replacement);
        return replacement;
    }

    shared
    String createTempName(TypedDeclarationModel declaration) {
        return declaration.name + "$" + (counter++).string;
    }

    shared
    String createTempNameCustom(String prefix="tmp") {
        return prefix + "$" + (counter++).string;
    }

    "The Dart library prefix for the Ceylon module."
    shared
    String moduleImportPrefix
            (DScope|Node|ElementModel|UnitModel|ModuleModel|ScopeModel declaration);

    // FIXME uneffective memoization
    moduleImportPrefix
        =   memoize((DScope | Node | ElementModel | UnitModel
                    | ModuleModel | ScopeModel declaration)
            =>  CeylonIterable(getModule(declaration).name)
                    .map(Object.string)
                    .interpose("$")
                    .fold("$")(plus));

    shared
    String getPackagePrefixedName(FunctionOrValueModel declaration) {
        value name = getName(declaration);
        if (declaration.container is PackageModel) {
            return "$package$" + name;
        }
        else {
            return name;
        }
    }

    shared
    String unPackagePrefixify(String identifier) {
        if (identifier.startsWith("$package")) {
            return identifier[9...];
        }
        else {
            throw AssertionError(
                "'``identifier``' is not a package prefixed identifier !");
        }
    }

    shared
    DartTypeName dartObject
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("Object");
                };
            };

    shared
    DartTypeName dartBool
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("bool");
                };
            };

    shared
    DartTypeName dartInt
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("int");
                };
            };

    shared
    DartTypeName dartDouble
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("double");
                };
            };

    shared
    DartTypeName dartFunction
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("Function");
                };
            };

    shared
    DartTypeName dartString
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("String");
                };
            };

    shared
    DartIdentifier dartDefault(DScope scope)
        =>  if (getModule(scope).nameAsString == "ceylon.language") then
                DartSimpleIdentifier("$package$dart$default")
            else
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$ceylon$language");
                    DartSimpleIdentifier("dart$default");
                };

    shared
    DartTypeModel dartLazyIterable
        =>  DartTypeModel("$ceylon$language", "LazyIterable");

    shared
    DartTypeModel dartFunctionIterableFactory
        =>  DartTypeModel("$ceylon$language", "functionIterable");

    shared
    DartTypeModel dartObjectModel
        =   DartTypeModel("$dart$core", "Object");

    shared
    DartTypeModel dartBoolModel
        =   DartTypeModel("$dart$core", "bool");

// FIXME shouldn't have hardcoded package!
    shared
    DartTypeModel dartCallableModel
        =>  DartTypeModel("$ceylon$language", "dart$Callable");

    shared
    DartTypeModel dartIntModel
        =   DartTypeModel("$dart$core", "int");

    shared
    DartTypeModel dartDoubleModel
        =   DartTypeModel("$dart$core", "double");

    shared
    DartTypeModel dartFunctionModel
        =   DartTypeModel("$dart$core", "Function");

    shared
    DartTypeModel dartStringModel
        =   DartTypeModel("$dart$core", "String");

    shared
    DartConstructorName dartConstructorName(
            DScope scope,
            ClassModel|ConstructorModel declaration) {
        switch (declaration)
        case (is ClassModel) {
            //"Only toplevel classes supported for now"
            //assert(withinPackage(declaration));
            // TODO above assertion uncommented; was there a reason for the restriction?

            return DartConstructorName {
                dartTypeName(scope, declaration.type, false, false);
                null;
            };
        }
        case (is ConstructorModel) {
            assert (is ClassModel container = declaration.container);
            "Only toplevel classes supported for now"
            assert(withinPackage(container));

            return DartConstructorName {
                dartTypeName(scope, container.type, false, false);
                DartSimpleIdentifier(getName(declaration));
            };
        }
    }

    shared
    DartTypeName dartTypeName(
            DScope scope,
            TypeOrNoType type,
            Boolean eraseToNative,
            Boolean eraseToObject = false)
        =>  if (eraseToObject) then
                dartTypeNameForDartModel(scope, dartObjectModel)
            else if (is NoType type) then
                dartTypeNameForDartModel(scope, dartObjectModel)
            else
                dartTypeNameForDartModel(scope, dartTypeModel(type, eraseToNative));

    shared
    DartTypeName dartTypeNameForDartModel(
            DScope scope,
            DartTypeModel dartModel)
        =>  DartTypeName(dartIdentifierForDartModel(scope, dartModel));

    shared
    DartIdentifier dartIdentifierForDartModel(
            DScope scope,
            DartTypeModel dartModel) {

        value fromDartPrefix = moduleImportPrefix(scope);

        if (dartModel.dartModule == fromDartPrefix) {
            return
            DartSimpleIdentifier(dartModel.name);
        }
        else {
            return
            DartPrefixedIdentifier {
                DartSimpleIdentifier(dartModel.dartModule);
                DartSimpleIdentifier(dartModel.name);
            };
        }
    }

    "For the `Value`, or a `Callable` if the declaration is a `Function`."
    shared
    DartTypeName dartTypeNameForDeclaration(
            DScope scope,
            FunctionOrValueModel declaration) {

        value dartModel =
            switch (declaration)
            case (is FunctionModel)
                // code path for Callable parameters, other?
                dartTypeModel {
                    declaration.typedReference.fullType;
                    false; false;
                }
            else //case (is ValueModel | SetterModel)
                dartTypeModelForDeclaration(declaration);
        value fromDartPrefix = moduleImportPrefix(scope);
        if (dartModel.dartModule == fromDartPrefix) {
            return
            DartTypeName {
                DartSimpleIdentifier(dartModel.name);
            };
        }
        else {
            return
            DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier(dartModel.dartModule);
                    DartSimpleIdentifier(dartModel.name);
                };
            };
        }
    }

    "For the Value, or the return type of the Function"
    shared
    DartTypeName dartReturnTypeNameForDeclaration(
            DScope scope,
            FunctionModel|ValueModel declaration) {

        value dartModel = dartTypeModel {
            declaration.type;
            erasedToNative(declaration);
            erasedToObject(declaration);
        };
        value fromDartPrefix = moduleImportPrefix(scope);
        if (dartModel.dartModule == fromDartPrefix) {
            return
            DartTypeName {
                DartSimpleIdentifier(dartModel.name);
            };
        }
        else {
            return
            DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier(dartModel.dartModule);
                    DartSimpleIdentifier(dartModel.name);
                };
            };
        }
    }

    function refinedParameter(FunctionOrValueModel declaration) {
        // FIXME This is a bit sloppy and trusting, and needs review
        //       Before, we were using the parameter name as a key. But... parameter
        //       names may change on refinement.

        "Only use this for parmaeters!!!"
        assert(declaration.parameter);
        assert (is FunctionOrValueModel result = JvmBackendUtil
                .getTopmostRefinedDeclaration(declaration));
        return result;
    }

    "Determine the *formal* type, which indicates Dart erasure/boxing"
    shared
    TypeModel formalType(FunctionOrValueModel declaration)
        =>  if (declaration.parameter,
                    is FunctionModel c = declaration.container,
                    is FunctionModel r = refinedDeclaration(c)) then
                // for parameters of method refinements, use the type of the parameter
                // of the refined method
                refinedParameter(declaration).type
            else if (declaration.parameter,
                // same, for shortcut refinements
                    is SpecificationModel s = declaration.container,
                    is FunctionModel c = s.declaration,
                    is FunctionModel r = refinedDeclaration(c)) then
                refinedParameter(declaration).type
            else if (is FunctionOrValueModel r = refinedDeclaration(declaration)) then
                r.type
            else
                declaration.type;

    shared
    DartTypeModel dartTypeModelForDeclaration(
            FunctionOrValueModel declaration)
        =>  dartTypeModel {
                declaration.type;
                erasedToNative(declaration);
                erasedToObject(declaration);
            };

    "Obtain the [[DartTypeModel]] that will be used for the given [[TypeModel]]."
    shared
    DartTypeModel dartTypeModel(
            TypeModel type,
            "Don't erase `Boolean`, `Integer`, `Float`,
             and `String` to native types."
            Boolean eraseToNative,
            "Treat all generic types as `core.Object`.

             NOTE: callers should set eraseToObject to true for defaulted parameters."
            Boolean eraseToObject = type.typeParameter) {

        if (eraseToObject) {
            return dartObjectModel;
        }

        value definiteType = ceylonTypes.definiteType(type);

        // Tricky: Element|Absent is not caught in the first type.typeParameter test
        if (definiteType.typeParameter) {
            return dartObjectModel;
        }

        // handle well known types first, before giving up
        // on unions and intersections

        // these types are erased when statically known
        if (eraseToNative) {
            if (ceylonTypes.isCeylonBoolean(definiteType)) {
                return dartBoolModel;
            }
            if (ceylonTypes.isCeylonInteger(definiteType)) {
                return dartIntModel;
            }
            if (ceylonTypes.isCeylonFloat(definiteType)) {
                return dartDoubleModel;
            }
            if (ceylonTypes.isCeylonString(definiteType)) {
                return dartStringModel;
            }
        }

        // types like Anything and Object are _always_ erased
        if (ceylonTypes.isCeylonAnything(definiteType)) {
            return dartObjectModel;
        }
        if (ceylonTypes.isCeylonNothing(definiteType)) {
            // this handles the `Null` case too,
            // since Null & Object = Nothing
            return dartObjectModel;
        }
        if (ceylonTypes.isCeylonObject(definiteType)) {
            return dartObjectModel;
        }
        if (ceylonTypes.isCeylonBasic(definiteType)) {
            return dartObjectModel;
        }

        // at this point, settle for Object for other
        // unions and intersections
        if (definiteType.union || definiteType.intersection) {
            return dartObjectModel;
        }

        // not erased
        return
        DartTypeModel {
            moduleImportPrefix(definiteType.declaration);
            getName(definiteType.declaration);
        };
    }

    "True if [[type]] is denotable in Dart (not Nothing, a type parameter, union type, or
     intersection type.) Note: generic types such as `List<String>` and `List<T>` are
     considered denotable by this method, whereas type parameters, like `T`, are not."
    shared
    Boolean denotable(TypeModel type)
        =>  !type.typeParameter
                && !ceylonTypes.isCeylonNothing(type)
                && !ceylonTypes.isCeylonIdentifiable(type)
                && (let (definiteType = ceylonTypes.definiteType(type))
                   // union types that are booleans are denotable, as bool/Boolean
                   (ceylonTypes.isCeylonBoolean(definiteType)
                        || (!definiteType.union
                                && !definiteType.intersection
                                && !definiteType.typeParameter)));

    "True if [[type]] is not a type parameter and has a corresponding Dart native type
     such as `dart.core.int`."
    shared
    Boolean native(TypeModel type)
        =>  !type.typeParameter
            && (let (definiteType = ceylonTypes.definiteType(type))
                ceylonTypes.isCeylonBoolean(definiteType)
                || ceylonTypes.isCeylonInteger(definiteType)
                || ceylonTypes.isCeylonFloat(definiteType)
                || ceylonTypes.isCeylonString(definiteType));


    String outerFieldName(ClassOrInterfaceModel declaration)
        =>  "$outer"
                + moduleImportPrefix(declaration) + "$"
                + getName(declaration);

    shared
    DartSimpleIdentifier identifierForOuter(ClassOrInterfaceModel declaration)
        =>  DartSimpleIdentifier(outerFieldName(declaration));

    "Outer declarations for the given [[declaration]] and all supertype (extended and
     satisfied) declarations."
    shared
    {ClassOrInterfaceModel*} outerDeclarationsForClass
            (ClassOrInterfaceModel declaration)
        =>  supertypeDeclarations(declaration)
                .map((d) => getContainingClassOrInterface(d.container))
                .coalesced
                .distinct;

    "Declarations for captures required by the given [[declaration]] and all supertype
     (extended and satisfied) declarations."
    shared
    {FunctionOrValueModel*} captureDeclarationsForClass
        (ClassOrInterfaceModel declaration)
        =>  supertypeDeclarations(declaration)
                .flatMap(ctx.captures.get)
                .distinct;

    shared
    DartIdentifier dartIdentifierForClassOrInterface(
            DScope scope,
            ClassOrInterfaceModel declaration)
        =>  let (identifier =
                    dartIdentifierForClassOrInterfaceDeclaration(declaration))
            if (sameModule(scope, declaration)) then
                identifier
            else
                DartPrefixedIdentifier {
                    DartSimpleIdentifier(moduleImportPrefix(declaration));
                    identifier;
                };

    shared
    DartSimpleIdentifier dartIdentifierForClassOrInterfaceDeclaration
            (ClassOrInterfaceModel declaration)
        =>  DartSimpleIdentifier(getName(declaration));

    shared
    DartSimpleIdentifier expressionForThis(ClassOrInterfaceModel scope)
        =>  switch (container = getContainingClassOrInterface(scope))
            case (is ClassModel)
                DartSimpleIdentifier("this")
            else
                DartSimpleIdentifier("$this");

    "A stream containing the given [[declaration]] followed by declarations for all
     of [[declaration]]'s ancestor Classes and Interfaces."
    {ClassOrInterfaceModel+} ancestorChain
            (ClassOrInterfaceModel declaration)
        =>  loop<ClassOrInterfaceModel>(declaration)((c)
            =>  getContainingClassOrInterface(c.container) else finished);

    shared
    {ClassOrInterfaceModel+} ancestorChainToExactDeclaration(
            ClassModel|InterfaceModel scope,
            ClassOrInterfaceModel declaration)
        =>  // up to and including an exact match for `declaration`
            takeUntil(ancestorChain(scope))
                    (declaration.equals);

    shared
    {ClassOrInterfaceModel+} ancestorChainToInheritingDeclaration(
            ClassModel|InterfaceModel scope,
            ClassOrInterfaceModel inheritedDeclaration)
        =>  // up to and including a declarations that inherits inheritedDeclaration
            takeUntil(ancestorChain(scope))((c)
                =>  c.inherits(inheritedDeclaration));

    shared
    {ClassOrInterfaceModel+} ancestorChainToCapturerOfDeclaration(
            ClassModel|InterfaceModel scope,
            FunctionOrValueModel capturedDeclaration)
        =>  // up to and including a declarations that inherits inheritedDeclaration
            takeUntil(ancestorChain(scope))((c)
                =>  capturedBySelfOrSupertype(capturedDeclaration, c));

    """
       Chain of references to the member:
            $this ("." $outer$CI)* "." memberName

        The first identifier in the chain will be `this` or `$this`.
    """
    shared
    DartPropertyAccess | DartSimpleIdentifier expressionToThisOrOuter
            ({ClassOrInterfaceModel+} chain)
        =>  let (isInterface = chain.first is InterfaceModel)
            (if (isInterface) then ["$this"] else ["this"])
                .chain(chain.skip(1).map(outerFieldName))
                .map(DartSimpleIdentifier)
                .reduce<DartPropertyAccess|DartSimpleIdentifier> {
                    (expression, field) =>
                    DartPropertyAccess {
                        expression;
                        field;
                    };
                };

    """
       Chain of references to the member:
            $this ("." $outer$CI)* "." memberName

       If the first declaration in the chain is a class, the leading `this`
       will be suppressed.
    """
    shared
    DartPropertyAccess | DartSimpleIdentifier? expressionToThisOrOuterStripThis
            ({ClassOrInterfaceModel+} chain)
        =>  let (isInterface = chain.first is InterfaceModel)
            (if (isInterface) then ["$this"] else [])
                .chain(chain.skip(1).map(outerFieldName))
                .map(DartSimpleIdentifier)
                .reduce<DartPropertyAccess|DartSimpleIdentifier> {
                    (expression, field) =>
                    DartPropertyAccess {
                        expression;
                        field;
                    };
                };

    """
       Chain of references to the member:
            $this ("." $outer$CI)* "." memberName

       If the first declaration in the chain is a class, the leading `this`
       will be suppressed.
    """
    shared
    DartPropertyAccess | DartSimpleIdentifier? expressionToThisOrOuterStripNonLoneThis
            ({ClassOrInterfaceModel+} chain)
        =>  let (isInterface = chain.first is InterfaceModel)
            let (chainSeq = chain.sequence())
            (if (isInterface) then ["$this"]
             else if (chainSeq.size == 1) then ["this"]
             else [])
                .chain(chain.skip(1).map(outerFieldName))
                .map(DartSimpleIdentifier)
                .reduce<DartPropertyAccess|DartSimpleIdentifier> {
                    (expression, field) =>
                    DartPropertyAccess {
                        expression;
                        field;
                    };
                };

    "Returns a tuple containing:

     - A Dart expression for the Ceylon FunctionOrValue
     - A boolean value that is true if the target is a dart function, or false if the
       target is a dart value. Note: this will be true for Ceylon values that must be
       mapped to Dart functions."
    shared
    [DartExpression, Boolean] expressionForBaseExpression(
            DScope scope,
            FunctionOrValueModel declaration,
            Boolean setter = false) {

        "By definition."
        assert (is FunctionModel|ValueModel|SetterModel declaration);

        value [identifier, isFunction] = dartIdentifierForFunctionOrValue {
            scope;
            declaration;
            setter;
        };

        if (exists container = getContainingClassOrInterface(scope)) {
            value declarationContainer = getRealContainingScope(declaration);

            "Arguments in named argument lists cannot be referenced."
            assert(!is NamedArgumentListModel declarationContainer);

            switch (declarationContainer)
            case (is ClassOrInterfaceModel) {

                "Identifiers for members will always be simple identifiers (not prefixed
                 as toplevels may be.)"
                assert (is DartSimpleIdentifier identifier);

                "An expression to the declaration including:
                 - `this`, `$this`, or a reference to an outer container that is also the
                   container of the declaration, and
                 - the identifier."
                value dartExpression
                    =   createDartPropertyAccess {
                            // We need to qualify with `this` inside constructors due to
                            // name conflicts with constructor parameters. Note: using
                            // `LoneThis()` we don't need `this` when referencing outers,
                            // like (what would be) `this.$outer$ceylon$language$.cap`.
                            if (declaration.parameter
                                && ctx.withinConstructor(declarationContainer)) then
                                expressionToThisOrOuterStripNonLoneThis {
                                    ancestorChainToInheritingDeclaration {
                                        container;
                                        declarationContainer;
                                    };
                                }
                            else
                                expressionToThisOrOuterStripThis {
                                    ancestorChainToInheritingDeclaration {
                                        container;
                                        declarationContainer;
                                    };
                                };
                            identifier;
                        };

                return [dartExpression, isFunction];
            }
            case (is ConstructorModel | ControlBlockModel
                    | FunctionOrValueModel | SpecificationModel) {

                value declarationsClassOrInterface
                    =   getContainingClassOrInterface(declaration);

                if (eq(container, declarationsClassOrInterface)) {
                    return [identifier, isFunction];
                }
                else {
                    // The declaration doesn't belong to a class or interface, and it
                    // does not share a containing class or interface, so it must be
                    // a capture.

                    // The capture must have been made by $this, a supertype of $this,
                    // some $outer, or a supertype of some $outer.

                    value dartExpression
                        =   createDartPropertyAccess {
                                expressionToThisOrOuterStripThis {
                                    ancestorChainToCapturerOfDeclaration {
                                        container;
                                        declaration;
                                    };
                                };
                                identifierForCapture(declaration);
                            };

                    return [dartExpression, isFunction];
                }
            }
            case (is PackageModel) {
                return [identifier, isFunction];
            }
        }
        else {
            return [identifier, isFunction];
        }
    }

    shared
    {ClassOrInterfaceModel+} classOrInterfaceContainers
            (ClassOrInterfaceModel declaration)
        =>  loop<ClassOrInterfaceModel>(declaration)((c)
                =>  getContainingClassOrInterface(c.container) else finished);

    "A non empty stream of containers, starting with [[inner]], and ending with the first
     of 1. a matching container per [[found]], or 2. the outermost class or interface."
    shared
    {ClassOrInterfaceModel+} classOrInterfaceContainerPath(
            ClassOrInterfaceModel inner,
            Boolean found(ClassOrInterfaceModel declaration))
        =>  takeUntil(classOrInterfaceContainers(inner))(found);

    shared
    DartSimpleIdentifier thisReference(ClassOrInterfaceModel scope)
        =>  if (scope is InterfaceModel)
            then DartSimpleIdentifier("$this")
            else DartSimpleIdentifier("this");

    """
       Returns a dart expression for [[outerDeclaration]] from [[scope]]. The expression
       will be of the form:

            $this ("." $outer$ref)*
    """
    shared
    DartExpression expressionToOuter(
            ClassOrInterfaceModel scope,
            ClassOrInterfaceModel outerDeclaration)
        =>  classOrInterfaceContainerPath(scope, outerDeclaration.equals)
                .skip(1) // don't include scope; will be $this instead
                .map(outerFieldName)
                .map(DartSimpleIdentifier)
                .follow(thisReference(scope))
                .reduce((DartExpression expression, field)
                    =>  DartPropertyAccess {
                            expression;
                            field;
                        });

    "Return true if [[target]] is captured by [[by]] or one of its supertypes."
    Boolean capturedBySelfOrSupertype
            (FunctionOrValueModel target, ClassOrInterfaceModel by)
        =>  supertypeDeclarations(by).any((d)
            =>  ctx.captures.contains(d->target));

    """
       Produces an identifier of the form "$capture$" followed by each declaration's name
       separated by '$' starting with the most distant ancestor of [[declaration]]—the
       one with the package as its immediate container.

       Control blocks are represented by the empty string, effectively being translated
       to "$". The idea is that to resolve ambiguities, control block depth is sufficient
       since declarations in sibling control blocks are not visible to each other.
    """
    shared
    DartSimpleIdentifier identifierForCapture(FunctionOrValueModel declaration) {
        value declarations
            =   loop<DeclarationModel|ControlBlockModel>(declaration)((d)
                =>  if (is DeclarationModel|ControlBlockModel result = d.container)
                    then result
                    else finished);

        return
        DartSimpleIdentifier {
            declarations
                .collect((d)
                    =>  if (is ControlBlockModel d)
                        then ""
                        else getName(d))
                .reversed
                .interpose("$")
                .fold("$capture$")(plus);
        };
    }

    "Returns a tuple containing:

     - The *unqualified* DartSimpleIdentifier for a Ceylon FunctionOrValue
     - A boolean value that is true if the target is a dart function, or false if the
       target is a dart value. This will be true for Ceylon values that must be mapped
       to Dart functions."
    shared
    see(`function dartIdentifierForFunctionOrValue`)
    [DartSimpleIdentifier, Boolean] dartIdentifierForFunctionOrValueDeclaration(
            DScope scope,
            FunctionOrValueModel declaration,
            Boolean setter = declaration is SetterModel) {

        // FIXME how should "string" setters be mapped, since the getters
        //       are mapped to "toString"? And, handle "hashCode" name translation.
        value mapped = mappedFunctionOrValue(refinedDeclaration(declaration));
        String name;
        Boolean isDartFunction;

        if (exists mapped) {
            name = mapped[0];
            isDartFunction = mapped[1];
        }
        else {
            name = getPackagePrefixedName(declaration);
            isDartFunction = declaration is FunctionModel;
        }

        switch (container = declaration.container)
        case (is PackageModel) {
            return [DartSimpleIdentifier(name), isDartFunction];
        }
        case (is ClassOrInterfaceModel
                    | FunctionOrValueModel
                    | ControlBlockModel
                    | ConstructorModel
                    | SpecificationModel) {

            if (is ValueModel|SetterModel declaration,
                    useGetterSetterMethods(declaration)) {
                // identifier for the getter or setter method
                return
                [DartSimpleIdentifier {
                    name + (if (setter) then "$set" else "$get");
                },true];
            }
            else {
                // identifier for the value or function
                return
                [DartSimpleIdentifier {
                    name;
                }, isDartFunction];
            }
        }
        else {
            // TODO should be a compiler bug, but we don't have a Node
            throw Exception(
                "Unexpected container for base expression: \
                 declaration type '``className(declaration)``' \
                 container type '``className(container)``'");
        }
    }

    "Returns a tuple containing:

     - The Dart identifier for a Ceylon FunctionOrValue
     - A boolean value that is true if the target is a dart function, or false if the
       target is a dart value. This will be true for Ceylon values that must be mapped
       to Dart functions.

     **Note** this function should not be used for base expressions since they may
     reference captured values. Use [[expressionForBaseExpression]] instead."
    shared
    see(`function dartIdentifierForFunctionOrValueDeclaration`)
    see(`function expressionForBaseExpression`)
    [DartIdentifier, Boolean] dartIdentifierForFunctionOrValue(
            DScope scope,
            FunctionOrValueModel declaration,
            Boolean setter = false)
        =>  let ([identifier, isDartFunction]
                    = dartIdentifierForFunctionOrValueDeclaration(
                            scope, declaration, setter))
            if (declaration.container is PackageModel
                && !sameModule(scope, declaration)) then
                [
                    DartPrefixedIdentifier {
                        DartSimpleIdentifier {
                            moduleImportPrefix(declaration);
                        };
                        DartSimpleIdentifier {
                            // trim leading "$package." A bit ugly...
                            unPackagePrefixify(identifier.identifier);
                        };
                    },
                    isDartFunction
                ]
            else
                [identifier, isDartFunction];

    shared
    BoxingConversion? boxingConversionFor(
            "The lhs expression type"
            TypeModel lhsType,
            "True if the lhs is native"
            Boolean lhsEraseToNative,
            "The rhs expression type"
            TypeModel rhsType,
            "True if the rhs is native"
            Boolean rhsEraseToNative) {

        // The provided lhsType and rhsType should be subtypes of the formal types
        // used to calculate erasue to native
        //assert(!lhsEraseToNative || native(lhsType));
        //assert(!rhsEraseToNative || native(rhsType));

        if (lhsEraseToNative == rhsEraseToNative) {
            // if erased, they must be the same type (we don't coerce)
            // if neither should be erased, no conversion necessary
            return null;
        }

        if (lhsEraseToNative) {
            value definiteLhs = ceylonTypes.definiteType(lhsType);
            if (ceylonTypes.isCeylonBoolean(definiteLhs)) {
                return ceylonBooleanToNative;
            }
            else if (ceylonTypes.isCeylonFloat(definiteLhs)) {
                return ceylonFloatToNative;
            }
            else if (ceylonTypes.isCeylonInteger(definiteLhs)) {
                return ceylonIntegerToNative;
            }
            else if (ceylonTypes.isCeylonString(definiteLhs)) {
                return ceylonStringToNative;
            }
            else {
                throw Exception(
                        "Cannot find native type for lhs type \
                         '``definiteLhs.asQualifiedString()``'");
            }
        } else {
            value definiteRhs = ceylonTypes.definiteType(rhsType);
            if (ceylonTypes.isCeylonBoolean(definiteRhs)) {
                return nativeToCeylonBoolean;
            }
            else if (ceylonTypes.isCeylonFloat(definiteRhs)) {
                return nativeToCeylonFloat;
            }
            else if (ceylonTypes.isCeylonInteger(definiteRhs)) {
                return nativeToCeylonInteger;
            }
            else if (ceylonTypes.isCeylonString(definiteRhs)) {
                return nativeToCeylonString;
            }
            else {
                throw Exception(
                        "Cannot find native type for rhs type \
                         '``definiteRhs.asQualifiedString()``'");
            }
        }
    }

    "For the Value, or the return type of the Function, *unless* it's a Function that is
     a callable parameter, in which case the result will be false.

     Regarding callable parameters:

     - When invoked, non-native values are returned
     - They may also appear as the lhs type, in which case they are treated as
       `Callable` values, which of course are not erased. (Although, the lhs case should
       be handled by `withLhs`, preempting a call to this function.)
     - They may also appear as the rhs type (when taking a reference to a Function), in
       which case they are treated as `Callable` values, which of course are not erased."
    shared
    Boolean erasedToNative(FunctionOrValueModel | ClassModel declaration)
        =>  switch (declaration)
            case (is ClassModel)
                false
            case (is FunctionOrValueModel)
                !ctx.disableErasureToNative.contains(declaration)
                && !isCallableParameterOrParamOf(declaration)
                && !isAnonymousFunctionOrParamOf(declaration)
                && !isFunctionArgumentOrParamOf(declaration)
                && !isParameterInNonFirstParamList(declaration)
                && native(formalType(declaration));

    "For the Value, or the return type of the Function.

     Regarding callable parameters:

     - This function cannot be used when callable parameters are used as the rhs
       expression, since this would be ambiguous with the normal case where we are
       concerned with the *return* type. (The return is always erased to `Object` for
       callable parameters, but the `Callable` value itself is usually not erased.)"
    shared
    Boolean erasedToObject(FunctionOrValueModel declaration)
        // Ignore "defaulted" for FunctionModel parameters, which are Callable
        // parameters that may be defaulted, where the erasure of the parameter
        // itself has no bearing on the erasure of the actual function return type
        // TODO shouldn't we always return `true` for FunctionModels that are parameters?
        =>  ((!declaration is FunctionModel)
                && (declaration.initializerParameter?.defaulted else false))
            || !denotable(declaration.type);

    "For a given Ceylon declaration, the closest original declaration that was actually
     used to create a Dart declaration.

     This function is used by [[CoreGenerator.withBoxing]]."
    shared
    FunctionOrValueModel | Absent declarationConsideringElidedReplacements<Absent>
            (FunctionOrValueModel | Absent declaration)
            given Absent satisfies Null {

        if (exists declaration) {
            if (!is ValueModel declaration) {
                return declaration;
            }
            else {
                variable value model = declaration;
                while (!ctx.nameCache.defines(model)) {
                    if (exists parent = model.originalDeclaration) {
                        assert (is ValueModel parent);
                        model = parent;
                        continue;
                    }
                    break;
                }
                return model;
            }
        }
        else {
            return declaration; // null
        }
    }

    "If the given declaration is a replacement declaration that was elided, the returned
     type will be that of the closest original declaration that was actually used as the
     basis for a Dart declaration.

     Otherwise, the returned type will be the given [[type]], or the given
     [[declaration]]'s type if the given [[type]] is null.

     Note that for replacement declarations, it's ok to determine the [[TypeModel]] from
     the [[ValueModel]] declaration, since the declaration will contain all known type
     information (no unbound type parameters, as is the case with parameters for called
     functions, for example.)

     This function is used by [[CoreGenerator.withBoxing]]."
    shared
    throws(`class AssertionError`, "If both [[type]] and [[declaration]] are null.")
    TypeModel typeConsideringElidedReplacements
            (TypeModel? type, FunctionOrValueModel? declaration) {
        if (exists declaration) {
            value usedDeclaration = declarationConsideringElidedReplacements(declaration);
            if (usedDeclaration != declaration) {
                return usedDeclaration.type;
            }
        }
        "Type and declaration arguments must not both be null."
        assert (exists type);
        return type;
    }
}
