import ceylon.collection {
    HashMap
}
import ceylon.file {
    parsePath,
    Path,
    Directory,
    File,
    lines
}
import ceylon.interop.java {
    createJavaObjectArray,
    createJavaStringArray
}
import ceylon.json {
    JsonObject=Object,
    parse
}
import ceylon.process {
    createProcess,
    currentOutput,
    currentError,
    currentInput
}

import com.redhat.ceylon.cmr.api {
    ArtifactContext,
    ModuleQuery,
    RepositoryManager
}
import com.redhat.ceylon.cmr.ceylon {
    RepoUsingTool
}
import com.redhat.ceylon.common {
    ModuleUtil
}
import com.redhat.ceylon.common.tool {
    argument=argument__SETTER,
    ToolError
}
import com.redhat.ceylon.common.tools {
    CeylonTool
}
import com.vasileff.ceylon.dart.compiler {
    ReportableException
}

import java.lang {
    ObjectArray
}
import java.nio.file {
    JFiles=Files,
    JPath=Path,
    FileAlreadyExistsException
}
import java.util {
    ListResourceBundle
}

shared
class CeylonRunDartTool() extends RepoUsingTool(resourceBundle) {

    shared variable
    argument {
        argumentName="module";
        multiplicity="1";
        order=1;
    }
    String moduleString = "";

    shared actual
    void initialize(CeylonTool? ceylonTool) {
        // noop
    }

    shared actual
    suppressWarnings("expressionTypeNothing")
    void run() {
        try {
            value exitCode = doRun();
            process.exit(exitCode);
        }
        catch (ReportableException e) {
            throw object extends ToolError(e.message, e.cause) {};
        }
    }

    function moduleFile(String moduleName, String? moduleVersion) {
        if (exists file = ceylonFile(repositoryManager.getArtifact(ArtifactContext(
                        moduleName, moduleVersion, ArtifactContext.\iDART)))) {
            return file;
        }
        throw ReportableException("Cannot find module: \
                 ``ModuleUtil.makeModuleName(moduleName, moduleVersion)``");
    }

    function moduleModelFile(String moduleName, String? moduleVersion) {
        if (exists file = ceylonFile(repositoryManager.getArtifact(ArtifactContext(
                        moduleName, moduleVersion, ArtifactContext.\iDART_MODEL)))) {
            return file;
        }
        throw ReportableException("Cannot find model metadata for module: \
                 ``ModuleUtil.makeModuleName(moduleName, moduleVersion)``");
    }

    function moduleModel(String moduleName, String? moduleVersion) {
        value modelFile = moduleModelFile(moduleName, moduleVersion);

        // There *has* to be a better way to parse a file!
        value parsedJson = parse("".join(lines(modelFile)));

        if (!is JsonObject parsedJson) {
            throw ReportableException(
                    "Unable to parse json model metadata for module: \
                     ``ModuleUtil.makeModuleName(moduleName, moduleVersion)``");
        }
        return parsedJson;
    }

    Integer doRun() {
        value dartPath = findDartInPath(process.environmentVariableValue("PATH"));
        if (!exists dartPath) {
            throw ReportableException("Cannot find dart executable in path.");
        }

        // Make sure the language module has been installed
        // Although, the program may actually import some other version...
        verifyLanguageModuleAvailability(repositoryManager);

        // TODO support default modules
        if (ModuleUtil.isDefaultModule(moduleString)) {
            throw ReportableException(
                    "Default modules not yet supported: ``moduleString``");
        }

        value moduleName
            =   ModuleUtil.moduleName(moduleString);

        value moduleVersion
            =   checkModuleVersionsOrShowSuggestions(
                    repositoryManager,
                    moduleName,
                    ModuleUtil.moduleVersion(moduleString),
                    ModuleQuery.Type.\iDART,
                    null, null) else null;

        value parsedJson
            =   moduleModel(moduleName, moduleVersion);

        value namesAndVersions
            =   parsedJson.getArray("$mod-deps").strings.map((dep)
                =>  [ModuleUtil.moduleName(dep),
                     ModuleUtil.moduleVersion(dep) else ""]);

        // TODO transitive dependencies
        value importedModules
            =   namesAndVersions.map((pair) {
                    if (exists name = pair.getFromFirst(0),
                        exists version = pair.getFromFirst(1)) {
                        return name -> moduleFile(name, version);
                    }
                    else {
                        return null;
                    }
                }).coalesced;

        value [packageRootPath, moduleMap]
            =   createTemporaryPackageRoot {
                    moduleName -> moduleFile(moduleName, moduleVersion),
                    *importedModules
                };

        assert (exists programModuleSymlink
            =   moduleMap[moduleName]?.string);

        value p
            =   createProcess {
                    command = dartPath.name;
                    arguments = [
                        "--package-root=" + packageRootPath.string,
                        programModuleSymlink];
                    path = dartPath.directory.path;
                    input = currentInput;
                    output = currentOutput;
                    error = currentError;
                };

        p.waitForExit();
        return p.exitCode else 0;
    }
}

[JPath, Map<String, JPath>] createTemporaryPackageRoot({<String->File>*} modules) {
    value moduleToLinkMap = HashMap<String, JPath>();

    // create temporary Dart package root directory
    value packageRootPath = JFiles.createTempDirectory("ceylon-run-dart");
    packageRootPath.toFile().deleteOnExit();

    // populate with modules
    for (name->file in modules) {
        variable JPath symLinkPath = packageRootPath;

        value nameParts = name.split('.'.equals);
        for (part in nameParts) {
            symLinkPath = symLinkPath.resolve(part);
            try {
                // this throws if "recreating" common dirs, like /com, since packages
                // may share leading path segments.
                JFiles.createDirectory(symLinkPath);
                symLinkPath.toFile().deleteOnExit();
            } catch (FileAlreadyExistsException e) {}
        }
        symLinkPath = symLinkPath.resolve(nameParts.last + ".dart");
        JFiles.createSymbolicLink(symLinkPath, javaPath(file));
        symLinkPath.toFile().deleteOnExit();
        moduleToLinkMap.put(name, symLinkPath);
    }
    return [packageRootPath, moduleToLinkMap];
}

File? findDartInPath(String? path) {
    assert (exists sep = operatingSystem.pathSeparator.first);

    // TODO handle Links, support windows (dart.exe?)
    return path?.split(sep.equals)
            ?.map(parsePath)
            ?.map(Path.resource)
            ?.narrow<Directory>()
            ?.flatMap((d) => d.files("dart"))
            ?.filter(File.executable)
            ?.first;
}

object resourceBundle extends ListResourceBundle() {
    shared actual ObjectArray<ObjectArray<Object>> contents
        =>  createJavaObjectArray([
                ["module.not.found", "Module {0} not found in the following repositories:"],
                ["missing.version.suggestion", "Not all repositories could be searched for matching modules/versions, try again using a specific version"],
                ["version.not.found", "Version {0} not found for module {1}"],
                ["missing.version", "Missing required version number for module {0}"],
                ["try.versions", "Try one of the following versions: "],
                ["compiling", "Source found for module {0}, compiling..."],
                ["compilation.failed", "Failed to compile sources"]
            ].map((e) => createJavaStringArray(e)));
}

void verifyLanguageModuleAvailability(RepositoryManager repositoryManager) {
    value version = `module`.version;

    value languageModuleFile = repositoryManager.getArtifact(
        ArtifactContext("ceylon.language", version, ArtifactContext.\iDART))
        else null;

    if (!exists languageModuleFile) {
        throw ReportableException(
              "The Ceylon/Dart language module version ``version`` was not found.
               Try installing with:

                   ceylon install-dart --out ~/.ceylon/repo");
    }
}