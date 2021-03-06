#Designed by Wang Bin(Lucas Wang). 2013 <wbsecg1@gmail.com>

## TODO: put in .qmake.conf for Qt5?
exists(user.conf): include(user.conf)

##TODO: BUILD_DIR=>BUILD_ROOT
#if not empty, it means the parent project may already set it
isEmpty(out_dir):out_dir = $$OUT_PWD
out_dir ~= s,\\\\,/,g #avoid warning for '\'. qmake knows how to deal with '/'
isEmpty(SOURCE_ROOT):SOURCE_ROOT = $$PWD
SOURCE_ROOT ~= s,\\\\,/,g #avoid warning for '\'. qmake knows how to deal with '/'
isEmpty(BUILD_DIR):BUILD_DIR=$$out_dir
message("BUILD_DIR=$$BUILD_DIR")

greaterThan(QT_MAJOR_VERSION, 4) {
    mkspecs_build = $$[QMAKE_SPEC]
    #recheck:write_file($$BUILD_DIR/.qmake.cache) #FIXME: empty_file result in no qtCompileTest result in cache
    load(configure)
} else {
    mkspecs_build = $$[QMAKE_MKSPECS]
    _QMAKE_CACHE_QT4_ = $$_QMAKE_CACHE_
    #_QMAKE_CACHE_QT4_ is built in and always not empty
    isEmpty(_QMAKE_CACHE_QT4_)|isEqual(_QMAKE_CACHE_QT4_,) {
        _QMAKE_CACHE_QT4_=$$BUILD_DIR/.qmake.cache
    }
    include(common.pri)
    #recheck:write_file($$BUILD_DIR/.qmake.cache) #FIXME: empty_file result in no qtCompileTest result in cache
    #use the following lines when building as a sub-project, write cache to this project src dir.
    #if build this project alone and do not have sub-project depends on this lib, those lines are not necessary
    ####ASSUME compile tests and .qmake.cache is in project out root dir
    #vars in .qmake.cache will affect all projects in subdirs, even if qmake's working dir is not in .qmake.cache dir
    #write_file($$BUILD_DIR/.qmake.cache) ##TODO: erase the existing lines!!
    include(configure.pri)
#clear config.log iff reconfigure is required
    write_file($$QMAKE_CONFIG_LOG)
    #cache() is available after include configure.pri
    #load(configure.pri) #what's the difference?
    message("cache: $$_QMAKE_CACHE_QT4_")
}
mkspecs_build ~= s,\\\\,/,g #avoid warning for '\'. qmake knows how to deal with '/'

defineTest(qtRunCommandQuitly) {
    #win32 always call windows command
    win32 { #QMAKE_HOST.os?
      system("$$1 2>&1 >nul")|return(false)  #system always call win32 cmd
    } else {
      system("$$1 2>&1 >/dev/null")|return(false)
    }
    return(true)
}

defineTest(testArch) {
  test_dir = $$_PRO_FILE_PWD_/tests/arch
  test_out_dir = $$shadowed($$test_dir)
  qtRunCommandQuitly("$$QMAKE_MKDIR $$system_path($$test_out_dir)")  #mkpath. but common.pri may not included
  win32:test_cmd_base = "cd /d $$system_quote($$system_path($$test_out_dir)) &&"
  else:test_cmd_base = "cd $$system_quote($$system_path($$test_out_dir)) &&"
  # Disable qmake features which are typically counterproductive for tests
  qmake_configs = "\"CONFIG -= qt debug_and_release app_bundle lib_bundle\""
  # Clean up after previous run
  exists($$test_out_dir/Makefile):qtRunCommandQuitly("$$test_cmd_base $$QMAKE_MAKE distclean")

#message("$$test_cmd_base $$system_quote($$system_path($$QMAKE_QMAKE)) $$qmake_configs $$system_path($$test_dir)")
  qtRunCommandQuitly("$$test_cmd_base  $$system_quote($$system_path($$QMAKE_QMAKE)) $$qmake_configs $$system_path($$test_dir)") {
    MSG=$$system("$$test_cmd_base  $$QMAKE_MAKE 2>&1")
  }
  V = $$find(MSG, ARCH.*=.*)
  ARCH=
  ARCH_SUB=
  for(v, V) {
# "ARCH=x86". can not evalate with ". why \" may fail? eval("expr")
    v=$$replace(v, \", )
    eval("$$v")
  }
  export(ARCH)
  export(ARCH_SUB)
  cache(TARGET_ARCH, set, ARCH)
  cache(TARGET_ARCH_SUB, set, ARCH_SUB)
  message("target arch: $$ARCH")
  message("target arch features: $$ARCH_SUB")
}

#cache mkspecs. compare mkspec with cached one. if not equal, remove old cache to run new compile tests
#Qt5 does not have QMAKE_MKSPECS, use QMAKE_SPEC, QMAKE_XSPEC
isEmpty(mkspecs_cached)|!isEmpty(mkspecs_cached):!isEqual(mkspecs_cached, $$mkspecs_build) {
    CONFIG += recheck
    testArch()
} else {
    isEmpty(TARGET_ARCH):testArch()
}

cache(BUILD_DIR, set, BUILD_DIR)
#cache(BUILD_ROOT, set, BUILD_DIR)
cache(SOURCE_ROOT, set, SOURCE_ROOT)
cache(mkspecs_cached, set, mkspecs_build)

defineTest(runConfigTests) {
  no_config_tests:return(false)
#config.tests
  !isEmpty(EssentialDepends) {
    for(d, EssentialDepends) {
     !config_$$d {
       CONFIG *= recheck
     }
     qtCompileTest($$d)|error("$$d is required, but compiler can not find it")
  #   CONFIG -= recheck
    }
  }
  !isEmpty(OptionalDepends) {
    message("checking for optional features...")
    for(d, OptionalDepends) {
      qtCompileTest($$d)
    }
  }
  !isEmpty(EssentialDepends)|!isEmpty(OptionalDepends) {
    message("To recheck the dependencies, delete '.qmake.cache' in the root of build dir, run qmake with argument 'CONFIG+=recheck' or '-config recheck'")
  }
  return(true)
}

message("To disable config tests, you can use 1 of the following methods")
message("1. create '.qmake.conf' in the root source dir, add 'CONFIG += no_config_tests'(Qt5)")
message("2. pass 'CONFIG += no_config_tests' or '-config no_config_tests' to qmake")
message("3. add 'CONFIG += no_config_tests' in $$PWD/user.conf")
message("To manually set a config test result to true, disable config tests and enable config_name like above")
