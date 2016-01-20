import ceylon.ast.core {
    Node,
    EntryPattern,
    VariablePattern,
    TuplePattern,
    Pattern,
    GroupedExpression,
    Super,
    OfOperation,
    Expression
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
    NamedArgumentListModel=NamedArgumentList,
    ClassAliasModel=ClassAlias
}
import com.vasileff.ceylon.dart.compiler {
    DScope
}
import com.vasileff.ceylon.dart.compiler.dartast {
    DartConstructorName,
    DartPrefixedIdentifier,
    DartTypeName,
    DartSimpleIdentifier,
    DartIdentifier,
    DartExpression,
    DartPropertyAccess
}
import com.vasileff.ceylon.dart.compiler.nodeinfo {
    UnspecifiedVariableInfo,
    VariadicVariableInfo,
    superInfo
}
import com.vasileff.jl4c.guava.collect {
    ImmutableMap
}

shared
class DartTypes(CeylonTypes ceylonTypes, CompilationContext ctx) {

    variable value counter = 0;

    value nameCache => ctx.nameCache;

    // TODO remove this ugliness.
    BaseGenerator baseGenerator => ctx.expressionTransformer;

    [String, DartElementType]?(DeclarationModel) mappedFunctionOrValue = (() {
        return ImmutableMap {
            ceylonTypes.objectDeclaration.getMember("string", null, false)
                -> ["toString", package.dartFunction],
            ceylonTypes.objectDeclaration.getMember("hash", null, false)
                -> ["hashCode", dartValue],
            ceylonTypes.objectDeclaration.getMember("equals", null, false)
                -> ["==", dartBinaryOperator],
            ceylonTypes.comparableDeclaration.getMember("smallerThan", null, false)
                -> ["<", dartBinaryOperator],
            ceylonTypes.comparableDeclaration.getMember("largerThan", null, false)
                -> [">", dartBinaryOperator],
            ceylonTypes.comparableDeclaration.getMember("notSmallerThan", null, false)
                -> [">=", dartBinaryOperator],
            ceylonTypes.comparableDeclaration.getMember("notLargerThan", null, false)
                -> ["<=", dartBinaryOperator],
            ceylonTypes.invertibleDeclaration.getMember("negated", null, false)
                -> ["-", dartPrefixOperator],
            ceylonTypes.summableDeclaration.getMember("plus", null, false)
                -> ["+", dartBinaryOperator],
            ceylonTypes.invertibleDeclaration.getMember("minus", null, false)
                -> ["-", dartBinaryOperator],
            ceylonTypes.numericDeclaration.getMember("times", null, false)
                -> ["*", dartBinaryOperator],
            ceylonTypes.numericDeclaration.getMember("divided", null, false)
                -> ["/", dartBinaryOperator],
            ceylonTypes.integralDeclaration.getMember("remainder", null, false)
                -> ["%", dartBinaryOperator]
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
        String usableShortName(ClassModel | FunctionModel | ValueModel declaration)
            =>  if (declaration.anonymous) then
                    // *all* objects are anonymous classes, not just expressions that
                    // get the "anonymous#" names. Non-expression objects are named
                    // the same as their values.
                    declaration.name.replace("anonymous#", "$anonymous$") + "_"
                else
                    declaration.name;

        // TODO refactor this code to reduce chance of caching a mangled name!!! As it
        // stands, only explicitly requested replacement names will be cached, so we're
        // fine, but this is dangerous. Mangling should probably happen further out,
        // perhaps managed by getName().
        function mangleName(DeclarationModel declaration, String name) {
            value originalDeclaration
                =   getOriginalDeclaration(declaration);

            if (declaration.parameter,
                    is ConstructorModel constructorModel = originalDeclaration.container,
                    ctx.withinConsolidatedConstructorSet.contains(
                            constructorModel.container)) {
                return "$" + getUnprefixedName(constructorModel) + "$" + name;
            }
            return name;
        }

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
                    return mangleName(model, name);
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
            return mangleName {
                originalDeclaration;
                makePrivate {
                    originalDeclaration;
                    sanitizeIdentifier {
                        usableShortName(originalDeclaration);
                    };
                };
            };
        }
        case (is ClassModel) {
            return sanitizeIdentifier(usableShortName(originalDeclaration));
        }
        case (is ConstructorModel | InterfaceModel) {
            return sanitizeIdentifier(originalDeclaration.name else "");
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
    String identifierPackagePrefix(DeclarationModel declaration);

    identifierPackagePrefix
        =   memoize((DeclarationModel declaration)
            =>  if (isToplevel(declaration))
                then (
                    CeylonIterable(getPackage(declaration).name)
                        .skip(getModule(declaration).name.size())
                        .map(Object.string)
                        .interpose("$")
                        .reduce(plus)
                        ?.plus("$") else "")
                else "");

    shared
    Boolean isCallableValue(FunctionModel declaration)
        =>  declaration.parameter
                && (!declaration.shared
                    || ctx.withinConstructorDefaultsSet.contains(declaration.container)
                    || ctx.withinConstructorSignatureSet.contains(declaration.container));

    shared
    Boolean valueMappedToNonField(ValueModel valueModel)
        =>  if (exists mapped = mappedFunctionOrValue(valueModel.refinedDeclaration))
            then mapped[1] != dartValue
            else false;

    shared
    Boolean valueRequiresSyntheticField(ValueModel valueModel)
        =>  !valueModel.transient && valueModel.default;

    shared
    Boolean capturedReferenceValue(ValueModel valueModel)
        =>  !valueModel.transient
                && valueModel.variable
                && ctx.capturedDeclarations.defines(valueModel);

    shared
    String getName(DeclarationModel | ParameterModel declaration) {
        // TODO it might make sense to make this private, and have callers
        //      use `dartIdentifierForX()` methods that can also handle
        //      function <-> value mappings.

        // If mapping a value to a value (e.g. hash->hashCode), use the Dart name. For
        // non-Dart-values, we'll return the Ceylon name, which may be used for a
        // synthetic field or setter.
        if (is ValueModel declaration,
            exists mapped = mappedFunctionOrValue(refinedDeclaration(declaration)),
                mapped[1] == dartValue) {
            return mapped[0];
        }

        String classOrInterfacePrefix(DeclarationModel member)
            // for member classes/interfaces, prepend with outer type names
            =>  if (exists container = getContainingDeclaration(member.container))
                then classOrInterfacePrefix(container)
                        + getUnprefixedName(container) + "$"
                else "";

        String getterSetterSuffix(ValueModel | SetterModel declaration)
            =>  if (useGetterSetterMethods(declaration))
                then (if (declaration is SetterModel) then "$set" else "$get")
                else "";

        switch (declaration)
        case (is ConstructorModel) {
            if (!declaration.name exists) {
                return "";
            }
            return identifierPackagePrefix(declaration)
                    + getUnprefixedName(declaration);
        }
        case (is ParameterModel) {
            // For captured reference values, treat like the ValueModel case but do not
            // mangle the name to the capture box name. For non-values, unwrap and try
            // again. (This won't conflict with "mapped" logic, because "mapped" is for
            // members, and captures always have non-class-or-interface containers.)
            if (is ValueModel valueModel = declaration.model,
                    capturedReferenceValue(valueModel)) {
                return identifierPackagePrefix(valueModel)
                        + getUnprefixedName(declaration);
            }
            return getName(declaration.model);
        }
        case (is ValueModel) {
            value result
                =   identifierPackagePrefix(declaration)
                        + getUnprefixedName(declaration);

            if (capturedReferenceValue(declaration)) {
                return "$b$" + result;
            }
            return result + getterSetterSuffix(declaration);
        }
        case (is SetterModel) {
            return identifierPackagePrefix(declaration)
                    + getUnprefixedName(declaration)
                    + getterSetterSuffix(declaration);
        }
        case (is FunctionModel) {
            return identifierPackagePrefix(declaration)
                    + getUnprefixedName(declaration);
        }
        case (is ClassModel | InterfaceModel) {
            return identifierPackagePrefix(declaration)
                    + classOrInterfacePrefix(declaration)
                    + getUnprefixedName(declaration);
        }
        else {
            // TODO let's encode this is the method signature
            throw Exception("declaration type not yet supported \
                             for ``className(declaration)``");
        }
    }

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
            (DScope|Node|ElementModel|UnitModel|ModuleModel|ScopeModel declaration)
        =>  package.moduleImportPrefix(getModule(declaration));

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
    DartTypeName dartList
        =   DartTypeName {
                DartPrefixedIdentifier {
                    DartSimpleIdentifier("$dart$core");
                    DartSimpleIdentifier("List");
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
    DartIdentifier dartIdentical
        =   DartPrefixedIdentifier {
                DartSimpleIdentifier("$dart$core");
                DartSimpleIdentifier("identical");
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
    DartTypeModel dartVariableBox
        =>  DartTypeModel("$ceylon$language", "dart$VariableBox");

    shared
    DartConstructorName dartConstructorName(
            DScope scope,
            ClassModel|ConstructorModel declaration) {

        assert (is ClassModel | ConstructorModel resolvedDeclaration
            =   if (is ClassAliasModel declaration)
                then declaration.constructor
                else declaration);

        switch (resolvedDeclaration)
        case (is ClassModel) {
            return DartConstructorName {
                dartTypeName(scope, resolvedDeclaration.type, false, false);
                null;
            };
        }
        case (is ConstructorModel) {
            assert (is ClassModel container = resolvedDeclaration.container);
            value constructorName = getName(resolvedDeclaration);
            return DartConstructorName {
                dartTypeName(scope, container.type, false, false);
                (!constructorName.empty) then
                    DartSimpleIdentifier(getName(resolvedDeclaration));
            };
        }
    }

    shared
    DartTypeName dartTypeName(
            DScope scope,
            TypeModel type,
            Boolean eraseToNative = true,
            Boolean eraseToObject = false)
        =>  dartTypeNameForDartModel {
                scope;
                dartTypeModel {
                    type;
                    eraseToNative;
                    eraseToObject;
                };
            };

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

    "The Dart implementation type for the Declaration. This is useful for captures where
     Dart functions are captured as `$dart$core$Function`s rather than wrapped as
     `Callable`s. It's also useful for non-transient variable value captures that are
     stored in variable boxes."
    shared
    see(`function dartTypeNameForDeclaration`)
    DartTypeName dartCaptureTypeNameForDeclaration(
            DScope scope,
            FunctionOrValueModel declaration,
            TypeModel | TypeDetails | Null type = null) {

        // Determine if `declaration` is implemented as a Dart function, and if
        // so, return $dart$core.Function. Otherwise, return the type of the Dart value.

        if (is ValueModel | SetterModel declaration,
                useGetterSetterMethods(declaration)) {
            return ctx.dartTypes.dartFunction;
        }

        if (is ValueModel declaration, capturedReferenceValue(declaration)) {
            return dartTypeNameForDartModel {
                scope;
                ctx.dartTypes.dartVariableBox;
            };
        }

        if (is FunctionModel declaration, !isCallableValue(declaration)) {
            // A Ceylon function that is *not* a value for a callable parameter
            return ctx.dartTypes.dartFunction;
        }

        value dartModel
            =   if (declaration is FunctionModel) // Callable parameter
                then dartTypeModel(ceylonTypes.callableAnythingType)
                else dartTypeModelForDeclaration(declaration, type);

        return dartTypeNameForDartModel(scope, dartModel);
    }

    "For the Value, or the return type of the Function, or Callable for
     callable parameters that are implemented as values."
    shared
    DartTypeName dartTypeNameForDeclaration(
            DScope scope, FunctionOrValueModel declaration,
            TypeModel | TypeDetails | Null type = null)
        =>  let (dartModel
                =   if (is FunctionModel declaration, isCallableValue(declaration))
                    then dartTypeModel(ceylonTypes.callableAnythingType)
                    else dartTypeModelForDeclaration(declaration, type))
            dartTypeNameForDartModel(scope, dartModel);

    "Use the declaration and type information to determine eraseToNative. The result is
     *never* erased to Object.

     `TypeModel.erasedToNative` information is validated against type information to
     determine if the type is *really* erased to native (i.e. erase the isType to native
     *iff* the type typeToCheck possibly native)."
    shared
    DartTypeName dartTypeNameForIsTest(
            DScope scope,
            TypeModel | TypeDetails typeToCheck,
            FunctionOrValueModel? declarationToCheck,
            TypeModel isType)
        =>  dartTypeNameForDartModel {
                scope;
                if (is TypeDetails typeToCheck) then
                    dartTypeModel {
                        isType;
                        typeToCheck.erasedToNative
                            && native(typeToCheck.type);
                        false;
                    }
                else
                    dartTypeModel {
                        isType;
                        if (exists declarationToCheck)
                            then erasedToNative(declarationToCheck)
                            else native(typeToCheck);
                        false;
                    };
            };

    "For the Value, or the return type of the Function"
    shared
    DartTypeName dartReturnTypeNameForDeclaration(
            DScope scope, FunctionModel|ValueModel declaration)
        =>  let(dartModel = dartTypeModelForDeclaration(declaration))
            dartTypeNameForDartModel(scope, dartModel);

    shared
    FunctionOrValueModel refinedParameter(FunctionOrValueModel declaration) {
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
            FunctionOrValueModel declaration,
            TypeModel | TypeDetails | Null type = null)
        =>  if (is TypeDetails type) then
                dartTypeModel {
                    type.type;
                    type.erasedToNative;
                    type.erasedToObject;
                }
            else
                dartTypeModel {
                    type else declaration.type;
                    erasedToNative(declaration);
                    erasedToObject(declaration);
                };

    "Obtain the [[DartTypeModel]] that will be used for the given [[TypeModel]]."
    shared
    DartTypeModel dartTypeModel(
            TypeModel type,
            "Erase `Boolean`, `Integer`, `Float`, and `String` to native types."
            Boolean eraseToNative = true,
            "Force return of $dart$core.Object. Note: eraseToObject must be true for
             defaulted parameters."
            Boolean eraseToObject = false) {

        if (eraseToObject) {
            return dartObjectModel;
        }

        "The actual type, erasing aliases."
        value resolved = type.resolveAliases();

        "The intersection of the type & Object"
        value definiteType = ceylonTypes.definiteType(resolved);

        // Test against `definiteType` instead of `type` as a likely optimization
        if (!denotable(definiteType)) {
            return dartObjectModel;
        }

        // Erased native types when statically known
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

        // Replace Anything with $dart$core.Object
        if (ceylonTypes.isCeylonAnything(definiteType)) {
            return dartObjectModel;
        }

        // Not erased
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
        =>  let (dt = ceylonTypes.definiteType(type))
            !dt.typeParameter
                && !dt.typeConstructor
                && !ceylonTypes.isCeylonObject(dt)
                && !ceylonTypes.isCeylonIdentifiable(dt)
                && !ceylonTypes.isCeylonBasic(dt)
                && !ceylonTypes.isCeylonNull(dt)
                && !ceylonTypes.isCeylonNothing(dt)
                && // union types that are booleans are denotable, as bool/Boolean
                   (ceylonTypes.isCeylonBoolean(dt)
                        || (!dt.union && !dt.intersection));

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

    "The identifier for the class or interface member. For member classes and
     constructors of member classes, the returned identifier is for the synthetic
     factory method of the member's containing class."
    shared
    DartSimpleIdentifier identifierForMember(
            FunctionOrValueModel | ClassModel | ConstructorModel member)
        =>  switch (member)
            case (is ClassModel | ConstructorModel)
                identifierForMemberFactory(member, false)
            else
                DartSimpleIdentifier(getName(member));

    shared
    DartSimpleIdentifier identifierForMemberFactory
            (ClassModel | ConstructorModel declaration, Boolean static)
        =>  DartSimpleIdentifier {
                (if (static) then "$" else "") +
                (if (is ClassModel declaration) then
                    "$new$" + getName(declaration.refinedDeclaration)
                 else if (getName(declaration).empty) then
                    "$new$" + getName(getClassOfConstructor(declaration)
                                        .refinedDeclaration)
                 else
                    "$new$" + getName(getClassOfConstructor(declaration)
                                        .refinedDeclaration)
                          + "$" + getName(declaration));
            };

    // TODO improve naming and functional consistency for get...Name and identifierFor...

    "The name of the static method used for the implementation of
     non-formal interface methods."
    shared
    String getStaticInterfaceMethodName(
            FunctionModel | ValueModel | SetterModel | ClassModel | ConstructorModel
            declaration,
            Boolean isSetter = declaration is SetterModel)
        =>  if (is FunctionModel declaration) then
                "$" + getName(declaration)
            else if (is ClassModel | ConstructorModel declaration) then
                identifierForMemberFactory(declaration, true).identifier
            else if (isSetter) then
                "$set$" + getName(declaration)
            else
                "$get$" + getName(declaration);

    shared
    DartSimpleIdentifier getStaticInterfaceMethodIdentifier(
            FunctionModel | ValueModel | SetterModel
                    | ClassModel | ConstructorModel declaration,
            Boolean isSetter = declaration is SetterModel)
        =>  DartSimpleIdentifier(getStaticInterfaceMethodName(declaration, isSetter));

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
    DartPrefixedIdentifier | DartSimpleIdentifier
    identifierForToplevel(DScope scope, FunctionOrValueModel declaration)
        =>  if (!sameModule(scope, declaration)) then
                DartPrefixedIdentifier {
                    DartSimpleIdentifier(moduleImportPrefix(declaration));
                    DartSimpleIdentifier(getName(declaration));
                }
            else
                DartSimpleIdentifier {
                    // toplevel functions and values from the same dart package
                    // get a prefix to avoid shadowing problems
                    getPackagePrefixedName(declaration);
                };

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

    "The identifier to use for the static method that calculates the default value
     for the given parameter."
    shared
    DartSimpleIdentifier dartIdentifierForDefaultedParameterMethod
            (DScope scope, ParameterModel parameter)
        =>  DartSimpleIdentifier(
                  "$" + getName(parameter.declaration)
                + "$" + getName(parameter.model));

    shared
    DartSimpleIdentifier expressionForThis(DScope scope)
        =>  if (isSelfAParameter(scope))
            then DartSimpleIdentifier("$this")
            else DartSimpleIdentifier("this");

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

    "Similar to ancestorChainToInheritingDeclaration, but does not stop at `this` in
     the case that `this` satisfies [[inheritedDeclaration]]."
    shared
    {ClassOrInterfaceModel+} ancestorChainToOuterInheritingDeclaration(
            ClassModel|InterfaceModel scope,
            ClassOrInterfaceModel inheritedDeclaration) {

        assert (exists containingClassOrInterface
            =   getContainingClassOrInterface(container(scope)));

        // up to and including a declarations that inherits inheritedDeclaration
        return ancestorChainToInheritingDeclaration {
            containingClassOrInterface;
            inheritedDeclaration;
        }.follow(scope);
    }

    shared
    {ClassOrInterfaceModel+} ancestorChainToCapturerOfDeclaration(
            ClassModel|InterfaceModel scope,
            FunctionOrValueModel capturedDeclaration)
        =>  // up to and including a declarations that inherits inheritedDeclaration
            takeUntil(ancestorChain(scope))((c)
                =>  capturedBySelfOrSupertype(capturedDeclaration, c));

    """
       Returns a dart expression for [[outerDeclaration]] from [[scope]]. The expression
       will be of the form:

            $this ("." $outer$ref)*

       For class scopes, `this` will not be included unless [[outerDeclaration]]
       is the same as [[scope]].
    """
    shared
    DartExpression expressionToOuter
            (DScope scope, ClassOrInterfaceModel outerDeclaration) {

        "If there is an outerDeclaration, there must be an innerDeclaration"
        assert (exists innerDeclaration = getContainingClassOrInterface(scope));

        return
        expressionToThisOrOuterStripNonLoneThis {
            scope;
            classOrInterfaceContainerPath {
                innerDeclaration;
                // outer may be exact, or may be a supertype of inner's outer in
                // the case of a member class inner
                (m) => m.inherits(outerDeclaration);
            };
        };
    }

    """
       Chain of references to the member:
            $this ("." $outer$CI)* "." memberName

        The first identifier in the chain will be `this` or `$this`.
    """
    shared
    DartPropertyAccess | DartSimpleIdentifier expressionToThisOrOuter(
            DScope scope,
            {ClassOrInterfaceModel+} chain,
            Boolean selfIsParameter = isSelfAParameter(scope))
        =>  let (thisExpression = if (selfIsParameter) then "$this" else "this")
            chain
                .skip(1) // skip outermost declaration; will be $this instead
                .map(outerFieldName)
                .follow(thisExpression)
                .map(DartSimpleIdentifier)
                .reduce<DartPropertyAccess|DartSimpleIdentifier> {
                        (expression, field)
                    =>  DartPropertyAccess {
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
    DartPropertyAccess | DartSimpleIdentifier expressionToThisOrOuterStripNonLoneThis(
            DScope scope,
            {ClassOrInterfaceModel+} chain,
            Boolean selfIsParameter = isSelfAParameter(scope))
        =>  expressionToThisOrOuterStripThis {
                scope;
                chain;
                selfIsParameter;
            } else DartSimpleIdentifier("this");

    """
       Chain of references to the member:
            $this ("." $outer$CI)* "." memberName

       If the first declaration in the chain is a class, the leading `this`
       will be suppressed.
    """
    shared
    DartPropertyAccess | DartSimpleIdentifier | Null
    expressionToThisOrOuterStripThis(
            DScope scope,
            {ClassOrInterfaceModel+} chain,
            Boolean selfIsParameter = isSelfAParameter(scope))
        =>  let (thisExpression = selfIsParameter then "$this")
            chain
                .skip(1) // skip outermost declaration; will be $this instead
                .map(outerFieldName)
                .follow(thisExpression)
                .coalesced
                .map(DartSimpleIdentifier)
                .reduce<DartPropertyAccess | DartSimpleIdentifier> {
                        (expression, field)
                    =>  DartPropertyAccess {
                            expression;
                            field;
                        };
                };

    "Returns a [[DartQualifiedInvocable]] for the [[declaration]] in [[scope]], with
     [[declaration]] being the target of a Ceylon base expression."
    shared
    DartQualifiedInvocable invocableForBaseExpression(
            DScope scope,
            FunctionOrValueModel | ClassModel | ConstructorModel declaration,
            Boolean setter = declaration is SetterModel) {

        "The declaration to invoke, taking care to use the SetterModel if a setter is
         desired and one exists (they don't exist for variable non-transient values)."
        value validDeclaration
            =   correctDeclaration(declaration, setter);

        "Use the correct original declaration, given that we may have ignored some
         replacement declarations."
        value originalDeclaration
            =   if (is ClassModel | ConstructorModel validDeclaration)
                then validDeclaration
                else declarationConsideringElidedReplacements(validDeclaration);

        value invocable
            =   dartInvocable {
                    scope;
                    originalDeclaration;
                    setter;
                };

        if (exists scopeContainer = getContainingClassOrInterface(scope)) {

            "The declaration's container, or in the case of a Constructor, the
             Constructor's class's container."
            value declarationContainer
                =   if (is ConstructorModel originalDeclaration)
                    then getRealContainingScope(
                            getClassOfConstructor(originalDeclaration))
                    else getRealContainingScope(originalDeclaration);

            "Arguments in named argument lists cannot be referenced."
            assert(!is NamedArgumentListModel declarationContainer);

            switch (declarationContainer)
            case (is ClassOrInterfaceModel) {
                // Some member of a class or interface: a function, value, class, or
                // or class's constructor.
                //
                // Usually, this will be a normal invocation like 'receiver.member()',
                // with 'receiver' being 'this' or some 'outer' calculated below.
                //
                // But, for non-shared member classes and non-shared constructors, the
                // result will be a Dart instance creation expression (invocation of a
                // Dart constructor) with the "receiver" being passed as the first
                // argument.
                //
                // All we need to do is determine the receiver. The 'invocable' we already
                // have handles the form of the invocation.

                // Non-shared declarations do not have factory methods, so we'll be
                // instantiating the class directly. And, the class may be a ClassAlias
                // to a class with a *different* container than that of the ClassAlias's.
                if (is ClassModel | ConstructorModel validDeclaration,
                        !getClassOfConstructor(validDeclaration).shared
                        || !validDeclaration.shared) {

                    return DartQualifiedInvocable {
                        baseGenerator.generateArgumentForOuter {
                            scope;
                            validDeclaration;
                        }[0];
                        invocable;
                    };
                }

                return
                DartQualifiedInvocable {
                    // We need to qualify with `this`
                    //
                    // - inside constructors due to name conflicts with constructor
                    //   parameters.
                    //
                    // - when the invocation requires an operator
                    //
                    // Note: using `LoneThis()` we don't need `this` when referencing
                    //       outers, like (what would be)
                    //       `this.$outer$ceylon$language$.cap`.
                    if (invocable.elementType is DartOperator
                        || (originalDeclaration.parameter
                            && ctx.withinConstructor(declarationContainer))) then
                        expressionToThisOrOuterStripNonLoneThis {
                            scope;
                            ancestorChainToInheritingDeclaration {
                                scopeContainer;
                                declarationContainer;
                            };
                        }
                    else
                        expressionToThisOrOuterStripThis {
                            scope;
                            ancestorChainToInheritingDeclaration {
                                scopeContainer;
                                declarationContainer;
                            };
                        };
                    invocable;
                };
            }
            case (is ConstructorModel | ControlBlockModel
                    | FunctionOrValueModel | SpecificationModel) {

                if (is ClassModel | ConstructorModel originalDeclaration) {
                        assert (is ClassModel | ConstructorModel validDeclaration);

                    // It's a non-member class (or constructor), but it does need a
                    // reference to the outer class or interface if there is one. The
                    // 'outer' capture looks pretty much like a qualifying instance.
                    return DartQualifiedInvocable {
                        baseGenerator.generateArgumentForOuter {
                            scope;
                            validDeclaration;
                        }[0];
                        invocable;
                    };
                }

                "This was just handled, but we don't have guards yet."
                assert (!is ClassModel | ConstructorModel validDeclaration);

                // Handle the non-class & constructor cases.

                value declarationsClassOrInterface
                    =   getContainingClassOrInterface(originalDeclaration);

                if (eq(scopeContainer, declarationsClassOrInterface)) {
                    // The declaration's outer class or interface is the same as the
                    // current scope's class or interface. So it's not a capture, and we
                    // can reference it directly.
                    return DartQualifiedInvocable {
                        null;
                        invocable;
                    };
                }
                else {
                    // The declaration doesn't belong to a class or interface, and it
                    // does not share a containing class or interface, so it must be
                    // a capture.

                    // The capture must have been made by $this, a supertype of $this,
                    // some $outer, or a supertype of some $outer.

                    return DartQualifiedInvocable {
                        expressionToThisOrOuterStripThis {
                            scope;
                            ancestorChainToCapturerOfDeclaration {
                                scopeContainer;
                                originalDeclaration;
                            };
                        };
                        invocable.with {
                            // Note on identifier name: we're using `declaration`, not
                            // originalDeclaration, since when class declarations are
                            // made, we don't know which replacements have been elided,
                            // so the parameter name for the capture will always assume
                            // no elided declarations. The result is that there may be
                            // more '$' is the name (an *extra* '$' for each refinement
                            // that was skipped.)

                            // TODO but we really need to have a visitor determine which
                            //      replacements we'll honor (before the capture visitor)
                            //      so that we *can* acknowledge elided replacements, and
                            //      in some cases consolidate/de-dup captures. And, make
                            //      sure the types all line up....

                            reference
                                =   identifierForCapture(validDeclaration);

                            // operators become functions when closurized
                            elementType
                                =   switch (et = invocable.elementType)
                                    case (package.dartFunction | dartValue) et
                                    case (is DartOperator) package.dartFunction;

                            setter
                                =   setter;

                            capturedReferenceValue
                                =   if (is ValueModel validDeclaration)
                                    then capturedReferenceValue(validDeclaration)
                                    else false;
                        };
                    };
                }
            }
            case (is PackageModel) {
                return DartQualifiedInvocable(null, invocable);
            }
        }
        else {
            return DartQualifiedInvocable(null, invocable);
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

    "Return true if [[target]] is captured by [[by]] or one of its supertypes."
    Boolean capturedBySelfOrSupertype
            (FunctionOrValueModel target, ClassOrInterfaceModel by)
        =>  supertypeDeclarations(by).any((d)
            =>  ctx.captures.contains(d->target));

    "A stream containing the given [[declaration]] followed by declarations for all
     of [[declaration]]'s ancestors, including all declarations and control blocks.
     See also [[ancestorChain]]."
    {DeclarationModel|ControlBlockModel+} ancestorDeclarations
            (DeclarationModel declaration)
        =>  loop<DeclarationModel|ControlBlockModel>(declaration)((d)
            =>  if (is DeclarationModel|ControlBlockModel result = d.container)
                then result
                else finished);

    """
       Produces an identifier of the form "$capture$" followed by each declaration's name
       separated by '$' starting with the most distant ancestor of [[declaration]]—the
       one with the package as its immediate container.

       Control blocks are represented by the empty string, effectively being translated
       to "$". The idea is that to resolve ambiguities, control block depth is sufficient
       since declarations in sibling control blocks are not visible to each other.
    """
    shared
    DartSimpleIdentifier identifierForCapture(FunctionOrValueModel declaration)
        =>  DartSimpleIdentifier {
                ancestorDeclarations(declaration)
                    .collect((d)
                        =>  if (is ControlBlockModel d)
                            then ""
                            else getName(d))
                    .reversed
                    .interpose("$")
                    .fold("$capture$")(plus);
            };

    "The identifier for the Dart field to store the Ceylon Callable or Value."
    see(`function identifierForSyntheticField`)
    see(`function BaseGenerator.generateBridgesToSyntheticField`)
    shared
    DartSimpleIdentifier identifierForField(FunctionOrValueModel valueModel)
        =>  if (is ValueModel valueModel,
                valueRequiresSyntheticField(valueModel))
            then identifierForSyntheticField(valueModel)
            else DartSimpleIdentifier(getName(valueModel));

    "The identifier for synthetic Dart field for a Ceylon Value."
    see(`function BaseGenerator.generateBridgesToSyntheticField`)
    shared
    DartSimpleIdentifier identifierForSyntheticField(ValueModel declaration)
        =>  DartSimpleIdentifier {
                "_$s" +
                ancestorDeclarations(declaration)
                    .collect((d)
                        =>  if (is ControlBlockModel d)
                            then ""
                            else getName(d))
                    .reversed
                    .interpose("$")
                    .fold("$")(plus);
            };

    "The identifier for the init method for classes with constructors. Name conflicts
     must be avoided to avoid refinement!"
    see(`function BaseGenerator.generateBridgesToSyntheticField`)
    shared
    DartSimpleIdentifier identifierForInitMethod(ClassModel declaration)
        =>  DartSimpleIdentifier {
                "_$init" +
                ancestorDeclarations(declaration)
                    .collect((d)
                        =>  if (is ControlBlockModel d)
                            then ""
                            else getName(d))
                    .reversed
                    .interpose("$")
                    .fold("$")(plus);
            };

    "The non-intersection type of a `super` reference; should map directly to a Dart
     type."
    shared
    TypeModel? denotableSuperType(
            "Primary may be `super` or `(super of T)`"
            Expression primary)
        =>  if (is Super primary) then
                let (sInfo = superInfo(primary))
                sInfo.typeModel.getSupertype(sInfo.declarationModel)
            else if (is GroupedExpression primary,
                     is OfOperation ofOp = primary.innerExpression,
                     is Super s = ofOp.operand) then
                let (sInfo = superInfo(s))
                sInfo.typeModel.getSupertype(sInfo.declarationModel)
            else
                null;

    "Swap ValueModel for SetterModel or vice-versa if necessary."
    FunctionModel | ValueModel | SetterModel | ClassModel | ConstructorModel
    correctDeclaration(
            FunctionOrValueModel | ClassModel | ConstructorModel declaration,
            Boolean setter) {
        value result
            =   if (setter, is ValueModel declaration,
                    exists setterModel = declaration.setter) then
                    setterModel
                else if (!setter, is SetterModel declaration) then
                    declaration.getter
                else
                    declaration;

        "By definition."
        assert (is FunctionModel | ValueModel | SetterModel
                    | ClassModel | ConstructorModel result);

        return result;
    }

    "Returns a [[DartInvocable]] suitable for use from [[scope]].

     **Note** this function should not be used for base expressions since they may
     reference captured values. Use [[invocableForBaseExpression]] instead."
    shared
    DartInvocable dartInvocable(
            DScope scope,
            FunctionOrValueModel | ClassModel | ConstructorModel declaration,
            Boolean setter = declaration is SetterModel) {

        "The delcaration to use. The typechecker always gives us a ValueModel for
         ValueSpecifications, but we need the SetterModel, if available."
        value validDeclaration
            =   correctDeclaration(declaration, setter);

        "The container, treating constructors as being contained by their class's
         container."
        value container
            =   switch (validDeclaration)
                case (is ConstructorModel) validDeclaration.container.container
                else package.container(validDeclaration);

        "Is it a Function implemented as a value?"
        value callableValue
            =   if (is FunctionModel validDeclaration)
                then isCallableValue(validDeclaration)
                else false;

        "Cast callableValues if held in a variable of type $dart$core.Object"
        value callableCast
            =   if (is FunctionModel validDeclaration,
                    callableValue &&
                    erasedToObjectCallableParam(validDeclaration.initializerParameter))
                then dartTypeName {
                    scope;
                    ceylonTypes.callableAnythingType;
                }
                else null;

        switch (container)
        case (is PackageModel) {
            // Toplevel class or constructor. Easy.
            if (is ClassModel | ConstructorModel validDeclaration) {
                return DartInvocable {
                    dartConstructorName {
                        scope;
                        validDeclaration;
                    };
                    package.dartFunction; // Constructor, really
                    false;
                };
            }

            // Toplevel function or value. Also easy.
            return DartInvocable {
                identifierForToplevel {
                    scope;
                    validDeclaration;
                };
                if (validDeclaration is FunctionModel)
                    then package.dartFunction
                    else dartValue;
                setter;
            };
        }
        case (is ClassOrInterfaceModel) {
            // Static function or value for interop
            if (validDeclaration.staticallyImportable) {
                "Dart doesn't have member classes"
                assert (!is ClassModel | ConstructorModel validDeclaration);

                return DartInvocable {
                    DartPropertyAccess {
                        dartIdentifierForClassOrInterface(scope, container);
                        DartSimpleIdentifier(getPackagePrefixedName(validDeclaration));
                    };
                    if (validDeclaration is FunctionModel)
                    then package.dartFunction
                    else dartValue;
                    setter;
                };
            }

            // Non-shared classes, constructors, and constructors of non-shared classes,
            // which are invoked statically
            if (is ClassModel | ConstructorModel validDeclaration,
                    !validDeclaration.shared
                    || !getClassOfConstructor(validDeclaration).shared) {

                return DartInvocable {
                    dartConstructorName {
                        scope;
                        validDeclaration;
                    };
                    package.dartFunction; // Constructor, really
                    false;
                };
            }

            // Non-shared interface functions and values
            if (is InterfaceModel container,
                    is FunctionOrValueModel validDeclaration,
                    !validDeclaration.shared) {

                return DartInvocable {
                    DartPropertyAccess {
                        dartIdentifierForClassOrInterface {
                            scope;
                            container;
                        };
                        DartSimpleIdentifier {
                            getStaticInterfaceMethodName(validDeclaration);
                        };
                    };
                    package.dartFunction; // Constructor, really
                    false;
                };
            }

            // Else, a member function, value, class, or class's constructor. If it's
            // a function or value, it may be mapped to something like "+", toString() or
            // hashCode

            "The mapped Dart program element name and type, if any. See
             [[mappedFunctionOrValue]] for the list of mapped declarations.

             `mapped` will be `null` if the declaration is currently being used within
             an extends clause or default argument expressions. IOW, treat 'equals' and
             'string' as values (ignore Function and Operator mapping)."
            value mapped
                =   if (!ctx.withinConstructorSignatureSet.contains(container)
                            && !ctx.withinConstructorDefaultsSet.contains(container))
                    then mappedFunctionOrValue(refinedDeclaration(validDeclaration))
                    else null;

            value [memberIdentifier, dartElementType]
                =   if (exists mapped, !setter || mapped[1] == dartValue) then [
                        // For mapped non-setters, or setters that are mapped to
                        // dartValues. This includes hash -> hashCode, but excludes
                        // string -> toString(), for which we want to use 'string' for
                        // the setter. Same for dartPrefixOperators like negated -> '-'
                        DartSimpleIdentifier(mapped[0]),
                        mapped[1]
                    ] else [
                        identifierForMember(validDeclaration),
                        if (!is ValueModel | SetterModel validDeclaration,
                            !callableValue)
                        then package.dartFunction
                        else dartValue
                    ];

            return DartInvocable {
                memberIdentifier;
                dartElementType;
                setter;
                callableValue;
                callableCast;
            };
        }
        case (is FunctionOrValueModel
                    | ControlBlockModel
                    | ConstructorModel
                    | SpecificationModel) {

            // Non-member constructors are invoked statically. The caller will will need
            // to provide outer & captures as arguments.
            if (is ClassModel | ConstructorModel validDeclaration) {
                return DartInvocable {
                    dartConstructorName {
                        scope;
                        validDeclaration;
                    };
                    package.dartFunction; // Constructor, really
                    false;
                };
            }

            value identifier
                =   DartSimpleIdentifier(getPackagePrefixedName(validDeclaration));

            // A variable reference Value that is stored in a capture box
            if (is ValueModel validDeclaration,
                    capturedReferenceValue(validDeclaration)) {

                return DartInvocable {
                    identifier;
                    package.dartValue;
                    setter;
                    capturedReferenceValue = true;
                };
            }

            // A transient Value that is not a member that uses $get and $set methods
            // rather than Dart property methods.
            if (is ValueModel | SetterModel validDeclaration,
                    useGetterSetterMethods(validDeclaration)) {

                return DartInvocable {
                    identifier;
                    package.dartFunction;
                    setter;
                };
            }

            // A callable value (a Function that is a callable parameter that is stored
            // as a Callable
            if (callableValue) {
                return DartInvocable {
                    identifier;
                    dartValue;
                    setter;
                    callableValue;
                    callableCast;
                };
            }

            // Else, a regular non-member function, value, or setter.
            return DartInvocable {
                identifier;
                if (validDeclaration is FunctionModel)
                    then package.dartFunction
                    else dartValue;
                setter;
            };
        }
        else {
            addError(scope, "Unexpected container.");
            return
            DartInvocable {
                DartSimpleIdentifier("");
                package.dartFunction;
                false;
            };
        }
    }

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

    "Is the declaration a Function that is implemented as a value, as callable parameters
     often are?"
    Boolean isCallableValueOrOrParamOf(FunctionOrValueModel declaration)
        =>  if (is FunctionModel declaration, isCallableValue(declaration)) then
                true
            else if (declaration.parameter,
                     is FunctionModel f = declaration.container,
                     isCallableValue(f)) then
                true
            else
                false;

    "For the Value, or the return type of the Function. If the declaration is a Function
     that is a callable parameter that is implemented as a Callable value, the result will
     be false."
    shared
    Boolean erasedToNative
            (FunctionOrValueModel | ClassModel | ConstructorModel declaration)
        =>  switch (declaration)
            case (is ClassModel | ConstructorModel)
                false
            case (is FunctionOrValueModel)
                !ctx.disableErasureToNative.contains(declaration)
                && !isCallableValueOrOrParamOf(declaration)
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
    Boolean erasedToObject(FunctionOrValueModel declaration) {
        // If there are multiple parameter lists, the function returns a Callable, not
        // the ultimate return type as advertised by the declaration.
        if (is FunctionModel declaration, declaration.parameterLists.size() > 1) {
            // FIXME but should be true from inside the function, for the return?
            return false;
        }

        // The return for Callable parameters is always erased to object.
        if (is FunctionModel declaration, isCallableValue(declaration)) {
            return true;
        }

        // Ignore "defaulted" for FunctionModel parameters, which are Callable
        // parameters that may be defaulted, where the erasure of the parameter
        // itself has no bearing on the erasure of the actual function return type
        if (declaration is ValueModel
                // defaulted parameters are erased
                && (declaration.initializerParameter?.defaulted else false)
                // unless they are class initializer parameters in a non-defaults
                // handling constructor
                && (!declaration.container is ClassModel ||
                    ctx.withinConstructorDefaultsSet.contains(declaration.container))) {
            return true;
        }

        // Non-denotable types are of course erased to object.
        return !denotable(declaration.type.resolveAliases());
    }

    shared
    Boolean erasedToObjectCallableParam(ParameterModel parameter)
        =>  parameter.defaulted
            && (!withinClass(parameter.model)
                || ctx.withinConstructorDefaultsSet.contains(
                            parameter.model.container));

    "For a given Ceylon declaration, the closest original declaration that was actually
     used to create a Dart declaration.

     This function is used by [[CoreGenerator.withBoxing]]."
    shared
    // FIXME this belongs in ceylonTypes
    FunctionModel | ValueModel | SetterModel | Absent
    declarationConsideringElidedReplacements<Absent>
            (FunctionOrValueModel | Absent declaration)
            given Absent satisfies Null {

        if (exists declaration) {
            if (!is ValueModel declaration) {
                "By definition."
                assert (is FunctionModel | SetterModel | Absent declaration);
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
        assert (exists result = type else declaration?.type);
        return result;
    }

    "Disable erasure for all variable declarations contained within the given pattern."
    shared
    void disableErasureToNative(Pattern p) {
        switch(p)
        case (is VariablePattern) {
            ctx.disableErasureToNative.add(
                UnspecifiedVariableInfo(p.variable).declarationModel);
        }
        case (is TuplePattern) {
            p.elementPatterns.each(disableErasureToNative);
            if (exists v = p.variadicElementPattern) {
                ctx.disableErasureToNative.add(
                    VariadicVariableInfo(v).declarationModel);
            }
        }
        case (is EntryPattern) {
            p.children.each(disableErasureToNative);
        }
    }
}
