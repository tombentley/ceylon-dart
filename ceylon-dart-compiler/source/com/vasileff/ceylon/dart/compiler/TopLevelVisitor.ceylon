import ceylon.ast.core {
    FunctionDefinition,
    ValueDefinition,
    FunctionShortcutDefinition,
    AnyFunction,
    InterfaceDefinition,
    FunctionDeclaration,
    ValueDeclaration,
    ClassDefinition,
    ObjectDefinition,
    ValueGetterDefinition,
    TypeAliasDefinition,
    CompilationUnit,
    Visitor,
    Node,
    Specifier,
    LazySpecifier,
    ValueSetterDefinition,
    Declaration,
    Specification,
    Assertion,
    ObjectExpression,
    ClassBody,
    Parameters,
    ExtendedType,
    ObjectArgument,
    DefaultedParameter,
    Parameter,
    ConstructorDefinition,
    Construction
}
import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.model.typechecker.model {
    InterfaceModel=Interface,
    ConstructorModel=Constructor,
    ClassModel=Class,
    SetterModel=Setter,
    TypedDeclarationModel=TypedDeclaration,
    FunctionModel=Function,
    ValueModel=Value,
    FunctionOrValueModel=FunctionOrValue
}
import com.vasileff.ceylon.dart.ast {
    DartArgumentList,
    DartClassDeclaration,
    DartSimpleIdentifier,
    DartMethodInvocation,
    DartSimpleFormalParameter,
    DartTopLevelVariableDeclaration,
    DartAssignmentExpression,
    DartAssignmentOperator,
    DartImplementsClause,
    DartFunctionExpression,
    DartExpressionFunctionBody,
    DartCompilationUnitMember,
    DartFormalParameterList,
    DartFunctionDeclaration,
    DartVariableDeclarationList,
    DartVariableDeclaration,
    DartFieldDeclaration,
    DartFieldFormalParameter,
    DartConstructorDeclaration,
    DartBlockFunctionBody,
    DartBlock,
    DartMethodDeclaration,
    DartExtendsClause,
    DartSuperConstructorInvocation,
    DartExpressionStatement,
    DartPrefixedIdentifier,
    DartDefaultFormalParameter,
    DartRedirectingConstructorInvocation,
    DartIntegerLiteral,
    DartIndexExpression,
    DartListLiteral
}
import com.vasileff.ceylon.dart.nodeinfo {
    AnyInterfaceInfo,
    ValueDefinitionInfo,
    AnyFunctionInfo,
    AnyClassInfo,
    ValueGetterDefinitionInfo,
    ObjectDefinitionInfo,
    ObjectExpressionInfo,
    NodeInfo,
    ObjectArgumentInfo,
    ParameterInfo,
    ConstructorInfo,
    ExtensionOrConstructionInfo
}

"For Dart TopLevel declarations."
shared
class TopLevelVisitor(CompilationContext ctx)
        extends BaseGenerator(ctx)
        satisfies Visitor {

    void add(DartCompilationUnitMember member)
        =>  ctx.compilationUnitMembers.add(member);

    void addAll({DartCompilationUnitMember*} members)
        =>  ctx.compilationUnitMembers.addAll(members);

    shared actual
    void visitValueDeclaration(ValueDeclaration that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        super.visitValueDeclaration(that);
    }

    shared actual
    void visitValueDefinition(ValueDefinition that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        switch(specifier = that.definition)
        case (is LazySpecifier) {
            addAll {
                generateForValueDefinitionGetter(that),
                *generateForwardingGetterSetter(that)
            };
        }
        case (is Specifier) {
            addAll {
                DartTopLevelVariableDeclaration {
                    generateForValueDefinition(that);
                },
                *generateForwardingGetterSetter(that)
            };
        }
    }

    shared actual
    void visitValueGetterDefinition(ValueGetterDefinition that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        addAll {
            generateForValueDefinitionGetter(that),
            *generateForwardingGetterSetter(that)
        };
    }

    shared actual
    void visitValueSetterDefinition(ValueSetterDefinition that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        // Forwarding setter was added by visitValue*()
        add(generateForValueSetterDefinition(that));
    }

    shared actual
    void visitFunctionDeclaration(FunctionDeclaration that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        super.visitFunctionDeclaration(that);
    }

    shared actual
    void visitClassDefinition(ClassDefinition that) {
        value info = AnyClassInfo(that);

        // skip native declarations entirely, for now
        if (!isForDartBackend(info)) {
            return;
        }

        // skip erased types
        if (info.declarationModel in [
                ceylonTypes.anythingDeclaration,
                ceylonTypes.objectDeclaration,
                ceylonTypes.basicDeclaration,
                ceylonTypes.nullDeclaration]) {
            return;
        }

        add {
            generateClassDefinition {
                info;
                info.declarationModel;
                that.body;
                that.extendedType;
                that.parameters;
            };
        };
    }

    shared actual
    void visitFunctionDefinition(FunctionDefinition that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        addAll {
            generateFunctionDefinition(that),
            generateForwardingFunction(that)
        };
    }

    shared actual
    void visitFunctionShortcutDefinition
            (FunctionShortcutDefinition that) {
        // skip native declarations entirely, for now
        if (!isForDartBackend(that)) {
            return;
        }

        addAll {
            generateFunctionDefinition(that),
            generateForwardingFunction(that)
        };
    }

    shared actual
    void visitInterfaceDefinition(InterfaceDefinition that) {
        value info = AnyInterfaceInfo(that);

        // skip native declarations entirely, for now
        if (!isForDartBackend(info)) {
            return;
        }

        // skip erased types
        if (info.declarationModel == ceylonTypes.identifiableDeclaration) {
            return;
        }

        value identifier
            =   dartTypes.dartIdentifierForClassOrInterfaceDeclaration(
                        info.declarationModel);

        value implementsTypes
            =   sequence(CeylonList(info.declarationModel.satisfiedTypes)
                        .filter(dartTypes.denotable)
                        .map((satisfiedType)
                =>  dartTypes.dartTypeName(info, satisfiedType, false)));


        "The containing class or interface, if one exists."
        value outerDeclaration
            =   getContainingClassOrInterface(info.scope.container);

        "An $outer getter declaration, if there is an outer class or interface."
        value outerField
            =   if (exists outerDeclaration) then
                    DartMethodDeclaration {
                        false;
                        null;
                        dartTypes.dartTypeName {
                            info;
                            outerDeclaration.type;
                            false; false;
                        };
                        "get";
                        dartTypes.identifierForOuter(outerDeclaration);
                        null;
                        null;
                    }
                else
                    null;

        value members
            =   { outerField,
                  *expand(that.body.transformChildren(classMemberTransformer))
                }.coalesced;

        value declarationsForCaptures
            =   ctx.captures.get(info.declarationModel).map {
                    (capture) => DartFieldDeclaration {
                        false;
                        DartVariableDeclarationList {
                            null;
                            dartTypes.dartTypeNameForDeclaration {
                                info;
                                capture;
                            };
                            [DartVariableDeclaration {
                                dartTypes.identifierForCapture(capture);
                                null;
                            }];
                        };
                    };
                };

        add {
            DartClassDeclaration {
                abstract = true;
                name = identifier;
                extendsClause = null;
                implementsClause =
                    if (exists implementsTypes)
                    then DartImplementsClause(implementsTypes)
                    else null;
                concatenate {
                    members,
                    declarationsForCaptures
                };
            };
        };
    }

    shared actual
    void visitObjectExpression(ObjectExpression that) {
        value info = ObjectExpressionInfo(that);

        add {
            generateClassDefinition {
                info;
                info.anonymousClass;
                that.body;
                that.extendedType;
            };
        };
    }

    shared actual
    void visitObjectArgument(ObjectArgument that) {
        value info = ObjectArgumentInfo(that);

        add {
            generateClassDefinition {
                info;
                info.anonymousClass;
                that.body;
                that.extendedType;
            };
        };
    }

    shared actual
    void visitObjectDefinition(ObjectDefinition that) {
        value info = ObjectDefinitionInfo(that);

        // skip native declarations entirely, for now
        if (!isForDartBackend(info)) {
            return;
        }

        // skip erased types
        // TODO Identifiable, but take a look
        //      at generated code first
        if (info.declarationModel in [
                ceylonTypes.nullValueDeclaration]) {
            return;
        }

        add {
            generateClassDefinition {
                info;
                info.anonymousClass;
                that.body;
                that.extendedType;
            };
        };

        if (isToplevel(info.declarationModel)) {
            // define toplevel value and forwarding function
            addAll {
                DartTopLevelVariableDeclaration {
                    generateForObjectDefinition(that);
                },
                *generateForwardingGetterSetter(that)
            };
        }
    }

    DartClassDeclaration generateClassDefinition(
            DScope scope, ClassModel classModel, ClassBody classBody,
            ExtendedType? extendedType, Parameters? parameters = null) {

        value identifier
            =   dartTypes.dartIdentifierForClassOrInterfaceDeclaration(classModel);

        value satisifesTypes
            =   sequence(CeylonList(classModel.satisfiedTypes)
                        .filter(dartTypes.denotable)
                        .map((satisfiedType)
                =>  dartTypes.dartTypeName(scope, satisfiedType, false)));

        value extendsClause
            =   if (exists et = classModel.extendedType,
                    !ceylonTypes.isCeylonBasic(classModel.extendedType)
                    && !ceylonTypes.isCeylonObject(classModel.extendedType))
                then  DartExtendsClause {
                    dartTypes.dartTypeName {
                        scope;
                        classModel.extendedType;
                        false;
                    };
                }
                else null;

        // TODO consolidate with similar visitInterfaceDefinition code?

        "Fields to capture initializer parameters. See also
         [[ClassMemberTransformer.transformValueDefinition]]."
        value fieldsForInitializerParameters
            =   (parameters?.parameters else []).collect {
                    (parameter) =>
                    let (model = ParameterInfo(parameter).parameterModel)
                    DartFieldDeclaration {
                        false;
                            DartVariableDeclarationList {
                                null;
                                dartTypes.dartTypeNameForDeclaration {
                                    scope;
                                    model.model;
                                };
                                [DartVariableDeclaration {
                                    DartSimpleIdentifier {
                                        dartTypes.getName(model);
                                    };
                                    initializer = null;
                                }];
                            };
                        };
                    };

        "Declarations for outer containers. We'll hold a reference to our immediate
         container, and access the rest through that."
        value outerDeclarations
            =   [*dartTypes.outerDeclarationsForClass(classModel)];

        "$outer field declaration, if any."
        value outerField
            =   outerDeclarations.take(1).map {
                    (outerDeclaration) =>
                    DartFieldDeclaration {
                        false;
                        DartVariableDeclarationList {
                            null;
                            dartTypes.dartTypeName {
                                scope;
                                outerDeclaration.type;
                                false; false;
                            };
                            [DartVariableDeclaration {
                                dartTypes.identifierForOuter {
                                    outerDeclaration;
                                };
                                null;
                            }];
                        };
                    };
                };

        "$outer getters for $outers that may be required by satisfied interfaces.
         Access through *our* outer."
        value outerForwarders
            // TODO We may also be picking up $outers handled by extended classes;
            //      if so, we should filter those out...
            =   outerDeclarations.skip(1).map {
                    (outerDeclaration) =>
                    DartMethodDeclaration {
                        false;
                        null;
                        dartTypes.dartTypeName {
                            scope;
                            outerDeclaration.type;
                            false; false;
                        };
                        "get";
                        dartTypes.identifierForOuter {
                            outerDeclaration;
                        };
                        null;
                        DartExpressionFunctionBody {
                            false;
                            assertExists {
                                dartTypes.expressionToThisOrOuterStripThis {
                                    dartTypes.ancestorChainToExactDeclaration {
                                        classModel;
                                        outerDeclaration;
                                    };
                                };
                            };
                        };
                    };
                };

        "declarations for captures we must hold references to."
        value captureDeclarations
            =   [*dartTypes.captureDeclarationsForClass(classModel)];

        "$capture field declarations, if any."
        value captureFields
            =   captureDeclarations.map {
                    (capture) => DartFieldDeclaration {
                        false;
                        DartVariableDeclarationList {
                            null;
                            dartTypes.dartTypeNameForDeclaration {
                                scope;
                                capture;
                            };
                            [DartVariableDeclaration {
                                dartTypes.identifierForCapture(capture);
                                null;
                            }];
                        };
                    };
                };

        value constructors
            =   if (!classModel.hasConstructors())
                then generateInitializerConstructors {
                    scope;
                    classModel;
                    classBody;
                    extendedType;
                    parameters?.parameters else [];
                }
                else generateConstructors {
                    scope;
                    classModel;
                    classBody;
                };

        "Class members. Statements (aside from Specification and Assertion statements) do
         not introduce members and are therefore not supported by
         [[ClassMemberTransformer]]."
        value members
            =   classBody.children
                    .narrow<Declaration|Specification|Assertion>()
                    .flatMap((d)
                        =>  d.transform(classMemberTransformer));

        "Functions and values for which the most refined member is contained by
         an Interface."
        value declarationsToBridge
            // Shouldn't there be a better way?
            =   supertypeDeclarations(classModel)
                    .flatMap((d) => CeylonList(d.members))
                    .narrow<FunctionOrValueModel>()
                    .filter(FunctionOrValueModel.shared)
                    .map(curry(mostRefined)(classModel))
                    .distinct
                    .map((m) => assertExists(m,
                        "Surely a most-refined implementation exists."))
                    .filter((m) => container(m) is InterfaceModel)
                    .filter((m) => container(m) != ceylonTypes.identifiableDeclaration)
                    .map((m) => asserted<FunctionOrValueModel>(m,
                        "Most refined function or value should be a function or value."))
                    .filter(not(FunctionOrValueModel.formal))
                    .sequence();

        value bridgeFunctions
            =   declarationsToBridge.map((f)
                =>  generateBridgeMethodOrField(scope, f));

        return
        DartClassDeclaration {
            classModel.abstract;
            identifier;
            extendsClause;
            implementsClause =
                if (exists satisifesTypes)
                then DartImplementsClause(satisifesTypes)
                else null;
            concatenate {
                outerField,
                outerForwarders,
                captureFields,
                constructors,
                fieldsForInitializerParameters,
                members,
                bridgeFunctions
            };
        };
    }

    [DartConstructorDeclaration*] generateInitializerConstructors(
            DScope scope, ClassModel classModel, ClassBody classBody,
            ExtendedType? extendedType, [Parameter*] parameters) {

        value identifier
            =   dartTypes.dartIdentifierForClassOrInterfaceDeclaration(classModel);

        "Class initializer parameters."
        value standardParameters
            =   if (!parameters.empty)
                then generateFormalParameterList(scope, parameters).parameters
                else [];

        value hasDefaultedParameter
            =   standardParameters.any((p) => p is DartDefaultFormalParameter);

        "Non-defaulted class initializer parameters."
        value standardParametersNonDefaulted
            =   hasDefaultedParameter then (
                if (!parameters.empty)
                then generateFormalParameterList(scope, parameters, true).parameters
                else []);

        "Explicit super call with arguments."
        value superInvocation
            =   generateSuperInvocation(extendedType);

        "Dart identifiers for each parameter."
        value parameterIdentifiers
            =   parameters.collect {
                    (p) => DartSimpleIdentifier {
                        dartTypes.getName {
                            ParameterInfo(p).parameterModel;
                        };
                    };
                };

        "Declarations for outer containers. We'll hold a reference to our immediate
         container, and access the rest through that."
        value outerDeclarations
            =   [*dartTypes.outerDeclarationsForClass(classModel)];

        "An $outer parameter, if there is an outer class or interface"
        value outerFieldConstructorParameter
            =   outerDeclarations.take(1).map {
                    (declaration) =>
                    DartFieldFormalParameter {
                        false; false;
                        dartTypes.dartTypeName {
                            scope;
                            declaration.type;
                            false; false;
                        };
                        dartTypes.identifierForOuter {
                            declaration;
                        };
                    };
                };

        "declarations for captures we must hold references to."
        value captureDeclarations
            =   [*dartTypes.captureDeclarationsForClass(classModel)];

        value captureConstructorParameters
            =   captureDeclarations.map {
                    (declaration) =>
                    DartFieldFormalParameter {
                        false; false;
                        dartTypes.dartTypeNameForDeclaration {
                            scope;
                            declaration;
                        };
                        dartTypes.identifierForCapture {
                            declaration;
                        };
                    };
                };

        value argsIdentifier
            =   DartSimpleIdentifier("a");

        value spreadConstructorName
            =   DartSimpleIdentifier("$s");

        value workerConstructorName
            =   hasDefaultedParameter then DartSimpleIdentifier("$w");

        function createSimpleFromFieldParameter(DartFieldFormalParameter p)
            =>  DartSimpleFormalParameter(p.const, p.final, p.type, p.identifier);

        "Resolves arguments against default value expressions, redirects to 'spread'
         constructor."
        value defaultsConstructor
            =   hasDefaultedParameter then (
                withInConstructorDefaults {
                    classModel;
                    () => DartConstructorDeclaration {
                        const = false;
                        factory = false;
                        returnType = identifier;
                        // The "defaults" constructor gets a `null` name; it is the public
                        // facing constructor
                        null;
                        DartFormalParameterList {
                            true; false;
                            concatenate {
                                // "redirecting" constructors cannot initialize fields,
                                // so remove "this." from the outer and capture
                                // parameters. (They will be initialized by the ultimate
                                // constructor).
                                outerFieldConstructorParameter
                                        .map(createSimpleFromFieldParameter),
                                captureConstructorParameters
                                        .map(createSimpleFromFieldParameter),
                                standardParameters
                            };
                        };
                        [DartRedirectingConstructorInvocation {
                            spreadConstructorName;
                            DartArgumentList {
                                [createExpressionEvaluationWithSetup {
                                    generateDefaultValueAssignments {
                                        scope;
                                        parameters.narrow<DefaultedParameter>();
                                    };
                                    DartListLiteral {
                                        false;
                                        concatenate {
                                            outerFieldConstructorParameter.map {
                                                DartFieldFormalParameter.identifier;
                                            },
                                            captureConstructorParameters.map {
                                                DartFieldFormalParameter.identifier;
                                            },
                                            parameterIdentifiers
                                        };
                                    };
                                }];
                            };
                        }];
                        null;
                        null;
                    };
                });

        "'Spread' constructor. Simply takes a dart Object[], and delegates to
         the 'worker' constructor"
        value spreadConstructor
            =   hasDefaultedParameter then (
                DartConstructorDeclaration {
                    const = false;
                    factory = false;
                    returnType = identifier;
                    spreadConstructorName;
                    DartFormalParameterList {
                        true; false;
                        [DartSimpleFormalParameter {
                            false; false;
                            dartTypes.dartList;
                            argsIdentifier;
                        }];
                    };
                    [DartRedirectingConstructorInvocation {
                        workerConstructorName;
                        DartArgumentList {
                            [ for (i in 0:(outerFieldConstructorParameter.size +
                                            captureConstructorParameters.size +
                                            standardParameters.size))
                                DartIndexExpression {
                                    argsIdentifier;
                                    DartIntegerLiteral(i);
                                }
                            ];
                        };
                    }];
                    null;
                    null;
                });

        "Constructor that does all the work. This constructor will have a private name if
         there are defaulted parameters."
        value workerConstructor
            =   DartConstructorDeclaration {
                    const = false;
                    factory = false;
                    returnType = identifier;
                    workerConstructorName;
                    DartFormalParameterList {
                        true; false;
                        concatenate {
                            outerFieldConstructorParameter,
                            captureConstructorParameters,
                            // this constructor never handles defaulted parameters
                            standardParametersNonDefaulted else standardParameters
                        };
                    };
                    if (exists superInvocation)
                        then [superInvocation]
                        else [];
                    null;
                    DartBlockFunctionBody {
                        null; false;
                        DartBlock {
                            concatenate {
                                // Assign parameters to corresponding 'this.' members.
                                // Eventually, we'll just do this for the ones we want to
                                // capture. Not supporting defaulted parameters yet.
                                parameterIdentifiers.map {
                                    // This might get ugly with replacements like
                                    // string/toString().
                                    (id) => DartExpressionStatement {
                                        DartAssignmentExpression {
                                            DartPrefixedIdentifier {
                                                DartSimpleIdentifier("this");
                                                id;
                                            };
                                            DartAssignmentOperator.equal;
                                            id;
                                        };
                                    };
                                },
                                *withInConstructor {
                                    classModel;
                                    () => classBody.transformChildren {
                                        classStatementTransformer;
                                    };
                                }
                            };
                        };
                    };
                };

        return
        [defaultsConstructor, spreadConstructor, workerConstructor].coalesced.sequence();
    }

    [DartConstructorDeclaration*] generateConstructors(
            DScope scope, ClassModel classModel, ClassBody classBody)
        =>  classBody.content.narrow<ConstructorDefinition>()
                .flatMap((c) => generateConstructor(c, classModel, classBody))
                .sequence();

    [DartConstructorDeclaration*] generateConstructor(
            ConstructorDefinition constructor,
            ClassModel classModel, ClassBody classBody) {

        value scope = NodeInfo(constructor);

        value classIdentifier
            =   dartTypes.dartIdentifierForClassOrInterfaceDeclaration(classModel);

        value info
            =   ConstructorInfo(constructor);

        value constructorModel
            =   info.constructorModel;

        if (exists et = constructorModel.extendedType,
            et.declaration is ConstructorModel) {
            throw CompilerBug(scope,
                "Extending constructors not yet supported.");
        }

        value extendedType
            =   constructor.extendedType;

        value parameters
            =   constructor.parameters.parameters;

        "Initializer parameters."
        value standardParameters
            =   if (!parameters.empty)
                then generateFormalParameterList(scope, parameters).parameters
                else [];

        value hasDefaultedParameter
            =   standardParameters.any((p) => p is DartDefaultFormalParameter);

        "Non-defaulted class initializer parameters."
        value standardParametersNonDefaulted
            =   hasDefaultedParameter then (
                if (!parameters.empty)
                then generateFormalParameterList(scope, parameters, true).parameters
                else []);


        "Explicit super call with arguments."
        value superInvocation
            =   generateSuperInvocation(extendedType);

        "Dart identifiers for each parameter."
        value parameterIdentifiers
            =   parameters.collect {
                    (p) => DartSimpleIdentifier {
                        dartTypes.getName {
                            ParameterInfo(p).parameterModel;
                        };
                    };
                };

        "Declarations for outer containers. We'll hold a reference to our immediate
         container, and access the rest through that."
        value outerDeclarations
            =   [*dartTypes.outerDeclarationsForClass(classModel)];

        "An $outer parameter, if there is an outer class or interface"
        value outerFieldConstructorParameter
            =   outerDeclarations.take(1).map {
                    (declaration) =>
                    DartFieldFormalParameter {
                        false; false;
                        dartTypes.dartTypeName {
                            scope;
                            declaration.type;
                            false; false;
                        };
                        dartTypes.identifierForOuter {
                            declaration;
                        };
                    };
                };

        "declarations for captures we must hold references to."
        value captureDeclarations
            =   [*dartTypes.captureDeclarationsForClass(classModel)];

        value captureConstructorParameters
            =   captureDeclarations.map {
                    (declaration) =>
                    DartFieldFormalParameter {
                        false; false;
                        dartTypes.dartTypeNameForDeclaration {
                            scope;
                            declaration;
                        };
                        dartTypes.identifierForCapture {
                            declaration;
                        };
                    };
                };

        value argsIdentifier
            =   DartSimpleIdentifier("a");

        value constructorPrefix
            =   dartTypes.getName(constructorModel);

        value constructorName
            // default constructors will have name of ""
            =   !constructorPrefix.empty
                then DartSimpleIdentifier(constructorPrefix);

        value spreadConstructorName
            =   DartSimpleIdentifier(constructorPrefix + "$s");

        value workerConstructorName
            =   if (hasDefaultedParameter)
                then DartSimpleIdentifier(constructorPrefix + "$w")
                else constructorName;

        function createSimpleFromFieldParameter(DartFieldFormalParameter p)
            =>  DartSimpleFormalParameter(p.const, p.final, p.type, p.identifier);

        "Resolves arguments against default value expressions, redirects to 'spread'
         constructor."
        value defaultsConstructor
            =   hasDefaultedParameter then (
                withInConstructorDefaults {
                    classModel;
                    () => DartConstructorDeclaration {
                        const = false;
                        factory = false;
                        returnType = classIdentifier;
                        // Defaults constructors are always public facing
                        constructorName;
                        DartFormalParameterList {
                            true; false;
                            concatenate {
                                // "redirecting" constructors cannot initialize fields,
                                // so remove "this." from the outer and capture
                                // parameters. (They will be initialized by the ultimate
                                // constructor).
                                outerFieldConstructorParameter
                                        .map(createSimpleFromFieldParameter),
                                captureConstructorParameters
                                        .map(createSimpleFromFieldParameter),
                                standardParameters
                            };
                        };
                        [DartRedirectingConstructorInvocation {
                            spreadConstructorName;
                            DartArgumentList {
                                [createExpressionEvaluationWithSetup {
                                    generateDefaultValueAssignments {
                                        scope;
                                        parameters.narrow<DefaultedParameter>();
                                    };
                                    DartListLiteral {
                                        false;
                                        concatenate {
                                            outerFieldConstructorParameter.map {
                                                DartFieldFormalParameter.identifier;
                                            },
                                            captureConstructorParameters.map {
                                                DartFieldFormalParameter.identifier;
                                            },
                                            parameterIdentifiers
                                        };
                                    };
                                }];
                            };
                        }];
                        null;
                        null;
                    };
                });

        "'Spread' constructor. Simply takes a dart Object[], and delegates to
         the 'worker' constructor"
        value spreadConstructor
            =   hasDefaultedParameter then (
                DartConstructorDeclaration {
                    const = false;
                    factory = false;
                    returnType = classIdentifier;
                    spreadConstructorName;
                    DartFormalParameterList {
                        true; false;
                        [DartSimpleFormalParameter {
                            false; false;
                            dartTypes.dartList;
                            argsIdentifier;
                        }];
                    };
                    [DartRedirectingConstructorInvocation {
                        workerConstructorName;
                        DartArgumentList {
                            [ for (i in 0:(outerFieldConstructorParameter.size +
                                            captureConstructorParameters.size +
                                            standardParameters.size))
                                DartIndexExpression {
                                    argsIdentifier;
                                    DartIntegerLiteral(i);
                                }
                            ];
                        };
                    }];
                    null;
                    null;
                });

        value constructorStatements
            =   classBody.children.takeWhile {
                    not(constructor.equals);
                }.chain {
                    constructor.block.children;
                }.chain {
                    classBody.children.skipWhile {
                        not(constructor.equals);
                    };
                }.sequence();

        "Constructor that does all the work. This constructor will have a private name if
         there are defaulted parameters."
        value workerConstructor
            =   DartConstructorDeclaration {
                    const = false;
                    factory = false;
                    returnType = classIdentifier;
                    workerConstructorName;
                    DartFormalParameterList {
                        true; false;
                        concatenate {
                            outerFieldConstructorParameter,
                            captureConstructorParameters,
                            // this constructor never handles defaulted parameters
                            standardParametersNonDefaulted else standardParameters
                        };
                    };
                    if (exists superInvocation)
                        then [superInvocation]
                        else [];
                    null;
                    DartBlockFunctionBody {
                        null; false;
                        DartBlock {
                            constructorStatements.flatMap((s)
                                =>  s.transform(classStatementTransformer)).sequence();
                        };
                    };
                };

        return
        [defaultsConstructor, spreadConstructor, workerConstructor].coalesced.sequence();
    }

    "Explicit super call with arguments."
    DartSuperConstructorInvocation? generateSuperInvocation(ExtendedType? extendedType) {
        if (exists extendedType) {
            value extensionOrConstruction = extendedType.target;

            if (is Construction extensionOrConstruction) {
                throw CompilerBug(extendedType, "Extending constructors not yet supported.");
            }

            "Arguments must exist for constructor or ininitializer extends"
            assert (exists arguments = extensionOrConstruction.arguments);

            if (!arguments.argumentList.children.empty) {

                value extensionOrConstructionInfo
                    =   ExtensionOrConstructionInfo(extensionOrConstruction);

                assert (exists parameterList
                    =   extensionOrConstructionInfo.declaration?.firstParameterList);

                assert (exists callableType
                    =   extensionOrConstructionInfo.typeModel);

                value signature
                    =   CeylonList {
                            ctx.unit.getCallableArgumentTypes(callableType.fullType);
                        };

                return
                DartSuperConstructorInvocation {
                    null;
                    generateArgumentListFromArguments {
                        extensionOrConstructionInfo;
                        arguments;
                        signature;
                        parameterList;
                    }[1];
                };
            }
        }
        return null;
    }

    shared actual
    void visitTypeAliasDefinition(TypeAliasDefinition that) {}

    [DartFunctionDeclaration*] generateForwardingGetterSetter
            (ValueDefinition | ValueGetterDefinition | ObjectDefinition that) {

        value info = NodeInfo(that);

        value declarationModel =
            switch (that)
            case (is ValueDefinition)
                ValueDefinitionInfo(that).declarationModel
            case (is ValueGetterDefinition)
                ValueGetterDefinitionInfo(that).declarationModel
            case (is ObjectDefinition)
                ObjectDefinitionInfo(that).declarationModel;

        value getter =
        DartFunctionDeclaration {
            external = false;
            returnType = dartTypes.dartTypeNameForDeclaration(
                info, declarationModel);
            propertyKeyword = "get";
            DartSimpleIdentifier {
                dartTypes.getName(declarationModel);
            };
            DartFunctionExpression {
                null;
                DartExpressionFunctionBody {
                    async = false;
                    DartSimpleIdentifier {
                        dartTypes.getPackagePrefixedName(declarationModel);
                    };
                };
            };
        };

        value setter = declarationModel.variable then
            DartFunctionDeclaration {
                external = false;
                returnType = null;
                propertyKeyword = "set";
                DartSimpleIdentifier {
                    dartTypes.getName(declarationModel);
                };
                DartFunctionExpression {
                    DartFormalParameterList {
                        positional = false;
                        named = false;
                        [DartSimpleFormalParameter {
                            final = false;
                            var = false;
                            type = dartTypes.dartTypeNameForDeclaration(
                                info, declarationModel);
                            identifier = DartSimpleIdentifier("value");
                        }];
                    };
                    DartExpressionFunctionBody {
                        async = false;
                        DartAssignmentExpression {
                            DartSimpleIdentifier {
                                dartTypes.getPackagePrefixedName(declarationModel);
                            };
                            DartAssignmentOperator.equal;
                            DartSimpleIdentifier("value");
                        };
                    };
                };
            };

        addAll {
            if (exists setter)
            then [getter, setter]
            else [getter];
        };

        return [];
    }

    "Transforms the declarations of the [[CompilationUnit]]. **Note:**
     imports are ignored."
    shared actual
    void visitCompilationUnit(CompilationUnit that)
        =>  that.declarations.each((d) => d.visit(this));

    shared actual default
    void visitNode(Node that) {
        throw CompilerBug(that,
            "Unhandled node (TopLevelVisitor): '``className(that)``'");
    }

    DartFunctionDeclaration generateForwardingFunction(AnyFunction that)
        =>  let (info = AnyFunctionInfo(that),
                functionName = dartTypes.getName(info.declarationModel),
                functionPPName = dartTypes.getPackagePrefixedName(info.declarationModel),
                parameterModels = CeylonList(
                        info.declarationModel.firstParameterList.parameters))
            DartFunctionDeclaration {
                external = false;
                generateFunctionReturnType(info, info.declarationModel);
                propertyKeyword = null;
                DartSimpleIdentifier(functionName);
                DartFunctionExpression {
                    generateFormalParameterList {
                        info;
                        that.parameterLists.first;
                    };
                    DartExpressionFunctionBody {
                        async = false;
                        expression = DartMethodInvocation {
                            target = null;
                            DartSimpleIdentifier(functionPPName);
                            DartArgumentList {
                                parameterModels.collect { (parameterModel) =>
                                    DartSimpleIdentifier {
                                        dartTypes.getName(parameterModel);
                                    };
                                };
                            };
                        };
                    };
                };
            };

    DartMethodDeclaration generateBridgeMethodOrField
            (DScope scope, FunctionOrValueModel declaration) {

        assert (is FunctionModel|ValueModel|SetterModel declaration);

        value [identifier, isFunction]
            =   dartTypes.dartIdentifierForFunctionOrValueDeclaration {
                    scope;
                    declaration;
                };

        value parameterModels
            =   switch (declaration)
                case (is FunctionModel)
                    CeylonList(declaration.firstParameterList.parameters)
                case (is SetterModel)
                    [declaration.parameter]
                case (is ValueModel)
                    [];

        value interfaceModel
            =   (declaration of TypedDeclarationModel).container;

        "The container of the target of a bridge method is surely an Interface."
        assert (is InterfaceModel interfaceModel);

        return
        DartMethodDeclaration {
            false; null;
            generateFunctionReturnType(scope, declaration);
            !isFunction then (
                if (declaration is SetterModel)
                then "set"
                else "get"
            );
            identifier;
            isFunction then generateFormalParameterList {
                scope;
                parameterModels;
            };
            DartExpressionFunctionBody {
                false;
                DartMethodInvocation {
                    dartTypes.dartIdentifierForClassOrInterface {
                        scope;
                        interfaceModel;
                    };
                    dartTypes.getStaticInterfaceMethodIdentifier {
                        declaration;
                    };
                    DartArgumentList {
                        [DartSimpleIdentifier("this"),
                         *parameterModels.collect { (parameterModel) =>
                            DartSimpleIdentifier {
                                dartTypes.getName(parameterModel);
                            };
                        }];
                    };
                };
            };
        };
    }
}
