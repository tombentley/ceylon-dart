import ceylon.interop.java {
    CeylonIterable,
    javaString,
    javaClass
}

import com.redhat.ceylon.cmr.api {
    ArtifactContext
}
import com.redhat.ceylon.compiler.js.loader {
    JsonModule
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.context {
    Context,
    PhasedUnits
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult
}
import com.redhat.ceylon.model.typechecker.model {
    ModuleImport,
    Module
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    FileInputStream
}
import java.lang {
    JString=String
}
import java.util {
    JMap=Map,
    JList=List,
    JLinkedList=LinkedList
}

import net.minidev.json {
    JSONValue
}

object reflection {
    value jasonModuleClass = javaClass<JsonModule>();
    value loadDeclarations = jasonModuleClass.getDeclaredMethod("loadDeclarations");
    loadDeclarations.accessible = true;

    // TODO pull request for ceylon-js to make this public
    shared void invokeLoadDeclarations(JsonModule jm)
        =>  loadDeclarations.invoke(jm);
}

shared
class DartModuleSourceMapper(Context context, ModuleManager moduleManager)
        extends ModuleSourceMapper(context, moduleManager) {

    void loadModuleFromMap(
            JMap<JString, Object> model,
            JsonModule m,
            JLinkedList<Module> dependencyTree,
            JList<PhasedUnits> phasedUnitsOfDependencies,
            Boolean forCompiledModule) {

        assert (is JList<out Anything>? dependencies
            =   model.get(javaString("$mod-deps")));

        "We'll always have dependencies; at least the language module."
        assert (exists dependencies);

        // clear the implicit langauge module import added by createModule()
        m.imports.clear();

        for (dependency in CeylonIterable(dependencies)) {
            // Add a ModuleImport to the module. The module will be resolved later, at
            // the request of ModuleValidator.

            String s;
            Boolean optional;
            Boolean export;

            assert (is JString | JMap<out Anything, out Anything> dependency);

            switch (dependency)
            case (is JMap<out Anything, out Anything>) {
                assert (is JString ss = dependency.get(javaString("path")));
                s = ss.string;
                optional = dependency.containsKey(javaString("opt"));
                export = dependency.containsKey(javaString("exp"));
            }
            case (is JString) {
                s = dependency.string;
                optional = false;
                export = false;
            }

            "There will always be a version separator, even if the version is the
             empty string."
            assert (exists slashIndex = s.firstOccurrence('/'));

            value dependencyName = s[0:slashIndex];

            value dependencyVersion = s[slashIndex+1...];

            "Version cannot be the empty string."
            assert (!dependencyVersion.empty);

            assert (is JsonModule dependencyModule = moduleManager.getOrCreateModule(
                            ModuleManager.splitModuleName(dependencyName),
                            dependencyVersion));

            // TODO This can't be right; dependencyModule hasn't yet been resolved
            //      Bug in JsModuleSourceMapper:73?
            value backends = dependencyModule.nativeBackends;

            value mi = ModuleImport(dependencyModule, optional, export, backends);

            m.addImport(mi);
        }

        model.remove(javaString("$mod-deps"));

        m.model = model;

        reflection.invokeLoadDeclarations(m); // the method is package private
    }

    shared actual
    void resolveModule(
            ArtifactResult artifact, Module m, ModuleImport? moduleImport,
            JLinkedList<Module> dependencyTree,
            JList<PhasedUnits> phasedUnitsOfDependencies,
            Boolean forCompiledModule) {

        "This should *always* be a JsonModule, right?"
        assert (is JsonModule m);

        if (m.model exists) {
            return;
        }

        "The json artifact for the model. The passed in artifact is no good; for the
         reason, see [[DartModuleManager.searchedArtifactExtensions]]"
        value modelAc
            =   ArtifactContext(artifact.name(), artifact.version(),
                                ArtifactContext.\iDART_MODEL);

        value modelAcResult
            =   context.repositoryManager.getArtifactResult(modelAc);

        value modelFile
            =   modelAcResult.artifact();

        "Unable to parse the model."
        assert (is JMap<out Anything, out Anything> jsonObject
            =   JSONValue.parse(FileInputStream(modelFile)));

        value model
            =   TypeHoles.unsafeCast<JMap<JString, Object>>(jsonObject);

        loadModuleFromMap(model, m, dependencyTree, phasedUnitsOfDependencies,
                forCompiledModule);
    }
}