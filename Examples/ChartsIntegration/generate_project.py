#!/usr/bin/env python3
"""Regenerate the standalone framework + public-import hosts; no third-party tooling."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parent
repo = root.parents[1]
objects = {}
def ident(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def add(key, isa, **fields):
    value = ident(key); objects[value] = dict(isa=isa, **fields); return value
def file(path, kind, tree='<group>'):
    return add('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree=tree)
def build(ref, key, **extra): return add('build:'+key, 'PBXBuildFile', fileRef=ref, **extra)
def phase(target, kind, files=(), **extra):
    return add(target+kind, 'PBX'+kind+'BuildPhase', buildActionMask='2147483647', files=list(files), runOnlyForDeploymentPostprocessing='0', **extra)
def configs(key, common, debug=None, release=None):
    ids=[]
    for name, more in [('Debug',debug or {}),('Release',release or {})]:
        ids.append(add(key+name,'XCBuildConfiguration',name=name,buildSettings={**common,**more}))
    return add(key+'configs','XCConfigurationList',buildConfigurations=ids,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
product_refs = {}
for name, ext, kind in [('HYMCharts','framework','wrapper.framework'),('SwiftHost','app','wrapper.application'),('OCHost','app','wrapper.application'),('IntegrationUITests','xctest','wrapper.cfbundle')]:
    product_refs[name] = file(name+'.'+ext,kind,'BUILT_PRODUCTS_DIR')
wrappers = {'BarChart.swift','ColumnChart.swift','CombinedChart.swift','HeatmapChart.swift','LineChart.swift','RadarChart.swift'}
source_paths = sorted(p for p in (repo/'SwiftFunctionProject/Charts').rglob('*.swift') if 'Debug' not in p.parts and ('SwiftUI' not in p.parts or p.name in wrappers))
framework_files = [file('../../'+str(p.relative_to(repo)), 'sourcecode.swift') for p in source_paths]
header = file('HYMCharts.h','sourcecode.c.h')
framework_settings = dict(PRODUCT_BUNDLE_IDENTIFIER='com.hoymiles.audit.HYMCharts',PRODUCT_NAME='$(TARGET_NAME)',DEFINES_MODULE='YES',SWIFT_INSTALL_OBJC_HEADER='YES',SWIFT_OBJC_INTERFACE_HEADER_NAME='HYMCharts-Swift.h',GENERATE_INFOPLIST_FILE='YES',SKIP_INSTALL='NO',INSTALL_PATH='$(LOCAL_LIBRARY_DIR)/Frameworks',DYLIB_INSTALL_NAME_BASE='@rpath',BUILD_LIBRARY_FOR_DISTRIBUTION='YES')
framework = add('target:HYMCharts','PBXNativeTarget',name='HYMCharts',productName='HYMCharts',productReference=product_refs['HYMCharts'],productType='com.apple.product-type.framework',buildConfigurationList=configs('HYMCharts',framework_settings),buildPhases=[phase('HYMCharts','Sources',[build(f,str(f)) for f in framework_files]),phase('HYMCharts','Headers',[build(header,'header',settings={'ATTRIBUTES':['Public']})]),phase('HYMCharts','Frameworks'),phase('HYMCharts','Resources')],buildRules=[],dependencies=[])
def dependency(target):
    proxy=add('proxy:'+target,'PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=ident('target:'+target),remoteInfo=target)
    return add('dependency:'+target,'PBXTargetDependency',target=ident('target:'+target),targetProxy=proxy)
all_refs=framework_files+[header]
neutral_sample = file('../ChartSpecifications/energy.json', 'text.json')
neutral_g1_sample = file('../ChartSpecifications/energy-g1-v2.json', 'text.json')
neutral_zones_sample = file('../ChartSpecifications/energy-zones-v3.json', 'text.json')
neutral_axes_sample = file('../ChartSpecifications/energy-axes-v4.json', 'text.json')
neutral_annotations_sample = file('../ChartSpecifications/energy-annotations-v5.json', 'text.json')
neutral_interaction_sample = file('../ChartSpecifications/energy-interaction-v6.json', 'text.json')
all_refs += [neutral_interaction_sample, neutral_sample, neutral_g1_sample, neutral_zones_sample, neutral_axes_sample, neutral_annotations_sample]
for name,kind in [('SwiftHost','sourcecode.swift'),('OCHost','sourcecode.c.objc')]:
    paths=sorted((root/name).glob('*.swift' if name=='SwiftHost' else '*.m'))
    refs=[file(str(p.relative_to(root)),kind) for p in paths]; all_refs+=refs
    settings=dict(PRODUCT_BUNDLE_IDENTIFIER='com.hoymiles.audit.'+name,PRODUCT_NAME='$(TARGET_NAME)',GENERATE_INFOPLIST_FILE='YES',INFOPLIST_KEY_UILaunchScreen_Generation='YES',INFOPLIST_KEY_UISupportedInterfaceOrientations='UIInterfaceOrientationPortrait',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks'],ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES='YES')
    add('target:'+name,'PBXNativeTarget',name=name,productName=name,productReference=product_refs[name],productType='com.apple.product-type.application',buildConfigurationList=configs(name,settings),buildPhases=[phase(name,'Sources',[build(f,name+f) for f in refs]),phase(name,'Frameworks',[build(product_refs['HYMCharts'],name+'link')]),phase(name,'Resources',[build(neutral_sample,name+'neutral-sample'), build(neutral_g1_sample,name+'neutral-g1-sample'), build(neutral_zones_sample,name+'neutral-zones-sample'), build(neutral_axes_sample,name+'neutral-axes-sample'), build(neutral_annotations_sample,name+'neutral-annotations-sample'), build(neutral_interaction_sample,name+'neutral-interaction-sample')]),phase(name,'CopyFiles',[build(product_refs['HYMCharts'],name+'embed',settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})],dstPath='',dstSubfolderSpec='10',name='Embed Frameworks')],buildRules=[],dependencies=[dependency('HYMCharts')])
ui=file('UITests/IntegrationUITests.swift','sourcecode.swift');all_refs.append(ui)
add('target:IntegrationUITests','PBXNativeTarget',name='IntegrationUITests',productName='IntegrationUITests',productReference=product_refs['IntegrationUITests'],productType='com.apple.product-type.bundle.ui-testing',buildConfigurationList=configs('IntegrationUITests',dict(PRODUCT_BUNDLE_IDENTIFIER='com.hoymiles.audit.IntegrationUITests',PRODUCT_NAME='$(TARGET_NAME)',GENERATE_INFOPLIST_FILE='YES',TEST_TARGET_NAME='SwiftHost')),buildPhases=[phase('IntegrationUITests','Sources',[build(ui,'uitest')]),phase('IntegrationUITests','Frameworks'),phase('IntegrationUITests','Resources')],buildRules=[],dependencies=[dependency('SwiftHost'),dependency('OCHost')])
products=add('products','PBXGroup',children=list(product_refs.values()),name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=all_refs+[products],sourceTree='<group>')
project_config=configs('project',dict(CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',SWIFT_VERSION='5.0',IPHONEOS_DEPLOYMENT_TARGET='15.0',SDKROOT='iphoneos',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',TARGETED_DEVICE_FAMILY='1,2',CODE_SIGN_STYLE='Automatic',SWIFT_STRICT_CONCURRENCY='minimal'),dict(SWIFT_OPTIMIZATION_LEVEL='-Onone',GCC_OPTIMIZATION_LEVEL='0',DEBUG_INFORMATION_FORMAT='dwarf',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG'),dict(SWIFT_OPTIMIZATION_LEVEL='-O',SWIFT_COMPILATION_MODE='wholemodule',DEBUG_INFORMATION_FORMAT='dwarf-with-dsym',VALIDATE_PRODUCT='YES'))
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'2630'},buildConfigurationList=project_config,compatibilityVersion='Xcode 14.0',developmentRegion='en',knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=[ident('target:'+n) for n in product_refs])
def encode(value, level=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(level+1)+json.dumps(k)+ ' = '+encode(v,level+1)+';\n' for k,v in value.items())+'\t'*level+'}'
    if isinstance(value,list): return '('+', '.join(encode(v,level) for v in value)+')'
    return json.dumps(str(value),ensure_ascii=False)
project_dir=root/'ChartsIntegration.xcodeproj';project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(dict(archiveVersion='1',classes={},objectVersion='56',objects=objects,rootObject=project))+'\n')
schemes=project_dir/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def reference(name):
    ext='framework' if name=='HYMCharts' else ('xctest' if name=='IntegrationUITests' else 'app')
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:"+name)}" BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:ChartsIntegration.xcodeproj"/>'
entries=''.join('<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+reference(n)+'</BuildActionEntry>' for n in product_refs)
(schemes/'ChartsIntegration.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>'+entries+'</BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'+reference('IntegrationUITests')+'</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+reference('SwiftHost')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+reference('SwiftHost')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>\n')
print(f'Generated framework with {len(framework_files)} Swift sources and two public-import hosts')
