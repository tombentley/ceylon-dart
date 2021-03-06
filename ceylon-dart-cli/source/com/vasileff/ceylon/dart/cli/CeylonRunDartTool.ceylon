import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.cmr.api {
    ModuleQuery
}
import com.redhat.ceylon.common {
    ModuleUtil
}
import com.redhat.ceylon.common.tool {
    argument=argument__SETTER,
    ToolError,
    rest=rest__SETTER,
    option=option__SETTER,
    optionArgument=optionArgument__SETTER,
    description=description__SETTER
}
import com.redhat.ceylon.common.tools {
    CeylonTool,
    RepoUsingTool
}
import com.vasileff.ceylon.dart.compiler {
    ReportableException,
    javaList
}

import java.lang {
    JString=String
}
import java.util {
    JList=List
}

shared
class CeylonRunDartTool() extends RepoUsingTool(repoUsingToolresourceBundle) {

    shared variable
    argument {
        argumentName="module";
        multiplicity="1";
        order=1;
    }
    String moduleString = "";

    shared variable rest
    JList<JString> args = javaList<JString> {};

    shared variable
    optionArgument
    description {
        "Link against the web compatible runtime. Defaults to 'false'.";
    }
    Boolean web = false;

    shared variable option
    description("Disable Ceylon version compatibility and language module availability \
                 checks (default is false)")
    Boolean disableCompatibilityCheck = false;

    shared variable option
    optionArgument {
        argumentName = "flags";
    }
    description {
        "Determines if and how compilation should be handled. \
         Allowed flags include: `never`, `once`, `force`, `check`."; }
    String compile = "never";

    shared variable
    optionArgument {
        longName = "run";
        argumentName = "toplevel";
    }
    description {
        "Specifies the fully qualified name of a toplevel method or class to run. \
         The indicated declaration must be shared by the <module> and have no \
         parameters. The format is: `qualified.package.name::classOrMethodName` with \
         `::` acting as separator between the package name and the toplevel class or \
         method name. (default: `<module>::run`)";
    }
    String? runDeclaration = null;

    shared actual
    void initialize(CeylonTool? ceylonTool) {
        // noop
    }

    shared actual
    suppressWarnings("expressionTypeNothing")
    void run() {
        try {
            value moduleName
                =   ModuleUtil.moduleName(moduleString);

            value moduleVersion
                =   checkModuleVersionsOrShowSuggestions(
                        repositoryManager,
                        moduleName,
                        ModuleUtil.moduleVersion(moduleString),
                        ModuleQuery.Type.\iDART,
                        null, null, null, null,
                        if (compile.empty) then "check" else compile) else "";

            value exitCode
                =   runDartToplevel {
                        moduleAndVersion = "``moduleName``/``moduleVersion``";
                        arguments = CeylonList(args).map(JString.string);
                        toplevel = runDeclaration;
                        web = web;
                        disableCompatibilityCheck =  disableCompatibilityCheck;
                        repositoryManager = repositoryManager;
                    };

            process.exit(exitCode);
        }
        catch (ReportableException e) {
            throw object extends ToolError(e.message, e.cause) {};
        }
    }
}
